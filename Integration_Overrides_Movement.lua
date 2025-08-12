-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

RuneReader = RuneReader or {}

-- This function will be going away in 12.0.0 of wow...    there eliminating the ability to read auras...
function RuneReader:IsMovementAllowedForChanneledSpell(spellID)
    -- Return true if the spell is NOT a known channel spell.
    if not RuneReader.ChanneledSpells[spellID] then return true end
    local data = RuneReader.GetPlayerAuraBySpellID(spellID)
    if not data then return false end

    for i = 1, #data do
        -- Only return true to allow cast if the aura allowing casting while moving is present
        if RuneReader.MovementCastingBuffs[data.spellId] then
            return true
        end
    end
    return false
end
