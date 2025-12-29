local function OnServerStartup()
    print("ALE is working! Server started successfully.")
end

RegisterServerEvent(33, OnServerStartup)  -- SERVER_EVENT_ON_CONFIG_LOAD