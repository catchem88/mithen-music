# Builds the Windows NSIS installer and copies it to res/MithenMusic-setup.exe.
#
#   ./scripts/build-windows-installer.ps1
#   ./scripts/build-windows-installer.ps1 -SkipFrontend   # reuse the last ui/build
#
# Requirements: Node + pnpm, the Rust MSVC toolchain, the Tauri CLI (`npm i -g @tauri-apps/cli` or
# `cargo install tauri-cli`), and src-tauri/libmpv-2.dll present (fetched at build time, not tracked).

param(
    [switch]$SkipFrontend
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root

$tauri = $null
# Prefer the .cmd shim: the npm .ps1 shim is blocked when PowerShell script execution is disabled.
if (Get-Command tauri.cmd -ErrorAction SilentlyContinue) { $tauri = (Get-Command tauri.cmd).Source }
elseif (Get-Command cargo-tauri -ErrorAction SilentlyContinue) { $tauri = 'cargo-tauri' }
elseif (Get-Command tauri -ErrorAction SilentlyContinue) { $tauri = 'tauri' }
else { throw "Tauri CLI not found. Install it with 'npm i -g @tauri-apps/cli' or 'cargo install tauri-cli'." }

if (-not (Test-Path 'src-tauri/libmpv-2.dll')) {
    Write-Warning 'src-tauri/libmpv-2.dll is missing; the bundle will fail to run without it.'
}

if (-not $SkipFrontend) {
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

Write-Host '==> Building the Explorer thumbnail handler'
cargo build -p thumbnail-provider --release
if ($LASTEXITCODE -ne 0) { throw "thumbnail-provider build failed ($LASTEXITCODE)" }
Copy-Item -Force (Join-Path $root 'target/release/mithenmusic_thumbnail.dll') (Join-Path $root 'src-tauri/mithenmusic-thumbnail.dll')

Write-Host "==> Building the NSIS installer ($tauri build --bundles nsis)"
# beforeBuildCommand emptied: the frontend was just built (Tauri would otherwise run `pnpm build`
# from the repo root, which has no package.json). Passed as a config file, not inline JSON: the npm
# `.cmd` shim strips the quotes from an inline `--config '{...}'`.
$override = Join-Path $env:TEMP 'mithenmusic-tauri-override.json'
'{"build":{"beforeBuildCommand":""}}' | Set-Content -Path $override -Encoding utf8
try {
    & $tauri build --bundles nsis --config $override
    if ($LASTEXITCODE -ne 0) { throw "tauri build failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -Force $override -ErrorAction SilentlyContinue
}

$nsisDir = Join-Path $root 'target/release/bundle/nsis'
if (-not (Test-Path $nsisDir)) { $nsisDir = Join-Path $root 'src-tauri/target/release/bundle/nsis' }
$setup = Get-ChildItem $nsisDir -Filter 'MithenMusic_*_x64-setup.exe' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $setup) { throw "No installer found in $nsisDir" }

$res = Join-Path $root 'res'
New-Item -ItemType Directory -Force -Path $res | Out-Null
$dest = Join-Path $res 'MithenMusic-setup.exe'
Copy-Item -Force $setup.FullName $dest
Write-Host "==> Installer ready: $dest"
