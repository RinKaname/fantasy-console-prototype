-- Amadeus Demo Cartridge: "Interactive Input Test"
-- Demonstrates the Makise palette and the pset/cls/btn APIs.

-- Global State
x = 128
y = 120
speed = 2
flip_x = false

-- Runs once when the cartridge is loaded
function _init()
    -- Change palette index 15 to a custom neon pink just for fun
    set_color(15, 255, 0, 255)

    -- Clear the screen with the deep dark blue (Makise color 0)
    cls(0)
end

-- Runs 60 times a second
function _update()
    -- Input check: 0=Left, 1=Right, 2=Up, 3=Down
    if btn(0) then
        x = x - speed
        flip_x = true -- Face left
    end
    if btn(1) then
        x = x + speed
        flip_x = false -- Face right
    end
    if btn(2) then
        y = y - speed
    end
    if btn(3) then
        y = y + speed
    end

    -- Action buttons: Z (4) and X (5)
    -- Hold Z to move faster, hold X to move slower
    if btn(4) then
        speed = 4
    elseif btn(5) then
        speed = 1
    else
        speed = 2
    end

    -- Keep the character on screen (NES res: 256x240)
    if x < 0 then x = 0 end
    if x > 240 then x = 240 end
    if y < 0 then y = 0 end
    if y > 224 then y = 224 end
end

-- Runs every frame after _update
function _draw()
    -- Clear the background every frame
    cls(0)

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

    -- If button Z (4) is held, draw a neon pink (15) trail/aura
    if btn(4) then
        for px = -4, 19 do
            for py = -4, 19 do
                pset(x + px, y + py, 15)
            end
        end
    end

    -- Draw the player sprite.
    -- We draw a 2x2 tile character starting at tile ID 0 in the Sprite RAM.
    -- spr(id, x, y, flip_x, flip_y, width, height)
    spr(0, x, y, flip_x, false, 2, 2)
end
