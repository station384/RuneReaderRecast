-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

RuneReader = RuneReader or {}


function RuneReader:IsSpellExcluded(SpellID)
    local excludedSpells = {
        [198793] = true, -- Vengful Retreat
        [195072] = true, -- Felrush
        [433874] = true, -- Felrush (duplicate ID)
        [19801] = true, -- Tranq Shot
        [147362] = true, -- Counter Shot
        [8936] = true, -- Regrowth 
    }
    return excludedSpells[SpellID] or false
end
