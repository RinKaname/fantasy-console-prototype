-- Amadeus Cartridge: Space Shooter (Makise Theme)

SCREEN_W = 256
SCREEN_H = 240

-- Colors
C_BG = 0      -- Deep Black/Blue
C_PLAYER = 14 -- Pale Sky Blue
C_LASER = 9   -- Faded Orange
C_ENEMY = 8   -- Crimson Red
C_STAR = 3    -- Light Gray
C_TEXT = 4    -- Off-White

-- Game State
game_state = "START"
score = 0
ticks = 0

player = {
    x = SCREEN_W / 2,
    y = SCREEN_H - 20,
    w = 12,
    h = 8,
    speed = 3,
    power = 1
}

lasers = {}
enemies = {}
stars = {}
powerups = {}

-- Controls
last_action_btn = false

-- Starfield setup
for i = 1, 30 do
    table.insert(stars, {
        x = ((i * 17) % SCREEN_W),
        y = ((i * 23) % SCREEN_H),
        speed = ((i % 3) + 1) * 0.5
    })
end

function random_range(min, max)
    local rnd = ((ticks * 31) + (score * 17)) % (max - min)
    return min + rnd
end

function _init()
    player.x = SCREEN_W / 2
    player.power = 1
    lasers = {}
    enemies = {}
    powerups = {}
    score = 0
    ticks = 0
    game_state = "START"
end

function fire_laser()
    local max_lasers = player.power * 4
    if #lasers < max_lasers then
        if player.power == 1 then
            table.insert(lasers, { x = player.x + (player.w / 2) - 1, y = player.y, w = 2, h = 6, speed = 6 })
        elseif player.power == 2 then
            table.insert(lasers, { x = player.x + 1, y = player.y, w = 2, h = 6, speed = 6 })
            table.insert(lasers, { x = player.x + player.w - 3, y = player.y, w = 2, h = 6, speed = 6 })
        else
            -- Power 3: Triple Laser (fast)
            table.insert(lasers, { x = player.x + (player.w / 2) - 1, y = player.y - 2, w = 2, h = 6, speed = 8 })
            table.insert(lasers, { x = player.x - 2, y = player.y, w = 2, h = 6, speed = 8 })
            table.insert(lasers, { x = player.x + player.w, y = player.y, w = 2, h = 6, speed = 8 })
        end
        sfx(2) -- Nixie click (Laser sound)
    end
end

function spawn_enemy()
    table.insert(enemies, {
        x = random_range(10, SCREEN_W - 20),
        y = -10,
        w = 10,
        h = 10,
        speed = 1 + (score * 0.05) -- Enemies speed up as score increases
    })
end

