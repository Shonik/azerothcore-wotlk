--[[
    Battle Pass System - Communication Module
    BP_Communication.lua

    Server -> client communication protocol for the addon.
    Uses prefixed messages ##BP## via SendBroadcastMessage.
]]

-- Namespace
BattlePass = BattlePass or {}
BattlePass.Communication = BattlePass.Communication or {}

-- Constants
local MESSAGE_PREFIX = "##BP##"
local MAX_MESSAGE_LENGTH = 240
local LEVELS_PER_BATCH = 5

-- Sends a formatted message to the player
local function SendMessage(player, messageType, data)
    local message = MESSAGE_PREFIX .. messageType .. ":" .. data
    player:SendBroadcastMessage(message)
    BattlePass.Debug("Sent to " .. player:GetName() .. ": " .. message)
end

-- Sends complete progression data to the player
-- Format: SYNC:level,exp,max_exp,total_exp,max_level,claimed_levels
function BattlePass.Communication.SendSync(player)
    local guid = player:GetGUIDLow()

    BattlePass.PlayerCache[guid] = nil

    local status = BattlePass.Progress.GetPlayerStatus(player)

    local data = string.format("%d,%d,%d,%d,%d,%s",
        status.level,
        status.current_exp,
        status.exp_required,
        status.total_exp,
        status.max_level,
        status.claimed_levels or "")

    SendMessage(player, "SYNC", data)
end

-- Sends level definitions to the player (in batches)
-- Format: LEVELS:batch_num,total_batches|lvl=name=icon=type=count=status;...
-- Status: 0=locked, 1=available, 2=claimed, 3=owned
function BattlePass.Communication.SendLevelDefinitions(player)
    local maxLevel = BattlePass.GetConfigNumber("max_level", 100)
    local levels = {}
    local guid = player:GetGUIDLow()
    local playerData = BattlePass.DB.GetOrCreatePlayerData(player)

    for level = 1, maxLevel do
        if BattlePass.LevelCache[level] then
            table.insert(levels, BattlePass.LevelCache[level])
        end
    end

    local totalBatches = math.ceil(#levels / LEVELS_PER_BATCH)

    for batchNum = 1, totalBatches do
        local startIdx = (batchNum - 1) * LEVELS_PER_BATCH + 1
        local endIdx = math.min(batchNum * LEVELS_PER_BATCH, #levels)

        local batchData = {}
        for i = startIdx, endIdx do
            local lvl = levels[i]

            -- Determine status: 0=locked, 1=available, 2=claimed, 3=owned
            local status = 0
            if lvl.level > playerData.current_level then
                status = 0  -- Locked
            elseif BattlePass.DB.IsLevelClaimed(guid, lvl.level) then
                status = 2  -- Claimed
            elseif BattlePass.Rewards and BattlePass.Rewards.PlayerOwnsReward and
                   BattlePass.Rewards.PlayerOwnsReward(player, lvl) then
                status = 3  -- Already owns reward
            else
                status = 1  -- Available to claim
            end

            local entry = string.format("%d=%s=%s=%d=%d=%d",
                lvl.level,
                lvl.reward_name:gsub("[=;|]", ""),
                lvl.reward_icon or "INV_Misc_QuestionMark",
                lvl.reward_type,
                lvl.reward_count,
                status)
            table.insert(batchData, entry)
        end

        local data = string.format("%d,%d|%s",
            batchNum, totalBatches, table.concat(batchData, ";"))

        SendMessage(player, "LEVELS", data)
    end
end

-- Sends a progression update after XP gain
-- Format: UPDATE:gained_exp,new_level,current_exp,max_exp,levels_gained
function BattlePass.Communication.SendProgressUpdate(player, gainedExp, levelsGained)
    local status = BattlePass.Progress.GetPlayerStatus(player)

    local data = string.format("%d,%d,%d,%d,%d",
        gainedExp,
        status.level,
        status.current_exp,
        status.exp_required,
        levelsGained)

    SendMessage(player, "UPDATE", data)
end

-- Sends a claim confirmation and refreshes level definitions
-- Format: CLAIMED:level
function BattlePass.Communication.SendClaimConfirmation(player, level)
    SendMessage(player, "CLAIMED", tostring(level))
    BattlePass.Communication.SendLevelDefinitions(player)
end

-- Sends an error message to the addon
-- Format: ERROR:code,message
function BattlePass.Communication.SendError(player, code, message)
    local data = code .. "," .. (message or "Unknown error")
    SendMessage(player, "ERROR", data)
end

-- Sends system configuration
-- Format: CONFIG:key=value;key=value;...
function BattlePass.Communication.SendConfig(player)
    local configData = {}
    local keysToSend = {"max_level", "exp_per_level", "exp_scaling", "npc_entry"}

    for _, key in ipairs(keysToSend) do
        local value = BattlePass.GetConfig(key, "")
        table.insert(configData, key .. "=" .. value)
    end

    SendMessage(player, "CONFIG", table.concat(configData, ";"))
end

-- Performs a full synchronization with the client
function BattlePass.Communication.FullSync(player)
    if not BattlePass.IsEnabled() then
        BattlePass.Communication.SendError(player, "DISABLED", "Battle Pass is disabled")
        return
    end

    BattlePass.Debug("Full sync for " .. player:GetName())

    BattlePass.Communication.SendConfig(player)
    BattlePass.Communication.SendLevelDefinitions(player)
    BattlePass.Communication.SendSync(player)
end

-- Parses a command received from the client via chat commands (.bp sync, etc.)
function BattlePass.Communication.HandleClientCommand(player, command)
    local cmd = command:lower()

    if cmd == "sync" then
        BattlePass.Communication.FullSync(player)
    elseif cmd == "status" then
        BattlePass.Communication.SendSync(player)
    elseif cmd:match("^claim%s+(%d+)$") then
        local level = tonumber(cmd:match("^claim%s+(%d+)$"))
        if level then
            BattlePass.Rewards.ClaimReward(player, level)
        end
    else
        BattlePass.Debug("Unknown client command: " .. command)
    end
end
