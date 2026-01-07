--[[
    Battle Pass System - Commands Module
    BP_Commands.lua

    Chat commands for players and administrators.

    IMPORTANT: This module must NOT block other game commands.
    The handler returns false by default to let non-BP commands
    pass through to other handlers.
]]

-- Namespace
BattlePass = BattlePass or {}
BattlePass.Commands = BattlePass.Commands or {}

-- Constants
local ADMIN_GM_RANK = 2 -- Minimum GM rank for admin commands

-- Player Commands

local function CommandStatus(player)
    if not BattlePass.Progress or not BattlePass.Progress.GetPlayerStatus then
        player:SendBroadcastMessage("|cffff0000[Battle Pass]|r Système non initialisé.")
        return
    end

    local status = BattlePass.Progress.GetPlayerStatus(player)

    player:SendBroadcastMessage("|cff00ff00========== Battle Pass ==========|r")
    player:SendBroadcastMessage(string.format("Niveau: |cffffd700%d|r / %d",
        status.level, status.max_level))

    if status.is_max_level then
        player:SendBroadcastMessage("Expérience: |cff00ff00NIVEAU MAX|r")
    else
        player:SendBroadcastMessage(string.format("Expérience: |cffffd700%d|r / %d (%d%%)",
            status.current_exp, status.exp_required, status.progress_percent))
    end

    player:SendBroadcastMessage(string.format("XP Total: |cff888888%d|r", status.total_exp))

    local unclaimed = BattlePass.Progress.CountUnclaimedRewards(player)
    if unclaimed > 0 then
        player:SendBroadcastMessage(string.format(
            "|cffff8000Récompenses disponibles: %d|r", unclaimed))
    end

    player:SendBroadcastMessage("|cff00ff00==================================|r")
end

local function CommandRewards(player)
    if not BattlePass.Progress or not BattlePass.Progress.GetAvailableRewards then
        player:SendBroadcastMessage("|cffff0000[Battle Pass]|r Système non initialisé.")
        return
    end

    local rewards = BattlePass.Progress.GetAvailableRewards(player)

    if #rewards == 0 then
        player:SendBroadcastMessage(
            "|cff00ff00[Battle Pass]|r Aucune récompense disponible.")
        return
    end

    player:SendBroadcastMessage("|cff00ff00===== Récompenses Disponibles =====|r")

    for _, reward in ipairs(rewards) do
        local desc = BattlePass.Rewards.FormatRewardDescription(reward)
        player:SendBroadcastMessage("  " .. desc)
    end

    player:SendBroadcastMessage(
        "|cff888888Utilisez .bp claim <niveau> pour réclamer|r")
    player:SendBroadcastMessage("|cff00ff00==================================|r")
end

local function CommandClaim(player, level)
    if not level then
        player:SendBroadcastMessage(
            "|cffff0000[Battle Pass]|r Usage: .bp claim <niveau>")
        return
    end

    if not BattlePass.Rewards or not BattlePass.Rewards.ClaimReward then
        player:SendBroadcastMessage("|cffff0000[Battle Pass]|r Système non initialisé.")
        return
    end

    BattlePass.Rewards.ClaimReward(player, level)
end

local function CommandClaimAll(player)
    if not BattlePass.Progress or not BattlePass.Rewards then
        player:SendBroadcastMessage("|cffff0000[Battle Pass]|r Système non initialisé.")
        return
    end

    local unclaimed = BattlePass.Progress.CountUnclaimedRewards(player)

    if unclaimed == 0 then
        player:SendBroadcastMessage(
            "|cff00ff00[Battle Pass]|r Aucune récompense à réclamer.")
        return
    end

    BattlePass.Rewards.ClaimAllRewards(player)
end

local function CommandPreview(player, startLevel)
    if not BattlePass.Progress then
        player:SendBroadcastMessage("|cffff0000[Battle Pass]|r Système non initialisé.")
        return
    end

    local status = BattlePass.Progress.GetPlayerStatus(player)
    startLevel = startLevel or (status.level + 1)

    local maxLevel = BattlePass.GetConfigNumber("max_level", 100)
    local endLevel = math.min(startLevel + 4, maxLevel)

    player:SendBroadcastMessage(string.format(
        "|cff00ff00===== Aperçu Niveaux %d-%d =====|r", startLevel, endLevel))

    for level = startLevel, endLevel do
        local levelData = BattlePass.LevelCache[level]
        if levelData then
            local expRequired = BattlePass.Progress.GetExpForLevel(level)
            local status_str = ""

            if level <= status.level then
                if BattlePass.DB and BattlePass.DB.IsLevelClaimed(player:GetGUIDLow(), level) then
                    status_str = " |cff00ff00[Réclamé]|r"
                else
                    status_str = " |cffff8000[Disponible]|r"
                end
            else
                status_str = string.format(" |cff888888(%d XP)|r", expRequired)
            end

            player:SendBroadcastMessage(string.format("  Niv %d: |cffffd700%s|r%s",
                level, levelData.reward_name, status_str))
        end
    end

    if endLevel < maxLevel then
        player:SendBroadcastMessage(string.format(
            "|cff888888Utilisez .bp preview %d pour voir plus|r", endLevel + 1))
    end

    player:SendBroadcastMessage("|cff00ff00==================================|r")
