-- Amadeus Cartridge: Snake (IBN-5100 Theme)

-- Game Constants
GRID_SIZE = 8 -- 8x8 pixels per grid square
COLS = 32     -- 256 / 8
ROWS = 30     -- 240 / 8

-- Colors (IBN-5100 palette)
C_BG = 0      -- CRT Black/Green
C_GRID = 1    -- Dark Phosphor
C_SNAKE = 2   -- Medium Phosphor
C_APPLE = 3   -- Bright Phosphor

-- Game State
snake = {}
dir_x = 1
dir_y = 0
apple = {x = 0, y = 0}
score = 0
game_over = false

-- Input debouncing
last_btn_z = false

-- Timing
tick_rate = 6 -- Move every N frames (60/6 = 10 moves per second)
ticks = 0

function _init()
    -- Initialize Snake in the middle
    snake = {}
    table.insert(snake, {x = 16, y = 15})
    table.insert(snake, {x = 15, y = 15})
    table.insert(snake, {x = 14, y = 15})

    dir_x = 1
    dir_y = 0
    score = 0
    game_over = false

    place_apple()
    sfx(3) -- System Startup
end

function place_apple()
    local valid = false
    while not valid do
        -- A simple pseudo-random generation since we don't have math.random imported yet
        -- We'll use the current score and a prime number
        apple.x = (score * 17 + ticks * 11) % COLS
        apple.y = (score * 23 + ticks * 13) % ROWS

        valid = true
        for i=1, #snake do
            if snake[i].x == apple.x and snake[i].y == apple.y then
                valid = false
                break
            end
        end
    end
end

function _update()
    local z_pressed = btn(4)
    if game_over then
        if z_pressed and not last_btn_z then
            _init()
        end
        last_btn_z = z_pressed
        return
    end
    last_btn_z = z_pressed

    -- Input
    if btn(0) and dir_x == 0 then
        dir_x = -1
        dir_y = 0
    elseif btn(1) and dir_x == 0 then
        dir_x = 1
        dir_y = 0
    elseif btn(2) and dir_y == 0 then
        dir_x = 0
        dir_y = -1
    elseif btn(3) and dir_y == 0 then
        dir_x = 0
        dir_y = 1
    end

    ticks = ticks + 1
    if ticks >= tick_rate then
        ticks = 0

        -- Move Head
        local head = snake[1]
        local new_x = head.x + dir_x
        local new_y = head.y + dir_y

        -- Wall Collision
        if new_x < 0 or new_x >= COLS or new_y < 0 or new_y >= ROWS then
            die()
            return
        end

        -- Self Collision
        for i=1, #snake do
            if snake[i].x == new_x and snake[i].y == new_y then
                die()
                return
            end
        end

        -- Add new head
        table.insert(snake, 1, {x = new_x, y = new_y})

        -- Apple Check
        if new_x == apple.x and new_y == apple.y then
            score = score + 10
            sfx(0) -- UI Blip for eating
            place_apple()

            -- Speed up slightly as you get longer
            if score % 50 == 0 and tick_rate > 2 then
                tick_rate = tick_rate - 1
            end
        else
            -- Remove tail
            table.remove(snake)
        end
    end
end

function die()
    game_over = true
    sfx(1) -- Error Buzz
end

-- Custom drawing primitive for Lua since we don't have rectfill in API yet
function fill_rect(x, y, w, h, col)
    for ry = 0, h - 1 do
        for rx = 0, w - 1 do
            pset(x + rx, y + ry, col)
        end
    end
end

function _draw()
    cls(C_BG)

    if game_over then
        -- Draw static/death pattern
        for y = 0, 240, 4 do
            for x = 0, 256, 4 do
                if (x + y + score) % 8 == 0 then
                    fill_rect(x, y, 4, 4, C_GRID)
                end
            end
        end

        -- We don't have print() yet, so we just use colors to indicate state
        fill_rect(64, 100, 128, 40, C_SNAKE)
        fill_rect(68, 104, 120, 32, C_BG)
        -- Red/Bright center block to mean "Press Z to restart"
        fill_rect(120, 112, 16, 16, C_APPLE)

        return
    end

    -- Draw Apple
    fill_rect(apple.x * GRID_SIZE + 1, apple.y * GRID_SIZE + 1, GRID_SIZE - 2, GRID_SIZE - 2, C_APPLE)

    -- Draw Snake
    for i=1, #snake do
        local segment = snake[i]
        local col = C_SNAKE
        if i == 1 then col = C_APPLE end -- Make head brighter

        fill_rect(segment.x * GRID_SIZE + 1, segment.y * GRID_SIZE + 1, GRID_SIZE - 2, GRID_SIZE - 2, col)
    end

    -- Draw Score Bar indicator
    for i=0, score/10 do
        fill_rect(i * 4, 0, 3, 2, C_APPLE)
    end
end
