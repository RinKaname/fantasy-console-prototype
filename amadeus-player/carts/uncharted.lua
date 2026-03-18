-- ==============================================================================
-- AMADEUS AGE OF DISCOVERY
-- A deep economic sailing/trading simulator with dual-inventory vehicles.
-- ==============================================================================

-- COLORS (Custom Palette mapping for Amadeus 256 colors)
local C_BLACK = 0
local C_SEA = 1       -- Dark Blue
local C_LAND = 10     -- Green/Brown
local C_COAST = 14    -- Sand
local C_CITY = 4      -- White/Cyan
local C_PLAYER = 12   -- Bright Green
local C_SHIP = 15     -- Yellow
local C_TEXT = 3      -- Light Gray
local C_WARN = 8      -- Red

-- SYSTEM
local frame = 0
local ticks = 0
local game_state = "WORLD" -- TITLE, WORLD, CITY, MENU
local msg_text = ""
local msg_timer = 0

-- PRNG (Linear Congruential Generator)
local rng_state = 987654321
local function random_float()
    rng_state = (1103515245 * rng_state + 12345) % 2147483648
    return rng_state / 2147483648
end

-- ==============================================================================
-- PLAYER STATE
-- ==============================================================================
local p = {
    name = "PEDDLER",
    gold = 500,
    bank = 0,
    debt = 0,
    credit_score = 50, -- 0 to 100
    rank = 1,          -- 1: Citizen ... 5: Archduke
    nation = 1,        -- ID of current nation
    x = 10,
    y = 10,
    mode = "LAND",     -- "LAND" or "SEA"
    ship_x = -1,       -- Where the ship is anchored
    ship_y = -1,

    -- Vehicles (0 = None, 1+ = Upgrades)
    cart_level = 1,
    ship_level = 0,

    -- Inventory
    cargo = {},        -- { [good_id] = qty }
    max_cargo = 10     -- Depends on current active vehicle
}

local ranks = { "CITIZEN", "KNIGHT", "BARON", "EARL", "DUKE", "ARCHDUKE" }

-- ==============================================================================
-- WORLD MAP (32x32 Grid)
-- 0: Sea, 1: Land, 2: Coast
-- ==============================================================================
local MAP_W = 32
local MAP_H = 32
local map = {}

-- Nations
local nations = {
    { id = 1, name = "VALERIA", rep = 50, hostile = false },
    { id = 2, name = "OAKHAVEN", rep = 50, hostile = false },
    { id = 3, name = "IRON ASCD.", rep = 50, hostile = false }
}

-- Goods Dictionary
local goods = {
    { id = 1, name = "GRAIN", base = 10, vol = 3, ind = false },
    { id = 2, name = "WOOD", base = 20, vol = 5, ind = false },
    { id = 3, name = "IRON", base = 50, vol = 10, ind = false },
    { id = 4, name = "SILK", base = 150, vol = 30, ind = false },
    { id = 5, name = "SPICES", base = 200, vol = 50, ind = false },
    { id = 6, name = "RIFLES", base = 500, vol = 80, ind = true },     -- Needs R&D
    { id = 7, name = "STEAM ENG", base = 1000, vol = 150, ind = true } -- Needs High R&D
}

-- Cities
local cities = {
    { name = "VALERIS", x = 10, y = 10, nation = 1, is_coastal = true,
      rd_sci = 0, rd_mil = 0,
      prod = {1, 4}, dem = {2, 3, 5}, prices = {} },

    { name = "LUMINA", x = 18, y = 8, nation = 1, is_coastal = false,
      rd_sci = 0, rd_mil = 0,
      prod = {2}, dem = {1, 4}, prices = {} },

    { name = "PORT OAK", x = 5, y = 20, nation = 2, is_coastal = true,
      rd_sci = 0, rd_mil = 0,
      prod = {2, 5}, dem = {3, 4}, prices = {} },

    { name = "DEEPWOOD", x = 8, y = 25, nation = 2, is_coastal = false,
      rd_sci = 0, rd_mil = 0,
      prod = {1, 2}, dem = {3, 5}, prices = {} },

    { name = "IRONCLAD", x = 25, y = 20, nation = 3, is_coastal = true,
      rd_sci = 0, rd_mil = 0,
      prod = {3}, dem = {1, 5}, prices = {} },

    { name = "FORGE", x = 28, y = 26, nation = 3, is_coastal = false,
      rd_sci = 0, rd_mil = 0,
      prod = {3, 4}, dem = {1, 2}, prices = {} }
}

