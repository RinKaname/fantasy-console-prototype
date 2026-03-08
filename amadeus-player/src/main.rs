use amadeus_engine::{Engine, HEIGHT, WIDTH};
use log::error;
use pixels::{Error, Pixels, SurfaceTexture};
use std::time::Instant;
use winit::dpi::LogicalSize;
use winit::event::{Event, VirtualKeyCode};
use winit::event_loop::{ControlFlow, EventLoop};
use winit::window::WindowBuilder;
use winit_input_helper::WinitInputHelper;

fn main() -> Result<(), Error> {
    env_logger::init();

    // Scale the window up so it's visible on modern monitors
    let scale_factor = 3.0;

    let event_loop = EventLoop::new();
    let mut input = WinitInputHelper::new();

    let window = {
        let size = LogicalSize::new(WIDTH as f64 * scale_factor, HEIGHT as f64 * scale_factor);
        WindowBuilder::new()
            .with_title("Amadeus - 8-Bit Fantasy Console")
            .with_inner_size(size)
            .with_min_inner_size(size)
            .build(&event_loop)
            .unwrap()
    };

    let mut pixels = {
        let window_size = window.inner_size();
        let surface_texture = SurfaceTexture::new(window_size.width, window_size.height, &window);
        Pixels::new(WIDTH as u32, HEIGHT as u32, surface_texture)?
    };

    let mut engine = Engine::new();

    // Load the test cartridge. Instead of hardcoding the path, we use the macro
    // to embed the script directly in the binary for this test phase.
    let test_cartridge = include_str!("../cart.lua");
    engine.load_cartridge(test_cartridge);

    let mut last_frame = Instant::now();

    event_loop.run(move |event, _, control_flow| {
        // IMPORTANT: Let the event loop run continuously so the game updates
        // without waiting for OS events (like mouse movement).
        *control_flow = ControlFlow::Poll;

        // Draw the current frame
        if let Event::RedrawRequested(_) = &event {
            // Step 1: Tell the Lua script to draw to the VRAM
            engine.draw();

            // Step 2: Copy the engine's VRAM to the pixels frame buffer
            // We use `with_vram` to pass a reference instead of cloning the whole array!
            engine.with_vram(|vram| {
                pixels.frame_mut().copy_from_slice(vram);
            });

            // Step 3: Render it to the screen
            if let Err(err) = pixels.render() {
                error!("pixels.render() failed: {err}");
                *control_flow = ControlFlow::Exit;
                return;
            }
        }

        // Handle input events
        if input.update(&event) {
            // Close events
            if input.close_requested() || input.destroyed() {
                *control_flow = ControlFlow::Exit;
                return;
            }

            // Resize the window
            if let Some(size) = input.window_resized() {
                if let Err(err) = pixels.resize_surface(size.width, size.height) {
                    error!("pixels.resize_surface() failed: {err}");
                    *control_flow = ControlFlow::Exit;
                    return;
                }
            }

            // Map physical keyboard keys to virtual controller buttons
            // Index mapping: 0=Left, 1=Right, 2=Up, 3=Down, 4=A, 5=B, 6=Start, 7=Select
            engine.set_button_state(0, input.key_held(VirtualKeyCode::Left));
            engine.set_button_state(1, input.key_held(VirtualKeyCode::Right));
            engine.set_button_state(2, input.key_held(VirtualKeyCode::Up));
            engine.set_button_state(3, input.key_held(VirtualKeyCode::Down));
            engine.set_button_state(4, input.key_held(VirtualKeyCode::Z));
            engine.set_button_state(5, input.key_held(VirtualKeyCode::X));
            engine.set_button_state(6, input.key_held(VirtualKeyCode::Return)); // Enter
            engine.set_button_state(7, input.key_held(VirtualKeyCode::RShift)); // Select

            // Cap the framerate roughly to 60 FPS
            let now = Instant::now();
            let elapsed = now.duration_since(last_frame).as_secs_f64();
            if elapsed >= 1.0 / 60.0 {
                // Update the console logic (runs Lua _update)
                engine.update();

                // Request a redraw
                window.request_redraw();
                last_frame = now;
            }
        }
    });
}
