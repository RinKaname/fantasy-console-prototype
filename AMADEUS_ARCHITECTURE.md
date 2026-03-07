# Amadeus: 8-Bit Fantasy Console Architecture & Requirements

Amadeus is a next-generation 8-bit fantasy console. Inspired by platforms like PICO-8 and Pixel Vision 8, it allows users to build and play retro-style games within a strict, simulated hardware environment.

This document outlines the core architecture, language choices, features, and roadmap needed to build Amadeus.

---

## 1. Core Architecture

The architecture of Amadeus is divided into two primary layers: a high-performance, safe engine written in Rust, and an accessible scripting environment for game developers using Lua.

### Host Engine (Rust)
The core engine will be written in **Rust**. Rust is chosen for its:
*   **Memory Efficiency:** No garbage collection overhead, ensuring steady framerates.
*   **Safety:** The compiler prevents data races and memory leaks, ensuring the engine itself never crashes during gameplay.
*   **Performance:** Native C-like performance for rendering pixels, handling audio, and processing inputs.

**Engine Responsibilities:**
*   Window creation and OS event loop (e.g., using `winit` or `sdl2`).
*   Fast software/hardware-accelerated 2D rendering (e.g., using `wgpu`, `pixels`, or `minifb`).
*   Audio synthesis and playback (e.g., using `cpal` or `rodio`).
*   Simulated hardware state management (managing VRAM, palette RAM, and sprite RAM as fixed-size arrays).
*   Embedding and sandboxing the guest language.

### Guest Language (Lua)
The games played on Amadeus will be written in **Lua**. Lua is chosen for its:
*   **Ease of Use:** Lightweight, easy to learn, and the industry standard for fantasy consoles.
*   **Embedding:** Exceptional compatibility with Rust via crates like `mlua` or `rlua`.

**Bridging Rust and Lua:**
The Rust engine will expose a strict API to the embedded Lua environment. For example, a Rust function `draw_sprite_to_vram(x, y, id)` will be exposed to Lua as simply `spr(x, y, id)`. The Lua environment will be fully sandboxed, preventing game scripts from accessing the host OS file system or internet.

---

## 2. Configurable 8-Bit Constraints ("Chips")

Like Pixel Vision 8, Amadeus will feature customizable "hardware" constraints. Users can configure the "chips" of their virtual console to emulate classic hardware (like the NES or Game Boy) or invent their own restrictions.

Configurable constraints should include:
*   **Resolution:** Adjustable internal rendering resolution (e.g., 128x128, 160x144, 256x240).
*   **Color Palette:** Limit the number of simultaneously displayable colors (e.g., 4, 16, 64, or 256 colors) from a master palette.
*   **Sprite Memory:** Limit the total number of 8x8 sprites loaded in memory (e.g., 256 or 512).
*   **Sprite Limits per Scanline/Frame:** Enforce hardware flicker if too many sprites are drawn.
*   **Audio Channels:** Limit concurrent audio channels (e.g., 4 channels: Pulse, Pulse, Triangle, Noise).
*   **Cartridge Size:** Limit the total size of the game code and assets (e.g., 32KB or 64KB).

---

## 3. Built-in Tooling (Optional Workspace Mode)

To support a complete desktop experience, Amadeus should include an integrated workspace or a suite of built-in tools, allowing users to build games entirely within the console environment.

*   **Code Editor:** A simple text editor with syntax highlighting for Lua.
*   **Sprite Editor:** A tool to draw pixel art sprites and manage the color palette.
*   **Map Editor:** A tilemap editor for designing levels, including collision flags.
*   **SFX Tracker:** A tool to synthesize sound effects based on waveforms.
*   **Music Tracker:** A pattern-based sequencer for composing chiptunes.

*Alternatively, Amadeus can run in a "Runtime Only" mode, where users write code in external editors (like VS Code) and create art in external tools (like Aseprite), while Amadeus simply reloads and runs the project folder.*

---

## 4. Target Platforms

Because it is built in Rust, Amadeus can be highly portable:
*   **Desktop:** Native binaries for Windows, macOS, and Linux.
*   **Web:** The Rust engine can be compiled to **WebAssembly (WASM)**, allowing Amadeus to run natively in modern web browsers, enabling easy game sharing.

---

## 5. Development Roadmap

If you were to start building Amadeus today, here is a suggested step-by-step roadmap:

### Phase 1: The Core Loop
1.  Initialize a Rust project (`cargo new amadeus`).
2.  Open a window and implement a game loop using `winit` and a simple pixel buffer crate like `pixels`.
3.  Create a simulated VRAM array in Rust (e.g., `[u8; 128 * 128]`) and render it to the window every frame.

### Phase 2: Lua Integration
4.  Embed a Lua runtime using `mlua`.
5.  Create a Lua script (`game.lua`) with `_init()`, `_update()`, and `_draw()` functions.
6.  Call these Lua functions from your Rust game loop.

### Phase 3: The API
7.  Implement basic drawing functions in Rust (clear screen, put pixel, draw rectangle).
8.  Expose these functions to Lua (e.g., `cls()`, `pset()`, `rect()`).
9.  Implement input handling (keyboard/gamepad) in Rust and expose a `btn()` function to Lua.

### Phase 4: Assets and Constraints
10. Implement sprite sheet loading and a `spr()` drawing function.
11. Implement a customizable constraint configuration file (e.g., `config.json` that defines resolution and palette).

### Phase 5: Audio & Tooling
12. Integrate an audio synthesis library in Rust and expose SFX/Music APIs.
13. (Optional) Begin building the in-console UI for the Sprite and Map editors.
