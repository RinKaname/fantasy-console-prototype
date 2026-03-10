-- ==============================================================================
-- AMADEUS - INVESTMENT BANKING SIMULATOR
-- Emulates Sell-Side Advisory, M&A, IPOs, and Market Making over a 15-year span.
-- ==============================================================================

-- GLOBALS
local t = 0
local frame = 0
local game_over = false
local win_screen = false

-- TIME (15 Years = 180 Months)
local month = 1
local max_months = 180

-- FIRM STATE
local firm = {
    name = "AMADEUS CAPITAL",
    cash = 10000000, -- $10M starting capital
    brand = 10,      -- Reputation score (affects deal size)
    -- Staff
    mds = 1,         -- Managing Directors (brings in deals)
    vps = 2,         -- Vice Presidents (manages execution)
    associates = 3,  -- Executes deals
    analysts = 5,    -- Grunt work, reduces duration
    traders = 2,     -- For market making
    -- Expenses (Monthly)
    base_cost = 500000,
    -- Stats
    total_revenue = 0,
    deals_completed = 0
}

-- MARKET REGIME
-- 0: Bull Market (High M&A, High IPO, Low Volatility)
-- 1: Bear Market (Low M&A, Low IPO, High Restructuring, Med Volatility)
-- 2: Stagnant   (Med M&A, Low IPO, Low Restructuring, Low Volatility)
-- 3: Volatile   (Med M&A, Low IPO, Med Restructuring, Extreme Volatility)
local market_regime = 0
local regime_names = {"BULL", "BEAR", "STAGNANT", "VOLATILE"}
local regime_timer = 0
local next_regime_shift = 12 -- Shifts every 6-24 months

-- PRNG (Linear Congruential Generator)
-- Amadeus doesn't expose math.random by default
local rng_state = 123456789
local function random_float()
    rng_state = (1103515245 * rng_state + 12345) % 2147483648
    return rng_state / 2147483648
end

-- UI STATE
local TABS = { "DEAL DESK", "MARKET MAKING", "STAFF", "LEADERBOARD" }
local active_tab = 1
local selected_item = 1

-- DEAL DESK STATE
local deals = {}
local active_deals = {}
local max_deals = 4
local deal_types = {
    { name = "M&A ADVISORY", base_dur = 6, base_cost = 200000, base_fee = 2000000, req_staff = 2, bull_mod = 1.2, bear_mod = 0.5 },
    { name = "TECH IPO", base_dur = 4, base_cost = 500000, base_fee = 5000000, req_staff = 3, bull_mod = 1.5, bear_mod = 0.2 },
    { name = "DEBT ISSUANCE", base_dur = 2, base_cost = 50000, base_fee = 500000, req_staff = 1, bull_mod = 1.0, bear_mod = 1.2 },
    { name = "RESTRUCTURING", base_dur = 8, base_cost = 100000, base_fee = 1500000, req_staff = 2, bull_mod = 0.5, bear_mod = 2.0 }
}

-- MARKET MAKING STATE
local orders = {}
local active_orders = {}
local max_orders = 5
local order_types = {
    { name = "EQT BLOCK", base_cap = 5000000, base_comm = 50000, volatility = 0.1, duration = 1 },
    { name = "FX SWAP", base_cap = 1000000, base_comm = 10000, volatility = 0.05, duration = 3 },
    { name = "CORP BOND", base_cap = 2000000, base_comm = 20000, volatility = 0.02, duration = 2 },
    { name = "DERIVATIVES", base_cap = 10000000, base_comm = 200000, volatility = 0.3, duration = 1 }
}

-- STAFF MANAGEMENT
local staff_types = {
    { id = "mds", name = "M. DIRECTOR", cost = 100000, desc = "INCREASES DEAL SIZES" },
    { id = "vps", name = "VICE PRES.", cost = 50000, desc = "IMPROVES BRAND/SUCCESS" },
    { id = "associates", name = "ASSOCIATE", cost = 25000, desc = "EXECUTES DEALS (REQ)" },
    { id = "analysts", name = "ANALYST", cost = 10000, desc = "SPEEDS UP DEALS" },
    { id = "traders", name = "TRADER", cost = 30000, desc = "EXECUTES MARKET ORDERS" }
}

