-- ============================================================
-- Script Name: KeybindPersistence.server.lua
-- Project: Keybind Customizer
-- Author: DrChicken2424
-- Description: Server‑side wrapper around DataStoreService
--              for loading & saving player keybind profiles.
-- ============================================================

---------------------------------------------------------------
-- VARIABLES & SERVICES
---------------------------------------------------------------
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local BIND_DS = DataStoreService:GetDataStore("KeybindProfiles_v1")

local Remote = Instance.new("RemoteFunction")
Remote.Name = "KeybindPersistence"
Remote.Parent = ReplicatedStorage

local DEFAULTS = require(ReplicatedStorage:WaitForChild("KeybindConfig")).contexts

---------------------------------------------------------------
-- REMOTEFUNCTION HANDLER
---------------------------------------------------------------
--[[  Expected calls:
      * Remote:InvokeServer("load")
          -> returns table (player’s map) or DEFAULTS
      * Remote:InvokeServer("save", mapTable)
          -> returns true on success, false on failure
]]
local function handleKeybindRequest(player, mode, payload)
    -- In Studio (Play Solo), skip DataStore entirely
    if RunService:IsStudio() then
        if mode == "load" then
            -- return default context shape
            return { Gameplay = DEFAULTS.Gameplay }
        elseif mode == "save" then
            return true
        end
    end

    if mode == "load" then
        -- safely load from DataStore
        local ok, data = pcall(function()
            return BIND_DS:GetAsync(player.UserId)
        end)
        if not ok then
            warn("DataStore load failed:", data)
            data = nil
        end

        -- data should be a table of { actionName = "Space", ... }
        local map = {}
        if type(data) == "table" then
            for action, keyName in pairs(data) do
                local enumKey = Enum.KeyCode[keyName]
                map[action] = enumKey or DEFAULTS.Gameplay[action]
            end
        end

        -- fill in any missing defaults
        for action, def in pairs(DEFAULTS.Gameplay) do
            if map[action] == nil then
                map[action] = def
            end
        end

        return { Gameplay = map }

    elseif mode == "save" and type(payload) == "table" then
        -- serialize payload into string‐only table
        local saveTable = {}
        for action, val in pairs(payload) do
            if typeof(val) == "EnumItem" then
                saveTable[action] = val.Name
            elseif typeof(val) == "string" then
                saveTable[action] = val
            else
                warn(("Unexpected type for keybind '%s': %s"):format(action, typeof(val)))
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

    -- invalid mode
    warn("KeybindPersistence got invalid mode:", mode)
    return nil
end
Remote.OnServerInvoke = handleKeybindRequest

---------------------------------------------------------------
-- AUTO‑SAVE ON LEAVE
---------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
    local currentMaps = player:FindFirstChild("CurrentBinds")
    if currentMaps then
        pcall(Remote.OnServerInvoke, nil, player, "save", currentMaps.Value)
    end
end)
