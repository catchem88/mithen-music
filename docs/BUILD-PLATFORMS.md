# Building MithenMusic on Windows

MithenMusic is a **Windows-only** fork of Limusic. Linux and macOS support, their bundle targets and
their release automation were removed, so this is the only build document. Tauri does not
cross-compile: build on Windows, for Windows.

The app is a Tauri 2 project (Rust core + SvelteKit SPA) that dynamically links **libmpv** (mpv API
2.x, i.e. mpv >= 0.35). "Getting it to build" is really "putting libmpv's import library on the
linker's search path"; "getting it to run" is "shipping the matching DLL next to the app."

## Prerequisites

- **Rust** with the **MSVC** toolchain (`rustup default stable-msvc`) and the Visual Studio Build
  Tools (C++). `dumpbin` and `lib` come from there.
- **Node + pnpm**, then install the UI deps once: `pnpm --dir ui install`.
- **WebView2** ships with Windows 10 (April 2018+) and Windows 11.
- No Tauri CLI install is needed: the scripts use the one in `ui/node_modules`.

## libmpv

1. Download a prebuilt **libmpv dev** package - the shinchiro `mpv-dev-x86_64-*.7z` builds
   ([releases](https://github.com/shinchiro/mpv-winbuild-cmake/releases); take the plain `x86_64`,
   **not** `-v3-`, which requires AVX2). It contains `libmpv-2.dll`, a MinGW import lib
   (`libmpv.dll.a`) and headers - **no `.def` and no `mpv.lib`**.
2. **Build an MSVC import library.** The MSVC linker cannot consume MinGW's `libmpv.dll.a`, so
   synthesise a `.def` from the DLL's own export table and turn it into `mpv.lib` (from a *Developer*
   PowerShell, so `dumpbin`/`lib` are on PATH):
   ```powershell
   $names = dumpbin /exports libmpv-2.dll |
     Select-String -Pattern '^\s+\d+\s+[0-9A-Fa-f]+\s+[0-9A-Fa-f]+\s+(\w+)' |
     ForEach-Object { $_.Matches[0].Groups[1].Value }
   @("EXPORTS") + ($names | ForEach-Object { "    $_" }) | Set-Content mpv.def -Encoding ascii
   lib /def:mpv.def /name:libmpv-2.dll /out:mpv.lib /machine:x64
   ```
   The Rust side only emits `cargo:rustc-link-lib=mpv` (pregenerated bindings), so the headers are
   not needed at build time.
3. **Lay the files out where the scripts expect them:**
   - `mpv.lib` -> `.libmpv/mpv.lib`
   - `libmpv-2.dll` -> `src-tauri/libmpv-2.dll` (it is listed under
     `tauri.windows.conf.json` -> `bundle.resources`, so the installer places it next to the exe).
     It is ~117 MB - gitignored, never commit it.

   Both scripts pin `RUSTFLAGS` to `-L native=<repo>/.libmpv` themselves and refuse to run if
   `mpv.lib` is missing. Set it the same way by hand if you build manually: cargo hashes `RUSTFLAGS`
   into every unit's fingerprint, so a different value between `check` and `build` rebuilds the whole
   graph.

## Building

- **Develop / run loop** (no LTO, no installer):
  ```powershell
  scripts\dev-run.cmd            # builds the frontend if needed, then runs target\fast\mithenmusic-app.exe
  scripts\dev-run.cmd -Check     # cargo check only
  scripts\dev-run.cmd -NoRun     # build, do not launch
  ```
  `[profile.fast]` in `Cargo.toml` inherits `release` (opt-level 3, no debug assertions) with
  `lto = false` and `codegen-units = 16`, so a relink takes seconds instead of minutes.
- **Release installer:**
  ```powershell
  scripts\build-windows-installer.cmd              # -> target\release\bundle\nsis\... ; copied to res\MithenMusic-setup.exe
  scripts\build-windows-installer.cmd -SkipFrontend
  ```
  This builds the frontend, builds the Explorer thumbnail DLL, runs `tauri build --bundles nsis`
  (thin LTO, one codegen unit, symbols stripped) and copies the result to
  `res\MithenMusic-setup.exe`. It is slow - minutes, not seconds.

Run the `.cmd` wrappers rather than the `.ps1` files: PowerShell script execution is disabled by
default on some machines, and the `.cmd` wrappers re-invoke the scripts with `-ExecutionPolicy
Bypass`.

## Validating a build

1. **Audio plays** - search a song, hear it.
2. **Gapless** - queue 3+ tracks; transitions have no gap.
3. **Loudness** - quiet and loud tracks sound roughly equally loud (attenuation only).
4. **Media keys** - the keyboard's play/pause and next/previous control playback, and the Windows
   media flyout shows title/artist/artwork with a working scrubber (SMTC).
5. **Login** - the Google sign-in webview populates the library.
6. **Settings persist** - change quality / history / a disabled client, relaunch, values stick.
7. **Queue restore** - play a queue, quit, relaunch; it comes back paused at the saved position.
8. **Watcher history** (signed in, history on) - a track played ~30s appears in
   music.youtube.com history.
9. **Installer** - installs into `Program Files`, asks for a language, honours `/S`, offers to reset
   settings over an older install, and uninstalls without leaving anything behind.
10. **Shell integration** - double-clicking a supported audio file plays it, Explorer draws album-art
    thumbnails, and the Information window's source button opens the YouTube page (or reveals a local
    file in its folder).

Bare unsigned bundles (no code signing), so expect an "unidentified developer" / SmartScreen prompt
on first launch.