-- COMPETITORS
local competitors = {
    { name = "GOLDMAN S.", rev = 1000000000, growth = 1.05, style = "BULL" },
    { name = "MORGAN S.", rev = 800000000, growth = 1.04, style = "BULL" },
    { name = "JPMORGAN", rev = 1200000000, growth = 1.02, style = "DEFENSIVE" },
    { name = "LAZARD", rev = 200000000, growth = 1.08, style = "RESTRUCTURING" },
    { name = "EVERCORE", rev = 150000000, growth = 1.10, style = "BOUTIQUE" }
}

-- INPUT STATE (Debounce)
local btn_prev = {false, false, false, false, false, false, false, false}

-- ==============================================================================
-- HELPER FUNCTIONS
-- ==============================================================================

local function format_money(amount)
    if amount >= 1000000000 then
        return string.format("$%.2fB", amount / 1000000000)
    elseif amount >= 1000000 then
        return string.format("$%.2fM", amount / 1000000)
    elseif amount >= 1000 then
        return string.format("$%.0fK", amount / 1000)
    else
        return string.format("$%.0f", amount)
    end
end

local function just_pressed(b)
    local current = btn(b)
    local pressed = current and not btn_prev[b]
    return pressed
end

-- ==============================================================================
-- LOGIC
-- ==============================================================================