local current_menu = 0 -- 0: Main, 1: Market, 2: Guild, 3: Palace, 4: Bank
local menu_idx = 1

local function get_tile(x, y)
    if x < 0 or x >= MAP_W or y < 0 or y >= MAP_H then return 0 end
    return map[y * MAP_W + x]
end

local function set_tile(x, y, v)
    if x >= 0 and x < MAP_W and y >= 0 and y < MAP_H then
        map[y * MAP_W + x] = v
    end
end

local function generate_map()
    -- Initialize all sea
    for i = 0, (MAP_W * MAP_H) - 1 do map[i] = 0 end

    -- Draw a massive central continent (Valeria)
    for y = 5, 15 do
        for x = 8, 22 do set_tile(x, y, 1) end
    end

    -- Draw SW continent (Oakhaven)
    for y = 18, 30 do
        for x = 2, 12 do set_tile(x, y, 1) end
    end

    -- Draw SE continent (Iron Ascd)
    for y = 16, 28 do
        for x = 22, 30 do set_tile(x, y, 1) end
    end

    -- Generate Coasts (1 tile border around land)
    local new_map = {}
    for i = 0, (MAP_W * MAP_H) - 1 do new_map[i] = map[i] end

    for y = 0, MAP_H - 1 do
        for x = 0, MAP_W - 1 do
            if map[y * MAP_W + x] == 0 then -- If sea
                -- Check neighbors for land
                if get_tile(x-1, y) == 1 or get_tile(x+1, y) == 1 or
                   get_tile(x, y-1) == 1 or get_tile(x, y+1) == 1 then
                    new_map[y * MAP_W + x] = 2 -- Make it coast
                end
            end
        end
    end
    map = new_map
end

-- ==============================================================================
-- HELPER FUNCTIONS
-- ==============================================================================

local function show_msg(text, is_good)
    msg_text = text
    msg_timer = 120
    if is_good then sfx(0) else sfx(1) end
end

local btn_prev = {false, false, false, false, false, false, false, false}
local function just_pressed(b)
    return btn(b) and not btn_prev[b]
end

local function init_prices()
    for _, c in ipairs(cities) do
        for _, g in ipairs(goods) do
            -- Base price + some randomness
            local p_mod = 1.0 + (random_float() * 0.4 - 0.2)
            local p_val = math.floor(g.base * p_mod)

            -- Producers have it cheaper
            for _, pid in ipairs(c.prod) do
                if pid == g.id then p_val = math.floor(p_val * 0.6) end
            end

            -- Demanders pay more
            for _, did in ipairs(c.dem) do
                if did == g.id then p_val = math.floor(p_val * 1.5) end
            end

            c.prices[g.id] = math.max(1, p_val)
        end
    end
end

local function current_cargo_amount()
    local total = 0
    for k, v in pairs(p.cargo) do total = total + v end
    return total
end

local function is_solid(x, y, mode)
    local t = get_tile(x, y)
    if mode == "LAND" then
        return t == 0 -- Can't walk on deep sea
    else -- SEA
        return t == 1 -- Can't sail on deep land
    end
end

local function get_city_at(x, y)
    for i, c in ipairs(cities) do
        if c.x == x and c.y == y then return c end
    end
    return nil
end

-- ==============================================================================
-- LIFECYCLE
-- ==============================================================================

function _init()
    generate_map()
    init_prices()

    -- Start in Valeris
    p.x = 10
    p.y = 10
    p.mode = "LAND"
    p.cart_level = 1
    p.ship_level = 0
    p.max_cargo = 10
end

