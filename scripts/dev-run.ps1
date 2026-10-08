# Fast developer loop: build the app with the `fast` profile (no LTO, parallel codegen) and run it.
# Use this while iterating on the YouTube-facing code; ship with build-windows-installer.ps1.
#
#   ./scripts/dev-run.ps1              # build (frontend if needed) and launch
#   ./scripts/dev-run.ps1 -Check       # cargo check only - fastest, no codegen and no link
#   ./scripts/dev-run.ps1 -NoRun       # build, do not launch
#   ./scripts/dev-run.ps1 -Frontend    # force a frontend rebuild first
#
# Requirements: MSVC toolchain and the libmpv import library at .libmpv/mpv.lib
# (see docs/BUILD-PLATFORMS.md). The app loads libmpv-2.dll from its own directory, so it is copied
# next to the exe.

param(
    [switch]$Check,
    [switch]$NoRun,
    [switch]$Frontend
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root

if (-not (Test-Path '.libmpv/mpv.lib')) {
    throw "'.libmpv/mpv.lib' not found - build the libmpv import library first (docs/BUILD-PLATFORMS.md)."
}
# Pin RUSTFLAGS here rather than passing it ad hoc: cargo hashes RUSTFLAGS into every unit's
# fingerprint, so toggling it between check and build throws the whole cache away. Same value for both.
$env:RUSTFLAGS = "-L native=$root\.libmpv"

if ($Check) {
    Write-Host '==> cargo check --profile fast'
    cargo check --profile fast -p mithenmusic-app
    if ($LASTEXITCODE -ne 0) { throw "cargo check failed ($LASTEXITCODE)" }
    return
}

if ($Frontend -or -not (Test-Path 'ui/build')) {
    # `pnpm` may only be reachable through corepack (or its .ps1 shim is blocked), so resolve it.
    $pnpm = $null
    $pnpmArgs = @()
    if (Get-Command pnpm.cmd -ErrorAction SilentlyContinue) { $pnpm = 'pnpm.cmd' }
    elseif (Get-Command pnpm -ErrorAction SilentlyContinue) { $pnpm = 'pnpm' }
    elseif (Get-Command corepack -ErrorAction SilentlyContinue) { $pnpm = 'corepack'; $pnpmArgs = @('pnpm') }
    else { throw "pnpm not found. Install it with 'corepack enable' or 'npm i -g pnpm'." }

    Write-Host '==> Building the frontend'
    & $pnpm @pnpmArgs --dir ui build
    if ($LASTEXITCODE -ne 0) { throw "frontend build failed ($LASTEXITCODE)" }
}

Write-Host '==> cargo build --profile fast'
cargo build --profile fast -p mithenmusic-app
if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }

Copy-Item -Force (Join-Path $root 'src-tauri/libmpv-2.dll') (Join-Path $root 'target/fast/libmpv-2.dll')

$exe = Join-Path $root 'target/fast/mithenmusic-app.exe'
if (-not (Test-Path $exe)) { throw "expected $exe to exist after the build" }

if ($NoRun) {
    Write-Host "==> Built: $exe"
    return
}

# Single instance hands off to an already-running copy, so a relaunch would silently do nothing.
if (Get-Process mithenmusic-app -ErrorAction SilentlyContinue) {
    Write-Warning 'mithenmusic-app.exe is already running - the new build will only hand off to it. Close it first.'
}

Write-Host "==> Launching $exe"
& $exe
