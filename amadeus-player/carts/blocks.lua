-- Amadeus Cartridge: Blocks (Makise Theme)

SCREEN_W = 256
SCREEN_H = 240

-- Colors
C_BG = 0      -- Deep Black/Blue
C_BORDER = 3  -- Light Gray
C_TEXT = 4    -- Off-White

-- The 7 Tetromino colors
COLORS = {
    8,  -- I (Crimson Red)
    9,  -- J (Faded Orange)
    10, -- L (Muted Gold)
    11, -- O (Olive Green)
    13, -- S (Muted Cerulean)
    14, -- T (Pale Sky Blue)
    15  -- Z (Pale Lavender)
}

-- Playfield Grid (10 cols, 20 rows)
grid_w = 10
grid_h = 20
grid = {}

tile_s = 10
board_x = (SCREEN_W - (grid_w * tile_s)) / 2
board_y = (SCREEN_H - (grid_h * tile_s)) / 2

score = 0
lines_cleared = 0
game_state = "START"
ticks = 0

-- Input debouncing
btn_state = {false, false, false, false, false, false, false, false}

-- The 7 shapes, represented as 4x4 grids in their 4 rotation states
-- We just define the base state and rotate it mathematically
-- 1 = I, 2 = J, 3 = L, 4 = O, 5 = S, 6 = T, 7 = Z
shapes = {
    -- I
    {
        {0,0,0,0, 1,1,1,1, 0,0,0,0, 0,0,0,0},
        {0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0},
        {0,0,0,0, 0,0,0,0, 1,1,1,1, 0,0,0,0},
        {0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0}
    },
    -- J
    {
        {2,0,0,0, 2,2,2,0, 0,0,0,0, 0,0,0,0},
        {0,2,2,0, 0,2,0,0, 0,2,0,0, 0,0,0,0},
        {0,0,0,0, 2,2,2,0, 0,0,2,0, 0,0,0,0},
        {0,2,0,0, 0,2,0,0, 2,2,0,0, 0,0,0,0}
    },
    -- L
    {
        {0,0,3,0, 3,3,3,0, 0,0,0,0, 0,0,0,0},
        {0,3,0,0, 0,3,0,0, 0,3,3,0, 0,0,0,0},
        {0,0,0,0, 3,3,3,0, 3,0,0,0, 0,0,0,0},
        {3,3,0,0, 0,3,0,0, 0,3,0,0, 0,0,0,0}
    },
    -- O
    {
        {0,4,4,0, 0,4,4,0, 0,0,0,0, 0,0,0,0},
        {0,4,4,0, 0,4,4,0, 0,0,0,0, 0,0,0,0},
        {0,4,4,0, 0,4,4,0, 0,0,0,0, 0,0,0,0},
        {0,4,4,0, 0,4,4,0, 0,0,0,0, 0,0,0,0}
    },
    -- S
    {
        {0,5,5,0, 5,5,0,0, 0,0,0,0, 0,0,0,0},
        {0,5,0,0, 0,5,5,0, 0,0,5,0, 0,0,0,0},
        {0,0,0,0, 0,5,5,0, 5,5,0,0, 0,0,0,0},
        {5,0,0,0, 5,5,0,0, 0,5,0,0, 0,0,0,0}
    },
    -- T
    {
        {0,6,0,0, 6,6,6,0, 0,0,0,0, 0,0,0,0},
        {0,6,0,0, 0,6,6,0, 0,6,0,0, 0,0,0,0},
        {0,0,0,0, 6,6,6,0, 0,6,0,0, 0,0,0,0},
        {0,6,0,0, 6,6,0,0, 0,6,0,0, 0,0,0,0}
    },
    -- Z
    {
        {7,7,0,0, 0,7,7,0, 0,0,0,0, 0,0,0,0},
        {0,0,7,0, 0,7,7,0, 0,7,0,0, 0,0,0,0},
        {0,0,0,0, 7,7,0,0, 0,7,7,0, 0,0,0,0},
        {0,7,0,0, 7,7,0,0, 7,0,0,0, 0,0,0,0}
    }
}

piece = {
    type = 1,
    rot = 1,
    x = 3,
    y = 0
}

fall_speed = 60 -- frames per drop
fall_timer = 0

function rng()
    local a = (ticks * 1103515245 + 12345) % 2147483648
    return (a / 2147483648)
end

function spawn_piece()
    piece.type = math.floor(rng() * 7) + 1
    piece.rot = 1
    piece.x = 3
    piece.y = 0

    if collides(piece.x, piece.y, piece.rot) then
        game_state = "GAMEOVER"
        sfx(1)
    end
end

function init_grid()
    grid = {}
    for y = 0, grid_h - 1 do
        grid[y] = {}
        for x = 0, grid_w - 1 do
            grid[y][x] = 0
        end
    end
end

function _init()
    score = 0
    lines_cleared = 0
    ticks = 0
    fall_speed = 60
    init_grid()
    spawn_piece()
    game_state = "START"
    sfx(3)
end

function just_pressed(b)
    if btn(b) and not btn_state[b] then
        btn_state[b] = true
        return true
    end
    if not btn(b) then
        btn_state[b] = false
    end
    return false
end

function collides(nx, ny, nrot)
    local shape = shapes[piece.type][nrot]
    for r = 0, 3 do
        for c = 0, 3 do
            local idx = (r * 4) + c + 1
            if shape[idx] ~= 0 then
                local wx = nx + c
                local wy = ny + r
                -- Wall / Floor
                if wx < 0 or wx >= grid_w or wy >= grid_h then
                    return true
                end
                -- Other pieces
                if wy >= 0 and grid[wy][wx] ~= 0 then
                    return true
                end
            end
        end
    end
    return false
