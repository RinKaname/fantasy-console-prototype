-- Amadeus Cartridge: Founder (Makise Theme)

SCREEN_W = 256
SCREEN_H = 240

-- Colors (Makise)
C_BG = 0      -- Deep Black/Blue
C_DIM = 1     -- Dark Blue/Gray
C_TEXT = 3    -- Light Gray
C_HL = 4      -- Off-White
C_WARN = 8    -- Crimson Red
C_GOOD = 12   -- Pale Green
C_ACCENT = 14 -- Pale Sky Blue

-- Game State
ticks = 0
rng_seed = 1234
game_state = "START" -- START, SETUP_SEC, SETUP_NICHE, PLAY, PITCH, GAMEOVER, WIN

-- Startup Metrics
metrics = {
    cash = 50000,
    mrr = 0,
    users = 0,
    burn = 2000,
    equity = 1.0,
    quality = 1.0,
    hype = 1.0,
    month = 1,
    ap = 3,
    max_ap = 3,
    valuation = 100000,
    devs = 0,
    sales = 0
}

-- Startup Identity
startup = {
    name = "UNDEFINED",
    sector = "",
    niche = "",
    -- Base multipliers
    user_mult = 1.0,
    rev_mult = 1.0,
    burn_mult = 1.0
}

-- Setup Data
sectors = {
    {name = "SAAS", u_mult = 0.8, r_mult = 1.5, b_mult = 1.0},
    {name = "AI", u_mult = 1.2, r_mult = 0.5, b_mult = 2.0},
    {name = "SOCIAL", u_mult = 2.0, r_mult = 0.2, b_mult = 1.2},
    {name = "CRYPTO", u_mult = 1.5, r_mult = 0.8, b_mult = 1.5},
    {name = "HARDWARE", u_mult = 0.5, r_mult = 2.0, b_mult = 2.5}
}

niches = {
    "ED-TECH", "FIN-TECH", "MED-TECH", "GAMING", "ENTERPRISE", "DATING"
}

-- UI State
menu_idx = 1
msg_text = ""
msg_timer = 0
pitch_offer = nil

function random_float()
    rng_seed = (rng_seed * 1103515245 + 12345) % 2147483648
    return rng_seed / 2147483648
end

function show_msg(text, is_good)
    msg_text = text
    msg_timer = 120
    if is_good then sfx(0) else sfx(1) end
end

function format_money(val)
    local abs_v = math.abs(val)
    local sign = val < 0 and "-" or ""

    if abs_v >= 1000000000000 then
        return sign .. "$" .. string.format("%.2f", abs_v / 1000000000000) .. "T"
    elseif abs_v >= 1000000000 then
        return sign .. "$" .. string.format("%.2f", abs_v / 1000000000) .. "B"
    elseif abs_v >= 1000000 then
        return sign .. "$" .. string.format("%.2f", abs_v / 1000000) .. "M"
    elseif abs_v >= 1000 then
        return sign .. "$" .. string.format("%.1f", abs_v / 1000) .. "K"
    else
        return sign .. "$" .. tostring(math.floor(abs_v))
    end
end

function format_num(val)
    if val >= 1000000 then return string.format("%.1fM", val / 1000000)
    elseif val >= 1000 then return string.format("%.1fK", val / 1000)
    else return tostring(math.floor(val)) end
end

function calc_valuation()
    -- Very rough VC logic: Revenue Multiple + User Value + Hype
    -- Valuations get harder to inflate at massive scale without real revenue
    local rev_val = (metrics.mrr * 12) * 10
    local user_val = metrics.users * 1.5 * startup.user_mult -- Greatly reduced per-user value
    local base = rev_val + user_val
    if base < 50000 then base = 50000 end
    metrics.valuation = base * math.min(3.0, (metrics.quality * metrics.hype))
end

function advance_month()
    metrics.month = metrics.month + 1
    metrics.ap = metrics.max_ap + math.floor(metrics.devs / 2) -- Devs give extra AP/automation
    if metrics.ap > 6 then metrics.ap = 6 end

    -- Server Costs (AWS Bill scales with users: approx $500 per 10k users)
    local server_cost = math.floor((metrics.users / 10000) * 500)
    local total_burn = metrics.burn + server_cost

    -- Burn Cash
    metrics.cash = metrics.cash + metrics.mrr - total_burn

    -- Churn & Organic Growth
    -- Churn increases if quality doesn't keep up with massive scale
    local scale_penalty = metrics.users / 5000000 -- 1% extra churn per 5M users
    local churn_rate = (0.10 + scale_penalty) / metrics.quality
    if churn_rate > 0.5 then churn_rate = 0.5 end -- Cap max churn at 50% a month

    local churn = metrics.users * churn_rate
    local viral = metrics.users * (0.05 * metrics.hype * startup.user_mult)

    metrics.users = math.floor(metrics.users - churn + viral)
    if metrics.users < 0 then metrics.users = 0 end

    -- Hype decays over time
    if metrics.hype > 1.0 then
        metrics.hype = metrics.hype - 0.1
    end

    calc_valuation()

    if metrics.cash < 0 then
        game_state = "GAMEOVER"
        sfx(1)
    elseif metrics.valuation > 1000000000 and metrics.mrr > 1000000 then
        game_state = "WIN"
        sfx(3)
    else
        sfx(2)
    end