end

local function CommandSync(player)
    if not BattlePass.Communication or not BattlePass.Communication.FullSync then
        player:SendBroadcastMessage("|cffff0000[Battle Pass]|r Système non initialisé.")
        return
    end

    BattlePass.Communication.FullSync(player)
    player:SendBroadcastMessage(
        "|cff00ff00[Battle Pass]|r Données synchronisées avec l'addon.")
end

local function CommandHelp(player)
    player:SendBroadcastMessage("|cff00ff00===== Battle Pass - Aide =====|r")
    player:SendBroadcastMessage("  |cffffd700.bp|r - Affiche votre progression")
    player:SendBroadcastMessage("  |cffffd700.bp rewards|r - Liste les récompenses disponibles")
    player:SendBroadcastMessage("  |cffffd700.bp claim <niveau>|r - Réclame une récompense")
    player:SendBroadcastMessage("  |cffffd700.bp claimall|r - Réclame toutes les récompenses")
    player:SendBroadcastMessage("  |cffffd700.bp preview [niveau]|r - Aperçu des niveaux à venir")
    player:SendBroadcastMessage("  |cffffd700.bp sync|r - Synchronise avec l'addon")
    player:SendBroadcastMessage("|cff00ff00==============================|r")
end

-- Admin Commands

local function AdminAddExp(admin, targetName, amount)
    local target = targetName and GetPlayerByName(targetName) or admin

    if not target then
        admin:SendBroadcastMessage(
            "|cffff0000[BP Admin]|r Joueur non trouvé: " .. tostring(targetName))
        return
    end

    if not BattlePass.Events or not BattlePass.Events.AwardCustomExp then
        admin:SendBroadcastMessage("|cffff0000[BP Admin]|r Système non initialisé.")
        return
    end

    BattlePass.Events.AwardCustomExp(target, amount, "ADMIN:" .. admin:GetName())

    admin:SendBroadcastMessage(string.format(
        "|cff00ff00[BP Admin]|r Ajouté %d XP à %s", amount, target:GetName()))
end

local function AdminSetLevel(admin, targetName, level)
    local target = targetName and GetPlayerByName(targetName) or admin

    if not target then
        admin:SendBroadcastMessage(
            "|cffff0000[BP Admin]|r Joueur non trouvé: " .. tostring(targetName))
        return
    end

    if not BattlePass.DB or not BattlePass.DB.SetPlayerLevel then
        admin:SendBroadcastMessage("|cffff0000[BP Admin]|r Système non initialisé.")
        return
    end

    BattlePass.DB.SetPlayerLevel(target:GetGUIDLow(), level)

    -- Update cache
    local data = BattlePass.PlayerCache[target:GetGUIDLow()]
    if data then
        data.current_level = level
        data.current_exp = 0
    end

    admin:SendBroadcastMessage(string.format(
        "|cff00ff00[BP Admin]|r Niveau de %s défini à %d", target:GetName(), level))

    -- Notify target player
    if target ~= admin then
        target:SendBroadcastMessage(string.format(
            "|cffff8000[Battle Pass]|r Votre niveau a été défini à %d par un admin.", level))
    end

    -- Sync addon
    if BattlePass.Communication and BattlePass.Communication.SendSync then
        BattlePass.Communication.SendSync(target)
    end
end

local function AdminReset(admin, targetName)
    local target = targetName and GetPlayerByName(targetName) or admin

    if not target then
        admin:SendBroadcastMessage(
            "|cffff0000[BP Admin]|r Joueur non trouvé: " .. tostring(targetName))
        return
    end

    if not BattlePass.DB or not BattlePass.DB.ResetPlayer then
        admin:SendBroadcastMessage("|cffff0000[BP Admin]|r Système non initialisé.")
        return
    end

    BattlePass.DB.ResetPlayer(target:GetGUIDLow())

    admin:SendBroadcastMessage(string.format(
        "|cff00ff00[BP Admin]|r Battle Pass de %s réinitialisé", target:GetName()))

    -- Notify target player
    if target ~= admin then
        target:SendBroadcastMessage(
            "|cffff8000[Battle Pass]|r Votre Battle Pass a été réinitialisé par un admin.")
    end

    -- Sync addon
    if BattlePass.Communication and BattlePass.Communication.SendSync then
        BattlePass.Communication.SendSync(target)
    end
