-- ============================================================
-- Script Name: KeybindMenu.client.lua
-- Project: Keybind Customizer
-- Author: DrChicken2424
-- Description: Renders the Keybinds ScreenGui, clones an
--              entry for every action, and handles the full
--              rebind -> conflict‑check -> save pipeline.
--              Extras:
--                * Toggle‑menu hint
--                * DataStore persistence (via RemoteFunction)
--                * Export / Import JSON modal
-- ============================================================

---------------------------------------------------------------
-- VARIABLES & SERVICES
---------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("KeybindConfig"))
local KBM = require(script.Parent:WaitForChild("KeybindManager"))
local Remote = ReplicatedStorage:WaitForChild("KeybindPersistence")

local gameplayMap -- live reference—filled in during initial populate

---------------------------------------------------------------
-- GUI SET‑UP  (clone template, then grab references)
---------------------------------------------------------------
local guiTemplate = ReplicatedStorage:WaitForChild("KeybindsScreenGui")
local gui = guiTemplate:Clone()
gui.Name = "KeybindsScreenGui"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- primary panels & widgets
local frameMain = gui:WaitForChild("Frame_Main")
local scrolling = frameMain:WaitForChild("ScrollingFrame_Actions")
local footer = frameMain:WaitForChild("Frame_Footer")

local btnReset = footer:WaitForChild("TextButton_ResetDefaults")
local btnClose = footer:WaitForChild("TextButton_Close")
local btnExport = footer:WaitForChild("TextButton_Export")
local btnImport = footer:WaitForChild("TextButton_Import")

local modal = gui:WaitForChild("Frame_ModalOverlay")
local txtJSON = modal:WaitForChild("TextBox_JSON")
local btnLoad = modal:WaitForChild("TextButton_Load")
local btnCancel = modal:WaitForChild("TextButton_Cancel")

---------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------
--[[  pauseRobloxJump / resumeRobloxJump
      Roblox’s ControlModule registers the “jumpAction” Context‑Action.
      To prevent Space from jumping while the menu is open, and while
      jump is binded to another key, we unbind it and restore it afterwards.
]]
local function pauseRobloxJump()
    CAS:UnbindAction("jumpAction")
end

local function resumeRobloxJump()
    CAS:BindAction(
        "jumpAction",
        function(_, state)
            if state == Enum.UserInputState.Begin then
                local hum = Players.LocalPlayer.Character
                         and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end
            return Enum.ContextActionResult.Pass
        end,
        false,
        Enum.KeyCode.Space
    )
end

-- auto‑resize ScrollFrame to its UIListLayout
local function resizeCanvas()
    local layout = scrolling:FindFirstChildOfClass("UIListLayout")
    scrolling.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 8)
end

-- push new live map into KeybindManager
local function applyMapToManager(map)
    KBM.SetContext("Gameplay", map)
end

---------------------------------------------------------------
-- INITIALIZE KEYBIND HINT
---------------------------------------------------------------
local hintGui = Instance.new("ScreenGui")
hintGui.Name = "ToggleMenuHint"
hintGui.ResetOnSpawn = false
hintGui.DisplayOrder = 50
hintGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.AnchorPoint = Vector2.new(0,1)
hintLabel.Position = UDim2.new(0,16,1,-16)
hintLabel.Size = UDim2.new(0,220,0,24)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 25
hintLabel.TextColor3 = Color3.new(1,1,1)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintGui

-- change which letter is shown in the hint to open settings
local function updateToggleHint()
    local keyName = (gameplayMap.ToggleMenu or Enum.KeyCode.K).Name
    hintLabel.Text = ("Press [%s] to change keybinds"):format(keyName)
end

---------------------------------------------------------------
-- ROW CREATION & REBIND FLOW
---------------------------------------------------------------
--[[  createRow(actionName, keyCode)
      Clones template, wires Rebind button, adds to ScrollFrame.
]]
local function createRow(actionName, keyCode)
    local row = scrolling.Template_ActionEntry:Clone()
    row.Name = actionName
    row.TextLabel_RowName.Text = Config.labels[actionName] or actionName
    row.TextButton_CurrentKey.Text = keyCode.Name
    row.Visible = true

    -- --- Rebind button logic ---------------------------------
    row.TextButton_Rebind.MouseButton1Click:Connect(function()
        row.TextButton_CurrentKey.Text = "..."
        local conn; conn = UIS.InputBegan:Connect(function(input, processed)
            if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            conn:Disconnect()

            local newKey = input.KeyCode
            local map = gameplayMap

            -- if the new key is already in use, swap with other action
            for other, bound in pairs(map) do
                if bound == newKey and other ~= actionName then
                    map[other] = map[actionName]
                    local otherRow = scrolling:FindFirstChild(other)
                    if otherRow then
                        otherRow.TextButton_CurrentKey.Text = map[other].Name
                    end
                    break
                end
            end

            map[actionName] = newKey
            row.TextButton_CurrentKey.Text = newKey.Name

            if actionName == "ToggleMenu" then
                updateToggleHint()
            end

            Remote:InvokeServer("save", map)
            resizeCanvas()
        end)
    end)

    row.Parent = scrolling