function _update()
    ticks = ticks + 1
    local action_pressed = btn(4) or btn(5) or btn(6) or btn(7)

    -- Update Starfield (Always runs)
    for i = 1, #stars do
        stars[i].y = stars[i].y + stars[i].speed
        if stars[i].y > SCREEN_H then
            stars[i].y = 0
            stars[i].x = random_range(0, SCREEN_W)
        end
    end

    if game_state == "START" then
        if action_pressed and not last_action_btn then
            game_state = "PLAY"
            sfx(3) -- System Startup
        end
        last_action_btn = action_pressed
        return
    elseif game_state == "GAMEOVER" then
        if action_pressed and not last_action_btn then
            _init()
            game_state = "PLAY"
        end
        last_action_btn = action_pressed
        return
    end

    -- Player Movement
    if btn(0) then -- Left
        player.x = player.x - player.speed
    elseif btn(1) then -- Right
        player.x = player.x + player.speed
    end

    -- Clamp Player
    if player.x < 0 then player.x = 0 end
    if player.x > SCREEN_W - player.w then player.x = SCREEN_W - player.w end

    -- Shooting
    if action_pressed and not last_action_btn then
        fire_laser()
    end
    last_action_btn = action_pressed

    -- Update Lasers
    for i = #lasers, 1, -1 do
        local l = lasers[i]
        l.y = l.y - l.speed
        if l.y < -l.h then
            table.remove(lasers, i)
        end
    end

    -- Spawn Enemies
    if ticks % 40 == 0 then
        spawn_enemy()
    end

    -- Update Enemies & Check Collisions
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e.y = e.y + e.speed

        -- Hit player?
        if e.x < player.x + player.w and e.x + e.w > player.x and
           e.y < player.y + player.h and e.y + e.h > player.y then
            if player.power > 1 then
                player.power = 1
                table.remove(enemies, i)
                sfx(1) -- Hit but survive
            else
                game_state = "GAMEOVER"
                sfx(1) -- Error Buzz (Explosion)
                return
            end
        else
            -- Hit bottom of screen?
            if e.y > SCREEN_H then
                table.remove(enemies, i)
            else
                -- Hit by laser?
                local destroyed = false
                for j = #lasers, 1, -1 do
                    local l = lasers[j]
                    if l.x < e.x + e.w and l.x + l.w > e.x and
                       l.y < e.y + e.h and l.y + l.h > e.y then
                        score = score + 10
                        sfx(0) -- UI Blip (Enemy destroyed)
                        table.remove(lasers, j)
                        destroyed = true

                        -- Spawn power-up (10% chance)
                        if random_range(0, 100) < 10 then
                            table.insert(powerups, {
                                x = e.x,
                                y = e.y,
                                w = 6,
                                h = 6,
                                speed = 1.5
                            })
                        end
                        break
                    end
                end
                if destroyed then
                    table.remove(enemies, i)
                end
            end
        end
    end

    -- Update Powerups
    for i = #powerups, 1, -1 do
        local p = powerups[i]
        p.y = p.y + p.speed

        -- Hit player?
        if p.x < player.x + player.w and p.x + p.w > player.x and
           p.y < player.y + player.h and p.y + p.h > player.y then
            if player.power < 3 then
                player.power = player.power + 1
            else
                score = score + 50 -- extra score if max power
            end
            sfx(3) -- Powerup sound
            table.remove(powerups, i)
        elseif p.y > SCREEN_H then
            table.remove(powerups, i)
        end
    end
end

-- Custom drawing primitive
function fill_rect(x, y, w, h, col)
    local ix = math.floor(x)
    local iy = math.floor(y)
    for ry = 0, h - 1 do
        for rx = 0, w - 1 do
            pset(ix + rx, iy + ry, col)
        end
    end
end

function _draw()
    cls(C_BG)

    -- Draw Starfield
    for i = 1, #stars do
        pset(stars[i].x, stars[i].y, C_STAR)
    end

    if game_state == "PLAY" or game_state == "GAMEOVER" then
        -- Draw Player (A simple triangle/ship shape)
        fill_rect(player.x, player.y + 4, player.w, 4, C_PLAYER)
        fill_rect(player.x + 4, player.y, 4, 4, C_PLAYER)

        -- Draw Lasers
        for i = 1, #lasers do
            fill_rect(lasers[i].x, lasers[i].y, lasers[i].w, lasers[i].h, C_LASER)
        end

        -- Draw Enemies
        for i = 1, #enemies do
            fill_rect(enemies[i].x, enemies[i].y, enemies[i].w, enemies[i].h, C_ENEMY)
        end

        -- Draw Powerups
        for i = 1, #powerups do
            local p = powerups[i]
            fill_rect(p.x, p.y, p.w, p.h, C_LASER)
            pset(p.x+1, p.y+1, C_TEXT)
            pset(p.x+4, p.y+1, C_TEXT)
            pset(p.x+1, p.y+4, C_TEXT)
            pset(p.x+4, p.y+4, C_TEXT)
        end

        -- Draw Score
        print("SCORE: " .. tostring(score), 4, 4, C_TEXT)
    end

    if game_state == "START" then
        fill_rect(54, 100, 148, 40, C_PLAYER)
        fill_rect(56, 102, 144, 36, C_BG)
        print("AMADEUS SHOOTER", 80, 108, C_TEXT)
        print("PRESS Z TO FIRE", 80, 120, C_LASER)
    elseif game_state == "GAMEOVER" then
        fill_rect(64, 100, 128, 40, C_ENEMY)
        fill_rect(66, 102, 124, 36, C_BG)
        print("SHIP DESTROYED", 82, 108, C_ENEMY)
        print("PRESS Z TO RESTART", 70, 120, C_TEXT)
    end
end