function _update()
    frame = frame + 1
    ticks = ticks + 1
    if msg_timer > 0 then msg_timer = msg_timer - 1 end

    -- Mix in user input for randomness
    for i=0, 7 do
        if btn(i) then rng_state = (rng_state + i * 17) % 2147483648 end
    end

    if game_state == "WORLD" then
        -- Map Movement
        local dx, dy = 0, 0
        if just_pressed(0) then dx = -1 end
        if just_pressed(1) then dx = 1 end
        if just_pressed(2) then dy = -1 end
        if just_pressed(3) then dy = 1 end

        if dx ~= 0 or dy ~= 0 then
            local nx, ny = p.x + dx, p.y + dy

            -- Prevent leaving map
            if nx >= 0 and nx < MAP_W and ny >= 0 and ny < MAP_H then
                if not is_solid(nx, ny, p.mode) then
                    p.x = nx
                    p.y = ny
                    sfx(2) -- step sound

                    -- Check if entered city
                    local c = get_city_at(p.x, p.y)
                    if c then
                        -- Check city access rules
                        if p.mode == "SEA" and not c.is_coastal then
                            show_msg("CANNOT REACH INLAND CITY BY SEA!", false)
                            -- step back
                            p.x = p.x - dx
                            p.y = p.y - dy
                        else
                            game_state = "CITY"
                            show_msg("ARRIVED AT " .. c.name, true)
                            sfx(3)

                            -- Check win condition on city entry
                            if p.gold >= 1000000 and p.rank >= 6 then
                                game_state = "WIN"
                                show_msg("TRADING COMPANY FOUNDED!", true)
                            end
                        end
                    else
                        -- Random Encounter chance on open map
                        if random_float() < 0.03 then -- 3% chance per step
                            local e_type = p.mode == "SEA" and "PIRATES" or "BANDITS"
                            local is_hostile_navy = false

                            -- Hostile navy check
                            for _, nat in ipairs(nations) do
                                if nat.hostile and random_float() < 0.5 then
                                    e_type = nat.name .. " NAVY"
                                    is_hostile_navy = true
                                end
                            end

                            -- Simplified Combat: Compare player level vs random enemy level
                            local p_level = p.mode == "SEA" and p.ship_level or p.cart_level
                            -- Hostile navies are much stronger
                            local e_level = is_hostile_navy and 3 or (math.floor(random_float() * 3) + 1)

                            if p_level >= e_level then
                                local reward = e_level * 100
                                p.gold = p.gold + reward
                                show_msg("DEFEATED " .. e_type .. "! +$" .. reward, true)
                            else
                                local loss = math.floor(p.gold * 0.2)
                                p.gold = math.max(0, p.gold - loss)
                                show_msg(e_type .. " STOLE $" .. loss .. "!", false)
                                sfx(1)
                            end
                        end
                    end
                else
                    sfx(1) -- bump
                end
            end
        end

        -- Action Button (Z): Switch Modes (Drop Anchor / Board Ship)
        if just_pressed(4) then
            local t = get_tile(p.x, p.y)

            if p.mode == "LAND" then
                -- Try to board ship
                if p.x == p.ship_x and p.y == p.ship_y then
                    p.mode = "SEA"
                    p.ship_x = -1 -- Ship is active
                    p.ship_y = -1
                    show_msg("BOARDED SHIP", true)
                    sfx(0)
                elseif p.ship_level == 0 then
                    show_msg("YOU DON'T OWN A SHIP!", false)
                else
                    show_msg("YOUR SHIP IS AT " .. p.ship_x .. "," .. p.ship_y, false)
                end
            else -- p.mode == "SEA"
                -- Try to drop anchor (must be on coast)
                if t == 2 then
                    p.mode = "LAND"
                    p.ship_x = p.x
                    p.ship_y = p.y
                    show_msg("DROPPED ANCHOR", true)
                    sfx(0)
                else
                    show_msg("MUST DROP ANCHOR ON COAST", false)
                end
            end
        end

    elseif game_state == "CITY" then
        local c = get_city_at(p.x, p.y)

        if current_menu == 0 then
            -- Main City Menu
            if just_pressed(2) then menu_idx = menu_idx - 1; sfx(2) end
            if just_pressed(3) then menu_idx = menu_idx + 1; sfx(2) end
            if menu_idx < 1 then menu_idx = 5 end
            if menu_idx > 5 then menu_idx = 1 end

            if just_pressed(4) then -- Z select
                if menu_idx == 5 then
                    game_state = "WORLD"
                    show_msg("DEPARTED CITY", true)
                else
                    current_menu = menu_idx
                    menu_idx = 1
                    sfx(0)
                end
            end
        elseif current_menu == 1 then
            -- MARKET
            if just_pressed(2) then menu_idx = menu_idx - 1; sfx(2) end
            if just_pressed(3) then menu_idx = menu_idx + 1; sfx(2) end
            if menu_idx < 1 then menu_idx = #goods end
            if menu_idx > #goods then menu_idx = 1 end

            local g = goods[menu_idx]
            local price = c.prices[g.id]

            -- Buy
            if just_pressed(4) then
                if (not g.ind or c.rd_sci >= 50) then -- Tech check
                    if p.gold >= price and current_cargo_amount() < p.max_cargo then
                        p.gold = p.gold - price
                        p.cargo[g.id] = (p.cargo[g.id] or 0) + 1
                        -- Dynamic price increase (demand goes up)
                        c.prices[g.id] = math.floor(c.prices[g.id] * 1.05) + 1
                        sfx(0)
                    else
                        sfx(1) -- Not enough gold or space
                    end
                else
                    sfx(1) -- Tech too low
                end
            end

            -- Sell
            if just_pressed(5) then
                if (p.cargo[g.id] or 0) > 0 then
                    p.cargo[g.id] = p.cargo[g.id] - 1
                    p.gold = p.gold + price
                    -- Dynamic price drop (supply goes up)
                    c.prices[g.id] = math.max(1, math.floor(c.prices[g.id] * 0.95))
                    sfx(0)
                else
                    sfx(1)
                end
            end

            -- Exit back to main
            if just_pressed(6) then -- Enter
                current_menu = 0
                menu_idx = 1
                sfx(2)
            end

        elseif current_menu == 2 then
            -- GUILD (SCIENCE R&D)
            if just_pressed(4) then
                if p.gold >= 500 then
                    p.gold = p.gold - 500
                    c.rd_sci = c.rd_sci + 10
                    -- Decrease base prices slightly as tech improves
                    for id, pr in pairs(c.prices) do
                        c.prices[id] = math.max(1, math.floor(pr * 0.95))
                    end
                    sfx(0)
                    show_msg("INVESTED $500 IN SCIENCE!", true)
                else
                    sfx(1)
                end
            end

            if just_pressed(6) then current_menu = 0; menu_idx = 1; sfx(2) end

        elseif current_menu == 3 then
            -- PALACE (MILITARY R&D / POLITICS)
            if just_pressed(2) then menu_idx = menu_idx - 1; sfx(2) end
            if just_pressed(3) then menu_idx = menu_idx + 1; sfx(2) end
            if menu_idx < 1 then menu_idx = 4 end
            if menu_idx > 4 then menu_idx = 1 end

            if just_pressed(4) then
                local nat = nations[c.nation]
                if menu_idx == 1 then
                    -- Buy Rank
                    local cost = p.rank * 10000
                    if p.gold >= cost and p.rank < 6 and nat.rep >= (p.rank * 10) then
                        p.gold = p.gold - cost
                        p.rank = p.rank + 1
                        sfx(0)
                        show_msg("PROMOTED TO " .. ranks[p.rank] .. "!", true)
                    else sfx(1) end
                elseif menu_idx == 2 then
                    -- Buy Ship Upgrade
                    local cost = (p.ship_level + 1) * 5000
                    if p.gold >= cost and p.ship_level < 3 then
                        p.gold = p.gold - cost
                        p.ship_level = p.ship_level + 1
                        if p.mode == "SEA" then p.max_cargo = p.max_cargo + 20 end
                        sfx(0)
                        show_msg("SHIP UPGRADED!", true)
                    else sfx(1) end
                elseif menu_idx == 3 then
                    -- Buy Cart Upgrade
                    local cost = (p.cart_level + 1) * 2000
                    if p.gold >= cost and p.cart_level < 3 then
                        p.gold = p.gold - cost
                        p.cart_level = p.cart_level + 1
                        if p.mode == "LAND" then p.max_cargo = p.max_cargo + 10 end
                        sfx(0)
                        show_msg("CART UPGRADED!", true)
                    else sfx(1) end
                elseif menu_idx == 4 then
                    -- Defect
                    if p.nation ~= c.nation then
                        nations[p.nation].rep = 0 -- Old nation hates you
                        nations[p.nation].hostile = true
                        p.nation = c.nation
                        p.rank = 1 -- Lose noble rank
                        sfx(1)
                        show_msg("DEFECTED TO " .. nat.name, false)
                    else
                        sfx(1)
                        show_msg("ALREADY A CITIZEN", false)
                    end
                end
            end

            if just_pressed(6) then current_menu = 0; menu_idx = 1; sfx(2) end

        elseif current_menu == 4 then
            -- BANK
            if just_pressed(2) then menu_idx = menu_idx - 1; sfx(2) end
            if just_pressed(3) then menu_idx = menu_idx + 1; sfx(2) end
            if menu_idx < 1 then menu_idx = 2 end
            if menu_idx > 2 then menu_idx = 1 end

            if just_pressed(4) then -- Action (Deposit/Loan)
                if menu_idx == 1 then
                    -- Deposit 100 gold
                    if p.gold >= 100 then
                        p.gold = p.gold - 100
                        p.bank = p.bank + 100
                        sfx(0)
                    else sfx(1) end
                elseif menu_idx == 2 then
                    -- Take Loan 1000 gold
                    p.debt = p.debt + 1000
                    p.gold = p.gold + 1000
                    sfx(0)
                end
            elseif just_pressed(5) then -- Reverse Action (Withdraw/Repay)
                if menu_idx == 1 then
                    -- Withdraw 100
                    if p.bank >= 100 then
                        p.bank = p.bank - 100
                        p.gold = p.gold + 100
                        sfx(0)
                    else sfx(1) end
                elseif menu_idx == 2 then
                    -- Repay Loan 1000
                    if p.debt >= 1000 and p.gold >= 1000 then
                        p.debt = p.debt - 1000
                        p.gold = p.gold - 1000
                        p.credit_score = math.min(100, p.credit_score + 1)
                        sfx(0)
                    else sfx(1) end
                end
            end

            -- Exit back to main
            if just_pressed(6) then -- Enter
                current_menu = 0
                menu_idx = 1
                sfx(2)
            end
        else
            -- Catchall exit for WIP menus
            if just_pressed(6) then current_menu = 0; menu_idx = 1; sfx(2) end
        end
    end

    -- Record inputs
    for i=0, 7 do btn_prev[i] = btn(i) end