end

local function AdminReload(admin)
    if not BattlePass.Reload then
        admin:SendBroadcastMessage("|cffff0000[BP Admin]|r Système non initialisé.")
        return
    end

    BattlePass.Reload()
    admin:SendBroadcastMessage(
        "|cff00ff00[BP Admin]|r Configuration Battle Pass rechargée.")
end

local function AdminStats(admin)
    local cachedPlayers = BattlePass.TableCount(BattlePass.PlayerCache or {})
    local levels = BattlePass.TableCount(BattlePass.LevelCache or {})
    local sources = BattlePass.TableCount(BattlePass.SourceCache or {})

    admin:SendBroadcastMessage("|cff00ff00===== Battle Pass Stats =====|r")
    admin:SendBroadcastMessage(string.format("  Version: %s", BattlePass.VERSION or "?"))
    admin:SendBroadcastMessage(string.format("  Tables Exist: %s",
        BattlePass.TablesExist and "Yes" or "No"))
    admin:SendBroadcastMessage(string.format("  Enabled: %s",
        BattlePass.IsEnabled() and "Yes" or "No"))
    admin:SendBroadcastMessage(string.format("  Max Level: %s",
        BattlePass.GetConfig("max_level", "?")))
    admin:SendBroadcastMessage(string.format("  Levels Defined: %d", levels))
    admin:SendBroadcastMessage(string.format("  Progress Sources: %d", sources))
    admin:SendBroadcastMessage(string.format("  Cached Players: %d", cachedPlayers))
    admin:SendBroadcastMessage("|cff00ff00==============================|r")
end

local function AdminUnclaim(admin, targetName, level)
    local target = targetName and GetPlayerByName(targetName) or admin

    if not target then
        admin:SendBroadcastMessage(
            "|cffff0000[BP Admin]|r Joueur non trouvé: " .. tostring(targetName))
        return
    end

    if not BattlePass.DB or not BattlePass.DB.UnmarkLevelClaimed then
        admin:SendBroadcastMessage("|cffff0000[BP Admin]|r Système non initialisé.")
        return
    end

    local guid = target:GetGUIDLow()

    -- Check if level is claimed
    if not BattlePass.DB.IsLevelClaimed(guid, level) then
        admin:SendBroadcastMessage(string.format(
            "|cffff0000[BP Admin]|r %s n'a pas claimed le niveau %d",
            target:GetName(), level))
        return
    end

    local success = BattlePass.DB.UnmarkLevelClaimed(guid, level)

    if success then
        -- Save immediately
        local data = BattlePass.PlayerCache[guid]
        if data then
            BattlePass.DB.SavePlayerProgress(guid, data)
        end

        admin:SendBroadcastMessage(string.format(
            "|cff00ff00[BP Admin]|r Niveau %d de %s retiré des récompenses claimed",
            level, target:GetName()))

        -- Notify target player
        if target ~= admin then
            target:SendBroadcastMessage(string.format(
                "|cffff8000[Battle Pass]|r Le niveau %d a été réinitialisé par un admin. Vous pouvez le réclamer à nouveau.",
                level))
        end

        -- Sync addon
        if BattlePass.Communication and BattlePass.Communication.SendSync then
            BattlePass.Communication.SendSync(target)
        end
    else
        admin:SendBroadcastMessage(
            "|cffff0000[BP Admin]|r Erreur lors du retrait du niveau")
    end
end

local function AdminHelp(admin)
    admin:SendBroadcastMessage("|cff00ff00===== BP Admin - Aide =====|r")
    admin:SendBroadcastMessage("  |cffffd700.bpadmin addxp <montant> [joueur]|r")
    admin:SendBroadcastMessage("  |cffffd700.bpadmin setlevel <niveau> [joueur]|r")
    admin:SendBroadcastMessage("  |cffffd700.bpadmin unclaim <niveau> [joueur]|r")
    admin:SendBroadcastMessage("  |cffffd700.bpadmin reset [joueur]|r")
    admin:SendBroadcastMessage("  |cffffd700.bpadmin reload|r - Recharge la config")
    admin:SendBroadcastMessage("  |cffffd700.bpadmin stats|r - Stats du système")
    admin:SendBroadcastMessage("|cff00ff00============================|r")
end

-- Main Command Handlers

