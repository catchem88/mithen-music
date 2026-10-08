//! Windows Explorer thumbnail handler for MithenMusic.
//!
//! Explorer calls this in-process to draw a thumbnail for an audio file. It reads the file's first
//! embedded picture and hands back a bitmap; files with no artwork return nothing, so Explorer
//! falls back to the default icon. Registration lives in the installer
//! (`src-tauri/windows/hooks.nsh`), which writes the CLSID below and wires it to each supported
//! extension.

#![cfg(windows)]
#![allow(non_snake_case)]

use std::io::Cursor;
use std::sync::Mutex;

use windows::core::{implement, Interface, Ref, Result, BOOL, GUID, HRESULT, IUnknown};
use windows::Win32::Foundation::{
    CLASS_E_CLASSNOTAVAILABLE, CLASS_E_NOAGGREGATION, E_FAIL, E_NOINTERFACE, E_POINTER, S_FALSE, S_OK,
};
use windows::Win32::Graphics::Gdi::{
    CreateDIBSection, DeleteObject, BITMAPINFO, BITMAPINFOHEADER, BI_RGB, DIB_RGB_COLORS, HBITMAP,
};
use windows::Win32::Graphics::Imaging::{
    IWICImagingFactory, CLSID_WICImagingFactory, GUID_WICPixelFormat32bppPBGRA,
    WICBitmapDitherTypeNone, WICBitmapInterpolationModeFant, WICBitmapPaletteTypeCustom,
    WICDecodeMetadataCacheOnDemand,
};
use windows::Win32::System::Com::{
    CoCreateInstance, IClassFactory, IClassFactory_Impl, IStream, CLSCTX_INPROC_SERVER,
};
use windows::Win32::UI::Shell::PropertiesSystem::{IInitializeWithStream, IInitializeWithStream_Impl};
use windows::Win32::UI::Shell::{IThumbnailProvider, IThumbnailProvider_Impl, WTSAT_ARGB};

/// The COM class of this handler. The installer writes this GUID into the registry; keep the two in
/// step (`CLSID_THUMBNAIL_PROVIDER` in `src-tauri/windows/hooks.nsh`).
const CLSID_THUMBNAIL_PROVIDER: GUID = GUID::from_u128(0x6e9b2c1a_5d3f_4a7b_9e21_3c4d5e6f7a80);

/// A handler instance. `bytes` is the whole audio file, read on `Initialize`.
#[implement(IThumbnailProvider, IInitializeWithStream)]
struct ThumbnailProvider {
    bytes: Mutex<Vec<u8>>,
}

impl IInitializeWithStream_Impl for ThumbnailProvider_Impl {
    fn Initialize(&self, pstream: Ref<'_, IStream>, _grfmode: u32) -> Result<()> {
        let stream = pstream.ok()?;
        // Audio files are small; cap the read so a bogus stream can't exhaust Explorer's memory.
        const MAX_BYTES: usize = 256 * 1024 * 1024;
        let mut data = Vec::new();
        let mut buf = vec![0u8; 64 * 1024];
        loop {
            let mut read = 0u32;
            unsafe { stream.Read(buf.as_mut_ptr() as *mut _, buf.len() as u32, Some(&mut read)).ok()? };
            if read == 0 {
                break;
            }
            data.extend_from_slice(&buf[..read as usize]);
            if data.len() >= MAX_BYTES {
                break;
            }
        }
        if let Ok(mut slot) = self.bytes.lock() {
            *slot = data;
        }
        Ok(())
    }
}

impl IThumbnailProvider_Impl for ThumbnailProvider_Impl {
    fn GetThumbnail(
        &self,
        cx: u32,
        phbmp: *mut HBITMAP,
        pdwalpha: *mut windows::Win32::UI::Shell::WTS_ALPHATYPE,
    ) -> Result<()> {
        if phbmp.is_null() || pdwalpha.is_null() {
            return Err(E_POINTER.into());
        }
        unsafe {
            *phbmp = HBITMAP::default();
            *pdwalpha = WTSAT_ARGB;
        }
        let bytes = self.bytes.lock().map_err(|_| E_FAIL)?;
        match album_art_bitmap(&bytes, cx) {
            Some(bmp) => {
                unsafe { *phbmp = bmp };
                Ok(())
            }
            None => Err(E_FAIL.into()),
        }
    }
}

/// The class factory Explorer uses to spin up a handler.
#[implement(IClassFactory)]
struct ThumbnailClassFactory;

impl IClassFactory_Impl for ThumbnailClassFactory_Impl {
    fn CreateInstance(
        &self,
        punkouter: Ref<'_, IUnknown>,
        riid: *const GUID,
        ppvobject: *mut *mut core::ffi::c_void,
    ) -> Result<()> {
        unsafe {
            if ppvobject.is_null() {
                return Err(E_POINTER.into());
            }
            *ppvobject = std::ptr::null_mut();
            if punkouter.ok().is_ok() {
                return Err(CLASS_E_NOAGGREGATION.into());
            }
            let obj: IUnknown = ThumbnailProvider { bytes: Mutex::new(Vec::new()) }.into();
            if *riid == IThumbnailProvider::IID {
                let p: IThumbnailProvider = obj.cast()?;
                *ppvobject = p.into_raw();
                Ok(())
            } else if *riid == IInitializeWithStream::IID {
                let p: IInitializeWithStream = obj.cast()?;
                *ppvobject = p.into_raw();
                Ok(())
            } else if *riid == IUnknown::IID {
                *ppvobject = obj.into_raw();
                Ok(())
            } else {
                Err(E_NOINTERFACE.into())
            }
        }
    }

