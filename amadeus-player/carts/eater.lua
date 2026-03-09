-- Amadeus Cartridge: Eater (Makise Theme)

SCREEN_W = 256
SCREEN_H = 240

-- Colors
C_BG = 0      -- Black
C_WALL = 13   -- Muted Cerulean Blue
C_PELLET = 4  -- Off-White
C_PLAYER = 10 -- Muted Gold/Yellow
C_GHOST1 = 8  -- Crimson Red
C_GHOST2 = 14 -- Pale Sky Blue
C_TEXT = 3    -- Light Gray

-- Tile properties
TILE_S = 10
MAP_W = 21
MAP_H = 21
MAP_OFFSET_X = (SCREEN_W - (MAP_W * TILE_S)) / 2
MAP_OFFSET_Y = 16

-- 1=Wall, 0=Pellet, 2=Empty
map_layout = {
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,
    1,0,1,1,1,0,1,1,1,0,1,0,1,1,1,0,1,1,1,0,1,
    1,0,1,1,1,0,1,1,1,0,1,0,1,1,1,0,1,1,1,0,1,
    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,0,1,1,1,0,1,0,1,1,1,1,1,0,1,0,1,1,1,0,1,
    1,0,0,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,0,0,1,
    1,1,1,1,1,0,1,1,1,2,1,2,1,1,1,0,1,1,1,1,1,
    2,2,2,2,1,0,1,2,2,2,2,2,2,2,1,0,1,2,2,2,2,
    1,1,1,1,1,0,1,2,1,1,2,1,1,2,1,0,1,1,1,1,1,
    2,2,2,2,2,0,2,2,1,2,2,2,1,2,2,0,2,2,2,2,2,
    1,1,1,1,1,0,1,2,1,1,1,1,1,2,1,0,1,1,1,1,1,
    2,2,2,2,1,0,1,2,2,2,2,2,2,2,1,0,1,2,2,2,2,
    1,1,1,1,1,0,1,2,1,1,1,1,1,2,1,0,1,1,1,1,1,
    1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,
    1,0,1,1,1,0,1,1,1,0,1,0,1,1,1,0,1,1,1,0,1,
    1,0,0,0,1,0,0,0,0,0,2,0,0,0,0,0,1,0,0,0,1,
    1,1,1,0,1,0,1,0,1,1,1,1,1,0,1,0,1,0,1,1,1,
    1,0,0,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,0,0,1,
    1,0,1,1,1,1,1,1,1,0,1,0,1,1,1,1,1,1,1,0,1,
    1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
}

map = {}
score = 0
pellets_left = 0

player = {
    tx = 10, ty = 16, -- Tile X/Y
    x = 0, y = 0,     -- Pixel X/Y
    dx = 0, dy = 0,
    ndx = 0, ndy = 0  -- Next desired direction
}

ghosts = {
    {tx = 9, ty = 10, x = 0, y = 0, dx = -1, dy = 0, color = C_GHOST1},
    {tx = 11, ty = 10, x = 0, y = 0, dx = 1, dy = 0, color = C_GHOST2}
}

game_state = "START"
ticks = 0

function init_map()
    map = {}
    pellets_left = 0
    for i = 1, #map_layout do
        map[i] = map_layout[i]
        if map[i] == 0 then pellets_left = pellets_left + 1 end
    end
end

function reset_actors()
    player.tx = 10
    player.ty = 16
    player.x = player.tx * TILE_S
    player.y = player.ty * TILE_S
    player.dx = 0
    player.dy = 0
    player.ndx = 0
    player.ndy = 0

    ghosts[1].tx = 9
    ghosts[1].ty = 10
    ghosts[1].x = ghosts[1].tx * TILE_S
    ghosts[1].y = ghosts[1].ty * TILE_S
    ghosts[1].dx = -1
    ghosts[1].dy = 0

    ghosts[2].tx = 11
    ghosts[2].ty = 10
    ghosts[2].x = ghosts[2].tx * TILE_S
    ghosts[2].y = ghosts[2].ty * TILE_S
    ghosts[2].dx = 1
    ghosts[2].dy = 0
end

function _init()
    score = 0
    init_map()
    reset_actors()
    game_state = "START"
    sfx(3)
end

