-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

RuneReader = RuneReader or {}


function RuneReader:IsSpellExcluded(SpellID)
    local excludedSpells = {
        -- Demon Hunter
        [198793] = true, -- Vengful Retreat
        [195072] = true, -- Felrush
       
        -- Hunter
        [19801] = true, -- Tranq Shot
        [147362] = true, -- Counter Shot
       
        --Druid
        [8936] = true, -- Regrowth 
        
        -- Evoker
        [358267] = true, -- Hover
        [433874] = true, -- Deep Breath
        [360995] = true, -- Verdant Embrace
        
        -- Rogue
        [1856] = true, -- Vanish

        --Racials to exclude 
        [265221] = true -- FireBlood
    }
    return excludedSpells[SpellID] or false
end


