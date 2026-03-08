//! The Amadeus core engine.
//! This library provides the simulated hardware state, including the 256x240 pixel buffer.

use mlua::prelude::*;
use std::cell::RefCell;
use std::rc::Rc;
use image::GenericImageView;

pub mod api;
pub mod audio;

use audio::AudioSystem;

/// The default width of the Amadeus console screen in pixels (NES resolution).
pub const DEFAULT_WIDTH: usize = 256;
/// The default height of the Amadeus console screen in pixels (NES resolution).
pub const DEFAULT_HEIGHT: usize = 240;

/// The hardware configuration of the console, loaded from config.json.
#[derive(serde::Deserialize, Debug, Clone)]
pub struct Config {
    pub width: usize,
    pub height: usize,
    pub palette: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            width: DEFAULT_WIDTH,
            height: DEFAULT_HEIGHT,
            palette: "makise".to_string(),
        }
    }
}

/// A simple RGBA color structure.
#[derive(Clone, Copy, Debug, PartialEq)]
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

    /// The Sprite RAM: stores color indices for 256 8x8 sprites.
    /// It is a 128x128 array representing the full spritesheet memory.
    pub sprite_ram: Vec<u8>,

    /// The hardware constraints of the current environment.
    pub config: Config,

    /// The state of the 8 virtual controller buttons.
    pub buttons: [bool; 8],

    pub frame_counter: u32,

    /// The audio subsystem (wrapped in an Option in case audio device fails to init)
    pub audio: Option<AudioSystem>,
}

impl Console {
    /// Initializes the console state with the given configuration.
    pub fn new(config: Config) -> Self {
        let mut palette = [Color { r: 0, g: 0, b: 0, a: 255 }; 256];

        let makise_palette = [
            (15, 15, 20),      // 0: Deep Black/Blue (Transparent color for sprites)
            (45, 50, 65),      // 1: Dark Blue/Gray
            (95, 90, 105),     // 2: Medium Muted Purple
            (160, 160, 170),   // 3: Light Gray
            (210, 210, 215),   // 4: Off-White
            (180, 140, 110),   // 5: Pale Skin/Peach
            (140, 90, 70),     // 6: Muted Brown/Copper
            (80, 40, 45),      // 7: Dark Red/Brown
            (145, 45, 45),     // 8: Crimson Red
            (200, 90, 70),     // 9: Faded Orange
            (160, 145, 70),    // 10: Muted Gold/Yellow
            (70, 100, 60),     // 11: Dark Olive Green
            (100, 140, 100),   // 12: Pale Green
            (60, 90, 130),     // 13: Muted Cerulean Blue
            (100, 130, 170),   // 14: Pale Sky Blue
            (190, 160, 190),   // 15: Pale Lavender
        ];

        let ibn5100_palette = [
            (5, 20, 5),        // 0: Deep CRT Black/Green (Transparent)
            (20, 80, 20),      // 1: Dark Phosphor
            (50, 160, 50),     // 2: Medium Phosphor
            (100, 255, 100),   // 3: Bright Phosphor
        ];

        if config.palette.to_lowercase() == "ibn5100" {
            for (i, &(r, g, b)) in ibn5100_palette.iter().enumerate() {
                palette[i] = Color { r, g, b, a: 255 };
            }
        } else {
            for (i, &(r, g, b)) in makise_palette.iter().enumerate() {
                palette[i] = Color { r, g, b, a: 255 };
            }
        }

        let audio = match AudioSystem::new() {
            Ok(sys) => Some(sys),
            Err(e) => {
                log::warn!("Audio system disabled: {}", e);
                None
            }
        };

        Self {
            vram: vec![0; config.width * config.height * 4],
            palette,
            sprite_ram: vec![0; 128 * 128], // 128x128 pixels holding color indices (0-255)
            config,
            buttons: [false; 8],
            frame_counter: 0,
            audio,
        }
    }

    /// Finds the closest color index in the current palette to the given RGB color.
    pub fn get_closest_palette_index(&self, r: u8, g: u8, b: u8) -> u8 {
        let mut closest_idx = 0;
        let mut min_dist = f32::MAX;

        for (i, color) in self.palette.iter().enumerate() {
            let dr = (r as f32) - (color.r as f32);
            let dg = (g as f32) - (color.g as f32);
            let db = (b as f32) - (color.b as f32);
            let dist = dr * dr + dg * dg + db * db;

            if dist < min_dist {
                min_dist = dist;
                closest_idx = i as u8;
            }
        }
        closest_idx
    }

    /// Loads a PNG into the Sprite RAM (128x128 max size)
    pub fn load_spritesheet(&mut self, image_bytes: &[u8]) {
        if let Ok(img) = image::load_from_memory(image_bytes) {
            let (width, height) = img.dimensions();
            let limit_w = width.min(128);
            let limit_h = height.min(128);

            for y in 0..limit_h {
                for x in 0..limit_w {
                    let pixel = img.get_pixel(x, y);
                    // Treat full alpha transparency as index 0 (background)
                    let index = if pixel[3] == 0 {
                        0
                    } else {
                        self.get_closest_palette_index(pixel[0], pixel[1], pixel[2])
                    };

                    let array_idx = (y as usize) * 128 + (x as usize);
                    self.sprite_ram[array_idx] = index;
                }
            }
        } else {
            log::warn!("Failed to load spritesheet data");
        }
    }
}

impl Default for Console {
    fn default() -> Self {
        Self::new(Config::default())
    }
}

pub struct Engine {
    pub console: Rc<RefCell<Console>>,
    pub lua: Lua,
}

impl Engine {
    pub fn new(config: Config) -> Self {
        let console = Rc::new(RefCell::new(Console::new(config)));
        let lua = Lua::new();

        if let Err(e) = api::setup_lua_sandbox(&lua, Rc::clone(&console)) {
            log::error!("Failed to setup Lua sandbox: {}", e);
        }

        Self { console, lua }
    }

    pub fn load_cartridge(&mut self, lua_code: &str) {
        if let Err(e) = self.lua.load(lua_code).exec() {
            log::error!("Error parsing cartridge: {}", e);
            return;
        }

        let globals = self.lua.globals();

        if let Ok(init_fn) = globals.get::<mlua::Function>("_init") {
            if let Err(e) = init_fn.call::<()>(()) {
                log::error!("Error in _init(): {}", e);
            }
        }
    }

    /// Expose spritesheet loading to the host layer
    pub fn load_spritesheet(&mut self, bytes: &[u8]) {
        self.console.borrow_mut().load_spritesheet(bytes);
    }

    pub fn set_button_state(&mut self, index: usize, pressed: bool) {
        if index < 8 {
            self.console.borrow_mut().buttons[index] = pressed;
        }
    }

    pub fn update(&mut self) {
        let globals = self.lua.globals();

        if let Ok(update_fn) = globals.get::<mlua::Function>("_update") {
            if let Err(e) = update_fn.call::<()>(()) {
                log::error!("Error in _update(): {}", e);
            }
        }
    }

    pub fn draw(&mut self) {
        let globals = self.lua.globals();

        if let Ok(draw_fn) = globals.get::<mlua::Function>("_draw") {
            if let Err(e) = draw_fn.call::<()>(()) {
                log::error!("Error in _draw(): {}", e);
            }
        }
    }

    pub fn with_vram<F, R>(&self, f: F) -> R
    where
        F: FnOnce(&[u8]) -> R,
    {
        let console = self.console.borrow();
        f(&console.vram)
    }
}
