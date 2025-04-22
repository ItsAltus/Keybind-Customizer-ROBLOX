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
local gameplayMap
local HttpService = game:GetService("HttpService")

---------------------------------------------------------------
-- GUI SETUP (clone + grab from clone)
---------------------------------------------------------------
local guiTemplate = ReplicatedStorage:WaitForChild("KeybindsScreenGui")
local gui         = guiTemplate:Clone()
gui.Name          = "KeybindsScreenGui"
gui.ResetOnSpawn  = false
gui.Enabled       = false
gui.Parent        = Players.LocalPlayer:WaitForChild("PlayerGui")

local frameMain    = gui:WaitForChild("Frame_Main")
local scrolling    = frameMain:WaitForChild("ScrollingFrame_Actions")
local footer       = frameMain:WaitForChild("Frame_Footer")

local btnReset     = footer:WaitForChild("TextButton_ResetDefaults")
local btnClose     = footer:WaitForChild("TextButton_Close")
local btnExport    = footer:WaitForChild("TextButton_Export")
local btnImport    = footer:WaitForChild("TextButton_Import")

local modal        = gui:WaitForChild("Frame_ModalOverlay")
local txtJSON      = modal:WaitForChild("TextBox_JSON")
local btnLoad      = modal:WaitForChild("TextButton_Load")
local btnCancel    = modal:WaitForChild("TextButton_Cancel")

---------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------
local function pauseRobloxJump()
    -- ControlModule registers the action name "jumpAction"
    game:GetService("ContextActionService"):UnbindAction("jumpAction")
end

local function resumeRobloxJump()
    -- Re‑create the default binding so Space works in menus, chat, etc.
    -- We call the same Roblox API ControlModule uses:
    game:GetService("ContextActionService"):BindAction(
        "jumpAction",
        function(_, state)
            if state == Enum.UserInputState.Begin then
                local humanoid = Players.LocalPlayer.Character
                    and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.Jump = true
                end
            end
            return Enum.ContextActionResult.Pass
        end,
        false,
        Enum.KeyCode.Space
    )
end

local function resizeCanvas()
    local layout = scrolling:FindFirstChildOfClass("UIListLayout")
    scrolling.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
end

local function applyMapToManager(map)
    KBM.SetContext("Gameplay", map)        -- live table reference
end

---------------------------------------------------------------
-- MENU‑TOGGLE HINT
---------------------------------------------------------------
-- Create a tiny ScreenGui with a TextLabel in the bottom‑left
local hintGui = Instance.new("ScreenGui")
hintGui.Name = "ToggleMenuHint"
hintGui.ResetOnSpawn = false
hintGui.DisplayOrder = 50
hintGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0,1)
hintLabel.Position = UDim2.new(0, 16, 1, -16)
hintLabel.Size = UDim2.new(0, 200, 0, 24)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 25
hintLabel.TextColor3 = Color3.fromRGB(255,255,255)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintGui

-- Function to update the hint text from the live binding
local function updateToggleHint()
    local key = gameplayMap.ToggleMenu or Enum.KeyCode.K
    hintLabel.Text = ("Press [%s] to change keybinds"):format(key.Name)
end

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
            if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end -- ignore chat / UI capture and non keyboard presses
            connection:Disconnect()

            local newKey = input.KeyCode
            local map = gameplayMap
            for otherAction, bound in pairs(map) do
                if bound == newKey and otherAction ~= actionName then
                    -- swap keys visually & in map
                    map[otherAction] = map[actionName]
                    local otherRow = scrolling:FindFirstChild(otherAction)
                    if otherRow then
                        otherRow.TextButton_CurrentKey.Text = map[otherAction].Name
                    end
                    break
                end
            end

            -- assign new key to this action
            map[actionName] = newKey
            row.TextButton_CurrentKey.Text = newKey.Name

            -- if this was the ToggleMenu entry, refresh our hint
            if actionName == "ToggleMenu" then
                updateToggleHint()
            end

            -- persist
            Remote:InvokeServer("save", map)
            resizeCanvas()
        end)
    end)

    row.Parent = scrolling
