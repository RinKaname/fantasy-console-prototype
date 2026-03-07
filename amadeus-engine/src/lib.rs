//! The Amadeus core engine.
//! This library provides the simulated hardware state, including the 256x240 pixel buffer.

/// The width of the Amadeus console screen in pixels (NES resolution).
pub const WIDTH: usize = 256;
/// The height of the Amadeus console screen in pixels (NES resolution).
pub const HEIGHT: usize = 240;

/// Represents the internal state of the Amadeus console.
pub struct Console {
    /// The virtual video RAM: a flat array of RGBA pixels.
    pub vram: Vec<u8>,

    // Example test pattern state
    pub frame_counter: u32,
}

impl Console {
    /// Initializes a new Amadeus console instance.
    pub fn new() -> Self {
        Self {
            vram: vec![0; WIDTH * HEIGHT * 4],
            frame_counter: 0,
        }
    }

    /// Updates the console state. This would typically run the embedded Lua scripts.
    /// For now, it simply increments a frame counter for our test pattern.
    pub fn update(&mut self) {
        self.frame_counter = self.frame_counter.wrapping_add(1);
    }

    /// Draws to the internal VRAM.
    /// Currently, this renders a scrolling test pattern.
    pub fn draw(&mut self) {
        // Simple test pattern: a scrolling color gradient
        let shift = (self.frame_counter % 256) as u8;

        for (i, pixel) in self.vram.chunks_exact_mut(4).enumerate() {
            let x = (i % WIDTH) as u8;
            let y = (i / WIDTH) as u8;

            let r = x.wrapping_add(shift);
            let g = y.wrapping_add(shift);
            let b = x.wrapping_mul(y).wrapping_add(shift);
            let a = 0xff; // Fully opaque

            pixel.copy_from_slice(&[r, g, b, a]);
        }
    }
}

impl Default for Console {
    fn default() -> Self {
        Self::new()
    }
}
