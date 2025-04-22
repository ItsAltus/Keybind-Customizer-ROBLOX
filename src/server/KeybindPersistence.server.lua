-- ============================================================
-- Script Name: KeybindPersistence.server.lua
-- Project: Keybind Customizer
-- Author: DrChicken2424
-- Description: Server‑side wrapper around DataStoreService.
--              Exposes a RemoteFunction that lets clients:
--                * load -> fetch their saved key‑map
--                * save -> persist a key‑map table
--
--              Studio safety:
--                * Skips DataStore calls when RunService:IsStudio()
--              Fault‑tolerance:
--                * pcall‑wrapped GetAsync / SetAsync
--                * Fills in any missing defaults on load
-- ============================================================

---------------------------------------------------------------
-- VARIABLES & SERVICES
---------------------------------------------------------------
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local BIND_DS = DataStoreService:GetDataStore("KeybindProfiles_v1")

-- RemoteFunction created once and parented for clients
local Remote = Instance.new("RemoteFunction")
Remote.Name = "KeybindPersistence"
Remote.Parent = ReplicatedStorage

-- Static defaults (copied from KeybindConfig)
local DEFAULTS = require(ReplicatedStorage:WaitForChild("KeybindConfig")).contexts

---------------------------------------------------------------
-- REMOTEFUNCTION  (load / save dispatcher)
---------------------------------------------------------------
--[[  handleKeybindRequest(player, mode, payload?)
      Expected:
        * "load" -> returns { Gameplay = map }
        * "save", mapTable -> returns boolean success
      Notes:
        * In Studio Play‑Solo we short‑circuit to avoid DataStore calls.
        * Stored format is strings only: { Jump = "Space", ... }
]]
local function handleKeybindRequest(player, mode, payload)
    -----------------------------------------------------------
    -- Studio bypass
    -----------------------------------------------------------
    if RunService:IsStudio() then
        if mode == "load" then
            return { Gameplay = DEFAULTS.Gameplay }
        elseif mode == "save" then
            return true
        end
    end

    -----------------------------------------------------------
    -- LOAD
    -----------------------------------------------------------
    if mode == "load" then
        -- safely fetch
        local ok, data = pcall(function()
            return BIND_DS:GetAsync(player.UserId)
        end)
        if not ok then
            warn("DataStore load failed:", data)
            data = nil
        end

        -- reconstruct map ‑ convert string -> Enum.KeyCode
        local map = {}
        if type(data) == "table" then
            for action, keyName in pairs(data) do
                map[action] = Enum.KeyCode[keyName] or DEFAULTS.Gameplay[action]
            end
        end

        -- ensure every default exists
        for action, def in pairs(DEFAULTS.Gameplay) do
            map[action] = map[action] or def
        end

        return { Gameplay = map }

    -----------------------------------------------------------
    -- SAVE
    -----------------------------------------------------------
    elseif mode == "save" and type(payload) == "table" then
        -- convert Enum.KeyCode -> string
        local saveTable = {}
        for action, val in pairs(payload) do
            if typeof(val) == "EnumItem" then
                saveTable[action] = val.Name
            elseif typeof(val) == "string" then
                saveTable[action] = val
            else
                warn(("Unexpected type for keybind '%s': %s")
                     :format(action, typeof(val)))
            end
        end

        local ok, err = pcall(function()
            BIND_DS:SetAsync(player.UserId, saveTable)
        end)
        if not ok then
            warn("DataStore save failed:", err)
        end
        return ok
    end

    -----------------------------------------------------------
    -- Fallback for bad calls
    -----------------------------------------------------------
    warn("KeybindPersistence got invalid mode:", mode)
    return nil
end

Remote.OnServerInvoke = handleKeybindRequest

---------------------------------------------------------------
-- AUTO‑SAVE on player leave
---------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
    -- Client -> Server object containing live map
    local currentMaps = player:FindFirstChild("CurrentBinds")
    if currentMaps then
        -- pcall so a failure here doesn’t block other events
        pcall(Remote.OnServerInvoke, nil, player, "save", currentMaps.Value)
    end
end)