function get_tile(tx, ty)
    if tx < 0 then tx = MAP_W - 1 end
    if tx >= MAP_W then tx = 0 end
    if ty < 0 or ty >= MAP_H then return 1 end

    local idx = (ty * MAP_W) + tx + 1
    return map[idx]
end

function set_tile(tx, ty, val)
    if tx >= 0 and tx < MAP_W and ty >= 0 and ty < MAP_H then
        local idx = (ty * MAP_W) + tx + 1
        map[idx] = val
    end
end

last_action_btn = false

function random_dir()
    local r = ((ticks * 17) + (score * 31)) % 4
    if r == 0 then return 1, 0
    elseif r == 1 then return -1, 0
    elseif r == 2 then return 0, 1
    else return 0, -1 end
end

function _update()
    ticks = ticks + 1
    local action_pressed = btn(4) or btn(5) or btn(6) or btn(7)

    if game_state == "START" or game_state == "GAMEOVER" or game_state == "WIN" then
        if action_pressed and not last_action_btn then
            if game_state ~= "WIN" then score = 0 end
            init_map()
            reset_actors()
            game_state = "PLAY"
            sfx(3)
        end
        last_action_btn = action_pressed
        return
    end

    last_action_btn = action_pressed

    -- Get Player Input (Buffering the next turn)
    if btn(0) then player.ndx = -1; player.ndy = 0
    elseif btn(1) then player.ndx = 1; player.ndy = 0
    elseif btn(2) then player.ndx = 0; player.ndy = -1
    elseif btn(3) then player.ndx = 0; player.ndy = 1 end

    -- Move Player (every 2 ticks for speed control)
    if ticks % 2 == 0 then
        -- Are we perfectly aligned to a grid tile?
        if player.x % TILE_S == 0 and player.y % TILE_S == 0 then
            player.tx = math.floor(player.x / TILE_S)
            player.ty = math.floor(player.y / TILE_S)

            -- Wrap around tunnel
            if player.tx < 0 then player.tx = MAP_W - 1; player.x = player.tx * TILE_S end
            if player.tx >= MAP_W then player.tx = 0; player.x = 0 end

            -- Check if we can turn in the buffered direction
            if player.ndx ~= 0 or player.ndy ~= 0 then
                local next_tile = get_tile(player.tx + player.ndx, player.ty + player.ndy)
                if next_tile ~= 1 then
                    player.dx = player.ndx
                    player.dy = player.ndy
                end
            end

            -- If the current direction leads to a wall, stop
            if get_tile(player.tx + player.dx, player.ty + player.dy) == 1 then
                player.dx = 0
                player.dy = 0
            end

            -- Eat pellet
            if get_tile(player.tx, player.ty) == 0 then
                set_tile(player.tx, player.ty, 2)
                score = score + 10
                pellets_left = pellets_left - 1
                if score % 20 == 0 then
                    sfx(0) -- UI blip for eating
                end

                if pellets_left <= 0 then
                    game_state = "WIN"
                    sfx(3)
                    return
                end
            end
        end

        -- Apply movement
        player.x = player.x + player.dx
        player.y = player.y + player.dy
    end

    -- Move Ghosts (every 3 ticks so they are slightly slower than the player)
    if ticks % 3 == 0 then
        for i = 1, #ghosts do
            local g = ghosts[i]

            if g.x % TILE_S == 0 and g.y % TILE_S == 0 then
                g.tx = math.floor(g.x / TILE_S)
                g.ty = math.floor(g.y / TILE_S)

                -- Wrap
                if g.tx < 0 then g.tx = MAP_W - 1; g.x = g.tx * TILE_S end
                if g.tx >= MAP_W then g.tx = 0; g.x = 0 end

                -- Ghost AI: Simple intersection randomizer
                local can_go_straight = get_tile(g.tx + g.dx, g.ty + g.dy) ~= 1

                -- Collect valid turns
                local valid_dirs = {}
                local dirs = {{1,0}, {-1,0}, {0,1}, {0,-1}}
                for d=1, 4 do
                    local nx = dirs[d][1]
                    local ny = dirs[d][2]
                    -- Don't allow 180 reversal unless stuck
                    if (nx ~= -g.dx or ny ~= -g.dy) then
                        if get_tile(g.tx + nx, g.ty + ny) ~= 1 then
                            table.insert(valid_dirs, dirs[d])
                        end
                    end
                end

                if #valid_dirs > 0 then
                    -- At an intersection or corner, pick a random valid direction
                    -- Favor straight if possible but mix it up
                    if not can_go_straight or ((ticks * i) % 7 == 0) then
                        local r = ((ticks + score + i * 13) % #valid_dirs) + 1
                        g.dx = valid_dirs[r][1]
                        g.dy = valid_dirs[r][2]
                    end
                else
                    -- Dead end, reverse
                    g.dx = -g.dx
                    g.dy = -g.dy
                end
            end

            g.x = g.x + g.dx
            g.y = g.y + g.dy

            -- Check Collision with player
            -- Simple AABB using pixel coordinates
            if math.abs(player.x - g.x) < TILE_S - 2 and math.abs(player.y - g.y) < TILE_S - 2 then
                game_state = "GAMEOVER"
                sfx(1) -- Error buzz
            end
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

function _draw()
    cls(C_BG)

    -- Draw Map
    for y = 0, MAP_H - 1 do
        for x = 0, MAP_W - 1 do
            local t = get_tile(x, y)
            local px = MAP_OFFSET_X + (x * TILE_S)
            local py = MAP_OFFSET_Y + (y * TILE_S)

            if t == 1 then
                -- Draw Wall (hollow block style)
                fill_rect(px, py, TILE_S, TILE_S, C_WALL)
                fill_rect(px + 2, py + 2, TILE_S - 4, TILE_S - 4, C_BG)
            elseif t == 0 then
                -- Draw Pellet
                pset(px + 4, py + 4, C_PELLET)
                pset(px + 5, py + 4, C_PELLET)
                pset(px + 4, py + 5, C_PELLET)
                pset(px + 5, py + 5, C_PELLET)
            end
        end
    end

    -- Draw Ghosts
    for i = 1, #ghosts do
        local g = ghosts[i]
        local gx = MAP_OFFSET_X + g.x + 1
        local gy = MAP_OFFSET_Y + g.y + 1
        -- Body
        fill_rect(gx, gy, 8, 8, g.color)
        -- Eyes
        pset(gx + 2, gy + 2, C_PELLET)
        pset(gx + 5, gy + 2, C_PELLET)
    end

    -- Draw Player
    if ticks % 16 < 8 then -- Mouth chomping animation
        fill_rect(MAP_OFFSET_X + player.x + 1, MAP_OFFSET_Y + player.y + 1, 8, 8, C_PLAYER)
    else
        -- Draw with a "mouth" depending on direction
        fill_rect(MAP_OFFSET_X + player.x + 1, MAP_OFFSET_Y + player.y + 1, 8, 8, C_PLAYER)

        local cx = MAP_OFFSET_X + player.x + 4
        local cy = MAP_OFFSET_Y + player.y + 4

        if player.dx > 0 then
            fill_rect(cx, cy - 2, 5, 5, C_BG)
        elseif player.dx < 0 then
            fill_rect(cx - 4, cy - 2, 5, 5, C_BG)
        elseif player.dy > 0 then
            fill_rect(cx - 2, cy, 5, 5, C_BG)
        elseif player.dy < 0 then
            fill_rect(cx - 2, cy - 4, 5, 5, C_BG)
        end
    end

    -- Draw UI
    print("SCORE: " .. tostring(score), 4, 4, C_TEXT)

    if game_state == "START" then
        fill_rect(54, 100, 148, 40, C_PLAYER)
        fill_rect(56, 102, 144, 36, C_BG)
        print("AMADEUS EATER", 80, 108, C_PLAYER)
        print("PRESS Z TO START", 80, 120, C_TEXT)
    elseif game_state == "GAMEOVER" then
        fill_rect(64, 100, 128, 40, C_GHOST1)
        fill_rect(66, 102, 124, 36, C_BG)
        print("GAME OVER", 90, 108, C_GHOST1)
        print("PRESS Z TO RESTART", 70, 120, C_TEXT)
    elseif game_state == "WIN" then
        fill_rect(64, 100, 128, 40, C_PLAYER)
        fill_rect(66, 102, 124, 36, C_BG)
        print("YOU WIN!", 96, 108, C_PLAYER)
        print("PRESS Z FOR NEXT LEVEL", 56, 120, C_TEXT)
    end
end
