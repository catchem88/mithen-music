//! Manual test harness for the installed thumbnail handler.
//!
//!     cargo run -p thumbnail-provider --example thumb -- "C:\path\to\file.mp3"
//!
//! Creates the handler by its registered CLSID (so this exercises the installed DLL, not the source),
//! feeds it the file stream, and reports whether Explorer would get a bitmap back.

#![cfg(windows)]

use windows::core::{Interface, GUID, HSTRING, PCWSTR};
use windows::Win32::Graphics::Gdi::HBITMAP;
use windows::Win32::System::Com::{
    CoCreateInstance, CoInitializeEx, IStream, CLSCTX_INPROC_SERVER, COINIT_APARTMENTTHREADED,
    STGM_READ,
};
use windows::Win32::UI::Shell::PropertiesSystem::IInitializeWithStream;
use windows::Win32::UI::Shell::{IThumbnailProvider, SHCreateStreamOnFileEx, WTS_ALPHATYPE};

const CLSID: GUID = GUID::from_u128(0x6e9b2c1a_5d3f_4a7b_9e21_3c4d5e6f7a80);

fn main() {
    let path = std::env::args().nth(1).expect("usage: thumb <file>");
    unsafe {
        CoInitializeEx(None, COINIT_APARTMENTTHREADED).ok().expect("CoInitializeEx");

        let provider: IThumbnailProvider = match CoCreateInstance(&CLSID, None, CLSCTX_INPROC_SERVER) {
            Ok(p) => p,
            Err(e) => {
                println!("CoCreateInstance failed: 0x{:08X}", e.code().0 as u32);
                return;
            }
        };
        println!("handler created");

        let s = HSTRING::from(path.as_str());
        let stream = match SHCreateStreamOnFileEx(
            PCWSTR(s.as_ptr()),
            STGM_READ.0,
            0,
            false,
            None::<&IStream>,
        ) {
            Ok(v) => v,
            Err(e) => {
                println!("SHCreateStreamOnFileEx failed: 0x{:08X}", e.code().0 as u32);
                return;
            }
        };

        let init: IInitializeWithStream = provider.cast().expect("cast to IInitializeWithStream");
        match init.Initialize(&stream, STGM_READ.0) {
            Ok(()) => println!("initialized"),
            Err(e) => {
                println!("Initialize failed: 0x{:08X}", e.code().0 as u32);
                return;
            }
        }

        let mut hbmp = HBITMAP::default();
        let mut alpha = WTS_ALPHATYPE(0);
        match provider.GetThumbnail(256, &mut hbmp, &mut alpha) {
            Ok(()) => println!("GetThumbnail OK: hbmp={:?} alpha={}", hbmp.0, alpha.0),
            Err(e) => println!("GetThumbnail failed: 0x{:08X}", e.code().0 as u32),
        }
    }
}