end

function generate_pitch()
    -- Calculate a realistic VC offer based on current valuation
    local ask_cash = metrics.valuation * (0.15 + (random_float() * 0.15)) -- Ask for 15-30% of val
    local ask_eq = ask_cash / (metrics.valuation + ask_cash) -- Post-money equity

    pitch_offer = {
        cash = ask_cash,
        equity = ask_eq
    }
end

-- Debouncing
btn_state = {false,false,false,false,false,false,false,false}
function just_pressed(b)
    if btn(b) and not btn_state[b] then
        btn_state[b] = true
        rng_seed = (rng_seed + ticks + b * 91) % 2147483648
        return true
    end
    if not btn(b) then btn_state[b] = false end
    return false
end

function _init()
    ticks = 0
    game_state = "START"
end

function start_game()
    metrics = {
        cash = 50000, mrr = 0, users = 0, burn = 2000,
        equity = 1.0, quality = 1.0, hype = 1.0,
        month = 1, ap = 3, max_ap = 3, valuation = 100000,
        devs = 0, sales = 0
    }
    menu_idx = 1
    game_state = "SETUP_SEC"
    sfx(3)
end

actions = {
    {name = "BUILD MVP", ap = 1, desc = "+ QUALITY | + HYPE"},
    {name = "MARKETING", ap = 1, desc = "COST SCALES | + USERS"},
    {name = "SALES PUSH", ap = 1, desc = "CONVERT USERS -> MRR"},
    {name = "HIRE DEV", ap = 2, desc = "+$5K BURN | + AP CAPACITY"},
    {name = "PITCH VC", ap = 3, desc = "SEEK SEED / SERIES FUNDING"}
}