local function HandleBPCommand(player, command)
    local args = {}
    for arg in command:gmatch("%S+") do
        table.insert(args, arg)
    end

    if not BattlePass.IsEnabled() then
        player:SendBroadcastMessage(
            "|cffff0000[Battle Pass]|r Le système est désactivé.")
        return
    end

    -- No arguments = show status
    if #args == 0 then
        CommandStatus(player)
        return
    end

    local subCmd = args[1]:lower()

    if subCmd == "status" or subCmd == "s" then
        CommandStatus(player)
    elseif subCmd == "rewards" or subCmd == "r" then
        CommandRewards(player)
    elseif subCmd == "claim" or subCmd == "c" then
        local level = tonumber(args[2])
        CommandClaim(player, level)
    elseif subCmd == "claimall" or subCmd == "ca" then
        CommandClaimAll(player)
    elseif subCmd == "preview" or subCmd == "p" then
        local startLevel = tonumber(args[2])
        CommandPreview(player, startLevel)
    elseif subCmd == "sync" then
        CommandSync(player)
    elseif subCmd == "help" or subCmd == "h" or subCmd == "?" then
        CommandHelp(player)
    else
        player:SendBroadcastMessage(
            "|cffff0000[Battle Pass]|r Commande inconnue. Utilisez |cff00ff00.bp help|r")
    end
end

local function HandleBPAdminCommand(player, command)
    if player:GetGMRank() < ADMIN_GM_RANK then
        player:SendBroadcastMessage(
            "|cffff0000[BP Admin]|r Permission refusée.")
        return
    end

    local args = {}
    for arg in command:gmatch("%S+") do
        table.insert(args, arg)
    end

    if #args == 0 then
        AdminHelp(player)
        return
    end

    local subCmd = args[1]:lower()

    if subCmd == "addxp" or subCmd == "ax" then
        local amount = tonumber(args[2])
        local targetName = args[3]
        if not amount then
            player:SendBroadcastMessage(
                "|cffff0000[BP Admin]|r Usage: .bpadmin addxp <montant> [joueur]")
        else
            AdminAddExp(player, targetName, amount)
        end
    elseif subCmd == "setlevel" or subCmd == "sl" then
        local level = tonumber(args[2])
        local targetName = args[3]
        if not level then
            player:SendBroadcastMessage(
                "|cffff0000[BP Admin]|r Usage: .bpadmin setlevel <niveau> [joueur]")
        else
            AdminSetLevel(player, targetName, level)
        end
    elseif subCmd == "unclaim" or subCmd == "uc" then
        local level = tonumber(args[2])
        local targetName = args[3]
        if not level then
            player:SendBroadcastMessage(
                "|cffff0000[BP Admin]|r Usage: .bpadmin unclaim <niveau> [joueur]")
        else
            AdminUnclaim(player, targetName, level)
        end
    elseif subCmd == "reset" then
        local targetName = args[2]
        AdminReset(player, targetName)
    elseif subCmd == "reload" or subCmd == "rl" then
        AdminReload(player)
    elseif subCmd == "stats" then
        AdminStats(player)
    elseif subCmd == "help" or subCmd == "h" or subCmd == "?" then
        AdminHelp(player)
    else
        player:SendBroadcastMessage(
            "|cffff0000[BP Admin]|r Commande inconnue. Utilisez |cff00ff00.bpadmin help|r")
    end
end

-- Command Registration

-- In Eluna PLAYER_EVENT_ON_COMMAND:
--   return false = command handled, suppress "Command does not exist"
--   return true (or nil) = pass to other handlers
local function OnCommand(event, player, command)
    if not command or not player then
        return
    end

    local cmd = command:lower()

    -- Handle .bp or .battlepass commands
    if cmd == "bp" or cmd:match("^bp ") or cmd == "battlepass" or cmd:match("^battlepass ") then
        local args = cmd:gsub("^bp%s*", ""):gsub("^battlepass%s*", "")
        local success, err = pcall(HandleBPCommand, player, args)
        if not success then
            player:SendBroadcastMessage("|cffff0000[Battle Pass]|r Erreur: " .. tostring(err))
        end
        return false
    end

    -- Handle .bpadmin commands
    if cmd == "bpadmin" or cmd:match("^bpadmin ") then
        local args = cmd:gsub("^bpadmin%s*", "")
        local success, err = pcall(HandleBPAdminCommand, player, args)
        if not success then
            player:SendBroadcastMessage("|cffff0000[BP Admin]|r Erreur: " .. tostring(err))
        end
        return false
    end

    -- Return nil to pass to other handlers
end

RegisterPlayerEvent(42, OnCommand) -- PLAYER_EVENT_ON_COMMAND

BattlePass.Info("Commands registered: .bp, .bpadmin")
