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
year = 1
month = 1

gp_cash = 10 * MILLION -- Start with $10M General Partner capital
total_aum = 50 * MILLION
year_start_aum = 50 * MILLION

compliance_spend = 5000000 -- $50k per month initially
base_opex = 10000000       -- $100k per month fixed cost
sec_heat = 0.0

last_return_pct = 0.0
msg_text = ""
msg_timer = 0

-- Market Regimes
regimes = {
    { name = "BULL MARKET", mom = 1.1, vol = 0.7, liq = 1.2, fund = 1.3 },
    { name = "BEAR MARKET", mom = -0.4, vol = 1.4, liq = 0.8, fund = 0.7 },
    { name = "SIDEWAYS GRIND", mom = 0.0, vol = 0.5, liq = 1.0, fund = 0.9 },
    { name = "VOLATILITY SPIKE", mom = -0.1, vol = 2.0, liq = 0.6, fund = 0.8 },
    { name = "LIQUIDITY CRISIS", mom = -0.8, vol = 2.5, liq = 0.3, fund = 0.2 },
    { name = "RECOVERY PHASE", mom = 0.8, vol = 1.2, liq = 1.1, fund = 1.1 }
}
current_regime = 1

view_mode = "DASH" -- "DASH" or "OPS"
ops_idx = 1

-- Staffing Roster
staff = {
    pm = 1,    -- Portfolio Managers ($30k/mo, +500M Capacity)
    quant = 0, -- Quant Researchers ($25k/mo, +0.5% Base Alpha)
    risk = 0,  -- Risk Managers ($20k/mo, -0.5% Volatility)
    comp = 0   -- Compliance Officers ($15k/mo, -1.0% SEC Heat)
}

roles = {
    { id="pm", name="PORTFOLIO MANAGER", cost=3000000, desc="+500M ALPHA CAPACITY" },
    { id="quant", name="QUANT RESEARCHER", cost=2500000, desc="+0.5% BASE ALPHA" },
    { id="risk", name="RISK MANAGER", cost=2000000, desc="-0.5% VOLATILITY" },
    { id="comp", name="COMPLIANCE OFFICER", cost=1500000, desc="-1.0% SEC HEAT/MO" }
}

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

function roll_regime()
    -- Simple weighted random (could be expanded)
    local r = random_float()
    if r < 0.3 then current_regime = 1 -- Bull (30%)
    elseif r < 0.5 then current_regime = 2 -- Bear (20%)
    elseif r < 0.8 then current_regime = 3 -- Sideways (30%)
    elseif r < 0.9 then current_regime = 4 -- Volatility Spike (10%)
    elseif r < 0.95 then current_regime = 5 -- Liquidity Crisis (5%)
    else current_regime = 6 end -- Recovery (5%)
end

function _init()
    ticks = 0
    year = 1
    month = 1
    gp_cash = 10 * MILLION
    total_aum = 50 * MILLION
    year_start_aum = 50 * MILLION
    sec_heat = 0.0
    last_return_pct = 0.0
    roll_regime()
    game_state = "PLAY"
    sfx(3)
end

