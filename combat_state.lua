-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

-- combat_state.lua: Detect hostile targets in player/pet range, factoring in combat and nameplate visibility
-- This is not used currently but put here for later when RuneReaderRecastDB will need to be more proactive in decisions it needs to take
-- Instead of trusting what is suggested.

RuneReader = RuneReader or {}

-- Define your fallback "basic" ranged spells per class for checking range
RuneReader.PlayerRangeSpell = "Attack"
RuneReader.PetRangeSpell = "Attack"

--[[
This function checks if an enemy unit is within RuneReader's effective range for combat.

Parameters:
- `unit`: The target unit to check against RuneReader's effectiveness criteria.
Returns: A boolean value indicating whether the specified 'unit' falls under any of RuneReader's interaction ranges (either spell-based or proximity).

The method first attempts a spell-range based evaluation using C_Spell.IsSpellInRange, which checks if there's an active Spell that can reach and affect the target unit. If this check returns true for at least one available range-spell combination ('1' signifies success), it implies RuneReader's spells are effective against 'unit', thus returning `true`.

If no spell-based interaction is detected (i.e., C_Spell.IsSpellInRange does not return a successful result, which would be anything other than 1 or nil for an empty table), the function then resorts to checking if there's any proximity-interaction possible within RuneReader's defined 'interact distance' of three yards. This fallback check is performed by calling CheckInteractDistance with `unit` and interaction radius as arguments.

The outcome from this secondary range-check determines whether a non-spell-based, close-range engagement possibility exists ('true') or not ('false'). If neither spell nor proximity checks are successful (i.e., both C_Spell.IsSpellInRange returns nil for all spells in RuneReader's active ranges and CheckInteractDistance yields 'false'), the function concludes that no effective interaction is possible with respect to this particular unit.
]]
function RuneReader:IsUnitInEffectiveRange(unit)
    -- First try spell range check
    if C_Spell.IsSpellInRange(RuneReader.PlayerRangeSpell, unit) == 1 then return true end
    -- Fallback to 10-yard interaction (trade/interact)
    return CheckInteractDistance(unit, 3)
end


--[[
This function checks if there is an active pet for RuneReader and whether it can cast its range spell on another unit.

Parameters:
- `unit`: The target unit to check the distance against RuneReader's pet (if any).

Returns: 
- true, if a valid pet exists that has enough mana left or cooldowns cleared allowing casting of PetRangeSpell.
- false otherwise. If there is no active pet for RuneReader (`UnitExists("pet")` returns `false`) it will always return false.

Note:
The function relies on the C_Spell.IsSpellInRange method to determine if a spell can be cast at range against another unit, which implies that this check may also depend upon other factors such as mana availability and cooldowns.
]]
function RuneReader:IsUnitInPetRange(unit)
    if not UnitExists("pet") or UnitIsDead("pet") then return false end
    if C_Spell.IsSpellInRange(RuneReader.PetRangeSpell, unit) == 1 then return true end
    return false
end

--[[
    File: /d:/Games/Blizzard/World of Warcraft/_retail_/Interface/AddOns/RuneReaderRecast/combat_state.lua

    Function Name:
        RuneReader:GetAllHostileTargetsInRange()

    Description:
        This function retrieves all hostile targets within a specified range from the current player's perspective. It is part of an add-on for World of Warcraft that enhances combat state information by providing additional details about nearby enemies.

    Parameters: None
    Return Type: Table (List of Hostile Targets)
]]
function RuneReader:GetAllHostileTargetsInRange()
    local count = 0
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitAffectingCombat(unit) then
            local valid = false
            if UnitCanAttack("player", unit) and RuneReader:IsUnitInEffectiveRange(unit) then
                valid = true
            elseif UnitCanAttack("pet", unit) and RuneReader:IsUnitInPetRange(unit) then
                valid = true
            end
            if valid then
                count = count + 1
            end
        end
    end
    return count
end

--[[
This function checks if there is exactly one hostile target within RuneReader's range.
It returns true when there's precisely one enemy (hostile) character that can be targeted,
indicating it's single-target combat.

Note: This method relies on the GetAllHostileTargetsInRange() which should return a table
with all enemies in ranged attack. The function assumes this behavior is consistent with RuneReader's design.
]]
function RuneReader:IsSingleTarget()
    return self:GetAllHostileTargetsInRange() == 1
end

--[[
This function determines if there are enough hostile targets within range to qualify for multi-targeting.

Parameters:
    - `threshold`: The minimum number of hostiles required inside the target's attack radius (default is set to 3).

Returns: A boolean value indicating whether or not a sufficient amount of enemies have been detected.
]]
function RuneReader:IsMultiTarget(threshold)
    threshold = threshold or 3
    return self:GetAllHostileTargetsInRange() >= threshold
end
