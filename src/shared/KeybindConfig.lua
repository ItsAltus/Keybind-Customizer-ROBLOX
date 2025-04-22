-- ============================================================
-- Script Name: KeybindConfig.lua
-- Project: Keybind Customizer
-- Author: DrChicken2424
-- Description: Central table for every bindable action, its
--              default keycode, and display label.  Client
--              and server modules require this to stay in sync.
-- ============================================================

---------------------------------------------------------------
-- VARIABLES & CONSTANTS
---------------------------------------------------------------
local Config = {
    -- increment if schema ever changes so old player profiles can be migrated
    version = 1,

    -- context maps let you swap controls (e.g. Gameplay vs Menu)
    contexts = {
        Gameplay = {
            Jump = Enum.KeyCode.Space,
            Dash = Enum.KeyCode.LeftShift,
            Interact = Enum.KeyCode.E,
            ToggleMenu = Enum.KeyCode.K,
        },

        Menu = {
            Select = Enum.KeyCode.Return,
            Back = Enum.KeyCode.Escape,
            ToggleMenu  = Enum.KeyCode.K,
        },
    },

    -- labels shown in the keybind UI
    labels = {
        Jump = "Jump",
        Dash = "Dash",
        Interact = "Interact",
        Select = "Select / Confirm",
        Back = "Back / Close",
        ToggleMenu = "Open/Close Menu",
    },
}

return Config
