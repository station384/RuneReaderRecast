-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

RuneReader = RuneReader or {}



--#region Mage Defensive Functions
function RuneReader:ShouldCastMageDefensive()
    local _, class = UnitClass("player")
    if class ~= "MAGE" then return nil end

    local specID = GetSpecialization()
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 then return nil end

    local healthPct = health / maxHealth

    local coldSnapID = 11958
    local iceBarrierID = 11426
    local blazingBarrierID = 235313
    local prismaticBarrierID = 235450

    local spellID = nil
    if specID == 1 then       -- Arcane
        spellID = prismaticBarrierID
    elseif specID == 2 then   -- Fire
        spellID = blazingBarrierID
    elseif specID == 3 then   -- Frost
        spellID = iceBarrierID
    else
        return nil -- Unknown spec
    end
     if not  C_SpellBook.IsSpellKnown (spellID )  then return nil end
    -- Barrier: trigger at 50% health
    if healthPct <= 0.70  then
        local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
        if not aura then
            local cd = C_Spell.GetSpellCooldown(spellID)
            --local GCD = RuneReader.GetSpellCooldown(61304).duration
            --print("Shield CD", cd and cd.startTime or "No CD")
            if cd and (cd.startTime <= 0 and (cd.startTime + cd.duration) <= GetTime()) then
                return spellID
            end
        end
    end

    -- Cold Snap: trigger at 30% health, Frost only
    if specID == 3 and healthPct <= 0.30 and RuneReader:HasTalentBySpellID(coldSnapID) then
        local cd = C_Spell.GetSpellCooldown(coldSnapID)
        --local GCD = RuneReader.GetSpellCooldown(61304).duration
            if cd and (cd.startTime <= 0 and (cd.startTime + cd.duration) <= GetTime()) then
            return coldSnapID
        end
    end

    return nil
end

--#endregion

--#region Druid Defensive Functions
function RuneReader:ShouldCastIronfur()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return nil end

    local specID = GetSpecialization()
    if specID ~= 3 then return nil end -- Guardian

    -- Only suggest if already in Bear Form (form index 1)
    if GetShapeshiftForm() ~= 1 then
        return nil
    end


    local spellID = 192081 -- Ironfur



    local rage = UnitPower("player", Enum.PowerType.Rage)
    if rage < 60 then return nil end

    -- Count current stacks of Ironfur aura (same spell ID)
    local stacks = 0
    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura and aura.applications then
        stacks = aura.applications
    end

    if stacks >= 3 then return nil end

    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end

function RuneReader:ShouldCastBarkskin()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return nil end

    local spellID = 22812 -- Barkskin

    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.60 then return nil end

    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end

--#endregion

--#region Priest Defensive Functions
function RuneReader:ShouldCastPowerWordShield()
    local _, class = UnitClass("player")
    if class ~= "PRIEST" then return nil end

    local spellID = 17  -- Power Word: Shield
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.50 then return nil end

    --if not RuneReader:HasTalentBySpellID(spellID) then return nil end
    if not  C_SpellBook.IsSpellKnown (spellID )  then return nil end

    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end
--#endregion

--#region Evoker Defensive Functions
function RuneReader:ShouldCastObsidianScales()
    local _, class = UnitClass("player")
    if class ~= "EVOKER" then return nil end

    local spellID = 363916  -- Obsidian Scales
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.50 then return nil end

    --if not RuneReader:HasTalentBySpellID(spellID) then return nil end
    if not  C_SpellBook.IsSpellKnown (spellID )  then return nil end

    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    -- Obsidian Scales has 2 charges — ensure at least one is usable
    local charges = C_Spell.GetSpellCharges(spellID)
    if not charges or charges.currentCharges < 1 then return nil end

    return spellID
end
--#endregion