function _update()
    ticks = ticks + 1
    if msg_timer > 0 then msg_timer = msg_timer - 1 end

    if game_state == "START" or game_state == "GAMEOVER" or game_state == "WIN" then
        if just_pressed(4) then start_game() end
        return
    end

    if game_state == "SETUP_SEC" then
        if just_pressed(2) then menu_idx = menu_idx - 1; sfx(2) end
        if just_pressed(3) then menu_idx = menu_idx + 1; sfx(2) end
        if menu_idx < 1 then menu_idx = #sectors end
        if menu_idx > #sectors then menu_idx = 1 end

        if just_pressed(4) then
            local sec = sectors[menu_idx]
            startup.sector = sec.name
            startup.user_mult = sec.u_mult
            startup.rev_mult = sec.r_mult
            startup.burn_mult = sec.b_mult
            metrics.burn = metrics.burn * sec.b_mult

            menu_idx = 1
            game_state = "SETUP_NICHE"
            sfx(0)
        end
    elseif game_state == "SETUP_NICHE" then
        if just_pressed(2) then menu_idx = menu_idx - 1; sfx(2) end
        if just_pressed(3) then menu_idx = menu_idx + 1; sfx(2) end
        if menu_idx < 1 then menu_idx = #niches end
        if menu_idx > #niches then menu_idx = 1 end

        if just_pressed(4) then
            startup.niche = niches[menu_idx]
            startup.name = startup.niche .. " " .. startup.sector
            menu_idx = 1
            game_state = "PLAY"
            sfx(3)
        end
    elseif game_state == "PLAY" then
        if just_pressed(2) then menu_idx = menu_idx - 1; sfx(2) end
        if just_pressed(3) then menu_idx = menu_idx + 1; sfx(2) end
        if menu_idx < 1 then menu_idx = #actions end
        if menu_idx > #actions then menu_idx = 1 end

        if just_pressed(4) then
            local act = actions[menu_idx]
            if metrics.ap >= act.ap then
                metrics.ap = metrics.ap - act.ap

                if menu_idx == 1 then -- BUILD
                    metrics.quality = metrics.quality + 0.2
                    metrics.hype = metrics.hype + 0.1
                    if metrics.users == 0 then metrics.users = 10 end -- First users
                    show_msg("SHIPPED NEW FEATURE!", true)
                elseif menu_idx == 2 then -- MARKETING
                    -- Marketing costs scale up as you get bigger
                    local ad_cost = 2000 + math.floor(metrics.users * 0.05)
                    if metrics.cash >= ad_cost then
                        metrics.cash = metrics.cash - ad_cost
                        -- Gain scales with existing userbase but has diminishing returns
                        local gain_base = 500 + (metrics.users * 0.10)
                        local gained = math.floor((gain_base + random_float() * gain_base) * startup.user_mult * metrics.hype)
                        metrics.users = metrics.users + gained
                        show_msg("ADS ($" .. format_num(ad_cost) .. "): +" .. format_num(gained) .. " USERS", true)
                    else
                        show_msg("NEED " .. format_money(ad_cost) .. " FOR ADS!", false)
                        metrics.ap = metrics.ap + act.ap -- refund AP
                    end
                elseif menu_idx == 3 then -- SALES
                    if metrics.users > 100 then
                        -- Convert a % of users to MRR
                        local converted = metrics.users * 0.05 * startup.rev_mult
                        local new_mrr = math.floor(converted * (5.0 + random_float() * 10.0))
                        metrics.mrr = metrics.mrr + new_mrr
                        show_msg("SALES CLOSED: +$" .. tostring(new_mrr) .. " MRR", true)
                    else
                        show_msg("NOT ENOUGH USERS TO MONETIZE!", false)
                        metrics.ap = metrics.ap + act.ap
                    end
                elseif menu_idx == 4 then -- HIRE
                    metrics.burn = metrics.burn + 5000
                    metrics.devs = metrics.devs + 1
                    show_msg("HIRED DEVELOPER! BURN +$5K", true)
                elseif menu_idx == 5 then -- PITCH
                    generate_pitch()
                    game_state = "PITCH"
                    sfx(3)
                end

                -- Check for month advance
                if metrics.ap <= 0 and game_state == "PLAY" then
                    advance_month()
                end
            else
                show_msg("NOT ENOUGH AP!", false)
            end
        end

        -- End turn early
        if just_pressed(6) and game_state == "PLAY" then
            metrics.ap = 0
            advance_month()
        end

    elseif game_state == "PITCH" then
        if just_pressed(4) then -- ACCEPT
            metrics.cash = metrics.cash + pitch_offer.cash
            metrics.equity = metrics.equity * (1.0 - pitch_offer.equity)
            show_msg("RAISED " .. format_money(pitch_offer.cash) .. "!", true)

            -- Advance month since pitch takes all AP
            metrics.ap = 0
            advance_month()
            if game_state ~= "GAMEOVER" then game_state = "PLAY" end

        elseif just_pressed(5) then -- REJECT
            show_msg("REJECTED VC OFFER.", false)
            metrics.ap = 0
            advance_month()
            if game_state ~= "GAMEOVER" then game_state = "PLAY" end
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

function draw_line(x0, y0, x1, y1, col)
    local dx = math.abs(x1 - x0)
    local dy = -math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx + dy
    while true do
        pset(x0, y0, col)
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 >= dy then err = err + dy; x0 = x0 + sx end
        if e2 <= dx then err = err + dx; y0 = y0 + sy end
    end
end

function draw_progress(x, y, w, current, max, col)
    fill_rect(x, y, w, 6, C_DIM)
    local pct = current / max
    if pct > 1.0 then pct = 1.0 end
    fill_rect(x, y, math.floor(w * pct), 6, col)
end

