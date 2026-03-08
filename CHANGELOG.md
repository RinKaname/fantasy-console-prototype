# Amadeus Changelog

All notable changes to the Amadeus 8-bit Fantasy Console project will be documented in this file.

## [Unreleased]

### Added
**Phase 1: Architecture & Planning**
- Added `AMADEUS_ARCHITECTURE.md`: Documented the Rust + Lua hybrid architecture, target resolution (NES 256x240), tooling scope, and the 5-phase development roadmap.
- Added `AMADEUS_CONTENT.md`: Documented the "Steins;Gate 0" visual and audio aesthetic requirements, including the "Makise" and "IBN-5100" palettes, hacker terminal font, and sci-fi boot logo.

**Phase 1: The Core Loop**
- Initialized the Cargo workspace with two crates: `amadeus-engine` (core logic library) and `amadeus-player` (desktop runtime binary).
- Implemented the 256x240 Video RAM buffer in Rust (`Vec<u8>`).
- Set up the desktop player using `winit` for window management and `pixels` for scaling the VRAM buffer and rendering it to the GPU at a capped 60 FPS.

**Phase 2: Lua Integration**
- Embedded the `mlua` 5.4 runtime directly into `amadeus-engine`.
- Bridged the Rust Game Loop to Lua, executing user-defined `_init()`, `_update()`, and `_draw()` functions from external cartridges.
- Implemented **Option C: Dynamic Palette RAM**:
  - Added a 256-color slot array to the console state.
  - Hardcoded the Steins;Gate inspired "Makise" 16-color palette into slots 0-15.
- Added the first Lua APIs:
  - `cls(color_index)`: Clears the screen to a specific palette color.
  - `pset(x, y, color_index)`: Draws a single pixel at `(x, y)`.
  - `set_color(index, r, g, b)`: Dynamically changes the color of a palette slot.

**Phase 3: The API (Input)**
- Implemented an 8-button virtual controller state array in the Rust engine (Left, Right, Up, Down, A, B, Start, Select).
- Captured physical OS keyboard inputs in `amadeus-player` using `winit_input_helper` and passed the states to the engine before every frame.
- Added the Lua API:
  - `btn(index)`: Returns `true` if a virtual button (0-7) is currently pressed.
- Created `cart.lua` (an interactive test cartridge) demonstrating user movement, screen clearing, dynamic palette swapping, and drawing primitives using the new APIs.

**Phase 4: Assets and Constraints**
- Added `config.json` support to the `amadeus-player` to override hardware constraints.
  - Users can customize the internal rendering resolution (e.g., 256x240 or 128x128).
  - Users can select a default boot palette (e.g., `makise` or `ibn5100`).
- Implemented a 128x128 Sprite RAM (16,384 bytes) to store up to 256 8x8 tiles as color indices.
- Added `image` crate integration to load standard `sprites.png` files, automatically mapping RGB pixels to the closest active palette index (using Color 0 as the transparent background).
- Added the Lua API:
  - `spr(id, x, y, [flip_x], [flip_y], [width], [height])`: Draws an 8x8 tile from the Sprite RAM to the screen. Supports horizontal/vertical flipping and multi-tile drawing (e.g., drawing a 2x2 grid of tiles at once).
- Created a sample 16x16 PNG `sprites.png` and updated the `cart.lua` to draw an interactive character instead of a pixel.

**Phase 5: Audio Engine**
- Integrated the `rodio` crate to handle asynchronous audio output.
- Built a 4-channel procedural synthesizer in `amadeus-engine/src/audio.rs` that generates waveforms mathematically at runtime, mimicking physical hardware.
- Implemented the "ROM" of built-in Steins;Gate themed audio assets:
  - `0`: UI Blip
  - `1`: Error Buzz
  - `2`: Nixie Click
  - `3`: System Startup
  - `10`: "Okarin" Beep
- Added the Lua API:
  - `sfx(id)`: Plays the specified synthesized sound effect on the next available audio channel.
- Updated `cart.lua` to trigger sound effects on startup, when colliding with screen boundaries, and when pressing buttons.

**Phase 6: Text Rendering**
- Created `amadeus-engine/src/font.rs` containing a hardcoded 5x7 "Hacker Terminal" bitmap font (supporting ASCII letters, numbers, and basic punctuation).
- Added the Lua API:
  - `print(text, x, y, color)`: Draws a string of text to the screen using the built-in bitmap font.
- Updated `carts/snake.lua` to use the `print` API to render a live scoreboard and a styled "SYSTEM FAILURE" Game Over screen with clear restart instructions.