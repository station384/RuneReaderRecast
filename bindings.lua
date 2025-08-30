-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

BINDING_HEADER_RUNE_READER_RECAST = "RuneReader Recast"
BINDING_NAME_RUNE_READER_TOGGLE_MAJOR_CD = "Toggle Major Cooldowns"


function RuneReader_ToggleMajorCooldowns()
   -- I was getting linting errors here,  so doing the checks manually to make sure opjects and functions exist.
    if type(RuneReader) ~= "table" then return end
    local fn = RuneReader.ToggleUseGlobalCooldowns
    if type(fn) ~= "function" then return end

    -- Using a pcall here to catch any errors in the function call and prevent breaking the keybinding system.
    local ok, err = pcall(fn, RuneReader)  -- pass self when using dot call
    if not ok and RuneReader.DEBUG then
        print("|cffff5555[RuneReader] Toggle error:|r", err)
    end
end