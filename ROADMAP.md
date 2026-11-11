# Roadmap

## Next

- Play Wario Land through to the end and fix what breaks.
- Check battery saves survive a restart.
- Compare audio against the original hardware.
- A PyBoy ground-truth trace (`--use-trace`) so more code is reached statically.

## Later

- A headless mode (`--headless --record out.mp4`) and a conformance harness, per the shared recomp house style.
- A recomp-launcher entry (`launcher/launcher.json`).
- Fix gb-recompiled's generated `CMakeLists.txt` (missing C++20 and the menu sources) so this repo's hand-kept copy can go.

## Out of scope

- Shipping the ROM, or anything generated from it.
