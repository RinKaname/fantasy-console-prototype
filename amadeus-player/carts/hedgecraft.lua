-- Amadeus Cartridge: HedgeCraft (IBN-5100 Theme)

SCREEN_W = 256
SCREEN_H = 240

C_BG = 0
C_DIM = 1
C_TEXT = 2
C_HL = 3

-- Mathematical Constants (Stored in Cents)
MILLION = 100000000 -- 1 million dollars = 100,000,000 cents
BILLION = 100000000000

-- Game State
ticks = 0
rng_seed = 42
game_state = "START"
month = 1

gp_cash = 2 * MILLION -- Start with $2M General Partner capital
total_aum = 0
series_list = {}
series_counter = 1

compliance_spend = 5000000 -- $50k per month initially
base_opex = 10000000       -- $100k per month fixed cost
sec_heat = 0.0

last_return_pct = 0.0
msg_text = ""
msg_timer = 0

-- PRNG
function random_float()
    rng_seed = (rng_seed * 1103515245 + 12345) % 2147483648
    return rng_seed / 2147483648
end

-- Box-Muller transform for normal distribution
function random_normal()
    local u1 = random_float()
    local u2 = random_float()
    if u1 == 0.0 then u1 = 0.0001 end -- avoid log(0)
    local z0 = math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)
    return z0
end

-- String formatting for cents -> $M
function format_money(cents)
    local m = cents / MILLION
    if m >= 1000.0 then
        return string.format("$%.2fB", m / 1000.0)
    else
        return string.format("$%.2fM", m)
    end
end

function show_msg(text, is_good)
    msg_text = text
    msg_timer = 120 -- 2 seconds
    if is_good then sfx(0) else sfx(1) end
end

function new_series(capital_cents)
    local s = {
        id = series_counter,
        shares = capital_cents, -- Initial NAV is $1.00/share, so shares == cents
        nav_per_share = 1.0,    -- Float (Multiplier)
        hwm = 1.0               -- High Water Mark (Float)
    }
    table.insert(series_list, s)
    series_counter = series_counter + 1
    total_aum = total_aum + capital_cents
    return s
end

function _init()
    ticks = 0
    month = 1
    gp_cash = 2 * MILLION
    total_aum = 0
    series_list = {}
    series_counter = 1
    sec_heat = 0.0
    last_return_pct = 0.0

    -- Raise initial $50M seed capital
    new_series(50 * MILLION)
    game_state = "PLAY"
    sfx(3)
end

function advance_month()
    month = month + 1

    -- 1. Calculate Gross Return (Alpha Decay + Volatility)
    -- As AUM approaches $1B, alpha decays towards 0.
    local capacity_limit = 1 * BILLION
    local utilization = total_aum / capacity_limit
    local alpha = 0.02 * math.exp(-2.0 * utilization) -- 2% monthly base alpha, decays exponentially

    -- Add market noise (volatility clustering simplified)
    local noise = random_normal() * 0.03 -- 3% monthly standard deviation

    local gross_return = alpha + noise
    last_return_pct = gross_return * 100.0

    -- 2. Apply Returns & Calculate Fees (Series Accounting)
    local total_mgmt_fee = 0
    local total_perf_fee = 0
    total_aum = 0 -- Recalculate

    for i = #series_list, 1, -1 do
        local s = series_list[i]

        -- Apply gross return to NAV
        s.nav_per_share = s.nav_per_share * (1.0 + gross_return)
        local series_value = math.floor(s.shares * s.nav_per_share)

        -- Deduct Management Fee (2% annually -> 0.1666% monthly)
        local mgmt_fee = math.floor(series_value * (0.02 / 12.0))
        total_mgmt_fee = total_mgmt_fee + mgmt_fee
        series_value = series_value - mgmt_fee

        -- Recalculate NAV after mgmt fee
        s.nav_per_share = series_value / s.shares

        -- Deduct Performance Fee (20% of profits above HWM)
        if s.nav_per_share > s.hwm then
            local profit_per_share = s.nav_per_share - s.hwm
            local perf_fee_per_share = profit_per_share * 0.20

            local perf_fee_total = math.floor(perf_fee_per_share * s.shares)
            total_perf_fee = total_perf_fee + perf_fee_total

            s.nav_per_share = s.nav_per_share - perf_fee_per_share
            s.hwm = s.nav_per_share -- Set new HWM
            series_value = math.floor(s.shares * s.nav_per_share)
        end

        -- Check if Series is wiped out
        if series_value <= 0 then
            table.remove(series_list, i)
        else
            total_aum = total_aum + series_value
        end
    end

    -- 3. OpEx and Compliance
    -- Base OpEx scales logarithmically with AUM: OpEx = Base + (Scale * ln(AUM_Millions))
    local aum_m = total_aum / MILLION
    if aum_m < 1 then aum_m = 1 end
    local scaling_cost = math.floor(1000000 * math.log(aum_m)) -- $10k per log unit
    local total_opex = base_opex + scaling_cost + compliance_spend

    -- Update GP Cash
    gp_cash = gp_cash + total_mgmt_fee + total_perf_fee - total_opex

    -- 4. Risk Check: Insolvency
    if gp_cash < 0 then
        game_state = "GAMEOVER_CASH"
        sfx(1)
        return
    end

    -- 5. Risk Check: SEC Audit
    -- Ideal compliance spend scales linearly with AUM. E.g., $10k per $100M AUM.
    local required_comp = math.floor((total_aum / (100 * MILLION)) * 1000000)
    if required_comp < 5000000 then required_comp = 5000000 end -- Min $50k

    if compliance_spend < required_comp then
        -- Build heat
        local deficit_ratio = 1.0 - (compliance_spend / required_comp)
        sec_heat = sec_heat + (deficit_ratio * 0.05) -- Heat grows up to 5% per month
    else
        -- Cool down
        sec_heat = math.max(0.0, sec_heat - 0.02)
    end

    if random_float() < sec_heat then
        game_state = "GAMEOVER_SEC"
        sfx(1)
        return
    end

    -- Play sound for advancing month based on return
    if gross_return > 0 then sfx(2) else sfx(1) end
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

