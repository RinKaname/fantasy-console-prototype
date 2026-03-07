use amadeus_engine::{Console, HEIGHT, WIDTH};
use log::error;
use pixels::{Error, Pixels, SurfaceTexture};
use std::time::Instant;
use winit::dpi::LogicalSize;
use winit::event::Event;
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

    let mut console = Console::new();
    let mut last_frame = Instant::now();

    event_loop.run(move |event, _, control_flow| {
        // Draw the current frame
        if let Event::RedrawRequested(_) = &event {
            // Step 1: Tell the console to draw to its internal VRAM
            console.draw();

            // Step 2: Copy the console's VRAM to the pixels frame buffer
            pixels.frame_mut().copy_from_slice(&console.vram);

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

            // Cap the framerate roughly to 60 FPS
            let now = Instant::now();
            let elapsed = now.duration_since(last_frame).as_secs_f64();
            if elapsed >= 1.0 / 60.0 {
                // Update the console logic
                console.update();

                // Request a redraw
                window.request_redraw();
                last_frame = now;
            }
        }
    });
}
