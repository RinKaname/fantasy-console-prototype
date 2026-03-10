use rodio::source::{SineWave, Source};
use rodio::{OutputStream, OutputStreamHandle, Sink};
use std::time::Duration;

/// The Amadeus Audio Subsystem.
/// Handles the `rodio` output stream and the synthesis of built-in ROM sounds.
pub struct AudioSystem {
    _stream: OutputStream,
    _stream_handle: OutputStreamHandle,
    // We keep a few sinks alive so sounds can overlap if necessary.
    sinks: Vec<Sink>,
    next_sink: usize,
}

impl AudioSystem {
    pub fn new() -> Result<Self, String> {
        let (_stream, stream_handle) =
            OutputStream::try_default().map_err(|e| format!("Failed to get output stream: {}", e))?;

        let mut sinks = Vec::new();
        // Create 4 channels (like the NES)
        for _ in 0..4 {
            let sink = Sink::try_new(&stream_handle)
                .map_err(|e| format!("Failed to create audio sink: {}", e))?;
            sinks.push(sink);
        }

        Ok(Self {
            _stream,
            _stream_handle: stream_handle,
            sinks,
            next_sink: 0,
        })
    }

    /// Triggers one of the built-in ROM sound effects.
    pub fn play_sfx(&mut self, id: u8) {
        let sink = &self.sinks[self.next_sink];

        // Stop whatever is currently playing on this channel
        sink.clear();

        // Very basic procedural synthesis for the required sounds
        match id {
            // UI Blip: Short, high-pitched beep
            0 => {
                let source = SineWave::new(880.0)
                    .take_duration(Duration::from_millis(50))
                    // apply a simple fade out to remove popping
                    .fade_in(Duration::from_millis(5))
                    .amplify(0.2);
                sink.append(source);
            }
            // Error Buzz: Harsh, low-frequency buzz
            1 => {
                // A very low frequency sinewave as a placeholder for a buzz, amplified to clip/distort
                let source = SineWave::new(65.41) // C2
                    .take_duration(Duration::from_millis(250))
                    .amplify(0.8);
                sink.append(source);
            }
            // Nixie Click: Extremely short, high transient click
            2 => {
                let source = SineWave::new(3000.0)
                    .take_duration(Duration::from_millis(10))
                    .amplify(0.6);
                sink.append(source);
            }
            // System Startup: Rising tone
            3 => {
                // A quick sequence of rising notes
                let s1 = SineWave::new(440.0).take_duration(Duration::from_millis(100)).amplify(0.2);
                let s2 = SineWave::new(554.37).take_duration(Duration::from_millis(100)).amplify(0.2);
                let s3 = SineWave::new(659.25).take_duration(Duration::from_millis(300)).amplify(0.2);
                sink.append(s1);
                sink.append(s2);
                sink.append(s3);
            }
            // "Okarin" Beep: Specific recognizable ringtone sequence (El Psy Kongroo!)
            10 => {
                // Just a tiny melody placeholder
                let s1 = SineWave::new(659.25).take_duration(Duration::from_millis(150)).amplify(0.2); // E5
                let s_pause = SineWave::new(1.0).take_duration(Duration::from_millis(50)).amplify(0.0);
                let s2 = SineWave::new(880.00).take_duration(Duration::from_millis(150)).amplify(0.2); // A5
                let s3 = SineWave::new(1046.50).take_duration(Duration::from_millis(300)).amplify(0.2); // C6
                sink.append(s1);
                sink.append(s_pause);
                sink.append(s2);
                sink.append(s3);
            }
            _ => {
                log::warn!("Requested unknown SFX id: {}", id);
            }
        }

        // Force playback to resume in case `clear` paused the sink,
        // which can happen on some backends (like WASAPI on Windows)
        // when the internal queue becomes empty.
        sink.play();

        // Round-robin to the next channel for polyphony
        self.next_sink = (self.next_sink + 1) % self.sinks.len();
    }
}