end

function _draw()
    cls(C_BLACK)

    if game_state == "WORLD" then
        -- Draw Map (Camera centered roughly on player, but constrained to map)
        -- Screen is 256x240. Tiles can be 8x8. Map is 32x32 tiles (256x256 pixels).
        -- It almost fits perfectly! Let's just draw the whole map starting at 0,0.

        local tile_size = 7
        local offset_x = (256 - (MAP_W * tile_size)) / 2
        local offset_y = 16 -- leave room for HUD

        for y = 0, MAP_H - 1 do
            for x = 0, MAP_W - 1 do
                local t = get_tile(x, y)
                local col = C_BLACK
                if t == 0 then col = C_SEA
                elseif t == 1 then col = C_LAND
                elseif t == 2 then col = C_COAST
                end

                -- Draw Tile
                local px = offset_x + (x * tile_size)
                local py = offset_y + (y * tile_size)

                for dy = 0, tile_size - 1 do
                    for dx = 0, tile_size - 1 do
                        pset(px + dx, py + dy, col)
                    end
                end
            end
        end

        -- Draw Cities
        for i, c in ipairs(cities) do
            local px = offset_x + (c.x * tile_size)
            local py = offset_y + (c.y * tile_size)
            for dy = 0, tile_size - 1 do
                for dx = 0, tile_size - 1 do
                    pset(px + dx, py + dy, C_CITY)
                end
            end
        end

        -- Draw Anchored Ship
        if p.ship_x >= 0 then
            local px = offset_x + (p.ship_x * tile_size)
            local py = offset_y + (p.ship_y * tile_size)
            pset(px + 3, py + 3, C_SHIP)
            pset(px + 4, py + 3, C_SHIP)
            pset(px + 3, py + 2, C_SHIP)
        end

        -- Draw Player
        local px = offset_x + (p.x * tile_size)
        local py = offset_y + (p.y * tile_size)
        -- Blink player
        if math.floor(frame / 15) % 2 == 0 then
            local pcol = (p.mode == "LAND") and C_PLAYER or C_SHIP
            for dy = 1, tile_size - 2 do
                for dx = 1, tile_size - 2 do
                    pset(px + dx, py + dy, pcol)
                end
            end
        end

        -- HUD
        print("AGE OF DISCOVERY", 4, 4, C_TEXT)
        print("GOLD: " .. p.gold, 130, 4, C_SHIP)
        print("MODE: " .. p.mode, 200, 4, C_CITY)

        if msg_timer > 0 then
            print(">> " .. msg_text, 4, 230, C_CITY)
        else
            print("ARROWS: MOVE   Z: ANCHOR/BOARD   X: MENU", 4, 230, C_TEXT)
        end

    elseif game_state == "CITY" then
        local c = get_city_at(p.x, p.y)
        local nat = nations[c.nation]

        print("CITY OF " .. c.name, 10, 10, C_CITY)
        print("NATION: " .. nat.name, 10, 20, C_TEXT)
        print("REP: " .. nat.rep, 120, 20, C_TEXT)

        if current_menu == 0 then
            print("CITY MENU:", 10, 40, C_TEXT)
            local opts = {"MARKET", "GUILD", "PALACE", "BANK", "DEPART"}
            for i, opt in ipairs(opts) do
                local col = (i == menu_idx) and C_CITY or C_TEXT
                if i == menu_idx then print(">", 10, 45 + (i*10), col) end
                print(opt, 20, 45 + (i*10), col)
            end
            print("Z: SELECT", 4, 230, C_TEXT)

        elseif current_menu == 1 then
            -- MARKET VIEW
            print("MARKETPLACE (Z: BUY | X: SELL)", 10, 40, C_CITY)
            print("CARGO: " .. current_cargo_amount() .. "/" .. p.max_cargo, 180, 40, C_TEXT)
            print("GOLD: " .. p.gold, 180, 50, C_SHIP)

            local y = 60
            for i, g in ipairs(goods) do
                local col = (i == menu_idx) and C_CITY or C_TEXT
                if i == menu_idx then print(">", 4, y, col) end

                local name = g.name
                if g.ind and c.rd_sci < 50 then name = "???" end

                print(name, 12, y, col)
                print("$" .. c.prices[g.id], 80, y, col)
                print("OWN: " .. (p.cargo[g.id] or 0), 130, y, col)
                y = y + 12
            end
            print("ENTER: BACK", 4, 230, C_TEXT)

        elseif current_menu == 2 then
            -- GUILD VIEW
            print("MERCHANT GUILD", 10, 40, C_CITY)
            print("CITY SCIENCE TECH: " .. c.rd_sci .. "/100", 10, 55, C_TEXT)

            if c.rd_sci < 50 then
                print("LOCKED: INDUSTRIAL GOODS", 10, 70, C_WARN)
            else
                print("UNLOCKED: INDUSTRIAL GOODS", 10, 70, C_GOOD)
            end

            print("Z: INVEST $500 IN R&D", 10, 100, C_HL)
            print("ENTER: BACK", 4, 230, C_TEXT)

        elseif current_menu == 3 then
            -- PALACE VIEW
            print("ROYAL PALACE", 10, 40, C_CITY)
            print("CURRENT RANK: " .. ranks[p.rank], 120, 40, C_SHIP)

            local rank_cost = p.rank * 10000
            local ship_cost = (p.ship_level + 1) * 5000
            local cart_cost = (p.cart_level + 1) * 2000

            local opts = {
                { name = "PURSUE NOBILITY", cost = rank_cost },
                { name = "UPGRADE FLEET", cost = ship_cost },
                { name = "UPGRADE CARAVAN", cost = cart_cost },
                { name = "DEFECT TO NATION", cost = 0 }
            }

            for i, opt in ipairs(opts) do
                local col = (i == menu_idx) and C_CITY or C_TEXT
                if i == menu_idx then print(">", 10, 65 + (i*15), col) end
                print(opt.name, 20, 65 + (i*15), col)
                if opt.cost > 0 then
                    print("$" .. opt.cost, 160, 65 + (i*15), col)
                end
            end

            print("Z: PURCHASE   ENTER: BACK", 4, 230, C_TEXT)

        elseif current_menu == 4 then
            -- BANK VIEW
            print("NATIONAL BANK", 10, 40, C_CITY)
            print("GOLD: " .. p.gold, 180, 40, C_SHIP)
            print("CREDIT SCORE: " .. p.credit_score, 10, 55, C_TEXT)

            -- Deposit interest: ~1%, Loan interest: ~5% (scales down with credit)
            local loan_int = math.max(2.0, 10.0 - (p.credit_score / 20.0))

            local opts = {
                { name = "DEPOSIT (-100)", val = p.bank, desc = "1% INTEREST/MO" },
                { name = "LOAN (+1000)", val = p.debt, desc = string.format("%.1f%% INT/MO", loan_int) }
            }

            for i, opt in ipairs(opts) do
                local col = (i == menu_idx) and C_CITY or C_TEXT
                if i == menu_idx then print(">", 10, 75 + (i*20), col) end
                print(opt.name, 20, 75 + (i*20), col)
                print("$" .. opt.val, 120, 75 + (i*20), col)
                print(opt.desc, 20, 85 + (i*20), C_TEXT)
            end

            print("Z: ACTION   X: REVERSE   ENTER: BACK", 4, 230, C_TEXT)
        else
            print("SECTION UNDER CONSTRUCTION", 10, 40, C_WARN)
            print("ENTER: BACK", 4, 230, C_TEXT)
        end
    end
end