end

---------------------------------------------------------------
-- RESET‑TO‑DEFAULTS
---------------------------------------------------------------
local function resetToDefaults()
    gameplayMap = table.clone(Config.contexts.Gameplay)
    applyMapToManager(gameplayMap)

    for _, child in ipairs(scrolling:GetChildren()) do
        if child:IsA("Frame") and child ~= scrolling.Template_ActionEntry then
            child:Destroy()
        end
    end
    for act, key in pairs(gameplayMap) do
        createRow(act, key)
    end
    resizeCanvas()
    Remote:InvokeServer("save", gameplayMap)
    updateToggleHint()
end
btnReset.MouseButton1Click:Connect(resetToDefaults)

---------------------------------------------------------------
-- MENU TOGGLE  (open / close screen)
---------------------------------------------------------------
local function toggleMenu(state)
    gui.Enabled = state
    if state then
        pauseRobloxJump()
        KBM.SetContext("Menu", { ToggleMenu = gameplayMap.ToggleMenu })
    else
        resumeRobloxJump()
        KBM.SetContext("Gameplay", gameplayMap)
    end
end

-- Bind ToggleMenu through KBM (so players can rebind it)
KBM.BindAction("ToggleMenu", function()
    toggleMenu(not gui.Enabled)
end)
btnClose.MouseButton1Click:Connect(function() toggleMenu(false) end)

---------------------------------------------------------------
-- INITIAL POPULATE (load & build rows)
---------------------------------------------------------------
do
    local loaded = Remote:InvokeServer("load")
    gameplayMap = loaded.Gameplay or table.clone(Config.contexts.Gameplay)

    applyMapToManager(gameplayMap)

    for act, key in pairs(gameplayMap) do
        createRow(act, key)
    end
    resizeCanvas()
    updateToggleHint()
end

---------------------------------------------------------------
-- EXPORT / IMPORT  (JSON modal pop‑up)
---------------------------------------------------------------
local function showModal(text)
    frameMain.Visible = false
    txtJSON.Text = text or ""
    modal.Visible = true
    txtJSON:CaptureFocus()
end

local function hideModal()
    frameMain.Visible = true
    modal.Visible = false
end

-- Export current map
btnExport.MouseButton1Click:Connect(function()
    local exportTbl = {}
    for act, keyEnum in pairs(gameplayMap) do
        exportTbl[act] = keyEnum.Name
    end
    local json = HttpService:JSONEncode(exportTbl)
    showModal(json)
end)

-- Prepare blank import box
btnImport.MouseButton1Click:Connect(function()
    showModal("")
end)

btnCancel.MouseButton1Click:Connect(hideModal)

-- Apply imported JSON
btnLoad.MouseButton1Click:Connect(function()
    local ok, tbl = pcall(HttpService.JSONDecode, HttpService, txtJSON.Text)
    if not ok or type(tbl) ~= "table" then
        txtJSON.Text = "❌ Invalid JSON"
        return
    end

    -- validate & build new table
    local newMap = {}
    for act, name in pairs(tbl) do
        local ek = Enum.KeyCode[name]
        if ek and Config.contexts.Gameplay[act] then
            newMap[act] = ek
        else
            newMap[act] = Config.contexts.Gameplay[act]
        end
    end
    for act, def in pairs(Config.contexts.Gameplay) do
        newMap[act] = newMap[act] or def
    end

    gameplayMap = newMap
    applyMapToManager(gameplayMap)

    -- rebuild UI
    for _, c in ipairs(scrolling:GetChildren()) do
        if c:IsA("Frame") and c ~= scrolling.Template_ActionEntry then
            c:Destroy()
        end
    end
    for act, key in pairs(gameplayMap) do
        createRow(act, key)
    end
    resizeCanvas()
    updateToggleHint()

    Remote:InvokeServer("save", gameplayMap)
    hideModal()
end)

---------------------------------------------------------------
-- RESPAWN (re‑apply context after death)
---------------------------------------------------------------
Players.LocalPlayer.CharacterAdded:Connect(function()
    if gui.Enabled then
        pauseRobloxJump()
        KBM.SetContext("Menu", { ToggleMenu = gameplayMap.ToggleMenu })
    else
        resumeRobloxJump()
        KBM.SetContext("Gameplay", gameplayMap)
    end
    updateToggleHint()
end)
