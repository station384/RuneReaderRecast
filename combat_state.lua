-- combat_state.lua: Detect hostile targets in player/pet range, factoring in combat and nameplate visibility
-- This is not used currently but put here for later when RuneReaderRecastDB will need to be more proactive in decisions it needs to take
-- Instead of trusting what is suggested.

RuneReader = RuneReader or {}

-- Define your fallback "basic" ranged spells per class for checking range
RuneReader.PlayerRangeSpell = "Attack"
RuneReader.PetRangeSpell = "Attack"

function RuneReader:IsUnitInEffectiveRange(unit)
    -- First try spell range check
    if C_Spell.IsSpellInRang(RuneReader.PlayerRangeSpell, unit) == 1 then return true end
    -- Fallback to 10-yard interaction (trade/interact)
    return CheckInteractDistance(unit, 3)
end

function RuneReader:IsUnitInPetRange(unit)
    if not UnitExists("pet") or UnitIsDead("pet") then return false end
    if C_Spell.IsSpellInRang(RuneReader.PetRangeSpell, unit) == 1 then return true end
    return false
end

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

function RuneReader:IsSingleTarget()
    return self:GetAllHostileTargetsInRange() == 1
end

function RuneReader:IsMultiTarget(threshold)
    threshold = threshold or 3
    return self:GetAllHostileTargetsInRange() >= threshold
end
