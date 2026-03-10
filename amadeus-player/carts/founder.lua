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
    cash = 20000,  -- Reduced from $50k to $20k (tighter runway)
    mrr = 0,
    users = 0,
    burn = 3000,   -- Increased base burn
    equity = 1.0,
    quality = 1.0,
    hype = 1.0,
    month = 1,
    ap = 3,
    max_ap = 3,
    valuation = 50000,  -- Lower starting valuation
    devs = 0,
    sales = 0,
    market_size = 100000,  -- Total addressable market
    market_share = 0,
    competitor_strength = 1.0,  -- AI competitors get stronger over time
    pmf_score = 0.3  -- Product-market fit (starts low, needs work)
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
    {name = "SAAS", u_mult = 0.7, r_mult = 1.3, b_mult = 1.1},      -- Nerfed slightly
    {name = "AI", u_mult = 1.0, r_mult = 0.7, b_mult = 1.6},        -- More competitive pressure
    {name = "SOCIAL", u_mult = 1.5, r_mult = 0.15, b_mult = 1.4},   -- Harder to monetize
    {name = "CRYPTO", u_mult = 1.2, r_mult = 0.6, b_mult = 1.7},    -- Volatile and risky
    {name = "HARDWARE", u_mult = 0.4, r_mult = 1.8, b_mult = 2.0}   -- Capital intensive
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
    -- Brutally realistic VC logic: Revenue is KING, users mean nothing without monetization
    -- Late stage investors punish vanity metrics hard
    local rev_val = (metrics.mrr * 12) * 8  -- Reduced multiple from 10x to 8x
    
    -- User value gets MASSIVE penalty at scale without revenue
    local user_val = 0
    if metrics.mrr > 0 then
        local arpu = metrics.mrr / math.max(1, metrics.users)
        if arpu < 1 then
            user_val = metrics.users * 0.1  -- Penny ARPU = worthless users
        elseif arpu < 5 then
            user_val = metrics.users * 0.5  -- Still bad
        else
            user_val = metrics.users * 2.0 * startup.user_mult  -- Decent ARPU
        end
    else
        user_val = metrics.users * 0.05  -- No revenue = almost worthless
    end
    
    local base = rev_val + user_val
    if base < 50000 then base = 50000 end
    
    -- Hype multiplier capped lower, quality matters more
    local hype_cap = metrics.pmf_score > 0.7 and 2.0 or 1.5
    metrics.valuation = base * math.min(hype_cap, (metrics.quality * (0.5 + metrics.hype * 0.5)))
end

function advance_month()
    metrics.month = metrics.month + 1
    -- FIX: Devs increase max_ap capacity, not just current AP
    metrics.max_ap = 3 + math.floor(metrics.devs / 2)
    metrics.ap = metrics.max_ap -- Reset to full AP at month start
    
    -- Competitors get stronger over time (especially in AI/Crypto) - ACCELERATED
    if startup.sector == "AI" or startup.sector == "CRYPTO" then
        metrics.competitor_strength = metrics.competitor_strength + 0.08  -- Increased from 0.05
    else
        metrics.competitor_strength = metrics.competitor_strength + 0.03  -- Increased from 0.02
    end
    
    -- Market saturation: harder to grow as you capture more market share
    local saturation_penalty = metrics.market_share * 0.5  -- 50% reduction at 100% share
    if viral > 0 then
        viral = viral * (1.0 - saturation_penalty)
    end
    
    -- Server Costs (AWS Bill scales with users: approx $500 per 10k users)
    local server_cost = math.floor((metrics.users / 10000) * 500)
    local total_burn = metrics.burn + server_cost

    -- Burn Cash (with penalty if burning too fast)
    local burn_penalty = 1.0
    if total_burn > metrics.mrr * 3 then
        burn_penalty = 1.2  -- 20% extra cash burn when inefficient
        show_msg(\"BURN RATE TOO HIGH! -20% EFFICIENCY\", false)
    end
    metrics.cash = metrics.cash + metrics.mrr - (total_burn * burn_penalty)

    -- Churn & Organic Growth
    -- Churn increases MASSIVELY if quality doesn't keep up with scale OR if competitors are strong
    local scale_penalty = metrics.users / 2000000 -- 1% extra churn per 2M users (was 5M)
    local competitor_penalty = (metrics.competitor_strength - 1.0) * 0.15 -- Stronger competitors = more churn (increased from 0.1)
    local pmf_bonus = metrics.pmf_score * 0.08 -- Better PMF = less churn (slightly increased)
    local quality_requirement = math.log10(metrics.users + 1) * 0.3 -- Quality needs to scale with log(users)
    local quality_gap = quality_requirement - metrics.quality
    if quality_gap > 0 then
        scale_penalty = scale_penalty + quality_gap * 0.1
    end
    local churn_rate = (0.15 + scale_penalty + competitor_penalty - pmf_bonus) / metrics.quality
    if churn_rate > 0.7 then churn_rate = 0.7 end -- Cap max churn at 70% a month

    local churn = metrics.users * churn_rate
    -- Viral growth is reduced by competitor strength
    local viral = metrics.users * (0.04 * metrics.hype * startup.user_mult / metrics.competitor_strength)

    metrics.users = math.floor(metrics.users - churn + viral)
    if metrics.users < 0 then metrics.users = 0 end
    
    -- Update market share
    if metrics.market_size > 0 then
        metrics.market_share = metrics.users / metrics.market_size
    end
    
    -- Hype decays faster if PMF is low
    local hype_decay = metrics.pmf_score < 0.5 and 0.15 or 0.1
    if metrics.hype > 1.0 then
        metrics.hype = metrics.hype - hype_decay
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
        cash = 20000, mrr = 0, users = 0, burn = 3000,
        equity = 1.0, quality = 1.0, hype = 1.0,
        month = 1, ap = 3, max_ap = 3, valuation = 50000,
        devs = 0, sales = 0,
        market_size = 100000,
        market_share = 0,
        competitor_strength = 1.0,
        pmf_score = 0.3
    }
    startup.user_mult = 1.0  -- Reset multipliers
    startup.rev_mult = 1.0
    startup.burn_mult = 1.0
    menu_idx = 1
    game_state = "SETUP_SEC"
    sfx(3)
end

actions = {
    {name = "BUILD MVP", ap = 1, desc = "+ QUALITY | + PMF | + HYPE"},
    {name = "MARKETING", ap = 1, desc = "COST SCALES | + USERS"},
    {name = "SALES PUSH", ap = 1, desc = "CONVERT USERS -> MRR"},
    {name = "HIRE DEV", ap = 2, desc = "+$5K BURN | + AP CAPACITY"},
    {name = "CUSTOMER DEV", ap = 1, desc = "++ PMF SCORE (INTERVIEWS)"},
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
                    metrics.pmf_score = math.min(1.0, metrics.pmf_score + 0.05) -- Small PMF gain
                    metrics.hype = metrics.hype + 0.1
                    if metrics.users == 0 then metrics.users = 10 end -- First users
                    show_msg("SHIPPED NEW FEATURE!", true)
                elseif menu_idx == 2 then -- MARKETING
                    -- Marketing costs scale up MUCH faster as you get bigger
                    local ad_cost = 3000 + math.floor(metrics.users * 0.1)  -- Increased base and scaling
                    if metrics.cash >= ad_cost then
                        metrics.cash = metrics.cash - ad_cost
                        -- Gain scales with existing userbase but has STRONG diminishing returns
                        local gain_base = 300 + (metrics.users * 0.05)  -- Reduced gains
                        local gained = math.floor((gain_base + random_float() * gain_base) * startup.user_mult * metrics.hype / (1 + metrics.users/1000000))
                        metrics.users = metrics.users + gained
                        show_msg("ADS ($" .. format_num(ad_cost) .. "): +" .. format_num(gained) .. " USERS", true)
                    else
                        show_msg("NEED " .. format_money(ad_cost) .. " FOR ADS!", false)
                        metrics.ap = metrics.ap + act.ap -- refund AP
                    end
                elseif menu_idx == 3 then -- SALES
                    if metrics.users > 100 then
                        -- Conversion rate now depends on PMF score (higher PMF = better conversion)
                        local base_conversion = 0.05 + (metrics.pmf_score * 0.07) -- 5%-12% based on PMF (reduced from 8%-16%)
                        local converted = metrics.users * base_conversion * startup.rev_mult
                        -- ARPU also benefits from PMF: $8-25 range scaled by PMF (reduced from $10-30)
                        local arpu_base = 8.0 + (metrics.pmf_score * 12.0)
                        local new_mrr = math.floor(converted * (arpu_base + random_float() * 10.0))
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
                elseif menu_idx == 5 then -- CUSTOMER DEV
                    -- Customer development significantly improves PMF
                    local pmf_gain = 0.1 + (random_float() * 0.1)
                    metrics.pmf_score = math.min(1.0, metrics.pmf_score + pmf_gain)
                    metrics.hype = metrics.hype + 0.05
                    show_msg("CUSTOMER INTERVIEWS: PMF +" .. string.format("%.0f", pmf_gain*100) .. "%", true)
                elseif menu_idx == 6 then -- PITCH
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
    
    -- Calculate server cost for display
    local server_cost = math.floor((metrics.users / 10000) * 500)
    print("BURN: " .. format_money(metrics.burn) .. "+" .. format_money(server_cost) .. "/MO", 4, 26, C_WARN)

    print("USERS: " .. format_num(metrics.users), 120, 16, C_ACCENT)
    print("MRR:   " .. format_money(metrics.mrr), 120, 26, C_GOOD)

    draw_line(0, 36, SCREEN_W, 36, C_DIM)

    print("VALUATION: " .. format_money(metrics.valuation), 4, 42, C_HL)
    print("EQUITY: " .. string.format("%.1f%%", metrics.equity * 100), 4, 52, C_TEXT)
    
    -- Calculate runway including MRR
    local net_burn = metrics.burn - metrics.mrr
    local runway = net_burn > 0 and (metrics.cash / net_burn) or 99.9
    if runway > 99 then runway = 99.9 end
    local run_col = runway < 3 and C_WARN or (runway < 6 and C_TEXT or C_GOOD)
    print("RUNWAY: " .. string.format("%.1f", runway) .. " MO", 150, 42, run_col)

    -- MIDDLE: Action Menu
    print("ACTION POINTS: " .. tostring(metrics.ap) .. " / " .. tostring(metrics.max_ap), 4, 70, C_HL)
    draw_progress(4, 80, 100, metrics.ap, metrics.max_ap, C_ACCENT)
    
    -- Show PMF score and competitor strength
    local pmf_col = metrics.pmf_score < 0.5 and C_WARN or (metrics.pmf_score < 0.8 and C_TEXT or C_GOOD)
    print("PMF: " .. string.format("%.0f%%", metrics.pmf_score * 100), 150, 70, pmf_col)
    print("COMP: " .. string.format("%.1fx", metrics.competitor_strength), 200, 70, C_WARN)

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