end

local function resetToDefaults()
    gameplayMap = table.clone(Config.contexts.Gameplay)
    applyMapToManager(gameplayMap)

    -- refresh rows
    for _, child in ipairs(scrolling:GetChildren()) do
        if child:IsA("Frame") and child ~= scrolling.Template_ActionEntry then
            child:Destroy()
        end
    end
    for action, key in pairs(gameplayMap) do
        createRow(action, key)
    end
    resizeCanvas()
    Remote:InvokeServer("save", gameplayMap)
    updateToggleHint()
end
btnReset.MouseButton1Click:Connect(resetToDefaults)

local function toggleMenu(state)
    gui.Enabled = state
    -- pause gameplay actions while menu is open
    if state then
        pauseRobloxJump()
        KBM.SetContext("Menu", { ToggleMenu = gameplayMap.ToggleMenu })
    else
        resumeRobloxJump()
        KBM.SetContext("Gameplay", gameplayMap)
    end
end

KBM.BindAction("ToggleMenu", function()
    toggleMenu(not gui.Enabled)
end)
btnClose.MouseButton1Click:Connect(function() toggleMenu(false) end)

---------------------------------------------------------------
-- INITIAL POPULATE
---------------------------------------------------------------
local loaded = Remote:InvokeServer("load")
gameplayMap = loaded.Gameplay or Config.contexts.Gameplay
applyMapToManager(gameplayMap)

for action, key in pairs(gameplayMap) do
    createRow(action, key)
end
resizeCanvas()

-- Initial call
updateToggleHint()

---------------------------------------------------------------
-- EXPORT / IMPORT LOGIC
---------------------------------------------------------------

-- show modal
local function showModal(text)
    frameMain.Visible = false
    txtJSON.Text = text or ""
    modal.Visible = true
    txtJSON:CaptureFocus()
end

-- hide modal
local function hideModal()
    frameMain.Visible = true
    modal.Visible = false
    gui.Enabled = true      -- re‑enable menu input if you disabled it
end

-- Export: JSON‑encode and show
btnExport.MouseButton1Click:Connect(function()
    local data = gameplayMap          -- table of Enum.KeyCode values
    -- convert to name‑only table
    local exportTbl = {}
    for action, keyEnum in pairs(data) do
        exportTbl[action] = keyEnum.Name
    end
    local json = HttpService:JSONEncode(exportTbl)
    showModal(json)
end)

-- Import: clear box and show
btnImport.MouseButton1Click:Connect(function()
    showModal("")                     -- empty for paste
end)

-- Cancel
btnCancel.MouseButton1Click:Connect(function()
    hideModal()
end)

-- Load: parse & apply
btnLoad.MouseButton1Click:Connect(function()
    local success, tbl = pcall(function()
        return HttpService:JSONDecode(txtJSON.Text)
    end)
    if not success or type(tbl) ~= "table" then
        txtJSON.Text = "❌ Invalid JSON"
        return
    end

    -- build new map, validate each key
    local newMap = {}
    for action, name in pairs(tbl) do
        local enumKey = Enum.KeyCode[name]
        if enumKey and Config.contexts.Gameplay[action] then
            newMap[action] = enumKey
        else
            newMap[action] = Config.contexts.Gameplay[action]
        end
    end
    -- fill any missing defaults
    for action, def in pairs(Config.contexts.Gameplay) do
        if newMap[action] == nil then
            newMap[action] = def
        end
    end

    -- apply & refresh UI
    gameplayMap = newMap
    applyMapToManager(gameplayMap)

    -- rebuild rows
    for _, child in ipairs(scrolling:GetChildren()) do
        if child:IsA("Frame") and child ~= scrolling.Template_ActionEntry then
            child:Destroy()
        end
    end
    for action, key in pairs(gameplayMap) do
        createRow(action, key)
    end
    resizeCanvas()
    updateToggleHint()

    -- persist & close
    Remote:InvokeServer("save", gameplayMap)
    hideModal()
end)
