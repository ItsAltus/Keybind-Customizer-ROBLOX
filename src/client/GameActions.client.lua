-- ============================================================
-- Script Name : GameActions.client.lua
-- Project     : Keybind Customizer
-- Author      : DrChicken2424
-- Description : Subscribes to key‑bind actions and performs
--               gameplay logic.
-- ============================================================

local Workspace = game:GetService("Workspace")
local KBM = require(script.Parent:WaitForChild("KeybindManager"))
local UIS = game:GetService("UserInputService")
local player = game.Players.LocalPlayer

local holdingJump = false
local humanoid
local stateConn

local moveSpeed = 16
local dashSpeed = 50
local isDashing = false

-- Utility: scan the world for all ProximityPrompts and update their key
local function updateAllPrompts(keyCode: Enum.KeyCode)
    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("ProximityPrompt") then
            instance.KeyboardKeyCode = keyCode
        end
    end
end

-- 1) On initial load, apply the saved binding
local map = KBM.GetCurrentMap()
if map and map.Interact then
    updateAllPrompts(map.Interact)
end

local function dashAction()
	if not isDashing then
		isDashing = true

		-- Optionally play a dash animation
		local dashAnimation = Instance.new("Animation")
		dashAnimation.AnimationId = "rbxassetid://94156304050794"
		local dashAnimTrack = humanoid:LoadAnimation(dashAnimation)
		dashAnimTrack.Priority = Enum.AnimationPriority.Action
		dashAnimTrack:Play()

		humanoid.WalkSpeed = dashSpeed

		-- Reset the dash after a brief delay
		task.delay(0.5, function()
			humanoid.WalkSpeed = moveSpeed
			isDashing = false
		end)
	end
end

local function tryJump()
    if not humanoid then return end
    -- FloorMaterial ~= Air means we're grounded
    if humanoid.FloorMaterial ~= Enum.Material.Air then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

local function onCharacterAdded(char)
    humanoid = char:WaitForChild("Humanoid")

    -- Clean up old connection if any
    if stateConn then
        stateConn:Disconnect()
    end

    -- When we land or return to running, and the player is holding jump, jump again
    stateConn = humanoid.StateChanged:Connect(function(newState)
        if holdingJump and (newState == Enum.HumanoidStateType.Landed
                         or newState == Enum.HumanoidStateType.Running) then
            tryJump()
        end
    end)
end

player.CharacterAdded:Connect(onCharacterAdded)
-- If character already exists (Play Solo), set it up now
if player.Character then
    onCharacterAdded(player.Character)
end

-- Jump -------------------------------------------------------
KBM.BindAction("Jump", function()
    local currentMap = KBM.GetCurrentMap()
    holdingJump = true
    tryJump()
    local boundKey = currentMap.Jump
    print(boundKey.Name .. " pressed - jumping!")
end)

-- Listen for key release to stop holding
UIS.InputEnded:Connect(function(input, processed)
    local currentMap = KBM.GetCurrentMap()
    if processed then return end
    if input.KeyCode == currentMap.Jump then
        holdingJump = false
    end
end)

-- Dash ----------------------------------------
KBM.BindAction("Dash", function()
    local currentMap = KBM.GetCurrentMap()
    local boundKey = currentMap.Dash
    print(boundKey.Name .. " pressed - dashing!")
    dashAction()
end)

-- Interact (placeholder) ------------------------------------
KBM.BindAction("Interact", function()
    local currentMap = KBM.GetCurrentMap()
    local boundKey = currentMap.Interact
    print(boundKey.Name .. " pressed - interacting!")
    local newKey = KBM.GetCurrentMap().Interact
    updateAllPrompts(newKey)
end)