function _draw()
    cls(C_BG)

    if game_state == "START" then
        fill_rect(40, 80, 176, 60, C_DIM)
        fill_rect(42, 82, 172, 56, C_BG)
        print("AMADEUS FOUNDER", 70, 90, C_HL)
        print("BUILD THE NEXT UNICORN", 48, 105, C_TEXT)
        print("PRESS Z TO START", 70, 125, C_ACCENT)
        return
    elseif game_state == "GAMEOVER" then
        fill_rect(40, 80, 176, 60, C_WARN)
        fill_rect(42, 82, 172, 56, C_BG)
        print("BANKRUPT", 100, 90, C_WARN)
        print("YOUR STARTUP RAN OUT OF CASH", 45, 105, C_TEXT)
        print("PRESS Z TO RESTART", 70, 125, C_DIM)
        return
    elseif game_state == "WIN" then
        fill_rect(30, 80, 196, 60, C_GOOD)
        fill_rect(32, 82, 192, 56, C_BG)
        print("UNICORN STATUS ACHIEVED!", 45, 90, C_GOOD)
        print("IPO / ACQUISITION COMPLETE", 45, 105, C_HL)
        print("PRESS Z TO PLAY AGAIN", 55, 125, C_TEXT)
        return
    end

    if game_state == "SETUP_SEC" or game_state == "SETUP_NICHE" then
        print("STARTUP REGISTRATION", 50, 20, C_HL)
        draw_line(0, 30, SCREEN_W, 30, C_DIM)

        if game_state == "SETUP_SEC" then
            print("SELECT CORE SECTOR:", 20, 50, C_TEXT)
            for i = 1, #sectors do
                local col = (i == menu_idx) and C_HL or C_DIM
                if i == menu_idx then print(">", 10, 65 + (i*12), C_HL) end
                print(sectors[i].name, 20, 65 + (i*12), col)
            end
        else
            print("SELECT NICHE:", 20, 50, C_TEXT)
            for i = 1, #niches do
                local col = (i == menu_idx) and C_HL or C_DIM
                if i == menu_idx then print(">", 10, 65 + (i*12), C_HL) end
                print(niches[i], 20, 65 + (i*12), col)
            end
        end
        return
    end

    -- MAIN UI (PLAY & PITCH)

    -- TOP: KPI Dashboard
    fill_rect(0, 0, SCREEN_W, 64, C_DIM)
    fill_rect(0, 0, SCREEN_W, 63, C_BG)

    print(startup.name, 4, 4, C_HL)
    print("MONTH: " .. tostring(metrics.month), 200, 4, C_TEXT)

    print("CASH: " .. format_money(metrics.cash), 4, 16, C_GOOD)
    print("BURN: " .. format_money(metrics.burn) .. "/MO", 4, 26, C_WARN)

    print("USERS: " .. format_num(metrics.users), 120, 16, C_ACCENT)
    print("MRR:   " .. format_money(metrics.mrr), 120, 26, C_GOOD)

    draw_line(0, 36, SCREEN_W, 36, C_DIM)

    print("VALUATION: " .. format_money(metrics.valuation), 4, 42, C_HL)
    print("EQUITY: " .. string.format("%.1f%%", metrics.equity * 100), 4, 52, C_TEXT)

    local runway = metrics.cash / metrics.burn
    local run_col = runway < 3 and C_WARN or C_GOOD
    print("RUNWAY: " .. string.format("%.1f", runway) .. " MO", 150, 42, run_col)

    -- MIDDLE: Action Menu
    print("ACTION POINTS: " .. tostring(metrics.ap) .. " / " .. tostring(metrics.max_ap), 4, 70, C_HL)
    draw_progress(4, 80, 100, metrics.ap, metrics.max_ap, C_ACCENT)

    if game_state == "PLAY" then
        draw_line(0, 92, SCREEN_W, 92, C_DIM)
        for i = 1, #actions do
            local act = actions[i]
            local col = (i == menu_idx) and C_HL or C_TEXT
            local y = 100 + ((i-1) * 20)

            if i == menu_idx then print(">", 4, y, C_HL) end

            local desc = act.desc
            -- Dynamically update the Marketing cost text based on current scaling
            if i == 2 then
                local ad_cost = 2000 + math.floor(metrics.users * 0.05)
                desc = "COST: " .. format_money(ad_cost) .. " | + USERS"
            end

            print(act.name .. " [" .. tostring(act.ap) .. " AP]", 14, y, col)
            print(desc, 14, y + 8, C_DIM)
        end

        draw_line(0, 205, SCREEN_W, 205, C_DIM)
        if msg_timer > 0 then
            print(">> " .. msg_text, 4, 215, C_HL)
        else
            print("Z: EXECUTE   ENTER: END MONTH", 4, 215, C_TEXT)
        end

    elseif game_state == "PITCH" then
        fill_rect(20, 100, 216, 80, C_DIM)
        fill_rect(22, 102, 212, 76, C_BG)

        print("TERM SHEET OFFER", 70, 110, C_HL)
        draw_line(22, 120, 238, 120, C_DIM)

        print("VC FIRM OFFERS: " .. format_money(pitch_offer.cash), 30, 130, C_GOOD)
        print("FOR EQUITY:     " .. string.format("%.1f%%", pitch_offer.equity * 100), 30, 145, C_WARN)

        print("Z: ACCEPT DEAL", 40, 165, C_HL)
        print("X: REJECT", 150, 165, C_TEXT)
    end
end
