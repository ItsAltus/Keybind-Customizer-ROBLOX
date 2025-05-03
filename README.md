# Keybind Customizer

**Project:** Keybind Customizer  
**Author:** ItsAltus (GitHub) / DrChicken2424 (ROBLOX)

**Demo Place:** [Keybind Customizer](https://www.roblox.com/games/107364302860159/Keybind-Customizer)  

## Overview

*Keybind Customizer* is a standalone modular system which implements fully customizable keybinds in a ROBLOX game. It features a clean and simple UI for rebinding keys, JSON-powered inport and export, and full data persistence using `DataStoreService`.

## Limitations

- **Studio-Only Limitations:**  
  While the system is fully functional in Studio, `DataStoreService` is intentionally skipped when using Play Solo or Run tests to avoid errors.

## Features

- **Fully Customizable Bindings:**  
  Players can rebind gameplay keys such as Jump, Dash, Interact, and ToggleMenu directly in-game with live updates.

- **Safe Rebinding UI:**  
  Detects and prevents duplicate binds with automatic swaps. Prevents binding to mouse clicks or non-keyboard inputs.

- **Persistent Profiles:**  
  Binds are saved to Roblox’s `DataStoreService`, ensuring players keep their preferences between sessions.

- **Import/Export JSON Sharing:**  
  Players can export or paste JSON configurations to share keybind profiles across accounts or games.

- **Keyboard Hint Label:**  
  UI prompt in the bottom-left updates in real-time to show the current "open menu" key.

## Project Structure

The system is organized into server-side, client-side, and shared scripts, and includes a json for Rojo-Roblox Studio mapping:

- **`Server-Side`**  
  - `KeybindPersistence.server.lua`: Handles saving/loading keybind data to DataStores.

- **`Client-Side`**
  - `KeybindManager.lua`: Client-side input handler with signal-based subscriptions.  
  - `KeybindMenu.client.lua`: UI logic, rebind pipeline, persistence syncing, and modal handling.  
  - `GameActions.client.lua`: Example consumer script that hooks into the keybinds to trigger player logic (e.g., Jump, Dash).

- **`Shared`**
  - `KeybindConfig.lua`: Defines all available actions, contexts, and default keybinds.  
  - `KeybindsScreenGui.rbxmx` (ScreenGui): Stored here to avoid duplication when joining.

## Usage

- **To Open the Menu:**  
  By default, press **K** to open the keybind menu. This can be changed via the UI.

- **Rebinding Keys:**  
  Press the "Rebind" button next to any action and then press a new keyboard key. The menu will automatically handle swaps if the new key is already bound.

- **Reset, Export, and Import:**  
  - **Reset Defaults**: Restores the default `Gameplay` map.  
  - **Export**: Serializes your binds as JSON.  
  - **Import**: Paste a JSON keybind table to load custom binds.
---