function _update()
    ticks = ticks + 1
    if msg_timer > 0 then msg_timer = msg_timer - 1 end

    if game_state == "GAMEOVER_CASH" or game_state == "GAMEOVER_SEC" then
        if just_pressed(4) then _init() end
        return
    end

    if game_state == "PLAY" then
        -- Adjust Compliance Spend
        if just_pressed(2) then -- UP
            compliance_spend = compliance_spend + 1000000 -- +$10k
            sfx(0)
        elseif just_pressed(3) then -- DOWN
            compliance_spend = math.max(0, compliance_spend - 1000000) -- -$10k
            sfx(0)
        end

        -- Raise Capital (Z)
        if just_pressed(4) then
            -- Can only raise if recent returns were good, simplified: random chance based on AUM
            if total_aum < 5 * BILLION then
                local raise_amt = math.floor((total_aum * 0.20) / MILLION) * MILLION -- Raise 20% of current AUM
                if raise_amt < 10 * MILLION then raise_amt = 10 * MILLION end
                new_series(raise_amt)
                show_msg("RAISED " .. format_money(raise_amt) .. " IN NEW SERIES!", true)
            else
                show_msg("CAPACITY REACHED. NO NEW LPs.", false)
            end
        end

        -- Advance Month (X)
        if just_pressed(5) then
            advance_month()
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

function _draw()
    cls(C_BG)

    -- HEADER
    fill_rect(0, 0, SCREEN_W, 46, C_DIM)
    print("HEDGECRAFT : ALPHA FUND I", 4, 4, C_HL)
    print("MONTH: " .. tostring(month), 200, 4, C_TEXT)

    print("AUM:     " .. format_money(total_aum), 4, 16, C_HL)
    print("GP CASH: " .. format_money(gp_cash), 4, 26, C_HL)

    local ret_col = last_return_pct >= 0 and C_HL or C_TEXT
    print("LAST MTH: " .. string.format("%.2f%%", last_return_pct), 140, 16, ret_col)

    -- HEAT
    local heat_col = sec_heat > 0.3 and C_TEXT or C_HL
    if sec_heat > 0.6 then heat_col = C_BG end -- Flash warning if we had more colors, use C_BG for now as a "blink" if we animate it
    print("SEC HEAT: " .. string.format("%.1f%%", sec_heat * 100), 140, 26, heat_col)

    draw_line(0, 47, SCREEN_W, 47, C_TEXT)

    if game_state == "PLAY" then
        -- COMPLIANCE SLIDER
        print("COMPLIANCE SPEND (UP/DWN): " .. format_money(compliance_spend) .. "/MO", 4, 55, C_TEXT)
        draw_line(0, 65, SCREEN_W, 65, C_DIM)

        -- SERIES BREAKDOWN
        print("ACTIVE SERIES ACCOUNTING (HWM)", 4, 72, C_HL)

        local start_idx = math.max(1, #series_list - 5)
        for i = start_idx, #series_list do
            local s = series_list[i]
            local y = 84 + ((i - start_idx) * 16)

            local nav_str = string.format("%.3f", s.nav_per_share)
            local hwm_str = string.format("%.3f", s.hwm)

            local col = C_TEXT
            if s.nav_per_share > s.hwm then col = C_HL end

            print("S" .. tostring(s.id) .. " NAV: " .. nav_str .. " | HWM: " .. hwm_str, 8, y, col)
        end

        -- FOOTER
        draw_line(0, 205, SCREEN_W, 205, C_DIM)
        if msg_timer > 0 then
            fill_rect(0, 206, SCREEN_W, 34, C_BG)
            print(msg_text, 4, 216, C_HL)
        else
            print("Z: RAISE CAPITAL", 10, 212, C_HL)
            print("X: ADVANCE 1 MONTH", 10, 224, C_HL)
        end

    elseif game_state == "GAMEOVER_CASH" then
        fill_rect(30, 90, 196, 50, C_TEXT)
        fill_rect(32, 92, 192, 46, C_BG)
        print("FUND INSOLVENT", 75, 100, C_TEXT)
        print("MANAGEMENT FEES FAILED TO COVER OPEX", 40, 110, C_DIM)
        print("PRESS Z TO RESTART", 60, 124, C_HL)
    elseif game_state == "GAMEOVER_SEC" then
        fill_rect(30, 90, 196, 50, C_HL)
        fill_rect(32, 92, 192, 46, C_BG)
        print("SEC RAID & ASSET FREEZE", 50, 100, C_HL)
        print("COMPLIANCE FAILURES DETECTED", 45, 110, C_TEXT)
        print("PRESS Z TO RESTART", 60, 124, C_DIM)
    end
end
