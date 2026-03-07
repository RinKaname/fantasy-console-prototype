# Amadeus: Default Content & Assets

The Amadeus console provides a complete out-of-the-box experience designed around a moody, retro-tech, visual-novel aesthetic heavily inspired by the "Amadeus" AI from the *Steins;Gate 0* series.

This document outlines the default content, BIOS behavior, and built-in assets that ship with every Amadeus environment.

---

## 1. The Boot Sequence (BIOS)

When the Amadeus console engine initializes (or when a user resets the environment), a built-in boot sequence plays before handing control over to the inserted cartridge (Lua script).

**The "Amadeus AI" Boot Logo:**
*   **Visual Motif:** The boot sequence mimics the initialization of the Amadeus AI system interface.
*   **Animation:** It begins with a command-line boot sequence (rapid text printing system checks), followed by an animated digital waveform or "eye" motif fading into the center of the screen.
*   **Audio Cue:** A crisp, synthesized "system online" chime or a mechanical relay "click" (resembling a Nixie tube turning on) plays as the logo resolves.
*   **Transition:** The logo flickers and dissolves, revealing either the command-line workspace or instantly launching the `game.lua` cartridge.

---

## 2. System Palettes

Rather than locking the user into a single default 16-color palette, Amadeus allows the user to configure or select from several built-in thematic palettes in their cartridge's metadata.

By default, Amadeus boots using the **"Makise" Palette**.

### Thematic Palette Options:
1.  **"Makise" (The Default):** A muted, atmospheric 16-color palette featuring sepia tones, desaturated grays, deep blues, and pale skin tones, perfect for visual novels or moody adventure games.
2.  **"IBN-5100":** A stark, high-contrast monochrome 4-color palette consisting entirely of dark greens and bright, phosphor terminal greens.
3.  **"Divergence":** A specialized high-contrast palette featuring deep blacks and glowing oranges/reds (mimicking Nixie tube filaments).
4.  **"Akihabara":** A vibrant, neon-heavy 16-color palette for more traditional arcade-style action games.

Users can change the active palette dynamically via the Lua API (e.g., `set_palette("ibn")`).

---

## 3. The Built-in Font

Amadeus includes a custom, stylized system font baked directly into the engine's ROM.

*   **Style:** "Hacker Terminal" Monospace.
*   **Characteristics:** Sharp, mechanical, and slightly blocky, designed for readability at small resolutions while maintaining a strong sci-fi/technical aesthetic.
*   **Support:** The font includes both uppercase and lowercase English characters, numbers, common punctuation, and a selection of specialized "box-drawing" or UI characters (like battery icons or signal bars) mapped to higher ASCII values.
*   **API Usage:** Text is rendered using the `print(text, x, y, color)` function, which utilizes this built-in font.

---

## 4. Built-in Demo Cartridge: "Amadeus Snake"

To help users learn the Amadeus API immediately, the console ships with a built-in demo cartridge containing a fully playable game.

**"Amadeus Snake":**
*   **Description:** A complete, highly polished version of the classic Snake game.
*   **Aesthetic:** It utilizes the "IBN-5100" terminal green palette and the "Hacker Terminal" font.
*   **Features:**
    *   Smooth movement and input handling demonstrating the `btn()` and `btnp()` APIs.
    *   A high-score system demonstrating persistent save data (if the API supports it).
    *   Juice/Polish: Screen shake on death, particle effects when eating an "apple" (which might be styled as a glowing data packet or a Dr. Pepper can).
    *   Sound effects: It uses the built-in system audio assets for movement, eating, and game over.
*   **Purpose:** The source code (`demo_snake.lua`) is heavily commented and acts as the definitive tutorial for drawing sprites, playing sounds, and managing game state in Amadeus.

---

## 5. Built-in Audio Assets (ROM Sounds)

To lower the barrier to entry, Amadeus includes a small "ROM" of pre-synthesized sound effects. Users can call these immediately without opening the SFX Tracker.

**The "Sci-Fi / Old Console" Sound Bank:**
These sounds lean into the mechanical, retro-tech vibe:
*   `sfx(0)`: **UI Blip:** A short, high-pitched terminal keystroke sound.
*   `sfx(1)`: **Error Buzz:** A harsh, low-frequency rejection sound.
*   `sfx(2)`: **Nixie Click:** A satisfying mechanical relay click (great for menu navigation).
*   `sfx(3)`: **System Startup:** A rising, synthesized sine wave (used in the boot sequence).
*   `sfx(4)`: **Data Transfer:** A rapid, static-like chirping sound.
*   `sfx(5)`: **Power Down:** A descending, pitch-bending tone.
*   `sfx(10)`: **"Okarin" Beep:** A specific, recognizable ringtone-style sequence of notes.

Users can use these instantly via `sfx(id)` or compose their own using the built-in audio tools.