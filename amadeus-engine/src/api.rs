use std::cell::RefCell;
use std::rc::Rc;
use mlua::prelude::*;

use crate::{Color, Console, HEIGHT, WIDTH};

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

            // Bounds checking
            if x >= 0 && x < WIDTH as i32 && y >= 0 && y < HEIGHT as i32 {
                let mut console = console_ref.borrow_mut();
                let color = console.palette[color_index as usize];

                let idx = ((y as usize) * WIDTH + (x as usize)) * 4;
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

    Ok(())
}
