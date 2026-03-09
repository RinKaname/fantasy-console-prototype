-- Amadeus Cartridge: Trader (IBN-5100 Theme)

SCREEN_W = 256
SCREEN_H = 240

-- Colors (IBN-5100 palette)
C_BG = 0
C_GRID = 1
C_TEXT = 2
C_HL = 3

-- Game State
ticks = 0
days = 1
cash = 1000.00
net_worth = 1000.00

-- Stocks
stocks = {
    { name = "AMDS", price = 45.50, hist = {}, owned = 0, vol = 1.2 },
    { name = "SERN", price = 120.00, hist = {}, owned = 0, vol = 2.5 },
    { name = "D-ML", price = 15.20, hist = {}, owned = 0, vol = 0.8 }
}

for i=1, 3 do
    -- Initialize history with 100 points
    for j=1, 120 do
        table.insert(stocks[i].hist, stocks[i].price)
    end
end

selected_stock = 1
multiplier = 1 -- Can be 1, 10, or 100

-- Economy States: STABLE, BOOM, BUST
economy = "STABLE"
news_ticker = "WELCOME TO THE AMADEUS TRADING TERMINAL..."
news_x = SCREEN_W

-- Pseudo-Random (since we don't have math.random imported yet)
function random_float()
    local a = (ticks * 1103515245 + 12345) % 2147483648
    return (a / 2147483648)
end

function get_price_change(volatility)
    local r1 = random_float()
    local r2 = random_float()
    -- Normal distribution approximation
    local normal = (r1 + r2 - 1) * 2.0

    local trend = 0.0
    if economy == "BOOM" then
        trend = 0.5 -- Upward bias
    elseif economy == "BUST" then
        trend = -0.5 -- Downward bias
    else
        -- Stable: Slight mean reversion if price gets too high/low
        trend = (r1 - 0.5) * 0.2
    end

    return (normal + trend) * volatility
end

function change_economy()
    local r = random_float()
    if r < 0.33 then
        economy = "BOOM"
        news_ticker = "NEWS: TECH SECTOR INNOVATION DRIVES MASSIVE MARKET BOOM!"
        sfx(3) -- Startup sound
    elseif r < 0.66 then
        economy = "BUST"
        news_ticker = "NEWS: MAJOR DATA BREACH AT SERN. MARKET CRASH IMMINENT!"
        sfx(1) -- Error buzz
    else
        economy = "STABLE"
        news_ticker = "NEWS: MARKET RETURNS TO NORMAL FOLLOWING RECENT VOLATILITY."
        sfx(2) -- Click
    end
    news_x = SCREEN_W
end

function _init()
    ticks = 0
    days = 1
    cash = 1000.00
    economy = "STABLE"
    news_ticker = "INITIALIZING TRADING TERMINAL..."
    sfx(3)
end

-- Input debouncing
btn_state = {false, false, false, false, false, false, false, false}

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

function _update()
    ticks = ticks + 1

    -- Input Handling
    -- Switch Stocks (Left/Right)
    if just_pressed(0) then
        selected_stock = selected_stock - 1
        if selected_stock < 1 then selected_stock = 3 end
        sfx(2)
    elseif just_pressed(1) then
        selected_stock = selected_stock + 1
        if selected_stock > 3 then selected_stock = 1 end
        sfx(2)
    end

    -- Multiplier (Up/Down)
    if just_pressed(2) then
        if multiplier == 1 then multiplier = 10
        elseif multiplier == 10 then multiplier = 100 end
        sfx(2)
    elseif just_pressed(3) then
        if multiplier == 100 then multiplier = 10
        elseif multiplier == 10 then multiplier = 1 end
        sfx(2)
    end

    local s = stocks[selected_stock]

    -- Buy (Z = 4)
    if just_pressed(4) then
        local cost = s.price * multiplier
        if cash >= cost then
            cash = cash - cost
            s.owned = s.owned + multiplier
            sfx(0) -- UI Blip
        else
            sfx(1) -- Error Buzz (insufficient funds)
        end
    end

    -- Sell (X = 5)
    if just_pressed(5) then
        if s.owned >= multiplier then
            local revenue = s.price * multiplier
            cash = cash + revenue
            s.owned = s.owned - multiplier
            sfx(0) -- UI Blip
        else
            sfx(1) -- Error Buzz (insufficient shares)
        end
    end

    -- Update Market every 15 frames (4 ticks a second)
    if ticks % 15 == 0 then
        -- Random chance to change economy state (roughly every 30 seconds)
        if random_float() < 0.015 then
            change_economy()
        end

        net_worth = cash
        for i=1, 3 do
            local st = stocks[i]
            local change = get_price_change(st.vol)
            st.price = st.price + change

            -- Floor price at $1.00
            if st.price < 1.0 then st.price = 1.0 end

            -- Update history
            table.remove(st.hist, 1)
            table.insert(st.hist, st.price)

            -- Update net worth
            net_worth = net_worth + (st.price * st.owned)
        end
    end

    -- Update News Ticker
    news_x = news_x - 1
    if news_x < -300 then -- approximate width
        news_x = SCREEN_W
    end
end

function fill_rect(x, y, w, h, col)
    for ry = 0, h - 1 do
        for rx = 0, w - 1 do
            pset(x + rx, y + ry, col)
        end
    end
end

-- Draw a line (Bresenham)
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
        if e2 >= dy then
            err = err + dy
            x0 = x0 + sx
        end
        if e2 <= dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
end

function to_fixed2(num)
    local int = math.floor(num)
    local dec = math.floor((num - int) * 100)
    if dec < 10 then dec = "0" .. tostring(dec) end
    return tostring(int) .. "." .. tostring(dec)
end

function _draw()
    cls(C_BG)

    -- 1. Draw Graph Area (Top Half)
    fill_rect(4, 4, 248, 120, C_BG)
    -- Draw grid
    for y=4, 124, 20 do
        draw_line(4, y, 252, y, C_GRID)
    end
    for x=4, 252, 40 do
        draw_line(x, 4, x, 124, C_GRID)
    end
    -- Draw border
    draw_line(4, 4, 252, 4, C_TEXT)
    draw_line(4, 124, 252, 124, C_TEXT)
    draw_line(4, 4, 4, 124, C_TEXT)
    draw_line(252, 4, 252, 124, C_TEXT)

    -- Draw actual graph for selected stock
    local s = stocks[selected_stock]

    -- Find min/max for scaling
    local min_p = s.hist[1]
    local max_p = s.hist[1]
    for i=1, #s.hist do
        if s.hist[i] < min_p then min_p = s.hist[i] end
        if s.hist[i] > max_p then max_p = s.hist[i] end
    end
    -- Add some padding to scale
    min_p = min_p * 0.9
    max_p = max_p * 1.1
    if max_p == min_p then max_p = min_p + 1 end
    local range = max_p - min_p

    local graph_x = 8
    local step_x = 2
    for i=2, #s.hist do
        local x1 = graph_x + ((i-2) * step_x)
        local y1 = 120 - (((s.hist[i-1] - min_p) / range) * 112)
        local x2 = graph_x + ((i-1) * step_x)
        local y2 = 120 - (((s.hist[i] - min_p) / range) * 112)

        draw_line(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2), C_HL)
    end

    -- Draw Min/Max labels
    print("$"..to_fixed2(max_p), 6, 6, C_HL)
    print("$"..to_fixed2(min_p), 6, 115, C_HL)

    -- 2. Draw Terminal Interface (Bottom Half)
    print("PORTFOLIO", 10, 134, C_TEXT)
    print("NET WORTH: $" .. to_fixed2(net_worth), 10, 144, C_HL)
    print("CASH:      $" .. to_fixed2(cash), 10, 154, C_HL)
    print("ECONOMY:   " .. economy, 10, 164, C_HL)

    -- Draw Stock List
    local list_x = 130
    local list_y = 134
    print("STOCKS", list_x, list_y, C_TEXT)

    for i=1, 3 do
        local st = stocks[i]
        local cy = list_y + 10 + ((i-1)*10)

        local color = C_TEXT
        if i == selected_stock then
            color = C_HL
            print(">", list_x - 6, cy, C_HL)
        end

        print(st.name, list_x, cy, color)
        print("$"..to_fixed2(st.price), list_x + 30, cy, color)
        print("OWN:"..tostring(st.owned), list_x + 80, cy, color)
    end

    -- Draw Controls
    print("QTY: x" .. tostring(multiplier), 10, 184, C_HL)
    print("Z: BUY", 10, 194, C_TEXT)
    print("X: SELL", 10, 204, C_TEXT)

    -- Draw Ticker Border
    draw_line(0, 220, SCREEN_W, 220, C_GRID)
    draw_line(0, 235, SCREEN_W, 235, C_GRID)
    print(news_ticker, news_x, 225, C_HL)
end