    fn LockServer(&self, _flock: BOOL) -> Result<()> {
        Ok(())
    }
}

#[no_mangle]
extern "system" fn DllGetClassObject(
    rclsid: *const GUID,
    riid: *const GUID,
    ppv: *mut *mut core::ffi::c_void,
) -> HRESULT {
    if ppv.is_null() || rclsid.is_null() || riid.is_null() {
        return E_POINTER;
    }
    unsafe {
        *ppv = std::ptr::null_mut();
        if *rclsid != CLSID_THUMBNAIL_PROVIDER {
            return CLASS_E_CLASSNOTAVAILABLE;
        }
        let factory: IUnknown = ThumbnailClassFactory.into();
        if *riid == IClassFactory::IID {
            match factory.cast::<IClassFactory>() {
                Ok(f) => {
                    *ppv = f.into_raw();
                    S_OK
                }
                Err(e) => e.code(),
            }
        } else if *riid == IUnknown::IID {
            *ppv = factory.into_raw();
            S_OK
        } else {
            E_NOINTERFACE
        }
    }
}

#[no_mangle]
extern "system" fn DllCanUnloadNow() -> HRESULT {
    // Nothing outlives a handler in a way that matters; let the module stay loaded.
    S_FALSE
}

/// The first embedded picture of `bytes`, decoded and scaled to fit within `max` pixels a side.
fn album_art_bitmap(bytes: &[u8], max: u32) -> Option<HBITMAP> {
    let art = first_picture(bytes)?;
    unsafe { wic_bitmap(&art, max) }
}

fn first_picture(bytes: &[u8]) -> Option<Vec<u8>> {
    use lofty::prelude::TaggedFileExt;
    // `Probe::read` alone does not sniff the format; the file is read from a stream (no extension to
    // fall back on), so guess from the content first.
    let probe = lofty::probe::Probe::new(Cursor::new(bytes)).guess_file_type().ok()?;
    let tagged = probe.read().ok()?;
    let tag = tagged.primary_tag().or_else(|| tagged.first_tag())?;
    let pic = tag.pictures().first()?;
    Some(pic.data().to_vec())
}

unsafe fn wic_bitmap(encoded: &[u8], max: u32) -> Option<HBITMAP> {
    let factory: IWICImagingFactory =
        CoCreateInstance(&CLSID_WICImagingFactory, None, CLSCTX_INPROC_SERVER).ok()?;
    let stream = factory.CreateStream().ok()?;
    stream.InitializeFromMemory(encoded).ok()?;
    let decoder =
        factory.CreateDecoderFromStream(&stream, std::ptr::null(), WICDecodeMetadataCacheOnDemand).ok()?;
    let frame = decoder.GetFrame(0).ok()?;
    let (mut w, mut h) = (0u32, 0u32);
    frame.GetSize(&mut w, &mut h).ok()?;
    if w == 0 || h == 0 {
        return None;
    }
    let (tw, th) = fit(w, h, max);

    let scaler = factory.CreateBitmapScaler().ok()?;
    scaler.Initialize(&frame, tw, th, WICBitmapInterpolationModeFant).ok()?;
    let converter = factory.CreateFormatConverter().ok()?;
    converter
        .Initialize(
            &scaler,
            &GUID_WICPixelFormat32bppPBGRA,
            WICBitmapDitherTypeNone,
            None,
            0.0,
            WICBitmapPaletteTypeCustom,
        )
        .ok()?;

    let stride = tw * 4;
    let mut pixels = vec![0u8; (stride * th) as usize];
    converter.CopyPixels(std::ptr::null(), stride, &mut pixels).ok()?;

    let mut bmi = BITMAPINFO::default();
    bmi.bmiHeader.biSize = std::mem::size_of::<BITMAPINFOHEADER>() as u32;
    bmi.bmiHeader.biWidth = tw as i32;
    bmi.bmiHeader.biHeight = -(th as i32); // top-down, matching WIC's row order
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB.0;

    let mut bits: *mut core::ffi::c_void = std::ptr::null_mut();
    let hbmp = CreateDIBSection(None, &bmi, DIB_RGB_COLORS, &mut bits, None, 0).ok()?;
    if bits.is_null() {
        let _ = DeleteObject(hbmp.into());
        return None;
    }
    std::ptr::copy_nonoverlapping(pixels.as_ptr(), bits as *mut u8, pixels.len());
    Some(hbmp)
}

/// Scale `w`x`h` to fit a `max`x`max` box, preserving aspect and never upscaling.
fn fit(w: u32, h: u32, max: u32) -> (u32, u32) {
    if max == 0 || (w <= max && h <= max) {
        return (w, h);
    }
    let scale = max as f64 / w.max(h) as f64;
    (
        ((w as f64 * scale).round() as u32).max(1),
        ((h as f64 * scale).round() as u32).max(1),
    )
}
