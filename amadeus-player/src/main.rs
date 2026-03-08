use amadeus_engine::{Config, Engine};
use log::{error, info};
use pixels::{Error, Pixels, SurfaceTexture};
use std::time::Instant;
use winit::dpi::LogicalSize;
use winit::event::{Event, VirtualKeyCode};
use winit::event_loop::{ControlFlow, EventLoop};
use winit::window::WindowBuilder;
use winit_input_helper::WinitInputHelper;

fn main() -> Result<(), Error> {
    env_logger::init();

    // Load configuration
    let config: Config = std::fs::read_to_string("config.json")
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_else(|| {
            info!("Could not load config.json, using defaults.");
            Config::default()
        });

    info!("Starting Amadeus with resolution: {}x{}", config.width, config.height);

    // Scale the window up so it's visible on modern monitors
    // E.g., 256x240 * 3 = 768x720 window
    let scale_factor = 3.0;

    let event_loop = EventLoop::new();
    let mut input = WinitInputHelper::new();

    let window = {
        let size = LogicalSize::new(config.width as f64 * scale_factor, config.height as f64 * scale_factor);
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
        Pixels::new(config.width as u32, config.height as u32, surface_texture)?
    };

    let mut engine = Engine::new(config);

    // Load the test cartridge
    let test_cartridge = include_str!("../cart.lua");
    engine.load_cartridge(test_cartridge);

    // Load the spritesheet into Sprite RAM
    let sprites_bytes = include_bytes!("../sprites.png");
    engine.load_spritesheet(sprites_bytes);

    let mut last_frame = Instant::now();

    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Poll;

        // Draw the current frame
        if let Event::RedrawRequested(_) = &event {
            engine.draw();

            engine.with_vram(|vram| {
                pixels.frame_mut().copy_from_slice(vram);
            });

            if let Err(err) = pixels.render() {
                error!("pixels.render() failed: {err}");
                *control_flow = ControlFlow::Exit;
                return;
            }
        }

        // Handle input events
        if input.update(&event) {
            if input.close_requested() || input.destroyed() {
                *control_flow = ControlFlow::Exit;
                return;
            }

            if let Some(size) = input.window_resized() {
                if let Err(err) = pixels.resize_surface(size.width, size.height) {
                    error!("pixels.resize_surface() failed: {err}");
                    *control_flow = ControlFlow::Exit;
                    return;
                }
            }

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
                engine.update();
                window.request_redraw();
                last_frame = now;
            }
        }
    });
}
