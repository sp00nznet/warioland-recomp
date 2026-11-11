# Quick-start setup for the Wario Land recompilation (Windows).
#
# Runs the same commands as README "Step by step", in order, skipping steps
# that are already done, so a rerun after a failure resumes. Your ROM is copied
# to generated\rom.gb in this folder and never leaves your machine. Everything
# it prints also goes to setup.log.
#
#   -Game <folder or file>  where your ROM is (.gb, or a .zip holding one)
#   -Yes                    install what's missing and pick the ROM without asking
param([switch]$Yes, [Alias('GameDir')][string]$Game = '')

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$Log = Join-Path $Root 'setup.log'
Start-Transcript -Path $Log -Force | Out-Null

$Msys = 'C:\msys64'
$Bin = "$Msys\mingw64\bin"
$Packages = 'mingw-w64-x86_64-gcc', 'mingw-w64-x86_64-cmake', 'mingw-w64-x86_64-ninja', 'mingw-w64-x86_64-SDL2', 'git'
$RepoUrl = 'https://github.com/sp00nznet/warioland-recomp.git'
$KnownSha1 = 'AE65800302438E37A99E623A71D1C954D73C843E'
$Match = 'wario ?land|mario ?land ?3|sml3'
$Steps = 7
$Play = 'Wario Land (recomp).cmd'

function Fail($msg) {
    Write-Host ''
    Write-Host "Setup stopped: $msg" -ForegroundColor Red
    Write-Host "Details are in $Log"
    Stop-Transcript | Out-Null
    exit 1
}
function Step($n, $msg) { Write-Host ''; Write-Host "[$n/$Steps] $msg" -ForegroundColor Cyan }
function Ask($q) { if ($Yes) { Write-Host "$q yes"; return $true }; (Read-Host "$q [y/N]") -match '^(y|yes)$' }
function Run($exe) {
    # Echo it, run it, fail on a non-zero exit. Output is indented so a tool's
    # own "[3/20] ..." lines (ninja) aren't mistaken for this script's steps.
    Write-Host "  > $exe $($args -join ' ')"
    $ErrorActionPreference = 'Continue'   # stderr lines are output here, not errors
    & $exe @args 2>&1 | ForEach-Object { Write-Host "  $_" }
    if ($LASTEXITCODE -ne 0) { Fail "'$exe' exited with code $LASTEXITCODE." }
}

