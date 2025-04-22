-- ============================================================
-- Script Name: KeybindManager.lua
-- Project: Keybind Customizer
-- Author: DrChicken2424
-- Description: Client‑side service that listens to
--              UserInputService and fires per‑action signals
--              that other client scripts can subscribe to.
--              Supports context switching (Gameplay/Menu).
-- ============================================================

---------------------------------------------------------------
-- VARIABLES & SERVICES
---------------------------------------------------------------
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("KeybindConfig"))

local KeybindManager = {}
KeybindManager.__index = KeybindManager

---------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------
--[[  newSignal
      Signal-er built with a BindableEvent.
      Each keybind action gets its own instance.
]]
local function newSignal()
    local evt = Instance.new("BindableEvent")
    return {
        fire = function(_, ...) evt:Fire(...) end,
        connect = function(_, fn) return evt.Event:Connect(fn) end,
    }
end

---------------------------------------------------------------
-- INTERNAL STATE
---------------------------------------------------------------
local signals = {} -- actionName -> signal
for _, map in pairs(Config.contexts) do -- iterates contexts from KeybindConfig.lua
    for action in pairs(map) do -- iterates current context's actions
        signals[action] = signals[action] or newSignal() -- assigns a new signal to the action if it doesn't exist
    end
end

local currentContext = "Gameplay" -- default context
local currentMap = table.clone(Config.contexts[currentContext]) -- shallow copy, what the input listener references during runtime

---------------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------------
--[[  BindAction(actionName, callback)
      Listens for the given action and runs callback whenever
      its key is pressed (and not game‑processed).
]]
function KeybindManager.BindAction(action, callback)
    return signals[action]:connect(callback)
end

--[[  SetContext(contextName, customMap)
      Switches the active key map. Only pass customMap if
      not using default keybinds (e.g. loading customs from a save).
]]
function KeybindManager.SetContext(contextName, newMap)
    currentContext = contextName
    currentMap = newMap or table.clone(Config.contexts[contextName])
end

-- getter for the live table
function KeybindManager.GetCurrentMap()
    return currentMap
end

---------------------------------------------------------------
-- INPUT HOOK
---------------------------------------------------------------
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    for action, key in pairs(currentMap) do
        if input.KeyCode == key then
            signals[action]:fire()
            break
        end
    end
end)

return KeybindManager