function advance_month()
    local regime = regimes[current_regime]

    -- 1. Calculate Gross Return (Alpha Decay + Regime Effects)
    local capacity_limit = (500 * MILLION) + (staff.pm * 500 * MILLION)
    local utilization = total_aum / capacity_limit

    local base_alpha = 0.015 + (staff.quant * 0.005)
    local alpha = base_alpha * math.exp(-2.0 * utilization)

    -- Apply Regime Momentum
    alpha = alpha + (regime.mom * 0.02)

    -- Calculate Volatility (Base - RiskMgr + Regime)
    local base_vol = 0.03 - (staff.risk * 0.005)
    if base_vol < 0.01 then base_vol = 0.01 end
    base_vol = base_vol * regime.vol

    -- Add market noise
    local noise = random_normal() * base_vol

    -- Apply Liquidity consistency factor
    local gross_return = (alpha + noise) / regime.liq
    last_return_pct = gross_return * 100.0

    -- 2. Apply Returns to total AUM
    local monthly_profit = math.floor(total_aum * gross_return)
    total_aum = total_aum + monthly_profit

    if total_aum < 0 then total_aum = 0 end

    -- 3. OpEx and Compliance
    local aum_m = total_aum / MILLION
    if aum_m < 1 then aum_m = 1 end
    local scaling_cost = math.floor(1000000 * math.log(aum_m))

    local staff_cost = (staff.pm * roles[1].cost) +
                       (staff.quant * roles[2].cost) +
                       (staff.risk * roles[3].cost) +
                       (staff.comp * roles[4].cost)

    local total_opex = base_opex + scaling_cost + compliance_spend + staff_cost

    -- Deduct monthly overhead from GP Cash directly
    gp_cash = gp_cash - total_opex

    -- 4. Risk Check: Insolvency
    if gp_cash < 0 then
        game_state = "GAMEOVER_CASH"
        sfx(1)
        return
    end

    -- 5. Risk Check: SEC Audit
    local required_comp = math.floor((total_aum / (100 * MILLION)) * 1000000)
    if required_comp < 5000000 then required_comp = 5000000 end

    if compliance_spend < required_comp then
        local deficit_ratio = 1.0 - (compliance_spend / required_comp)
        sec_heat = sec_heat + (deficit_ratio * 0.05)
    else
        sec_heat = math.max(0.0, sec_heat - 0.02)
    end
    sec_heat = math.max(0.0, sec_heat - (staff.comp * 0.01))

    if random_float() < sec_heat then
        game_state = "GAMEOVER_SEC"
        sfx(1)
        return
    end

    -- 6. Time Progression & Year-End Accounting
    if month == 12 then
        -- YEAR END! Calculate Fees
        local annual_return_raw = (total_aum - year_start_aum) / year_start_aum

        local perf_fee = 0
        local mgmt_fee = 0

        -- 8% Hurdle Rate
        if annual_return_raw > 0.08 then
            local excess = annual_return_raw - 0.08
            perf_fee = math.floor(year_start_aum * excess * 0.20)
        end

        total_aum = total_aum - perf_fee

        -- 2% Management Fee (applied to final AUM)
        mgmt_fee = math.floor(total_aum * 0.02)
        total_aum = total_aum - mgmt_fee

        gp_cash = gp_cash + perf_fee + mgmt_fee

        -- LP Revolt Check (Excessive Fees > 15% AND AUM < 1M)
        local total_fees = perf_fee + mgmt_fee
        local fee_ratio = 0
        if total_aum > 0 then fee_ratio = total_fees / (total_aum + total_fees) end

        if fee_ratio > 0.15 and total_aum < 1 * MILLION then
            game_state = "GAMEOVER_REVOLT"
            sfx(1)
            return
        end

        show_msg("YEAR END. FEES EARNED: " .. format_money(total_fees), true)

        -- Reset for next year
        year_start_aum = total_aum
        month = 1
        year = year + 1
        roll_regime()
    else
        month = month + 1
        if gross_return > 0 then sfx(2) else sfx(1) end
    end
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
        -- Toggle Views
        if just_pressed(0) then
            view_mode = "DASH"
            sfx(2)
        elseif just_pressed(1) then
            view_mode = "OPS"
            sfx(2)
        end

        if view_mode == "DASH" then
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
                -- Check capacity logic
                local capacity_limit = (500 * MILLION) + (staff.pm * 500 * MILLION)
                if total_aum < capacity_limit * 0.9 then
                    -- Apply Regime fundraising multiplier
                    local raise_base = (total_aum * 0.20) * regimes[current_regime].fund
                    local raise_amt = math.floor(raise_base / MILLION) * MILLION

                    if raise_amt < 10 * MILLION then raise_amt = 10 * MILLION end

                    total_aum = total_aum + raise_amt
                    -- Adjust year_start_aum to prevent performance fee bugs on mid-year raises
                    year_start_aum = year_start_aum + raise_amt

                    show_msg("ORGANIC INFLOW: " .. format_money(raise_amt), true)
                else
                    show_msg("FIRM CAPACITY REACHED. HIRE MORE PMs.", false)
                end
            end
        elseif view_mode == "OPS" then
            -- Scroll Ops
            if just_pressed(2) then
                ops_idx = ops_idx - 1
                if ops_idx < 1 then ops_idx = #roles end
                sfx(2)
            elseif just_pressed(3) then
                ops_idx = ops_idx + 1
                if ops_idx > #roles then ops_idx = 1 end
                sfx(2)
            end

            -- Hire (Z)
            if just_pressed(4) then
                local role_id = roles[ops_idx].id
                staff[role_id] = staff[role_id] + 1
                show_msg("HIRED 1 " .. roles[ops_idx].name, true)
            end

            -- Fire (X)
            if just_pressed(5) then
                local role_id = roles[ops_idx].id
                if staff[role_id] > 0 then
                    -- Prevent firing last PM
                    if role_id == "pm" and staff.pm <= 1 then
                        show_msg("CANNOT FIRE SOLE PORTFOLIO MANAGER", false)
                    else
                        staff[role_id] = staff[role_id] - 1
                        show_msg("FIRED 1 " .. roles[ops_idx].name, true)
                    end
                else
                    show_msg("NO STAFF TO FIRE", false)
                end
            end
        end

        -- Advance Month (X) only in DASH
        if view_mode == "DASH" and just_pressed(5) then
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
    print("YR: " .. tostring(year) .. " | MO: " .. tostring(month), 160, 4, C_TEXT)

    print("AUM:     " .. format_money(total_aum), 4, 16, C_HL)
    print("GP CASH: " .. format_money(gp_cash), 4, 26, C_HL)

    local ytd_return_raw = 0
    if year_start_aum > 0 then
        ytd_return_raw = (total_aum - year_start_aum) / year_start_aum
    end
    local ytd_pct = ytd_return_raw * 100.0

    local ret_col = ytd_pct >= 8.0 and C_HL or C_TEXT
    print("YTD RET: " .. string.format("%.2f%%", ytd_pct), 140, 16, ret_col)
    print("HURDLE:  8.00%", 140, 26, C_TEXT)

    draw_line(0, 47, SCREEN_W, 47, C_TEXT)

    if game_state == "PLAY" then

        -- TAB HEADERS
        local d_col = view_mode == "DASH" and C_HL or C_DIM
        local o_col = view_mode == "OPS" and C_HL or C_DIM
        print("< DASHBOARD >", 20, 52, d_col)
        print("< OPERATIONS >", 130, 52, o_col)
        draw_line(0, 62, SCREEN_W, 62, C_DIM)

        if view_mode == "DASH" then
            -- REGIME & RISK
            print("MARKET REGIME:", 4, 70, C_TEXT)
            local reg_name = regimes[current_regime].name
            print(reg_name, 100, 70, C_HL)

            local heat_col = sec_heat > 0.3 and C_TEXT or C_HL
            if sec_heat > 0.6 then heat_col = C_BG end
            print("SEC HEAT: " .. string.format("%.1f%%", sec_heat * 100), 4, 82, heat_col)

            draw_line(0, 94, SCREEN_W, 94, C_DIM)

            -- COMPLIANCE SLIDER
            print("COMPLIANCE SPEND (UP/DWN):", 4, 102, C_HL)
            print(format_money(compliance_spend) .. "/MO", 20, 114, C_TEXT)

            -- NOTIFICATIONS
            if msg_timer > 0 then
                print(">> " .. msg_text, 4, 140, C_TEXT)
            end

        elseif view_mode == "OPS" then
            print("PERSONNEL ROSTER", 4, 70, C_HL)
            local aum_m = total_aum / MILLION
            if aum_m < 1 then aum_m = 1 end
            local scaling_cost = math.floor(1000000 * math.log(aum_m))
            local staff_cost = (staff.pm * roles[1].cost) + (staff.quant * roles[2].cost) + (staff.risk * roles[3].cost) + (staff.comp * roles[4].cost)
            local total_opex = base_opex + scaling_cost + compliance_spend + staff_cost

            print("MONTHLY BURN: " .. format_money(total_opex), 4, 82, C_TEXT)

            for i=1, #roles do
                local r = roles[i]
                local count = staff[r.id]
                local y = 105 + ((i-1) * 25)

                local col = C_TEXT
                if i == ops_idx then
                    col = C_HL
                    print(">", 4, y, C_HL)
                end

                print(r.name .. " x" .. tostring(count), 14, y, col)
                print(r.desc, 14, y + 10, C_DIM)
                print(format_money(r.cost), 200, y, col)
            end
        end

        -- FOOTER
        draw_line(0, 205, SCREEN_W, 205, C_DIM)
        if view_mode == "DASH" then
            print("Z: RAISE CAPITAL", 10, 212, C_HL)
            print("X: ADVANCE 1 MONTH", 10, 224, C_HL)
        else
            print("Z: HIRE", 10, 212, C_HL)
            print("X: FIRE", 10, 224, C_HL)
        end

    elseif game_state == "GAMEOVER_CASH" then
        fill_rect(30, 90, 196, 50, C_TEXT)
        fill_rect(32, 92, 192, 46, C_BG)
        print("FUND INSOLVENT", 75, 100, C_TEXT)
        print("RAN OUT OF GP CASH MID-YEAR", 40, 110, C_DIM)
        print("PRESS Z TO RESTART", 60, 124, C_HL)
    elseif game_state == "GAMEOVER_SEC" then
        fill_rect(30, 90, 196, 50, C_HL)
        fill_rect(32, 92, 192, 46, C_BG)
        print("SEC RAID & ASSET FREEZE", 50, 100, C_HL)
        print("COMPLIANCE FAILURES DETECTED", 45, 110, C_TEXT)
        print("PRESS Z TO RESTART", 60, 124, C_DIM)
    elseif game_state == "GAMEOVER_REVOLT" then
        fill_rect(20, 90, 216, 50, C_HL)
        fill_rect(22, 92, 212, 46, C_BG)
        print("LIMITED PARTNER REVOLT", 50, 100, C_HL)
        print("EXCESSIVE FEES DESTROYED ALL VALUE", 25, 110, C_TEXT)
        print("PRESS Z TO RESTART", 60, 124, C_DIM)
    end
end
