-- Amadeus Demo Cartridge: "Bouncing Pixel"
-- Demonstrates the Makise palette and the pset/cls APIs.

-- Global State
x = 0
y = 120
direction = 1

-- Runs once when the cartridge is loaded
function _init()
    -- Change palette index 15 to a custom neon pink just for fun
    set_color(15, 255, 0, 255)

    -- Clear the screen with the deep dark blue (Makise color 0)
    cls(0)
end

-- Runs 60 times a second
function _update()
    -- Bounce the pixel back and forth
    x = x + direction
    if x >= 256 then
        direction = -1
        x = 255
    elseif x < 0 then
        direction = 1
        x = 0
    end
end

-- Runs every frame after _update
function _draw()
    -- Clear the background every frame so it doesn't leave a trail
    cls(0)

    -- Draw a single pixel moving across the screen (color #8 is crimson red in Makise)
    pset(x, y, 8)

    -- Draw a static box to show the "Makise" palette
    local start_x = 10
    local start_y = 10
    local size = 10

    -- Draw all 16 colors of the default palette in a 4x4 grid
    for row = 0, 3 do
        for col = 0, 3 do
            local color_idx = (row * 4) + col

            -- Fill a 10x10 block
            for bx = 0, size - 1 do
                for by = 0, size - 1 do
                    pset(start_x + (col * size) + bx, start_y + (row * size) + by, color_idx)
                end
            end
        end
    end
end
