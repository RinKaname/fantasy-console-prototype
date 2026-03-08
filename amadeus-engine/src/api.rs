use std::cell::RefCell;
use std::rc::Rc;
use mlua::prelude::*;

use crate::{Color, Console};

/// Sets up the Lua environment and binds the Amadeus APIs.
pub fn setup_lua_sandbox(lua: &Lua, console_ref: Rc<RefCell<Console>>) -> LuaResult<()> {
    let globals = lua.globals();

    // API: cls(color)
    // Clears the entire screen using the given palette index.
    let cls = {
        let console_ref = Rc::clone(&console_ref);
        lua.create_function(move |_, color_index: u8| {
            let mut console = console_ref.borrow_mut();
            let color = console.palette[color_index as usize];
            let rgba = [color.r, color.g, color.b, color.a];

            for pixel in console.vram.chunks_exact_mut(4) {
                pixel.copy_from_slice(&rgba);
            }
            Ok(())
        })?
    };
    globals.set("cls", cls)?;

    // API: pset(x, y, color)
    // Draws a single pixel at (x, y) using the given palette index.
    let pset = {
        let console_ref = Rc::clone(&console_ref);
        lua.create_function(move |_, (x, y, color_index): (f64, f64, u8)| {
            let x = x.floor() as i32;
            let y = y.floor() as i32;

            let mut console = console_ref.borrow_mut();
            let width = console.config.width as i32;
            let height = console.config.height as i32;

            // Bounds checking
            if x >= 0 && x < width && y >= 0 && y < height {
                let color = console.palette[color_index as usize];
                let idx = ((y as usize) * (width as usize) + (x as usize)) * 4;
                console.vram[idx] = color.r;
                console.vram[idx + 1] = color.g;
                console.vram[idx + 2] = color.b;
                console.vram[idx + 3] = color.a;
            }
            Ok(())
        })?
    };
    globals.set("pset", pset)?;

    // API: set_color(index, r, g, b)
    // Modifies the color stored in a specific palette slot.
    let set_color = {
        let console_ref = Rc::clone(&console_ref);
        lua.create_function(move |_, (index, r, g, b): (u8, u8, u8, u8)| {
            let mut console = console_ref.borrow_mut();
            console.palette[index as usize] = Color { r, g, b, a: 255 };
            Ok(())
        })?
    };
    globals.set("set_color", set_color)?;

    // API: btn(index)
    // Returns true if the button at the given index is currently pressed.
    // Index mapping: 0=Left, 1=Right, 2=Up, 3=Down, 4=A, 5=B, 6=Start, 7=Select.
    let btn = {
        let console_ref = Rc::clone(&console_ref);
        lua.create_function(move |_, index: u8| {
            let is_pressed = if index < 8 {
                console_ref.borrow().buttons[index as usize]
            } else {
                false
            };
            Ok(is_pressed)
        })?
    };
    globals.set("btn", btn)?;

    // API: spr(id, x, y, [flip_x], [flip_y], [width], [height])
    // Draws a sprite from the Sprite RAM to the VRAM.
    // id: Sprite index (0-255). The spritesheet is 16x16 tiles (128x128 pixels).
    // flip_x/y: Booleans to flip the sprite horizontally or vertically.
    // width/height: How many 8x8 tiles to draw (defaults to 1x1).
    let spr = {
        let console_ref = Rc::clone(&console_ref);
        lua.create_function(
            move |_,
                  (id, x, y, flip_x, flip_y, w, h): (
                      u8,
                      f64,
                      f64,
                      Option<bool>,
                      Option<bool>,
                      Option<u8>,
                      Option<u8>,
                  )| {
                let x = x.floor() as i32;
                let y = y.floor() as i32;
                let flip_x = flip_x.unwrap_or(false);
                let flip_y = flip_y.unwrap_or(false);
                let w = w.unwrap_or(1) as i32;
                let h = h.unwrap_or(1) as i32;

                let mut console = console_ref.borrow_mut();
                let screen_width = console.config.width as i32;
                let screen_height = console.config.height as i32;

                // Loop over the number of 8x8 tiles specified by width/height
                for ty in 0..h {
                    for tx in 0..w {
                        // Determine the source tile ID, adjusting for the grid (16 tiles wide)
                        let tile_id = id as i32 + tx + (ty * 16);
                        if tile_id > 255 {
                            continue;
                        }

                        // Coordinates of this tile on the screen
                        let mut screen_tx = x + (tx * 8);
                        let mut screen_ty = y + (ty * 8);

                        // If flipping a multi-tile sprite, we need to swap the tile positions
                        if flip_x {
                            screen_tx = x + ((w - 1 - tx) * 8);
                        }
                        if flip_y {
                            screen_ty = y + ((h - 1 - ty) * 8);
                        }

                        // Top-left pixel coordinate of this tile in the Sprite RAM
                        let src_x_base = (tile_id % 16) * 8;
                        let src_y_base = (tile_id / 16) * 8;

                        // Draw the 8x8 pixels of the current tile
                        for py in 0..8 {
                            for px in 0..8 {
                                let screen_px = screen_tx + px;
                                let screen_py = screen_ty + py;

                                // Bounds check for the screen
                                if screen_px < 0
                                    || screen_px >= screen_width
                                    || screen_py < 0
                                    || screen_py >= screen_height
                                {
                                    continue;
                                }

                                // Calculate which pixel to read from the tile, applying flips
                                let read_px = if flip_x { 7 - px } else { px };
                                let read_py = if flip_y { 7 - py } else { py };

                                let src_px = src_x_base + read_px;
                                let src_py = src_y_base + read_py;

                                // Read the color index from Sprite RAM (128x128 array)
                                let sprite_idx = (src_py * 128 + src_px) as usize;
                                let color_index = console.sprite_ram[sprite_idx];

                                // Index 0 is strictly transparent
                                if color_index > 0 {
                                    let color = console.palette[color_index as usize];
                                    let vram_idx =
                                        ((screen_py as usize) * (screen_width as usize)
                                            + (screen_px as usize))
                                            * 4;

                                    console.vram[vram_idx] = color.r;
                                    console.vram[vram_idx + 1] = color.g;
                                    console.vram[vram_idx + 2] = color.b;
                                    console.vram[vram_idx + 3] = color.a;
                                }
                            }
                        }
                    }
                }
                Ok(())
            },
        )?
    };
    globals.set("spr", spr)?;

    Ok(())
}
