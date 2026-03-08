# Amadeus: 8-Bit Fantasy Console

**Amadeus** is a high-performance, fully customizable 8-bit fantasy game console. Inspired by platforms like PICO-8 and Pixel Vision 8, it allows users to build and play retro-style games within strict, simulated hardware environments.

Amadeus features a distinct, moody, retro-tech aesthetic heavily inspired by the "Amadeus" AI system from the *Steins;Gate 0* visual novel series.

## Features

* **Rust Core Engine:** The host emulator is built purely in Rust, ensuring memory safety and extremely high performance (running a strict 60 FPS update loop with GPU-accelerated pixel scaling).
* **Lua Scripting:** Games ("cartridges") are written entirely in Lua 5.4, providing a beginner-friendly but incredibly powerful scripting environment.
* **Customizable Constraints:** Users can edit `config.json` to change the internal rendering resolution (e.g., NES 256x240, Gameboy 160x144) and swap color palettes.
* **Dynamic Palette RAM:** A 256-color palette system that defaults to the Steins;Gate themed "Makise" (16-color) or "IBN-5100" (4-color terminal phosphor) palettes.
* **Built-in Audio Synthesizer:** An integrated procedural synthesizer that mathematically generates retro/sci-fi sound effects (like Nixie tube clicks and interface buzzes) at runtime without needing external `.wav` files.
* **Developer Workflow:** Supports dynamic cartridge loading via the command line and instant code hot-swapping using the `F5` key.

---

## Installation & Setup

Amadeus requires the Rust toolchain (Cargo) to build and run.

### Linux Dependencies
If you are running on Linux, the `rodio` audio engine requires the ALSA development headers to compile successfully. You can install them via:
```bash
sudo apt-get update && sudo apt-get install -y libasound2-dev
```

*(Windows and macOS typically have the required audio APIs built-in).*

---

## Playing Games

To launch the Amadeus console and play the built-in demo game (**Amadeus Snake**), you must navigate into the player directory so the engine can find the asset files (`config.json`, `carts/`, etc.):

```bash
cd amadeus-player
cargo run
```

### Controls (Amadeus Snake)
* **Arrow Keys:** Move the Snake
* **Z:** Restart the game after dying

---

## Developing Games

To write your own game, create a `.lua` file (e.g., `my_game.lua`) and define the three core engine hooks: `_init()`, `_update()`, and `_draw()`.

Make sure you are in the `amadeus-player` directory, and load your custom cartridge by passing the file path to the player:

```bash
cd amadeus-player
cargo run -- carts/test_input.lua
```

### Hot-Swapping
While the console window is open, you can edit your `.lua` file in your favorite text editor, save it, and press **`F5`** inside the Amadeus window. The engine will instantly reload the cartridge, reset the Lua state, and execute your new code without needing to recompile the Rust engine!

---

## Architecture & Documentation

For detailed information on the console's technical architecture, hardware specifications, and the available Lua APIs (like `spr()`, `pset()`, `sfx()`, and `btn()`), please see the included design documents:

* [`AMADEUS_ARCHITECTURE.md`](./AMADEUS_ARCHITECTURE.md) - The core engine design and roadmap.
* [`AMADEUS_CONTENT.md`](./AMADEUS_CONTENT.md) - The thematic visual and audio specifications.
* [`CHANGELOG.md`](./CHANGELOG.md) - The history of the engine's development.
