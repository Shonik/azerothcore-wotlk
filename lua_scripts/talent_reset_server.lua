--[[
    Talent Reset Button - Server Script (ALE/Eluna)

    This script handles the talent reset functionality.
    Works with the TalentResetButton WoW addon.

    Installation:
    1. Place this file in your lua_scripts folder (next to worldserver executable)
    2. Install the TalentResetButton addon on the client
    3. Reload ALE with: .reload ale
]]

local ADDON_PREFIX = "TalentReset"

-- Configuration
local CONFIG = {
    -- Set to true to charge players for reset (like class trainer)
    CHARGE_GOLD = false,
    -- Set to true to reset the cost accumulator (makes next reset free/cheaper)
    RESET_COST = true,
    -- Minimum level required to use the feature (0 = no restriction)
    MIN_LEVEL = 0,
    -- Cooldown in seconds between resets (0 = no cooldown)
    COOLDOWN = 0,
}

-- Player cooldown tracking
local playerCooldowns = {}

-- Handle the talent reset request
local function HandleTalentReset(player)
    local playerGuid = player:GetGUIDLow()
    local playerName = player:GetName()

    -- Check minimum level
    if CONFIG.MIN_LEVEL > 0 and player:GetLevel() < CONFIG.MIN_LEVEL then
        player:SendBroadcastMessage("|cffff0000You must be at least level " .. CONFIG.MIN_LEVEL .. " to reset talents.|r")
        return false
    end

    -- Check cooldown
    if CONFIG.COOLDOWN > 0 then
        local currentTime = os.time()
        local lastReset = playerCooldowns[playerGuid] or 0
        local timeLeft = CONFIG.COOLDOWN - (currentTime - lastReset)

        if timeLeft > 0 then
            player:SendBroadcastMessage("|cffff0000You must wait " .. timeLeft .. " seconds before resetting talents again.|r")
            return false
        end
        playerCooldowns[playerGuid] = currentTime
    end

    -- Check and charge gold if configured
    if CONFIG.CHARGE_GOLD then
        local cost = player:ResetTalentsCost()
        local playerGold = player:GetCoinage()

        if playerGold < cost then
            local goldNeeded = math.floor(cost / 10000)
            local silverNeeded = math.floor((cost % 10000) / 100)
            local copperNeeded = cost % 100
            player:SendBroadcastMessage(string.format(
                "|cffff0000You need %dg %ds %dc to reset your talents.|r",
                goldNeeded, silverNeeded, copperNeeded
            ))
            return false
        end

        -- Deduct gold
        player:ModifyMoney(-cost)
    end

    -- Reset talents (true = no cost, no accumulator increase)
    local noCost = CONFIG.RESET_COST
    player:ResetTalents(noCost)

    -- Send success message
    player:SendBroadcastMessage("|cff00ff00Your talents have been reset!|r")

    -- Log the action
    print("[TalentReset] Player " .. playerName .. " (GUID: " .. playerGuid .. ") reset their talents.")

    -- Send confirmation to addon
    player:SendAddonMessage(ADDON_PREFIX, "SUCCESS", 7, player)

    return true
end

-- Method 1: Custom dot command (.resettalents)
local PLAYER_EVENT_ON_COMMAND = 42

local function OnPlayerCommand(event, player, command)
    if command == "resettalents" or command == "rt" then
        HandleTalentReset(player)
        return false -- Don't show "unknown command" error
    end
    return true -- Let other commands pass through
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, OnPlayerCommand)

-- Method 3: Slash command handler via chat (for addon communication)
-- This allows the addon to send "/resettalents" and get a response
local PLAYER_EVENT_ON_CHAT = 18

local function OnPlayerChat(event, player, msg, msgType, lang)
    -- Check if it's our addon command sent via say (hidden from others)
    if msg == "#TALENT_RESET_REQUEST#" then
        HandleTalentReset(player)
        return false -- Don't broadcast this message
    end
    return true
end

-- Uncomment if you want chat-based trigger (not recommended, use command instead)
-- RegisterPlayerEvent(PLAYER_EVENT_ON_CHAT, OnPlayerChat)

-- Startup message
local SERVER_EVENT_ON_STARTUP = 14

local function OnServerStartup()
    print("========================================")
    print("[TalentReset] Server script loaded!")
    print("[TalentReset] Commands: .resettalents or .rt")
    print("========================================")
end

RegisterServerEvent(SERVER_EVENT_ON_STARTUP, OnServerStartup)

print("[TalentReset] Script initialized.")
