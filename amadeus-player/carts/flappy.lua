-- Amadeus Cartridge: Flappy (IBN-5100 Theme)

SCREEN_W = 256
SCREEN_H = 240

C_BG = 0
C_PIPE = 1
C_BIRD = 3
C_TEXT = 2

-- Game state
game_state = "START"

-- Bird properties
bird = {
    x = 40,
    y = 120,
    w = 6,
    h = 4,
    vel = 0,
    gravity = 0.25,
    jump = -3.5
}

-- Pipe properties
pipes = {}
pipe_w = 20
pipe_gap = 60
pipe_speed = 1.5
pipe_timer = 0
pipe_spawn_time = 90

score = 0
high_score = 0
ticks = 0

last_action_btn = false

-- Poor man's pseudo-random number generator
function random_range(min, max)
    -- Just use ticks to generate somewhat unpredictable numbers
    local rnd = ((ticks * 31) + (score * 17) + (bird.y * 11)) % (max - min)
    return min + rnd
end

function spawn_pipe()
    local gap_y = random_range(40, SCREEN_H - 40 - pipe_gap)
    table.insert(pipes, {
        x = SCREEN_W,
        gap_y = gap_y,
        passed = false
    })
end

function reset_game()
    bird.y = 120
    bird.vel = 0
    pipes = {}
    pipe_timer = 0
    score = 0
    ticks = 0
    spawn_pipe()
    game_state = "PLAY"
    sfx(3)
end

function _init()
    game_state = "START"
    high_score = 0
end

function _update()
    ticks = ticks + 1
    local action_pressed = btn(4) or btn(5) or btn(6) or btn(7)

    if game_state == "START" then
        if action_pressed and not last_action_btn then
            reset_game()
        end
        last_action_btn = action_pressed
        return
    elseif game_state == "GAMEOVER" then
        if action_pressed and not last_action_btn then
            reset_game()
        end
        last_action_btn = action_pressed
        return
    end

    -- Bird Physics
    if action_pressed and not last_action_btn then
        bird.vel = bird.jump
        sfx(0) -- Jump sound
    end
    last_action_btn = action_pressed

    bird.vel = bird.vel + bird.gravity
    bird.y = bird.y + bird.vel

    -- Floor/Ceiling collision
    if bird.y < 0 then
        bird.y = 0
        bird.vel = 0
    elseif bird.y > SCREEN_H - bird.h then
        die()
        return
    end

    -- Pipes logic
    pipe_timer = pipe_timer + 1
    if pipe_timer >= pipe_spawn_time then
        pipe_timer = 0
        spawn_pipe()
    end

    for i = #pipes, 1, -1 do
        local p = pipes[i]
        p.x = p.x - pipe_speed

        -- Collision detection
        local b_right = bird.x + bird.w
        local b_bottom = bird.y + bird.h
        local p_right = p.x + pipe_w

        -- Check horizontal intersection
        if b_right > p.x and bird.x < p_right then
            -- Check vertical intersection (hit upper or lower pipe)
            if bird.y < p.gap_y or b_bottom > (p.gap_y + pipe_gap) then
                die()
                return
            end
        end

        -- Scoring
        if not p.passed and bird.x > p_right then
            p.passed = true
            score = score + 1
            if score > high_score then
                high_score = score
            end
            sfx(2) -- Score beep
        end

        -- Remove off-screen pipes
        if p.x + pipe_w < 0 then
            table.remove(pipes, i)
        end
    end
end

function die()
    game_state = "GAMEOVER"
    sfx(1) -- Error sound
end

-- Custom drawing primitive
function fill_rect(x, y, w, h, col)
    for ry = 0, h - 1 do
        for rx = 0, w - 1 do
            pset(x + rx, y + ry, col)
        end
    end
end

function _draw()
    cls(C_BG)

    -- Draw pipes
    for i = 1, #pipes do
        local p = pipes[i]
        -- Top pipe
        fill_rect(p.x, 0, pipe_w, p.gap_y, C_PIPE)
        -- Bottom pipe
        local bottom_y = p.gap_y + pipe_gap
        fill_rect(p.x, bottom_y, pipe_w, SCREEN_H - bottom_y, C_PIPE)
    end

    -- Draw Bird
    if game_state ~= "START" then
        fill_rect(bird.x, bird.y, bird.w, bird.h, C_BIRD)
    end

    -- Draw UI
    if game_state == "PLAY" then
        print(tostring(score), 4, 4, C_TEXT)
    elseif game_state == "START" then
        fill_rect(50, 80, 156, 40, C_PIPE)
        fill_rect(52, 82, 152, 36, C_BG)
        print("AMADEUS FLAPPY", 85, 90, C_TEXT)
        print("PRESS Z TO FLAP", 80, 105, C_BIRD)
    elseif game_state == "GAMEOVER" then
        fill_rect(50, 80, 156, 50, C_PIPE)
        fill_rect(52, 82, 152, 46, C_BG)
        print("CRASHED!", 100, 90, C_BIRD)
        print("SCORE: " .. tostring(score), 100, 100, C_TEXT)
        print("BEST: " .. tostring(high_score), 105, 110, C_TEXT)
        print("PRESS Z TO RESTART", 75, 120, C_PIPE)
    end
end
