-- Amadeus Cartridge: VC (IBN-5100 Theme)

SCREEN_W = 256
SCREEN_H = 240

C_BG = 0
C_DIM = 1
C_TEXT = 2
C_HL = 3

-- Fund State
-- Firm & Persistent State
firm_state = {
    wealth = 0.0,
    fund_number = 1,
    current_size = 10.0 -- Start with a 10M fund
}

-- Fund State (Resets every 10 years)
fund = {
    total = 10.0,
    cash = 10.0,
    deployed = 0.0,
    returned = 0.0,
    month = 1,
    max_months = 120
}

-- Game State
ticks = 0
rng_seed = 9999
game_state = "START"

-- Lists
inbox = {}
portfolio = {}

-- UI State
view_mode = "INBOX" -- or "PORTFOLIO"
selected_idx = 1
msg_timer = 0
msg_text = ""
show_details = false

-- Startup Data Generators
names_first = {"Aero", "Cloud", "Cyber", "Data", "Deep", "Neuro", "Nova", "Omni", "Quantum", "Syn", "Tech", "Zen"}
names_last = {"AI", "Block", "Base", "Box", "Chain", "Coin", "ify", "Hub", "Link", "Net", "Node", "Sys"}
sectors = {"SAAS", "FINTECH", "CRYPTO", "BIOTECH", "HARDWARE", "SOCIAL"}
stages = {"SEED", "SERIES A", "SERIES B", "SERIES C", "IPO/EXIT"}

-- Utilities
function random_float()
    rng_seed = (rng_seed * 1103515245 + 12345) % 2147483648
    local mixed = (rng_seed + (ticks * 73)) % 2147483648
    return (mixed / 2147483648)
end

function random_int(min, max)
    return math.floor(random_float() * (max - min + 1)) + min
end