local function generate_deal()
    local t_idx = math.floor(random_float() * #deal_types) + 1
    local t = deal_types[t_idx]

    -- Modify chances based on market regime
    local mod = 1.0
    if market_regime == 0 then mod = t.bull_mod
    elseif market_regime == 1 then mod = t.bear_mod
    end

    -- Brand and MDs affect the scale of the deal
    local scale = 1.0 + (firm.brand / 20.0) + (firm.mds * 0.2) + (random_float() * 0.5)

    -- VPs improve success chance
    local base_chance = 70 * mod
    local vp_bonus = firm.vps * 2.5

    return {
        name = t.name,
        type = t_idx,
        dur = math.max(1, math.floor(t.base_dur / mod)),
        cost = math.floor(t.base_cost * scale),
        fee = math.floor(t.base_fee * scale),
        req = t.req_staff,
        chance = math.min(95, math.floor(base_chance + (firm.brand * 0.5) + vp_bonus))
    }
end

local function refresh_deal_board()
    deals = {}
    for i=1, max_deals do
        table.insert(deals, generate_deal())
    end
end

local function generate_order()
    local t_idx = math.floor(random_float() * #order_types) + 1
    local t = order_types[t_idx]

    local scale = 1.0 + (random_float() * 2.0)

    return {
        name = t.name,
        cap = math.floor(t.base_cap * scale),
        comm = math.floor(t.base_comm * scale),
        vol = t.volatility,
        dur = t.duration,
        progress = 0
    }
end

local function refresh_order_board()
    orders = {}
    for i=1, max_orders do
        table.insert(orders, generate_order())
    end
end

local function update_market_regime()
    regime_timer = regime_timer + 1
    if regime_timer >= next_regime_shift then
        regime_timer = 0
        -- Randomize next shift duration (6 to 24 months)
        next_regime_shift = math.floor(random_float() * 18) + 6

        -- Transition logic (markov chain-ish)
        local r = random_float()
        if market_regime == 0 then -- Bull
            if r < 0.6 then market_regime = 2 -- Stagnant
            elseif r < 0.8 then market_regime = 3 -- Volatile
            else market_regime = 1 end -- Bear
        elseif market_regime == 1 then -- Bear
            if r < 0.5 then market_regime = 2 -- Stagnant
            else market_regime = 0 end -- Bull (V-shape recovery)
        elseif market_regime == 2 then -- Stagnant
            if r < 0.6 then market_regime = 0 -- Bull
            else market_regime = 1 end -- Bear
        elseif market_regime == 3 then -- Volatile
            if r < 0.5 then market_regime = 1 -- Bear
            else market_regime = 0 end -- Bull
        end
        sfx(2) -- Nixie click on regime change
    end
end

local function end_month()
    month = month + 1

    -- Pay expenses
    local staff_cost = (firm.mds * 100000) + (firm.vps * 50000) + (firm.associates * 25000) + (firm.analysts * 10000) + (firm.traders * 30000)
    firm.cash = firm.cash - firm.base_cost - staff_cost

    -- Process Active Deals
    for i=#active_deals, 1, -1 do
        local d = active_deals[i]
        d.progress = d.progress + 1

        -- Analysts reduce duration slightly (pseudo-speedup)
        if random_float() < (firm.analysts * 0.05) then
            d.progress = d.progress + 1
        end

        if d.progress >= d.dur then
            -- Deal completes, roll for success
            if random_float() * 100 <= d.chance then
                -- Success
                firm.cash = firm.cash + d.fee
                firm.total_revenue = firm.total_revenue + d.fee
                firm.deals_completed = firm.deals_completed + 1
                firm.brand = firm.brand + 1
                sfx(10) -- "Okarin" Beep for big success
            else
                -- Failure
                firm.brand = math.max(0, firm.brand - 1)
                sfx(1) -- Error buzz
            end
            table.remove(active_deals, i)
        end
    end

    -- Process Active Market Making Orders
    for i=#active_orders, 1, -1 do
        local o = active_orders[i]
        o.progress = o.progress + 1

        if o.progress >= o.dur then
            -- Unwind position
            -- Volatility multiplier based on market regime
            local regime_vol_mult = 1.0
            if market_regime == 3 then regime_vol_mult = 2.5 -- Volatile
            elseif market_regime == 2 then regime_vol_mult = 0.5 -- Stagnant
            end

            -- Traders reduce negative risk
            local trader_skill = math.min(0.5, firm.traders * 0.05)

            -- Calculate PnL from position
            local pnl_pct = (random_float() * (o.vol * 2) - o.vol) * regime_vol_mult

            -- Apply trader skill buffer if loss
            if pnl_pct < 0 then pnl_pct = pnl_pct * (1.0 - trader_skill) end

            local trading_pnl = math.floor(o.cap * pnl_pct)
            local total_return = o.comm + trading_pnl

            -- Return capital + comm + pnl
            firm.cash = firm.cash + o.cap + total_return
            firm.total_revenue = firm.total_revenue + total_return

            if total_return > 0 then
                sfx(0) -- Blip for good trade
            else
                sfx(1) -- Buzz for bad trade
            end

            table.remove(active_orders, i)
        end
    end

    -- Update Competitors
    for _, c in ipairs(competitors) do
        local mult = 1.0

        -- Style interactions with market regime
        if c.style == "BULL" then
            if market_regime == 0 then mult = 1.1 -- Bull
            elseif market_regime == 1 then mult = 0.9 end -- Bear
        elseif c.style == "DEFENSIVE" then
            if market_regime == 1 then mult = 1.05 -- Bear
            elseif market_regime == 3 then mult = 1.05 end -- Volatile
        elseif c.style == "RESTRUCTURING" then
            if market_regime == 1 then mult = 1.15 end -- Bear
        elseif c.style == "BOUTIQUE" then
            if market_regime == 0 then mult = 1.2 -- Bull
            elseif market_regime == 1 then mult = 0.8 end -- Bear
        end

        -- Apply baseline growth + monthly variance
        c.rev = c.rev * (1.0 + ((c.growth - 1.0) / 12) * mult + ((random_float() * 0.04) - 0.02))
    end

    update_market_regime()
    refresh_deal_board() -- Periodically refresh available deals
    refresh_order_board()

    if firm.cash < 0 then
        game_over = true
        sfx(1) -- Error buzz
    end

    if month > max_months then
        win_screen = true
        sfx(3) -- Startup sound for win
    end

    sfx(0) -- UI Blip
end

-- ==============================================================================
-- LIFECYCLE
-- ==============================================================================

function _init()
    refresh_deal_board()
    refresh_order_board()
end

function _update()
    frame = frame + 1

    -- Mix in user input for randomness
    for i=0, 7 do
        if btn(i) then rng_state = (rng_state + i * 17) % 2147483648 end
    end

    if game_over or win_screen then
        if just_pressed(6) then -- Enter/Start to restart
            game_over = false
            win_screen = false
            month = 1
            firm.cash = 10000000
            firm.brand = 10
            firm.mds = 1
            firm.vps = 2
            firm.associates = 3
            firm.analysts = 5
            firm.traders = 2
            firm.total_revenue = 0
            firm.deals_completed = 0
            market_regime = 0
            regime_timer = 0

            -- Reset competitors
            competitors = {
                { name = "GOLDMAN S.", rev = 1000000000, growth = 1.05, style = "BULL" },
                { name = "MORGAN S.", rev = 800000000, growth = 1.04, style = "BULL" },
                { name = "JPMORGAN", rev = 1200000000, growth = 1.02, style = "DEFENSIVE" },
                { name = "LAZARD", rev = 200000000, growth = 1.08, style = "RESTRUCTURING" },
                { name = "EVERCORE", rev = 150000000, growth = 1.10, style = "BOUTIQUE" }
            }
        end
        -- Update input state even when dead
        for i=0, 7 do btn_prev[i] = btn(i) end
        return
    end

    -- Navigation
    if just_pressed(0) then -- Left
        active_tab = active_tab - 1
        if active_tab < 1 then active_tab = #TABS end
        selected_item = 1
        sfx(0)
    elseif just_pressed(1) then -- Right
        active_tab = active_tab + 1
        if active_tab > #TABS then active_tab = 1 end
        selected_item = 1
        sfx(0)
    end

    if just_pressed(2) then -- Up
        selected_item = selected_item - 1
        sfx(0)
    elseif just_pressed(3) then -- Down
        selected_item = selected_item + 1
        sfx(0)
    end

    if active_tab == 1 then
        if selected_item < 1 then selected_item = #deals end
        if selected_item > #deals then selected_item = 1 end

        -- Accept Deal
        if just_pressed(4) then -- Z button
            local d = deals[selected_item]
            if d then
                -- Check if we have enough staff (Associates) and cash
                local busy_staff = 0
                for _, ad in ipairs(active_deals) do busy_staff = busy_staff + ad.req end

                if (busy_staff + d.req) <= firm.associates then
                    if firm.cash >= d.cost then
                        firm.cash = firm.cash - d.cost
                        d.progress = 0
                        table.insert(active_deals, d)
                        table.remove(deals, selected_item)
                        sfx(2) -- Click
                        if selected_item > #deals then selected_item = math.max(1, #deals) end
                    else
                        sfx(1) -- Buzz (No Cash)
                    end
                else
                    sfx(1) -- Buzz (No Staff)
                end
            end
        end
    elseif active_tab == 2 then
        if selected_item < 1 then selected_item = #orders end
        if selected_item > #orders then selected_item = 1 end

        -- Take Order
        if just_pressed(4) then -- Z button
            local o = orders[selected_item]
            if o then
                -- Check trader capacity (1 trader = 1 order)
                if #active_orders < firm.traders then
                    -- Check capital requirement
                    if firm.cash >= o.cap then
                        firm.cash = firm.cash - o.cap
                        table.insert(active_orders, o)
                        table.remove(orders, selected_item)
                        sfx(2) -- Click
                        if selected_item > #orders then selected_item = math.max(1, #orders) end
                    else
                        sfx(1) -- Buzz (No Cash)
                    end
                else
                    sfx(1) -- Buzz (No Traders)
                end
            end
        end
    elseif active_tab == 3 then
        if selected_item < 1 then selected_item = #staff_types end
        if selected_item > #staff_types then selected_item = 1 end

        local s = staff_types[selected_item]

        if just_pressed(4) then -- Z (Hire)
            firm.cash = firm.cash - s.cost -- Upfront hiring bonus/cost
            firm[s.id] = firm[s.id] + 1
            sfx(2)
        elseif just_pressed(5) then -- X (Fire)
            if firm[s.id] > 0 then
                firm[s.id] = firm[s.id] - 1
                sfx(1)
            end
        end
    end

    if just_pressed(6) then -- Enter (End Month)
        end_month()
    end

    -- Record button states for next frame
    for i=0, 7 do
        btn_prev[i] = btn(i)
    end
end

function _draw()
    cls(0) -- Clear to black/dark blue

    -- Draw Header
    print(firm.name, 4, 4, 4)
    print("M: " .. month .. "/" .. max_months, 190, 4, 4)

    -- Draw Firm Stats
    print("CASH: " .. format_money(firm.cash), 4, 16, 2)
    print("BRAND: " .. firm.brand, 100, 16, 2)

    -- Draw Market Regime
    local regime_color = 2 -- Green for Bull
    if market_regime == 1 then regime_color = 3 -- Red for Bear
    elseif market_regime == 2 then regime_color = 6 -- Gray for Stagnant
    elseif market_regime == 3 then regime_color = 5 -- Gold for Volatile
    end
    print("MARKET: " .. regime_names[market_regime + 1], 160, 16, regime_color)

    -- Draw Divider
    for x=0, 255 do pset(x, 26, 1) end

    -- Draw Tabs
    local tab_x = 4
    for i, tab_name in ipairs(TABS) do
        local color = 6 -- Gray
        if i == active_tab then
            color = 4 -- Cyan for active
            print("[" .. tab_name .. "]", tab_x, 30, color)
            tab_x = tab_x + (string.len(tab_name) * 6) + 16
        else
            print(tab_name, tab_x, 30, color)
            tab_x = tab_x + (string.len(tab_name) * 6) + 8
        end
    end
    for x=0, 255 do pset(x, 40, 1) end

    -- Draw Content based on active tab
    if game_over then
        print("BANKRUPTCY. FIRM LIQUIDATED.", 30, 100, 3)
        print("PRESS ENTER TO RESTART.", 40, 110, 6)
    elseif win_screen then
        print("15 YEARS COMPLETED.", 50, 80, 2)

        -- Sort leaderboard (including player) to find final rank
        local sorted = {}
        for _, c in ipairs(competitors) do table.insert(sorted, {name = c.name, rev = c.rev, is_player = false}) end
        table.insert(sorted, {name = firm.name, rev = firm.total_revenue, is_player = true})
        table.sort(sorted, function(a, b) return a.rev > b.rev end)

        local final_rank = 1
        for i, c in ipairs(sorted) do
            if c.is_player then final_rank = i end
        end

        print("FINAL RANKING: #" .. final_rank, 40, 100, 4)
        print("TOTAL REVENUE: " .. format_money(firm.total_revenue), 40, 110, 5)
        print("DEALS CLOSED: " .. firm.deals_completed, 40, 120, 6)

        if final_rank == 1 then
            print("YOU ARE THE #1 INVESTMENT BANK!", 30, 140, 2)
        else
            print("KEEP CLIMBING THE LEAGUE TABLES.", 30, 140, 6)
        end

        print("PRESS ENTER TO RESTART.", 40, 160, 6)
    else
        if active_tab == 1 then
            -- DEAL DESK
            print("AVAILABLE MANDATES:", 4, 46, 4)

            local y = 56
            for i, d in ipairs(deals) do
                local color = 6
                if i == selected_item then
                    color = 2
                    print(">", 4, y, 2)
                end

                print(d.name, 12, y, color)
                print("FEE: " .. format_money(d.fee), 12, y + 8, color)
                print("CST: " .. format_money(d.cost) .. " | DUR: " .. d.dur .. "M | REQ: " .. d.req .. " ASSOC", 120, y + 8, color)

                local chance_color = 2
                if d.chance < 50 then chance_color = 3 end
                print("CHANCE: " .. d.chance .. "%", 12, y + 16, chance_color)

                y = y + 26
            end

            -- Draw Active Deals Tracker
            for x=0, 255 do pset(x, 156, 1) end
            print("ACTIVE DEALS PIPELINE:", 4, 160, 4)

            local busy_staff = 0
            for _, ad in ipairs(active_deals) do busy_staff = busy_staff + ad.req end
            print("STAFF UTILIZATION: " .. busy_staff .. " / " .. firm.associates, 110, 160, 6)

            y = 170
            for i, ad in ipairs(active_deals) do
                if i <= 3 then -- Only show top 3 to fit screen
                    print(ad.name .. " [" .. ad.progress .. "/" .. ad.dur .. "M]", 12, y, 5)
                    -- Progress bar
                    local pct = ad.progress / ad.dur
                    local bar_w = math.floor(100 * pct)
                    for px=0, 100 do pset(140 + px, y + 3, 1) end
                    for px=0, bar_w do pset(140 + px, y + 3, 2) end
                    y = y + 10
                end
            end
            if #active_deals > 3 then print("...AND " .. (#active_deals - 3) .. " MORE", 12, y, 6) end

        elseif active_tab == 2 then
            -- MARKET MAKING
            print("CLIENT ORDER FLOW:", 4, 46, 4)

            local y = 56
            for i, o in ipairs(orders) do
                local color = 6
                if i == selected_item then
                    color = 2
                    print(">", 4, y, 2)
                end

                print(o.name, 12, y, color)
                print("COMM: " .. format_money(o.comm) .. " | DUR: " .. o.dur .. "M", 120, y, color)
                print("CAPITAL: " .. format_money(o.cap) .. " | RISK: " .. (o.vol * 100) .. "%", 12, y + 8, color)

                y = y + 18
            end

            -- Draw Active Orders Tracker
            for x=0, 255 do pset(x, 156, 1) end
            print("TRADING BOOK:", 4, 160, 4)
            print("TRADER UTILIZATION: " .. #active_orders .. " / " .. firm.traders, 110, 160, 6)

            y = 170
            for i, o in ipairs(active_orders) do
                if i <= 4 then
                    print(o.name .. " [" .. format_money(o.cap) .. "]", 12, y, 5)
                    local pct = o.progress / o.dur
                    local bar_w = math.floor(100 * pct)
                    for px=0, 100 do pset(140 + px, y + 3, 1) end
                    for px=0, bar_w do pset(140 + px, y + 3, 2) end
                    y = y + 10
                end
            end
            if #active_orders > 4 then print("...AND " .. (#active_orders - 4) .. " MORE", 12, y, 6) end

        elseif active_tab == 3 then
            -- STAFF MANAGEMENT
            print("PERSONNEL & OPERATIONS:", 4, 46, 4)

            local staff_cost = (firm.mds * 100000) + (firm.vps * 50000) + (firm.associates * 25000) + (firm.analysts * 10000) + (firm.traders * 30000)
            print("MONTHLY PAYROLL: " .. format_money(staff_cost), 4, 56, 3)
            print("BASE EXPENSES: " .. format_money(firm.base_cost), 130, 56, 3)

            local y = 76
            for i, s in ipairs(staff_types) do
                local color = 6
                if i == selected_item then
                    color = 2
                    print(">", 4, y, 2)
                end

                print(s.name, 12, y, color)
                print(firm[s.id], 100, y, 4) -- Count
                print(format_money(s.cost) .. "/MO", 130, y, color)

                if i == selected_item then
                    print(s.desc, 12, y + 10, 5)
                    y = y + 10
                end

                y = y + 18
            end

            print("Z: HIRE (COSTS 1 MONTH SALARY)   X: FIRE", 4, 210, 6)

        elseif active_tab == 4 then
            -- LEADERBOARD
            print("GLOBAL IB LEAGUE TABLES:", 4, 46, 4)

            -- Sort leaderboard (including player)
            local sorted = {}
            for _, c in ipairs(competitors) do table.insert(sorted, {name = c.name, rev = c.rev, is_player = false}) end
            table.insert(sorted, {name = firm.name, rev = firm.total_revenue, is_player = true})

            table.sort(sorted, function(a, b) return a.rev > b.rev end)

            local y = 60
            for i, c in ipairs(sorted) do
                local color = 6
                if c.is_player then color = 2 end

                print(i .. ". " .. c.name, 12, y, color)
                print(format_money(c.rev), 160, y, color)

                y = y + 14
            end

        end

        -- Draw Footer Controls
        for x=0, 255 do pset(x, 226, 1) end
        print("ARROWS: NAVIGATE   Z: SELECT   ENTER: END MONTH", 4, 230, 2)
    end
end
