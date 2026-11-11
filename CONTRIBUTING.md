# Contributing

Issues and pull requests are welcome.

- **Never attach or commit the ROM, or anything generated from it** (`generated/`, `rom.c`, `rom_rom.c`, save files). Pull requests that include them are closed.
- Runtime or recompiler fixes belong in [sp00nznet/gb-recompiled](https://github.com/sp00nznet/gb-recompiled), the submodule; this repo then bumps the pointer.
- A bug report is most useful with: what you did, what you saw, the frame or screenshot, your OS, and whether your ROM's SHA-1 matches the one in the README.
- Test both setup routes (`Setup.cmd` / `setup.sh` and the step-by-step commands) from a clean folder if you change either.