function generate_startup()
    local name = names_first[random_int(1, #names_first)] .. names_last[random_int(1, #names_last)]
    local sector = sectors[random_int(1, #sectors)]

    -- Seed stage values
    local val = random_int(2, 8) + (random_float() * 2) -- Valuation: 2M - 10M
    local ask = val * (random_int(10, 20) / 100)        -- Ask for 10-20% equity
    local burn = ask / random_int(12, 24)               -- Runway: 12-24 months

    return {
        id = ticks,
        name = name,
        sector = sector,
        stage_idx = 1,
        valuation = val,
        ask_amt = ask,
        ask_eq = (ask / val),
        burn = burn,
        runway = ask / burn,
        quality = random_float(), -- Hidden modifier for success chance
        player_eq = 0.0,
        player_inv = 0.0,
        is_follow_on = false
    }
end

function show_msg(text, is_good)
    msg_text = text
    msg_timer = 90 -- 1.5 seconds
    if is_good then sfx(0) else sfx(1) end
end

function process_payout(payout)
    -- Calculate 20% Carry if we passed the hurdle rate (the total $10M fund size)
    local prev_returned = fund.returned
    fund.returned = fund.returned + payout

    local carry = 0.0
    if fund.returned > fund.total then
        -- We are in profit!
        local profit = 0.0
        if prev_returned < fund.total then
            -- Only the portion above the 10M hurdle counts for carry
            profit = fund.returned - fund.total
        else
            -- Every dollar is pure profit now
            profit = payout
        end
        carry = profit * 0.20 -- 20% Carried Interest
    end

    firm_state.wealth = firm_state.wealth + carry
    -- The fund keeps the rest of the cash
    fund.cash = fund.cash + (payout - carry)

    return carry
end

function advance_month()
    fund.month = fund.month + 1

    -- Charge 2% Management Fee (0.02 * 10M / 12 months = ~$0.0166M per month)
    local mgmt_fee = (fund.total * 0.02) / 12.0
    if fund.cash >= mgmt_fee then
        fund.cash = fund.cash - mgmt_fee
        firm_state.wealth = firm_state.wealth + mgmt_fee
    end

    if fund.month > fund.max_months then
        game_state = "GAMEOVER"
        sfx(3)
        return
    end

    -- Process Portfolio
    for i = #portfolio, 1, -1 do
        local p = portfolio[i]

        -- Burn cash
        p.runway = p.runway - 1

        -- Chance to fail or succeed each month based on quality
        local event_roll = random_float()

        if p.runway <= 0 then
            -- Out of cash. Must raise or die.
            if p.quality > 0.4 and event_roll < p.quality + 0.2 then
                -- Success! Needs follow-on funding
                p.stage_idx = p.stage_idx + 1
                if p.stage_idx > 4 then
                    -- EXIT!
                    local exit_val = p.valuation * (2.0 + (random_float() * 3.0))
                    local payout = exit_val * p.player_eq
                    local carry = process_payout(payout)

                    local msg = "EXIT! " .. p.name .. " ACQUIRED FOR $" .. string.format("%.1f", exit_val) .. "M!"
                    if carry > 0 then msg = msg .. " (CARRY: $" .. string.format("%.2f", carry) .. "M)" end
                    show_msg(msg, true)
                    sfx(3)
                    table.remove(portfolio, i)
                else
                    -- Next Round Pitch
                    p.valuation = p.valuation * (2.0 + (random_float() * 2.0)) -- 2x-4x step up
                    p.ask_amt = p.valuation * (random_int(10, 20) / 100)
                    p.ask_eq = p.ask_amt / p.valuation
                    p.runway = 12 + random_int(0, 6)
                    p.burn = p.ask_amt / p.runway
                    p.is_follow_on = true

                    -- Move to Inbox for a decision
                    table.insert(inbox, 1, p)
                    table.remove(portfolio, i)
                end
            else
                -- Bankruptcy
                show_msg("BANKRUPT! " .. p.name .. " ran out of cash. ($" .. string.format("%.2f", p.player_inv) .. "M lost)", false)
                table.remove(portfolio, i)
            end
        else
            -- Small chance to unexpectedly fail or get acquired early
            if event_roll < 0.005 then
                show_msg("SCANDAL! " .. p.name .. " founders arrested. Zeroed out.", false)
                table.remove(portfolio, i)
            elseif event_roll > 0.98 and p.stage_idx >= 2 then
                -- Generate a formal M&A Offer instead of an auto-exit
                local offer_val = p.valuation * (1.5 + random_float())

                -- We create a fake inbox item to represent the offer
                local offer = {
                    id = ticks,
                    name = p.name,
                    sector = p.sector,
                    stage_idx = p.stage_idx,
                    valuation = offer_val,
                    ask_amt = 0,
                    ask_eq = 0,
                    burn = p.burn,
                    runway = p.runway,
                    quality = p.quality,
                    player_eq = p.player_eq,
                    player_inv = p.player_inv,
                    is_follow_on = false,
                    is_ma_offer = true,
                    target_idx = i -- remember which portfolio item this is for
                }
                table.insert(inbox, 1, offer)
                show_msg("NEW M&A OFFER FOR " .. p.name .. "!", true)
            end
        end
    end

    -- Add new deal flow
    if #inbox == 0 then
        -- Guarantee at least one deal if completely empty to prevent dry spells
        table.insert(inbox, generate_startup())
    elseif #inbox < 5 and random_float() < 0.7 then
        table.insert(inbox, generate_startup())
    end
end

function start_fund()
    fund.total = firm_state.current_size
    fund.cash = firm_state.current_size
    fund.deployed = 0.0
    fund.returned = 0.0
    fund.month = 1
    inbox = {}
    portfolio = {}

    for i=1, 3 do
        table.insert(inbox, generate_startup())
    end

    game_state = "PLAY"
    view_mode = "INBOX"
    selected_idx = 1
    sfx(3)
end

function _init()
    firm_state.wealth = 0.0
    firm_state.fund_number = 1
    firm_state.current_size = 10.0
    start_fund()
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

    if msg_timer > 0 then
        msg_timer = msg_timer - 1
    end

    local action_pressed = btn(4) or btn(5) or btn(6) or btn(7)

    if game_state == "START" then
        if just_pressed(4) then _init() end
        return
    end

    if game_state == "GAMEOVER" then
        if just_pressed(4) then
            -- Calculate final TVPI to determine next fund size
            local mult = (fund.returned + fund.portfolio_val(portfolio)) / fund.total

            if mult >= 2.0 then
                firm_state.current_size = firm_state.current_size * 3.0
            elseif mult >= 1.0 then
                firm_state.current_size = firm_state.current_size * 1.5
            else
                firm_state.current_size = math.max(5.0, firm_state.current_size * 0.5)
            end

            firm_state.fund_number = firm_state.fund_number + 1
            start_fund()
        end
        return
    end

    -- View Switching
    if just_pressed(0) then
        view_mode = "INBOX"
        selected_idx = 1
        show_details = false
        sfx(2)
    elseif just_pressed(1) then
        view_mode = "PORTFOLIO"
        selected_idx = 1
        show_details = false
        sfx(2)
    end

    -- Toggle Details View
    if just_pressed(6) then
        show_details = not show_details
        sfx(2)
    end

    -- Safety clamp before logic
    local current_list = (view_mode == "INBOX") and inbox or portfolio
    if selected_idx > #current_list then selected_idx = math.max(1, #current_list) end

    -- List Scrolling
    local max_idx = #current_list
    if max_idx < 1 then max_idx = 1 end

    if just_pressed(2) then
        selected_idx = selected_idx - 1
        if selected_idx < 1 then selected_idx = max_idx end
        show_details = false
        sfx(2)
    elseif just_pressed(3) then
        selected_idx = selected_idx + 1
        if selected_idx > max_idx then selected_idx = 1 end
        show_details = false
        sfx(2)
    end

    -- Actions
    if view_mode == "INBOX" then
        if #inbox > 0 and inbox[selected_idx] ~= nil then
            local p = inbox[selected_idx]

            -- Z: INVEST / ACCEPT
            if just_pressed(4) then
                if p.is_ma_offer then
                    -- Accept M&A buyout!
                    local payout = p.valuation * p.player_eq
                    local carry = process_payout(payout)

                    local msg = "SOLD! " .. p.name .. " M&A PAYOUT: $" .. string.format("%.2f", payout) .. "M"
                    if carry > 0 then msg = msg .. " (CARRY: $" .. string.format("%.2f", carry) .. "M)" end

                    -- Remove the original company from the portfolio using target_idx
                    table.remove(portfolio, p.target_idx)

                    -- If we removed something before other offers, their target_idx might be wrong now.
                    -- Simple fix: we just search for matching name to remove the real one to be safe
                    for i=#portfolio, 1, -1 do
                        if portfolio[i].name == p.name then table.remove(portfolio, i) end
                    end

                    table.remove(inbox, selected_idx)
                    if selected_idx > #inbox then selected_idx = #inbox end
                    show_msg(msg, true)
                    sfx(3)
                    advance_month()
                else
                    -- Normal Invest
                    if fund.cash >= p.ask_amt then
                        fund.cash = fund.cash - p.ask_amt
                        fund.deployed = fund.deployed + p.ask_amt

                        p.player_eq = p.player_eq + p.ask_eq
                        p.player_inv = p.player_inv + p.ask_amt
                        p.is_follow_on = false

                        table.insert(portfolio, p)
                        table.remove(inbox, selected_idx)
                        if selected_idx > #inbox then selected_idx = #inbox end
                        show_msg("INVESTED $" .. string.format("%.2f", p.ask_amt) .. "M IN " .. p.name, true)
                        advance_month()
                    else
                        show_msg("INSUFFICIENT FUNDS FOR THIS ROUND!", false)
                    end
                end
            end

            -- X: PASS / REJECT
            if just_pressed(5) then
                if p.is_ma_offer then
                    show_msg("REJECTED M&A BUYOUT FOR " .. p.name, false)
                    table.remove(inbox, selected_idx)
                    if selected_idx > #inbox then selected_idx = #inbox end
                    advance_month()
                else
                    if p.is_follow_on then
                        -- Dilute our equity
                        p.player_eq = p.player_eq * (1.0 - p.ask_eq)
                        p.is_follow_on = false
                        table.insert(portfolio, p)
                        show_msg("PASSED ON " .. p.name .. " ROUND. EQUITY DILUTED.", false)
                    else
                        show_msg("PASSED ON " .. p.name, false)
                    end
                    table.remove(inbox, selected_idx)
                    if selected_idx > #inbox then selected_idx = #inbox end
                    advance_month()
                end
            end
        else
            -- Inbox is empty. Allow player to advance time manually.
            if just_pressed(5) then -- X button
                show_msg("ADVANCING 1 MONTH...", true)
                advance_month()
            end
        end
    elseif view_mode == "PORTFOLIO" then
        if #portfolio > 0 and portfolio[selected_idx] ~= nil then
            local p = portfolio[selected_idx]

            -- Z: REPLACE CEO
            if p.runway <= 5 and fund.cash >= 0.1 then
                if just_pressed(4) then
                    fund.cash = fund.cash - 0.1
                    p.quality = math.min(1.0, p.quality + 0.4)
                    p.runway = p.runway + 6
                    p.player_eq = p.player_eq * 0.90 -- 10% dilution to new CEO
                    show_msg("FIRED CEO OF " .. p.name .. ". RUNWAY +6 MO. EQ DILUTED.", true)
                end
            elseif p.runway <= 5 and fund.cash < 0.1 then
                if just_pressed(4) then
                    show_msg("NEED $0.1M TO FIRE CEO!", false)
                end
            end
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

function _draw()
    cls(C_BG)

    -- HEADER: Fund Stats
    fill_rect(0, 0, SCREEN_W, 36, C_DIM)

    local fund_title = "AMADEUS VENTURES - FUND " .. tostring(firm_state.fund_number)
    print(fund_title, 4, 4, C_HL)
    print("MONTH: " .. tostring(math.min(fund.month, fund.max_months)) .. "/" .. tostring(fund.max_months), 180, 4, C_TEXT)

    local mult = (fund.returned + fund.portfolio_val(portfolio)) / fund.total
    print("FUND CASH: $" .. string.format("%.2f", fund.cash) .. "M", 4, 16, C_HL)
    print("RETURNED:  $" .. string.format("%.2f", fund.returned) .. "M", 4, 26, C_TEXT)
    print("WEALTH: $" .. string.format("%.2f", firm_state.wealth) .. "M", 150, 16, C_HL)
    print("TVPI: " .. string.format("%.2f", mult) .. "x", 150, 26, C_TEXT)

    draw_line(0, 37, SCREEN_W, 37, C_TEXT)

    -- TABS
    local ix_col = view_mode == "INBOX" and C_HL or C_DIM
    local pf_col = view_mode == "PORTFOLIO" and C_HL or C_DIM
    print("< INBOX ("..#inbox..") >", 10, 44, ix_col)
    print("< PORTFOLIO ("..#portfolio..") >", 120, 44, pf_col)
    draw_line(0, 54, SCREEN_W, 54, C_DIM)

    -- LIST VIEW OR DETAILS VIEW
    local current_list = (view_mode == "INBOX") and inbox or portfolio

    if #current_list == 0 then
        print("EMPTY", 110, 100, C_DIM)
    elseif show_details then
        -- DUE DILIGENCE / DETAILS VIEW
        local p = current_list[selected_idx]
        if p then
            fill_rect(8, 60, 240, 140, C_DIM)
            fill_rect(10, 62, 236, 136, C_BG)
            print("DUE DILIGENCE: " .. p.name, 14, 66, C_HL)
            draw_line(10, 76, 246, 76, C_DIM)

            print("SECTOR: " .. p.sector, 14, 84, C_TEXT)
            print("STAGE:  " .. stages[p.stage_idx], 14, 94, C_TEXT)

            local rating = "HIGH RISK"
            if p.quality > 0.8 then rating = "EXCELLENT"
            elseif p.quality > 0.5 then rating = "GOOD"
            elseif p.quality > 0.25 then rating = "AVERAGE" end
            print("RATING: " .. rating, 14, 104, C_HL)

            -- Calculate the exact probability they secure next round / survive
            local odds = 0.0
            if p.quality > 0.4 then
                odds = math.min(1.0, p.quality + 0.2)
            end

            local odds_str = string.format("%.0f%%", odds * 100)
            local odds_col = C_TEXT
            if odds == 0.0 then
                odds_str = "0% (DOOMED)"
                odds_col = C_DIM
            elseif odds > 0.8 then
                odds_col = C_HL
            end
            print("SURVIVAL ODDS: " .. odds_str, 130, 104, odds_col)

            draw_line(10, 116, 246, 116, C_DIM)

            print("VALUATION: $" .. string.format("%.2f", p.valuation) .. "M", 14, 124, C_TEXT)
            print("BURN RATE: $" .. string.format("%.2f", p.burn) .. "M/MO", 14, 134, C_TEXT)
            print("RUNWAY:    " .. math.floor(p.runway) .. " MO", 14, 144, C_TEXT)

            draw_line(10, 156, 246, 156, C_DIM)

            if view_mode == "INBOX" then
                if p.is_ma_offer then
                    print("BUYOUT OFFER: $" .. string.format("%.2f", p.valuation) .. "M", 14, 164, C_HL)
                    print("YOUR PAYOUT:  $" .. string.format("%.2f", p.valuation * p.player_eq) .. "M", 14, 174, C_HL)
                else
                    print("ASK AMOUNT:   $" .. string.format("%.2f", p.ask_amt) .. "M", 14, 164, C_HL)
                    print("FOR EQUITY:   " .. string.format("%.1f%%", p.ask_eq * 100), 14, 174, C_HL)
                end
            else
                print("YOUR INVEST:  $" .. string.format("%.2f", p.player_inv) .. "M", 14, 164, C_HL)
                print("YOUR EQUITY:  " .. string.format("%.1f%%", p.player_eq * 100), 14, 174, C_HL)
                print("CURRENT VAL:  $" .. string.format("%.2f", p.valuation * p.player_eq) .. "M", 14, 184, C_HL)
            end
        end
    else
        -- Draw List items
        local start_idx = math.max(1, selected_idx - 2)
        local end_idx = math.min(#current_list, start_idx + 4)

        for i = start_idx, end_idx do
            local p = current_list[i]
            local y = 60 + ((i - start_idx) * 28)

            local col = C_TEXT
            if i == selected_idx then
                col = C_HL
                fill_rect(2, y-2, SCREEN_W-4, 26, C_DIM)
                print(">", 4, y, C_HL)
            end

            local title = p.name .. " [" .. p.sector .. "] " .. stages[p.stage_idx]
            if p.is_follow_on and view_mode == "INBOX" then
                title = "*PORTFOLIO* " .. title
            elseif p.is_ma_offer and view_mode == "INBOX" then
                title = "*M&A OFFER* " .. title
            end
            print(title, 12, y, col)

            if view_mode == "INBOX" then
                if p.is_ma_offer then
                    local details = "BUYOUT VAL: $"..string.format("%.1f", p.valuation).."M | PAYOUT: $"..string.format("%.2f", p.valuation * p.player_eq).."M"
                    print(details, 12, y + 10, col)
                else
                    local details = "VAL: $"..string.format("%.1f", p.valuation).."M | ASK: $"..string.format("%.2f", p.ask_amt).."M FOR "..string.format("%.1f", p.ask_eq * 100).."%"
                    print(details, 12, y + 10, col)
                end
            else
                local details = "OWN: "..string.format("%.1f", p.player_eq * 100).."% | RUNWAY: "..math.floor(p.runway).." MO"
                print(details, 12, y + 10, col)
            end
        end
    end

    -- CONTROLS / MSG FOOTER
    draw_line(0, 210, SCREEN_W, 210, C_DIM)

    if msg_timer > 0 then
        fill_rect(0, 211, SCREEN_W, 29, C_BG)
        print(msg_text, 4, 220, C_HL)
    else
        if show_details then
            print("ENTER: CLOSE DETAILS", 10, 220, C_TEXT)
        else
            if view_mode == "INBOX" then
                if #inbox > 0 then
                    local p = inbox[selected_idx]
                    if p and p.is_ma_offer then
                        print("Z: ACCEPT BUYOUT   X: REJECT", 10, 220, C_HL)
                    else
                        print("ENTER: DD", 180, 220, C_DIM)
                        print("Z: INVEST  X: PASS", 10, 220, C_HL)
                    end
                else
                    print("X: ADVANCE 1 MONTH", 10, 220, C_HL)
                end
            else
                if #portfolio > 0 then
                    local p = portfolio[selected_idx]
                    if p and p.runway <= 5 then
                        print("ENTER: DD", 180, 220, C_DIM)
                        print("Z: REPLACE CEO ($0.1M)", 10, 220, C_HL)
                    else
                        print("ENTER: DUE DILIGENCE", 10, 220, C_TEXT)
                    end
                else
                    print("ARROWS: NAVIGATE", 10, 220, C_TEXT)
                end
            end
        end
    end

    -- OVERLAYS
    if game_state == "START" then
        fill_rect(50, 90, 156, 40, C_DIM)
        fill_rect(52, 92, 152, 36, C_BG)
        print("AMADEUS VENTURES", 70, 100, C_HL)
        print("PRESS Z TO RAISE FUND 1", 56, 112, C_TEXT)
    elseif game_state == "GAMEOVER" then
        fill_rect(40, 85, 176, 60, C_HL)
        fill_rect(42, 87, 172, 56, C_BG)
        print("FUND LIFECYCLE COMPLETE", 50, 95, C_HL)
        print("FINAL MULTIPLE: " .. string.format("%.2f", mult) .. "x", 50, 107, C_TEXT)
        print("YOUR WEALTH: $" .. string.format("%.2f", firm_state.wealth) .. "M", 50, 117, C_HL)
        print("PRESS Z TO START NEXT FUND", 45, 130, C_DIM)
    end
end

-- Helper for UI calc
function fund.portfolio_val(port)
    local v = 0
    for i=1, #port do
        v = v + (port[i].valuation * port[i].player_eq)
    end
    return v
end
