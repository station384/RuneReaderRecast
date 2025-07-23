-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

RuneReader = RuneReader or {}


function RuneReader:IsSpellExcluded(SpellID)
    if SpellID == 198793 then
        return true -- Exclude "Vengful Retreat" for all classes
    elseif SpellID == 195072 then
            return true -- Exclude "Felrush" for all classes
    end
    return false
end