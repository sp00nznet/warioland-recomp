#!/usr/bin/env bash
# Quick-start setup for the Wario Land recompilation (Linux, macOS).
#
# Runs the same commands as README "Step by step", skipping steps that are
# already done, so a rerun after a failure resumes. Your ROM is copied to
# generated/rom.gb and never leaves your machine. Output also goes to setup.log.
#
#   ./setup.sh [--yes] [path/to/rom.gb or folder]
set -eo pipefail
cd "$(dirname "$0")"
exec > >(tee setup.log) 2>&1

KNOWN_SHA1=ae65800302438e37a99e623a71d1c954d73c843e
MATCH='wario ?land|mario ?land ?3|sml3'
EXCLUDE='^$'
TITLE='Wario Land'
YES=0; GAME=''
for a in "$@"; do case "$a" in -y|--yes) YES=1 ;; *) GAME="$a" ;; esac; done

fail() { echo; echo "Setup stopped: $*"; echo "Details are in setup.log"; exit 1; }
step() { echo; echo "[$1/5] $2"; }
ask()  { [ $YES = 1 ] && { echo "$1 yes"; return 0; }; read -r -p "$1 [y/N] " r; [[ $r =~ ^[Yy] ]]; }
sha1() { if command -v sha1sum >/dev/null; then sha1sum "$1"; else shasum "$1"; fi | cut -d' ' -f1; }

# 1. Tools: a C/C++ compiler, CMake, Ninja, SDL2, git
step 1 'Checking the tools'
need=()
for t in cc c++ cmake ninja git; do command -v $t >/dev/null || need+=($t); done
pkg-config --exists sdl2 2>/dev/null || command -v sdl2-config >/dev/null || need+=(sdl2)
if [ ${#need[@]} -gt 0 ]; then
    echo "Missing: ${need[*]}"
    if command -v apt-get >/dev/null; then cmd='sudo apt-get install -y build-essential cmake ninja-build libsdl2-dev git pkg-config'
    elif command -v dnf >/dev/null; then cmd='sudo dnf install -y gcc gcc-c++ cmake ninja-build SDL2-devel git pkgconf'
    elif command -v pacman >/dev/null; then cmd='sudo pacman -S --needed --noconfirm base-devel cmake ninja sdl2 git'
    elif command -v brew >/dev/null; then cmd='brew install cmake ninja sdl2 git pkg-config'
    else fail "install ${need[*]} with your package manager and rerun."; fi
    ask "Install them now with: $cmd ?" || fail "install ${need[*]} and rerun."
    $cmd
fi

# 2. Source: a git clone gets gbrecomp/ from its submodule; a zip download has none.
step 2 'Checking the source'
if [ ! -f gbrecomp/runtime/CMakeLists.txt ]; then
    if [ ! -d .git ]; then
        git init -q && git remote add origin https://github.com/sp00nznet/warioland-recomp.git
        git fetch -q --depth 1 origin main && git reset -q FETCH_HEAD
    fi
    git submodule update --init --recursive
fi

# 3. ROM
step 3 'Finding your ROM'
mkdir -p generated
if [ ! -f generated/rom.gb ]; then
    src=''
    if [ -n "$GAME" ]; then
        [ -f "$GAME" ] && src="$GAME" || src="$(find "$GAME" -maxdepth 1 -name '*.gb' | head -1)"
    else
        src="$(find roms . ~/Downloads ~/Desktop ~/Documents -maxdepth 1 -name '*.gb' 2>/dev/null | grep -iE "$MATCH" | grep -viE "$EXCLUDE" | head -1)"
        [ -n "$src" ] && { echo "  Found: $src"; ask '  Use this file?' || src=''; }
    fi
    if [ -z "$src" ]; then
        [ $YES = 1 ] && fail "no $TITLE ROM found. Pass its path: ./setup.sh --yes path/to/rom.gb"
        read -r -p "Path to your $TITLE ROM (.gb): " src
    fi
    [ -f "$src" ] || fail "no .gb file at '$src'."
    cp "$src" generated/rom.gb
fi
sha=$(sha1 generated/rom.gb)
[ "$sha" = "$KNOWN_SHA1" ] || echo "  Warning: the ROM (SHA-1 $sha) is not the tested dump ($KNOWN_SHA1). It may not work."

# 4. Recompiler, then C from the ROM. The recompiler also writes a
# CMakeLists.txt and rom_main.c; this repo ships its own, so those are removed.
step 4 'Building the recompiler and recompiling the ROM'
if [ ! -x gbrecomp/build/bin/gbrecomp ]; then
    cmake -S gbrecomp -B gbrecomp/build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build gbrecomp/build --target gbrecomp
fi
if [ ! -f generated/rom.c ] || [ generated/rom.gb -nt generated/rom.c ]; then
    gbrecomp/build/bin/gbrecomp generated/rom.gb -o generated
    rm -f generated/CMakeLists.txt generated/rom_main.c
else echo '  Already done (skipping).'; fi

# 5. The game
step 5 'Building the game (a few minutes the first time)'
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build

echo
echo "Done. Play with: ./build/rom"