# The .gb files in a folder, or the one file given, with any inside .zip files
# unpacked to a temp folder. Best first: the tested dump, then a matching name.
function Find-Roms($where) {
    $files = if (Test-Path $where -PathType Leaf) { @(Get-Item $where) } else { @(Get-ChildItem $where -File -ErrorAction SilentlyContinue) }
    $roms = @($files | Where-Object Extension -eq '.gb')
    $tmp = Join-Path $env:TEMP 'warioland-recomp-rom'
    foreach ($z in $files | Where-Object Extension -eq '.zip') {
        try {
            $zip = [IO.Compression.ZipFile]::OpenRead($z.FullName)
            foreach ($e in $zip.Entries | Where-Object { $_.Name -like '*.gb' }) {
                $out = Join-Path $tmp "$($z.BaseName)\$($e.Name)"
                New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
                $roms += Get-Item $out
            }
            $zip.Dispose()
        } catch { Write-Host "  Skipping $($z.Name): not a readable zip." }
    }
    $roms | Sort-Object { ((Get-FileHash $_.FullName -Algorithm SHA1).Hash -ne $KnownSha1) }, { $_.Name -notmatch $Match }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem

# 1. MSYS2 (compiler toolchain)
Step 1 'Checking for MSYS2 (the compiler)'
if (-not (Test-Path "$Msys\usr\bin\pacman.exe")) {
    Write-Host 'MSYS2 provides the C compiler, CMake and SDL2 this build needs.'
    Write-Host 'It installs to C:\msys64 (about 500 MB with the packages).'
    if (-not (Ask 'Install MSYS2 now with winget?')) { Fail 'MSYS2 is required. Install it from https://www.msys2.org and rerun Setup.cmd.' }
    Run winget install -e --id MSYS2.MSYS2 --accept-package-agreements --accept-source-agreements
    if (-not (Test-Path "$Msys\usr\bin\pacman.exe")) { Fail 'MSYS2 did not install to C:\msys64. Install it from https://www.msys2.org and rerun.' }
}
$env:PATH = "$Bin;$Msys\usr\bin;$env:PATH"

# 2. Packages
Step 2 'Checking the compiler packages'
$missing = @($Packages | Where-Object { & "$Msys\usr\bin\pacman.exe" -Q $_ 2>$null | Out-Null; $LASTEXITCODE -ne 0 })
if ($missing.Count -gt 0) {
    Write-Host "Missing: $($missing -join ', ') (about 400 MB from the MSYS2 mirrors)."
    if (-not (Ask 'Install them now?')) { Fail 'the compiler packages are required.' }
    Run "$Msys\usr\bin\pacman.exe" -S --needed --noconfirm @missing
}

# 3. Source. A git clone gets gbrecomp/ from its submodule; a zip download has none.
Step 3 'Checking the source'
if (-not (Test-Path 'gbrecomp\runtime\CMakeLists.txt')) {
    if (-not (Test-Path '.git')) {
        Run git init -q
        Run git remote add origin $RepoUrl
        Run git fetch -q --depth 1 origin main
        Run git reset -q FETCH_HEAD
    }
    # longpaths: nested submodule metadata can pass Windows' 260-char limit.
    Run git -c core.longpaths=true submodule update --init --recursive
}

# 4. ROM
Step 4 'Finding your ROM'
New-Item -ItemType Directory -Force 'generated' | Out-Null
if (-not (Test-Path 'generated\rom.gb')) {
    $where = $Game.Trim('"', ' ')
    $roms = @()
    if ($where) {
        if (-not (Test-Path $where)) { Fail "there's no file or folder at '$where'." }
        $roms = @(Find-Roms $where)
        if ($roms.Count -eq 0) { Fail "there's no .gb file (or .zip holding one) in '$where'." }
    } else {
        foreach ($d in "$Root\roms", $Root, "$HOME\Downloads", "$HOME\Desktop", "$HOME\Documents") {
            $roms += @(Find-Roms $d | Where-Object { $_.Name -match $Match })
        }
    }
    $src = $null
    if ($roms.Count -gt 0) {
        Write-Host "  Found: $($roms[0].FullName)"
        if (Ask '  Use this file?') { $src = $roms[0].FullName }
    }
    if (-not $src) {
        if ($Yes) { Fail 'no Wario Land ROM was found. Give its folder or file with -Game.' }
        $p = (Read-Host 'Path to your Wario Land ROM (.gb or .zip)').Trim('"')
        $src = (@(Find-Roms $p) | Select-Object -First 1).FullName
        if (-not $src) { Fail "no .gb file at '$p'." }
    }
    Copy-Item $src 'generated\rom.gb'
}
$sha = (Get-FileHash 'generated\rom.gb' -Algorithm SHA1).Hash
if ($sha -ne $KnownSha1) {
    Write-Host "  Warning: the ROM (SHA-1 $sha) is not the tested dump ($KnownSha1). It may not work." -ForegroundColor Yellow
}

# 5. Recompiler
Step 5 'Building the recompiler'
if (-not (Test-Path 'gbrecomp\build-mingw\bin\gbrecomp.exe')) {
    Run cmake -S gbrecomp -B gbrecomp/build-mingw -G Ninja
    Run cmake --build gbrecomp/build-mingw --target gbrecomp
}

# 6. Generate C from the ROM. The recompiler also writes a CMakeLists.txt and
# rom_main.c; this repo ships its own, so those two are removed.
Step 6 'Recompiling the ROM to C (seconds)'
if (-not (Test-Path 'generated\rom.c') -or (Get-Item 'generated\rom.c').LastWriteTime -lt (Get-Item 'generated\rom.gb').LastWriteTime) {
    Run gbrecomp\build-mingw\bin\gbrecomp.exe generated\rom.gb -o generated
    Remove-Item 'generated\CMakeLists.txt', 'generated\rom_main.c' -ErrorAction SilentlyContinue
} else { Write-Host '  Already done (skipping).' }

# 7. Build the game
Step 7 'Building the game (a few minutes the first time)'
Run cmake -S . -B build-mingw -G Ninja
Run cmake --build build-mingw

Set-Content -Path (Join-Path $Root $Play) -Encoding ascii -Value "@echo off`r`nstart """" ""%~dp0build-mingw\rom.exe"""

Write-Host ''
Write-Host "Done. Double-click ""$Play"" in this folder to play." -ForegroundColor Green
Stop-Transcript | Out-Null
