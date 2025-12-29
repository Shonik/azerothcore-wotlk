local NPC_ENTRY = 90002

-- Configuration des destinations {MapID, X, Y, Z, O}
local Locations = {
    -- Capitales Alliance
    ["Stormwind"] = {0, -8960.14, 516.26, 96.35, 0.67},
    ["Ironforge"] = {0, -4924.07, -951.95, 501.55, 5.40},
    ["Darnassus"] = {1, 9947.52, 2482.73, 1316.21, 0.00},
    
    -- Capitales Horde
    ["Orgrimmar"] = {1, 1552.50, -4420.66, 8.50, 0.13},
    ["ThunderBluff"] = {1, -1280.19, 127.21, 131.35, 5.16},
    ["Undercity"] = {0, 1819.71, 238.79, 60.53, 3.49},

    -- Zones Neutres / WotLK
    ["Dalaran"] = {571, 5811.00, 449.00, 658.40, 4.64},
    ["Shattrath"] = {530, -1850.50, 5435.90, -12.42, 3.40}
}

local function OnGossipHello(event, player, creature)
    player:GossipMenuAddItem(0, "|TInterface\\icons\\inv_misc_map02:20:20:0:0|t Capitales de l'Alliance", 1, 100)
    player:GossipMenuAddItem(0, "|TInterface\\icons\\inv_misc_map01:20:20:0:0|t Capitales de la Horde", 1, 200)
    player:GossipMenuAddItem(0, "|TInterface\\icons\\Spell_Arcane_TeleportDalaran:20:20:0:0|t Sanctuaires (Dalaran/Shatt)", 1, 300)
    player:GossipSendMenu(1, creature)
end

local function OnGossipSelect(event, player, creature, sender, intid, code)
    -- Menu Alliance
    if (intid == 100) then
        player:GossipMenuAddItem(0, "Hurlevent", 2, 1)
        player:GossipMenuAddItem(0, "Forgefer", 2, 2)
        player:GossipMenuAddItem(0, "Darnassus", 2, 3)
        player:GossipMenuAddItem(0, "<- Retour", 1, 999)
        player:GossipSendMenu(1, creature)

    -- Menu Horde
    elseif (intid == 200) then
        player:GossipMenuAddItem(0, "Orgrimmar", 2, 4)
        player:GossipMenuAddItem(0, "Les Pitons du Tonnerre", 2, 5)
        player:GossipMenuAddItem(0, "Fossoyeuse", 2, 6)
        player:GossipMenuAddItem(0, "<- Retour", 1, 999)
        player:GossipSendMenu(1, creature)

    -- Menu Neutre
    elseif (intid == 300) then
        player:GossipMenuAddItem(0, "Dalaran", 2, 7)
        player:GossipMenuAddItem(0, "Shattrath", 2, 8)
        player:GossipMenuAddItem(0, "<- Retour", 1, 999)
        player:GossipSendMenu(1, creature)

    -- Retour au menu principal
    elseif (intid == 999) then
        OnGossipHello(event, player, creature)

    -- Traitement de la téléportation
    else
        local loc = nil
        if (intid == 1) then loc = Locations["Stormwind"]
        elseif (intid == 2) then loc = Locations["Ironforge"]
        elseif (intid == 3) then loc = Locations["Darnassus"]
        elseif (intid == 4) then loc = Locations["Orgrimmar"]
        elseif (intid == 5) then loc = Locations["ThunderBluff"]
        elseif (intid == 6) then loc = Locations["Undercity"]
        elseif (intid == 7) then loc = Locations["Dalaran"]
        elseif (intid == 8) then loc = Locations["Shattrath"]
        end

        if (loc) then
            player:CastSpell(player, 64446, true) -- Effet visuel de téléportation
            player:Teleport(loc[1], loc[2], loc[3], loc[4], loc[5])
            player:ResurrectPlayer() -- Sécurité si mort
            player:SetHealth(player:GetMaxHealth()) -- Soin complet (utile pour ton serveur 9.5)
            player:SetPower(player:GetMaxPower(0), 0) -- Mana full
            player:CloseGossip()
        end
    end
end

RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnGossipHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnGossipSelect)