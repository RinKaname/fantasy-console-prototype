//! The Amadeus core engine.
//! This library provides the simulated hardware state, including the 256x240 pixel buffer.

use mlua::prelude::*;
use std::cell::RefCell;
use std::rc::Rc;

pub mod api;

/// The width of the Amadeus console screen in pixels (NES resolution).
pub const WIDTH: usize = 256;
/// The height of the Amadeus console screen in pixels (NES resolution).
pub const HEIGHT: usize = 240;

/// A simple RGBA color structure.
#[derive(Clone, Copy, Debug)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

/// Represents the internal state of the Amadeus console.
pub struct Console {
    /// The virtual video RAM: a flat array of RGBA pixels.
    pub vram: Vec<u8>,

    /// The virtual Palette RAM: 256 color slots.
    pub palette: [Color; 256],

    /// The state of the 8 virtual controller buttons.
    /// Index mapping: 0=Left, 1=Right, 2=Up, 3=Down, 4=A, 5=B, 6=Start, 7=Select.
    pub buttons: [bool; 8],

    // Example test pattern state
    pub frame_counter: u32,
}

impl Console {
    /// Initializes the console state with the default palette.
    pub fn new() -> Self {
        // Initialize an empty palette
        let mut palette = [Color { r: 0, g: 0, b: 0, a: 255 }; 256];

        // Define the default "Makise" 16-color palette (Steins;Gate inspired)
        // A muted, atmospheric palette with deep blues, grays, and sepias.
        let makise_palette = [
            (15, 15, 20),      // 0: Deep Black/Blue
            (45, 50, 65),      // 1: Dark Blue/Gray
            (95, 90, 105),     // 2: Medium Muted Purple
            (160, 160, 170),   // 3: Light Gray
            (210, 210, 215),   // 4: Off-White
            (180, 140, 110),   // 5: Pale Skin/Peach
            (140, 90, 70),     // 6: Muted Brown/Copper
            (80, 40, 45),      // 7: Dark Red/Brown (Kurisu's Hair)
            (145, 45, 45),     // 8: Crimson Red
            (200, 90, 70),     // 9: Faded Orange
            (160, 145, 70),    // 10: Muted Gold/Yellow
            (70, 100, 60),     // 11: Dark Olive Green
            (100, 140, 100),   // 12: Pale Green
            (60, 90, 130),     // 13: Muted Cerulean Blue
            (100, 130, 170),   // 14: Pale Sky Blue
            (190, 160, 190),   // 15: Pale Lavender
        ];

        // Load the Makise palette into the first 16 slots
        for (i, &(r, g, b)) in makise_palette.iter().enumerate() {
            palette[i] = Color { r, g, b, a: 255 };
        }

        Self {
            vram: vec![0; WIDTH * HEIGHT * 4],
            palette,
            buttons: [false; 8],
            frame_counter: 0,
        }
    }
}

impl Default for Console {
    fn default() -> Self {
        Self::new()
    }
}

/// The runtime engine that owns the console state and the Lua environment.
pub struct Engine {
    pub console: Rc<RefCell<Console>>,
    pub lua: Lua,
}

impl Engine {
    /// Initializes the engine, sets up the Lua sandbox, and loads the cartridge.
    pub fn new() -> Self {
        let console = Rc::new(RefCell::new(Console::new()));
        let lua = Lua::new();

        // Bind the Rust APIs to the Lua sandbox
        if let Err(e) = api::setup_lua_sandbox(&lua, Rc::clone(&console)) {
            log::error!("Failed to setup Lua sandbox: {}", e);
        }

        Self { console, lua }
    }

    /// Loads a Lua script into the engine and calls `_init()` if it exists.
    pub fn load_cartridge(&mut self, lua_code: &str) {
        if let Err(e) = self.lua.load(lua_code).exec() {
            log::error!("Error parsing cartridge: {}", e);
            return;
        }

        let globals = self.lua.globals();

        // Call the _init function if the user defined one
        if let Ok(init_fn) = globals.get::<mlua::Function>("_init") {
            if let Err(e) = init_fn.call::<()>(()) {
                log::error!("Error in _init(): {}", e);
            }
        }
    }

    /// Update the input states before running the frame.
    pub fn set_button_state(&mut self, index: usize, pressed: bool) {
        if index < 8 {
            self.console.borrow_mut().buttons[index] = pressed;
        }
    }

    /// Calls the user's `_update()` function.
    pub fn update(&mut self) {
        let globals = self.lua.globals();

        if let Ok(update_fn) = globals.get::<mlua::Function>("_update") {
            if let Err(e) = update_fn.call::<()>(()) {
                log::error!("Error in _update(): {}", e);
            }
        }
    }

    /// Calls the user's `_draw()` function.
    pub fn draw(&mut self) {
        let globals = self.lua.globals();

        if let Ok(draw_fn) = globals.get::<mlua::Function>("_draw") {
            if let Err(e) = draw_fn.call::<()>(()) {
                log::error!("Error in _draw(): {}", e);
            }
        }
    }

    /// Helper to get a reference to the current VRAM slice for rendering.
    /// Uses `borrow` to safely access the RefCell data without cloning.
    pub fn with_vram<F, R>(&self, f: F) -> R
    where
        F: FnOnce(&[u8]) -> R,
    {
        let console = self.console.borrow();
        f(&console.vram)
    }
}

impl Default for Engine {
    fn default() -> Self {
        Self::new()
    }
}
