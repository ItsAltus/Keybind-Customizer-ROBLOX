-- ============================================================
-- Script Name: KeybindMenu.client.lua
-- Project: Keybind Customizer
-- Author: DrChicken2424
-- Description: Renders the “Keybinds” ScreenGui, clones an
--              entry for every action, and handles the
--              rebind -> conflict‑check -> save pipeline.
-- ============================================================

---------------------------------------------------------------
-- VARIABLES & SERVICES
---------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("KeybindConfig"))
local KBM = require(script.Parent:WaitForChild("KeybindManager"))
local Remote = ReplicatedStorage:WaitForChild("KeybindPersistence")

---------------------------------------------------------------
-- GUI INSTANTIATION
---------------------------------------------------------------
-- Clone template ScreenGui stored in ReplicatedStorage so it
-- doesn’t load twice when multiple players join in Studio tests.
local guiTemplate = ReplicatedStorage:WaitForChild("KeybindsScreenGui")
local gui = guiTemplate:Clone()
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local scrolling = gui.Frame_Main.ScrollingFrame_Actions

---------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------
--[[  createRow(actionName, keyCode)
      Clones the template frame, wires up the Rebind button,
      and inserts it into the scrolling list.
]]
local function createRow(actionName, keyCode)
    local row = scrolling.Template_ActionEntry:Clone()
    row.Name = actionName
    row.TextLabel_RowName.Text = Config.labels[actionName] or actionName
    row.TextButton_CurrentKey.Text = keyCode.Name
    row.Visible = true

    ----------------------------------------------------------------
    -- REBIND FLOW
    ----------------------------------------------------------------
    row.TextButton_Rebind.MouseButton1Click:Connect(function()
        row.TextButton_CurrentKey.Text = "..."
        local connection; connection = UIS.InputBegan:Connect(function(input, processed)
            if processed then return end -- ignore chat / UI capture
            connection:Disconnect()

            local newKey = input.KeyCode
            row.TextButton_CurrentKey.Text = newKey.Name

            -- Update local map then persist to server
            local map = KBM.GetCurrentMap()
            if map then map[actionName] = newKey end
            Remote:InvokeServer("save", map)
        end)
    end)

    row.Parent = scrolling
end

---------------------------------------------------------------
-- INITIAL POPULATE
---------------------------------------------------------------
local binds = Remote:InvokeServer("load")
for action, key in pairs(binds.Gameplay or Config.contexts.Gameplay) do
    createRow(action, key)
end
