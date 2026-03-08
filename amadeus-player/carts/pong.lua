-- Amadeus Cartridge: Pong (Makise Theme)

-- Screen resolution: 256x240
SCREEN_W = 256
SCREEN_H = 240

-- Colors (Makise palette)
C_BG = 0         -- Deep Black/Blue
C_PADDLE = 3     -- Light Gray
C_BALL = 4       -- Off-White
C_TEXT = 9       -- Faded Orange
C_LINE = 1       -- Dark Blue/Gray
C_WIN = 10       -- Gold/Yellow

-- Paddle properties
PADDLE_W = 4
PADDLE_H = 32
PADDLE_SPEED = 4

-- Game State
player_y = (SCREEN_H - PADDLE_H) / 2
ai_y = (SCREEN_H - PADDLE_H) / 2

ball = { x = SCREEN_W / 2, y = SCREEN_H / 2, dx = 3, dy = 3, size = 4 }

score_p1 = 0
score_ai = 0
WIN_SCORE = 5

game_state = "START" -- START, PLAY, GAMEOVER

-- Input debouncing
last_action_btn = false

function reset_ball(direction)
    ball.x = (SCREEN_W - ball.size) / 2
    ball.y = (SCREEN_H - ball.size) / 2
    ball.dy = 3

    if direction == "LEFT" then
        ball.dx = -3
    else
        ball.dx = 3
    end
end

function _init()
    score_p1 = 0
    score_ai = 0
    player_y = (SCREEN_H - PADDLE_H) / 2
    ai_y = (SCREEN_H - PADDLE_H) / 2
    reset_ball("RIGHT")
    game_state = "START"
    sfx(3) -- System Startup
end

function _update()
    local action_pressed = btn(4) or btn(5) or btn(6) or btn(7)

    if game_state == "START" then
        if action_pressed and not last_action_btn then
            game_state = "PLAY"
        end
        last_action_btn = action_pressed
        return
    elseif game_state == "GAMEOVER" then
        if action_pressed and not last_action_btn then
            _init()
        end
        last_action_btn = action_pressed
        return
    end

    last_action_btn = action_pressed

    -- Player Movement
    if btn(2) then -- Up
        player_y = player_y - PADDLE_SPEED
    elseif btn(3) then -- Down
        player_y = player_y + PADDLE_SPEED
    end

    -- Clamp Player
    if player_y < 0 then player_y = 0 end
    if player_y > SCREEN_H - PADDLE_H then player_y = SCREEN_H - PADDLE_H end

    -- AI Movement (Simple tracking with some delay)
    local ai_center = ai_y + (PADDLE_H / 2)
    local ball_center = ball.y + (ball.size / 2)

    if ball.dx > 0 then -- Only move if ball is coming towards AI
        if ai_center < ball_center - 4 then
            ai_y = ai_y + PADDLE_SPEED - 1 -- slightly slower than player
        elseif ai_center > ball_center + 4 then
            ai_y = ai_y - PADDLE_SPEED + 1
        end
    else
        -- Return to center
        local screen_center = SCREEN_H / 2
        if ai_center < screen_center - 2 then
            ai_y = ai_y + 1
        elseif ai_center > screen_center + 2 then
            ai_y = ai_y - 1
        end
    end

    -- Clamp AI
    if ai_y < 0 then ai_y = 0 end
    if ai_y > SCREEN_H - PADDLE_H then ai_y = SCREEN_H - PADDLE_H end

    -- Ball Movement
    ball.x = ball.x + ball.dx
    ball.y = ball.y + ball.dy

    -- Wall Collision (Top and Bottom)
    if ball.y <= 0 then
        ball.y = 0
        ball.dy = -ball.dy
        sfx(2) -- Nixie Click
    elseif ball.y >= SCREEN_H - ball.size then
        ball.y = SCREEN_H - ball.size
        ball.dy = -ball.dy
        sfx(2) -- Nixie Click
    end

    -- Paddle Collision: Player (Left)
    if ball.x <= 16 + PADDLE_W and ball.x + ball.size >= 16 then
        if ball.y + ball.size >= player_y and ball.y <= player_y + PADDLE_H then
            ball.x = 16 + PADDLE_W
            ball.dx = -ball.dx + 0.5 -- slightly speed up

            -- English (spin) based on where it hit the paddle
            local hit_pos = (ball.y + (ball.size / 2)) - (player_y + (PADDLE_H / 2))
            ball.dy = ball.dy + (hit_pos * 0.1)

            sfx(0) -- UI Blip
        end
    end

    -- Paddle Collision: AI (Right)
    if ball.x + ball.size >= SCREEN_W - 16 - PADDLE_W and ball.x <= SCREEN_W - 16 then
        if ball.y + ball.size >= ai_y and ball.y <= ai_y + PADDLE_H then
            ball.x = SCREEN_W - 16 - PADDLE_W - ball.size
            ball.dx = -ball.dx - 0.5 -- slightly speed up

            local hit_pos = (ball.y + (ball.size / 2)) - (ai_y + (PADDLE_H / 2))
            ball.dy = ball.dy + (hit_pos * 0.1)

            sfx(0) -- UI Blip
        end
    end

    -- Scoring
    if ball.x < 0 then
        score_ai = score_ai + 1
        sfx(1) -- Error Buzz (Player missed)
        if score_ai >= WIN_SCORE then
            game_state = "GAMEOVER"
            sfx(10) -- Okarin Beep
        else
            reset_ball("LEFT")
        end
    elseif ball.x > SCREEN_W then
        score_p1 = score_p1 + 1
        sfx(3) -- Score Sound (System Startup)
        if score_p1 >= WIN_SCORE then
            game_state = "GAMEOVER"
            sfx(10) -- Okarin Beep
        else
            reset_ball("RIGHT")
        end
    end
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

    -- Draw dashed center line
    for y = 0, SCREEN_H, 16 do
        fill_rect(SCREEN_W / 2 - 1, y, 2, 8, C_LINE)
    end

    -- Draw scores
    print(tostring(score_p1), (SCREEN_W / 2) - 40, 20, C_TEXT)
    print(tostring(score_ai), (SCREEN_W / 2) + 30, 20, C_TEXT)

    if game_state == "START" then
        fill_rect(64, 100, 128, 40, C_LINE)
        fill_rect(66, 102, 124, 36, C_BG)
        print("AMADEUS PONG", 90, 108, C_TEXT)
        print("PRESS Z TO START", 80, 120, C_PADDLE)
    elseif game_state == "GAMEOVER" then
        fill_rect(64, 100, 128, 40, C_WIN)
        fill_rect(66, 102, 124, 36, C_BG)

        if score_p1 >= WIN_SCORE then
            print("PLAYER WINS!", 90, 108, C_WIN)
        else
            print("AI WINS!", 100, 108, C_TEXT)
        end
        print("PRESS Z TO RESTART", 75, 120, C_PADDLE)
    else
        -- Draw Ball
        fill_rect(ball.x, ball.y, ball.size, ball.size, C_BALL)
    end

    -- Draw Player Paddle
    fill_rect(16, player_y, PADDLE_W, PADDLE_H, C_PADDLE)

    -- Draw AI Paddle
    fill_rect(SCREEN_W - 16 - PADDLE_W, ai_y, PADDLE_W, PADDLE_H, C_PADDLE)
end
