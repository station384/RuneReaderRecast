> [!NOTE]
> This addon will be shutdown after Midnight 12.0 (Pre-patch)
>
> The functions that this addon utilizes will no longer be available to use with release of 12.0 (pre-patch)
> with no path to move forward I am forced to shutdown the project, unless blizzard changes course.

# RuneReader Recast

**RuneReader Recast** is a World of Warcraft addon that visually displays combat recommendations from multiple sources using **barcodes**, **QR codes**, and a **spell icon frame** with hotkeys.  
It is designed to encode in-game combat suggestions for external analysis or assistive use.

RuneReader Recast can function as:
- A component of **assistive devices** (e.g., external readers or visual aids).
- A **standalone overlay** for reviewing combat data in recorded video feeds.

---

## ✅ Features:
- **Combat Assist Integration:**
  - Supports Hekili, Blizzard Assisted Combat, MaxDPS and ConRO.
  - Automatically detects available addons and selects the appropriate data source.
- **Visual Spell Encoding:**
  - **Barcode (Code39):** Low CPU usage, simple visual output.
  - **QR Code:** Compact, high-density encoding for advanced use cases.
  - Dynamically updates as combat priorities change.
- **Spell Icon Frame:**
  - Displays the currently recommended spell icon with associated hotkey.
  - Tooltip support for additional details.
  - Draggable with position-saving between sessions.
- **Highly Configurable:**
  - Adjustable UI scale per display type.
  - Configurable refresh delay, barcode type, and spell queue pre-press delay.
  - Debug logging for advanced users.
  - Settings stored both account-wide and per character.

---

## ✅ Installation:
1. Download or clone this addon into your WoW AddOns folder:
2. Restart the game or reload the UI with `/reload`.

---

## ✅ Configuration:
Access the settings via:
 - Addon Options

Here, you can:
- Select which combat assist source to use (Hekili, WoW Assisted Combat, ConRO).
- Choose between Code39 or QR code output.
- Adjust scaling, encoding preferences, refresh delays, and debug options.

---

## ✅ License:
This project is licensed under the **GNU General Public License v3.0 (GPLv3)**.  
You are free to use, modify, and distribute this addon under the terms of the license.  
See `LICENSE.txt` or [GPLv3 License](https://www.gnu.org/licenses/gpl-3.0.en.html) for full details.

---

## ✅ Credits:
Developed by Tanstaafl Gaming.

Contributions are welcome under the terms of GPLv3. Forks, improvements, and shared enhancements are encouraged!

---

## ✅ Notes:
RuneReader Recast is intended for advanced users and developers seeking visual encoding of combat suggestions within WoW.  
It is particularly useful for external systems such as **assistive devices** or for reviewing combat data in **video analysis** workflows.

This addon is experimental in some areas, particularly with Blizzard’s Assisted Combat API, which may change in future patches.

---
