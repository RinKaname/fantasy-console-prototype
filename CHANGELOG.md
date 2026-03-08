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
