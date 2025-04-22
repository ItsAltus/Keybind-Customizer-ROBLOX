-- ============================================================
-- Script Name: GameActions.client.lua
-- Project: Keybind Customizer
-- Author: DrChicken2424
-- Description: Subscribes to key‑bind actions (Jump, Dash,
--              Interact) and performs local gameplay logic.
--              * Auto‑updates ProximityPrompts on rebind
--              * Implements multi‑jump‑hold & dash cooldown
--              * Stays in sync with live key‑map from
--                KeybindManager
-- ============================================================

---------------------------------------------------------------
-- VARIABLES & SERVICES
---------------------------------------------------------------
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local player = game.Players.LocalPlayer

local KBM = require(script.Parent:WaitForChild("KeybindManager"))

local humanoid = nil
local holdingJump = false
local stateConn = nil

local MOVE_SPEED = 16
local DASH_SPEED = 50
local isDashing = false

---------------------------------------------------------------
-- HELPER UTILITIES
---------------------------------------------------------------
--[[  updateAllPrompts
      Re‑bind every ProximityPrompt in the world to the current
      Interact key.
      Called once on load and whenever Interact is rebound.
]]
local function updateAllPrompts(keyCode: Enum.KeyCode)
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("ProximityPrompt") then
            inst.KeyboardKeyCode = keyCode
        end
    end
end

--[[  dashAction
      Temporarily boosts WalkSpeed & plays an anim.
]]
local function dashAction()
    if isDashing then return end
    isDashing = true

    local dashAnim = Instance.new("Animation")
    dashAnim.AnimationId = "rbxassetid://94156304050794"
    local track = humanoid:LoadAnimation(dashAnim)
    track.Priority = Enum.AnimationPriority.Action
    track:Play()

    humanoid.WalkSpeed = DASH_SPEED
    task.delay(0.5, function()
        humanoid.WalkSpeed = MOVE_SPEED
        isDashing = false
    end)
end

--[[  tryJump
      Issues a jump only if player grounded.
]]
local function tryJump()
    if not humanoid then return end
    if humanoid.FloorMaterial ~= Enum.Material.Air then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

---------------------------------------------------------------
-- CHARACTER / HUMANOID SET‑UP
---------------------------------------------------------------
local function onCharacterAdded(char)
    humanoid = char:WaitForChild("Humanoid")

    if stateConn then
        stateConn:Disconnect()
    end

    -- auto‑jump again if player is holding the key
    stateConn = humanoid.StateChanged:Connect(function(new)
        if holdingJump and (new == Enum.HumanoidStateType.Landed
                         or new == Enum.HumanoidStateType.Running) then
            tryJump()
        end
    end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
    onCharacterAdded(player.Character)
end

---------------------------------------------------------------
-- INITIAL ONE‑TIME SETUP
---------------------------------------------------------------
do
    local map = KBM.GetCurrentMap()
    if map and map.Interact then
        updateAllPrompts(map.Interact)
    end
end

---------------------------------------------------------------
-- KEYBIND ACTIONS
---------------------------------------------------------------
-- Jump -------------------------------------------------------
KBM.BindAction("Jump", function()
    holdingJump = true
    tryJump()

    local k = KBM.GetCurrentMap().Jump
    print(k.Name .. " pressed – jumping!")
end)

-- stop holding on key‑up
UIS.InputEnded:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == KBM.GetCurrentMap().Jump then
        holdingJump = false
    end
end)

-- Dash -------------------------------------------------------
KBM.BindAction("Dash", function()
    local k = KBM.GetCurrentMap().Dash
    print(k.Name .. " pressed – dashing!")
    dashAction()
end)

-- Interact (ProximityPrompt) --------------------------------
KBM.BindAction("Interact", function()
    local k = KBM.GetCurrentMap().Interact
    print(k.Name .. " pressed – interacting!")
    updateAllPrompts(k)
end)
