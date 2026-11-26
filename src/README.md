# Super Mario Engine (x86 Assembly)

**Course:** CS401 / COAL Lab Semester Project  
**Institution:** FAST-NUCES Chiniot-Faisalabad Campus

## Group Members

- **Asmad Nadeem (`25F-0537`):** Main program entry, constants, level map, sprite data, and Mode 13h graphics/tile engine (`src/mario.asm`, `src/gfx.asm`, `build.bat`)
- **Faisal Shahzad (`25F-0619`):** Custom `INT 9` keyboard ISR, `INT 8` timer chaining, horizontal camera scrolling, and 8.8 fixed-point physics/collisions (`src/phys.asm`)
- **Umar Saleem (`25F-0545`):** Goomba/Koopa/Shell AI, block/mushroom mechanics, 32-bit scoring, HUD, and game state machine (`src/game.asm`, `README.md`, `MARIO.COM`)

## Build & Run Instructions (DOSBox + NASM)

1. Open DOSBox and mount the project folder as `C:`.
2. Assemble the binary and run:

   ```dos
   nasm src/mario.asm -f bin -o MARIO.COM
   MARIO.COM
   ```

## Controls

- **Left / Right Arrow:** Move Mario
- **Left Shift:** Run / Sprint
- **Spacebar:** Jump
- **P:** Pause / Resume game
- **Enter:** Select menu option / Continue
- **Esc:** Return to Title Screen / Exit

## Memory & Video Layout

- **Video Mode:** BIOS `INT 10h` Mode `0x13` (320x200, 256 colors, linear framebuffer at `0xA000:0000`)
- **Double Buffer:** Off-screen segment at `CS + 0x1000` (64,000 bytes blitted via `REP MOVSW`)
- **Hardware Interrupts Hooked:** `INT 0x08` (System Timer) and `INT 0x09` (Keyboard Controller)