end

function lock_piece()
    local shape = shapes[piece.type][piece.rot]
    for r = 0, 3 do
        for c = 0, 3 do
            local idx = (r * 4) + c + 1
            if shape[idx] ~= 0 then
                local wx = piece.x + c
                local wy = piece.y + r
                if wy >= 0 and wy < grid_h then
                    grid[wy][wx] = shape[idx]
                end
            end
        end
    end

    -- Check for full lines
    local lines = 0
    for y = grid_h - 1, 0, -1 do
        local full = true
        for x = 0, grid_w - 1 do
            if grid[y][x] == 0 then
                full = false
                break
            end
        end

        if full then
            lines = lines + 1
            -- Shift everything above down
            for yy = y, 1, -1 do
                for x = 0, grid_w - 1 do
                    grid[yy][x] = grid[yy - 1][x]
                end
            end
            -- Clear top row
            for x = 0, grid_w - 1 do
                grid[0][x] = 0
            end
            -- Recheck this row since the one above moved down
            y = y + 1
        end
    end

    if lines > 0 then
        sfx(3)
        lines_cleared = lines_cleared + lines
        -- Scoring: 1=100, 2=300, 3=500, 4=800
        if lines == 1 then score = score + 100
        elseif lines == 2 then score = score + 300
        elseif lines == 3 then score = score + 500
        elseif lines >= 4 then score = score + 800 end

        -- Speed up every 10 lines
        fall_speed = math.max(10, 60 - (math.floor(lines_cleared / 10) * 5))
    end

    spawn_piece()
end

function _update()
    ticks = ticks + 1
    local action_pressed = btn(4) or btn(5) or btn(6) or btn(7)

    if game_state == "START" or game_state == "GAMEOVER" then
        if just_pressed(4) or just_pressed(5) or just_pressed(6) then
            _init()
            game_state = "PLAY"
        end
        return
    end

    -- Movement
    if just_pressed(0) then -- Left
        if not collides(piece.x - 1, piece.y, piece.rot) then
            piece.x = piece.x - 1
            sfx(0)
        end
    elseif just_pressed(1) then -- Right
        if not collides(piece.x + 1, piece.y, piece.rot) then
            piece.x = piece.x + 1
            sfx(0)
        end
    end

    -- Rotation
    if just_pressed(4) then -- Clockwise
        local next_rot = piece.rot + 1
        if next_rot > 4 then next_rot = 1 end
        if not collides(piece.x, piece.y, next_rot) then
            piece.rot = next_rot
            sfx(2)
        end
    elseif just_pressed(5) then -- Counter-clockwise
        local next_rot = piece.rot - 1
        if next_rot < 1 then next_rot = 4 end
        if not collides(piece.x, piece.y, next_rot) then
            piece.rot = next_rot
            sfx(2)
        end
    end

    -- Soft Drop
    if btn(3) then
        fall_timer = fall_timer + 5 -- Drop faster
    end

    -- Gravity
    fall_timer = fall_timer + 1
    if fall_timer >= fall_speed then
        fall_timer = 0
        if not collides(piece.x, piece.y + 1, piece.rot) then
            piece.y = piece.y + 1
        else
            lock_piece()
        end
    end
end

function fill_rect(x, y, w, h, col)
    for ry = 0, h - 1 do
        for rx = 0, w - 1 do
            pset(x + rx, y + ry, col)
        end
    end
end

function draw_block(x, y, type)
    if type == 0 then return end
    local px = board_x + (x * tile_s)
    local py = board_y + (y * tile_s)
    local color = COLORS[type]

    -- Main block
    fill_rect(px, py, tile_s, tile_s, color)
    -- Border/Highlight to make grid visible
    fill_rect(px + 2, py + 2, tile_s - 4, tile_s - 4, 1) -- Use dark color for inner bevel
end

function _draw()
    cls(C_BG)

    -- Draw Board Border
    fill_rect(board_x - 2, board_y - 2, (grid_w * tile_s) + 4, (grid_h * tile_s) + 4, C_BORDER)
    fill_rect(board_x, board_y, grid_w * tile_s, grid_h * tile_s, C_BG)

    -- Draw locked blocks
    if game_state == "PLAY" or game_state == "GAMEOVER" then
        for y = 0, grid_h - 1 do
            for x = 0, grid_w - 1 do
                if grid[y][x] ~= 0 then
                    draw_block(x, y, grid[y][x])
                end
            end
        end

        -- Draw active piece
        if game_state == "PLAY" then
            local shape = shapes[piece.type][piece.rot]
            for r = 0, 3 do
                for c = 0, 3 do
                    local idx = (r * 4) + c + 1
                    if shape[idx] ~= 0 then
                        draw_block(piece.x + c, piece.y + r, piece.type)
                    end
                end
            end
        end
    end

    -- UI
    print("SCORE:", 10, 20, C_TEXT)
    print(tostring(score), 10, 30, COLORS[5])

    print("LINES:", 10, 50, C_TEXT)
    print(tostring(lines_cleared), 10, 60, COLORS[3])

    if game_state == "START" then
        fill_rect(64, 100, 128, 40, COLORS[1])
        fill_rect(66, 102, 124, 36, C_BG)
        print("AMADEUS BLOCKS", 75, 108, COLORS[1])
        print("PRESS Z TO START", 75, 120, C_TEXT)
    elseif game_state == "GAMEOVER" then
        fill_rect(64, 100, 128, 40, COLORS[7])
        fill_rect(66, 102, 124, 36, C_BG)
        print("GAME OVER", 95, 108, COLORS[7])
        print("PRESS Z TO RESTART", 75, 120, C_TEXT)
    end
end
