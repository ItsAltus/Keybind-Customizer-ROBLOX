-- ============================================================
-- Script Name: KeybindMenu.client.lua
-- Project: Keybind Customizer
-- Author: DrChicken2424
-- Description: Renders the “Keybinds” ScreenGui, clones an
--              entry for every action, and handles the
--              rebind -> conflict‑check -> save pipeline,
--              plus Export/Import via JSON modal.
-- ============================================================

---------------------------------------------------------------
-- SERVICES & MODULES
---------------------------------------------------------------
local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS             = game:GetService("UserInputService")
local CAS             = game:GetService("ContextActionService")
local HttpService     = game:GetService("HttpService")

local Config          = require(ReplicatedStorage:WaitForChild("KeybindConfig"))
local KBM             = require(script.Parent:WaitForChild("KeybindManager"))
local Remote          = ReplicatedStorage:WaitForChild("KeybindPersistence")

local gameplayMap

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
    game:GetService("ContextActionService"):UnbindAction("jumpAction")
end

local function resumeRobloxJump()
    game:GetService("ContextActionService"):BindAction(
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

local function resizeCanvas()
    local layout = scrolling:FindFirstChildOfClass("UIListLayout")
    scrolling.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 8)
end

local function applyMapToManager(map)
    KBM.SetContext("Gameplay", map)
end

---------------------------------------------------------------
-- MENU‑TOGGLE HINT
---------------------------------------------------------------
local hintGui = Instance.new("ScreenGui")
hintGui.Name         = "ToggleMenuHint"
hintGui.ResetOnSpawn = false
hintGui.DisplayOrder = 50
hintGui.Parent       = Players.LocalPlayer:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.AnchorPoint    = Vector2.new(0,1)
hintLabel.Position       = UDim2.new(0,16,1,-16)
hintLabel.Size           = UDim2.new(0,200,0,24)
hintLabel.BackgroundTransparency = 1
hintLabel.Font           = Enum.Font.Gotham
hintLabel.TextSize       = 25
hintLabel.TextColor3     = Color3.new(1,1,1)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent         = hintGui

local function updateToggleHint()
    local keyName = (gameplayMap.ToggleMenu or Enum.KeyCode.K).Name
    hintLabel.Text = ("Press [%s] to change keybinds"):format(keyName)
end

---------------------------------------------------------------
-- ROW CREATION & REBIND LOGIC
---------------------------------------------------------------
local function createRow(actionName, keyCode)
    local row = scrolling.Template_ActionEntry:Clone()
    row.Name                         = actionName
    row.TextLabel_RowName.Text       = Config.labels[actionName] or actionName
    row.TextButton_CurrentKey.Text   = keyCode.Name
    row.Visible                      = true

    -- rebind prompt
    row.TextButton_Rebind.MouseButton1Click:Connect(function()
        row.TextButton_CurrentKey.Text = "..."
        local conn; conn = UIS.InputBegan:Connect(function(input, processed)
            if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            conn:Disconnect()

            local newKey = input.KeyCode
            local map   = gameplayMap
            -- swap on conflict
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
-- RESET TO DEFAULTS
---------------------------------------------------------------
local function resetToDefaults()
    gameplayMap = table.clone(Config.contexts.Gameplay)
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
    Remote:InvokeServer("save", gameplayMap)
end
btnReset.MouseButton1Click:Connect(resetToDefaults)

---------------------------------------------------------------
-- MENU TOGGLE
---------------------------------------------------------------
local function toggleMenu(on)
    gui.Enabled = on
    if on then
        pauseRobloxJump()
        KBM.SetContext("Menu", { ToggleMenu = gameplayMap.ToggleMenu })
    else
        resumeRobloxJump()
        KBM.SetContext("Gameplay", gameplayMap)
    end
end

-- bind via ContextActionService so it never gets consumed
do
    local ACTION = "TOGGLE_KEYBINDS"
    CAS:BindActionAtPriority(ACTION, function(_, state)
        if state == Enum.UserInputState.Begin then
            toggleMenu(not gui.Enabled)
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.ContextActionPriority.High.Value+1, Config.contexts.Gameplay.ToggleMenu)
    -- rebind when ToggleMenu changes:
    KBM.BindAction("ToggleMenu", function()
        CAS:UnbindAction(ACTION)
        CAS:BindActionAtPriority(ACTION, toggleMenu, false,
            Enum.ContextActionPriority.High.Value+1,
            gameplayMap.ToggleMenu
        )
        updateToggleHint()
    end)
end

btnClose.MouseButton1Click:Connect(function() toggleMenu(false) end)

---------------------------------------------------------------
-- INITIAL POPULATE
---------------------------------------------------------------
do
    local loaded = Remote:InvokeServer("load")
    gameplayMap    = loaded.Gameplay or table.clone(Config.contexts.Gameplay)
    applyMapToManager(gameplayMap)

    for act, key in pairs(gameplayMap) do
        createRow(act, key)
    end
    resizeCanvas()
    updateToggleHint()
end

---------------------------------------------------------------
-- EXPORT / IMPORT MODAL
---------------------------------------------------------------
local function showModal(text)
    frameMain.Visible = false
    txtJSON.Text      = text
    modal.Visible     = true
    txtJSON:CaptureFocus()
end

local function hideModal()
    frameMain.Visible = true
    modal.Visible     = false
end

btnExport.MouseButton1Click:Connect(function()
    local exportTbl = {}
    for act, keyEnum in pairs(gameplayMap) do
        exportTbl[act] = keyEnum.Name
    end
    local json = HttpService:JSONEncode(exportTbl)
    warn("Export JSON:", json)      -- debug print
    showModal(json)
end)

btnImport.MouseButton1Click:Connect(function()
    showModal("")   -- empty for paste
end)

btnCancel.MouseButton1Click:Connect(hideModal)

btnLoad.MouseButton1Click:Connect(function()
    local ok, tbl = pcall(HttpService.JSONDecode, HttpService, txtJSON.Text)
    if not ok or type(tbl) ~= "table" then
        txtJSON.Text = "❌ Invalid JSON"
        return
    end

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
        if newMap[act] == nil then
            newMap[act] = def
        end
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
-- RESET‑ON‑DEATH / REAPPLY ON RESPAWN
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
