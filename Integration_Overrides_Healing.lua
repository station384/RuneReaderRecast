-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

RuneReader = RuneReader or {}
RuneReader.HealthHistory =  RuneReader.HealthHistory or {}

function RuneReader:GetHealthLostInLast5Seconds()
    local currentHP = UnitHealth("player")
    local maxHP = UnitHealthMax("player")
    if maxHP == 0 then return 0 end

    local oldest = RuneReader.HealthHistory[1]
    if oldest then
        local delta = math.max(0, oldest.hp - currentHP)
        return delta / maxHP -- Returns fraction (e.g., 0.12 = 12%)
    end

    return 0
end


--#region Druid Self Healing Functions
function RuneReader:ShouldCastBearOrRegen()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return nil end

    local frenziedRegenID = 22842      -- Frenzied Regeneration
    local bearFormID = 5487            -- Bear Form
    local bearForm = 1                 -- FORM index for Bear (see below)

    -- Health check
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.60 then return nil end

    -- Has Frenzied Regeneration talent?
    --if not RuneReader:HasTalentBySpellID(frenziedRegenID) then return nil end
    if not IsSpellKnown(frenziedRegenID) then return nil end

    -- Is Frenzied Regeneration ready?
    local regenCD = C_Spell.GetSpellCooldown(frenziedRegenID)
    local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    local regenReady = regenCD and (regenCD.startTime == 0 or regenCD.duration == 0 or (regenCD.startTime + regenCD.duration - GetTime()) <= GCD)
--print("Frenzied Regen CD", regenCD and regenCD.startTime or "No CD")
    if not regenReady then return nil end

    -- Check if player is in Bear Form
    if GetShapeshiftForm() == bearForm then
        return frenziedRegenID
    else
        return bearFormID
    end
end

function RuneReader:ShouldCastRejuvenationIfNeeded()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return nil end

    local rejuvenationID = 774

    -- Health threshold (adjustable if needed)
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.70 then return nil end

    -- Check for existing Rejuvenation aura on player
    for i = 1, 40 do
        local aura = RuneReader.GetPlayerAuraBySpellID(rejuvenationID)
        if not aura then break end
        if aura.spellId == rejuvenationID then
            return nil -- Already has Rejuvenation active
        end
    end

    -- Has Rejuvenation in talent tree?
    --if not RuneReader:HasTalentBySpellID(rejuvenationID) then return nil end
    if not IsSpellKnown(rejuvenationID) then return nil end

    -- Check cooldown (though Rejuvenation usually has no CD, this is for completeness)
    local cd = C_Spell.GetSpellCooldown(rejuvenationID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return rejuvenationID
end

function RuneReader:ShouldCastNaturesVigil()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return nil end

    local spellID = 124974 -- Nature's Vigil
    if not RuneReader:HasTalentBySpellID(spellID) then return nil end

    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if RuneReader:GetHealthLostInLast5Seconds() < 0.10 and (health / maxHealth) > 0.60 then
        return nil
    end
    -- if maxHealth == 0 or (health / maxHealth) > 0.50 then return nil end

    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end
--#endregion

--#region Paladin Self Healing Functions
function RuneReader:ShouldCastWordOfGlory()
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then return nil end

    local wordOfGloryID = 85673
    local specID = GetSpecialization()
    local isRet = specID == 3
    local isProt = specID == 2

    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 then return nil end

    local healthPct = health / maxHealth

    -- Threshold tuning by spec
    local threshold = isRet and 0.40 or (isProt and 0.45) or 0.50
    if healthPct > threshold then return nil end

    -- Already have talent?
--    if not RuneReader:HasTalentBySpellID(wordOfGloryID) then return nil end
    if not IsSpellKnown(wordOfGloryID) then return nil end


    -- Cooldown check
    local cd = C_Spell.GetSpellCooldown(wordOfGloryID)
     --local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    -- Ret or Prot: Check Holy Power
    if isRet or isProt then
        if UnitPower("player", Enum.PowerType.HolyPower) < 3 then
            return nil
        end
    end

    return wordOfGloryID
end

--#endregion

--#region Hunter Pet Self Healing Functions
function RuneReader:ShouldCastRevivePet()
    -- Only apply to hunters
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return nil end

    -- Pet must exist and be dead
    if not UnitExists("pet") or not UnitIsDead("pet") then return nil end

    local revivePetID = 982  -- Retail spell ID for Revive Pet

    -- Check cooldown
    local cd = C_Spell.GetSpellCooldown(revivePetID)
    if not cd or cd.startTime == 0 or cd.duration == 0 then
        return revivePetID  -- Spell is ready
    end
    local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    -- Still on cooldown?
    local remaining = cd.startTime + cd.duration - GetTime()
    if remaining <= 0 then
        return revivePetID
    end

    return nil
end

function RuneReader:ShouldCastMendPet()
    -- Only apply to hunters
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return nil end

    -- Pet must exist and be alive
    if not UnitExists("pet") or UnitIsDead("pet") then return nil end

    -- Pet health must be ≤ 40%
    local health = UnitHealth("pet")
    local maxHealth = UnitHealthMax("pet")
    if maxHealth == 0 or (health / maxHealth) > 0.40 then return nil end

    -- Mend Pet spell info
    local mendPetID = 136  -- Retail spell ID for Mend Pet

    -- Check cooldown
    local cd = RuneReader.GetSpellCooldown(mendPetID)
    if not cd or cd.startTime == 0 or cd.duration == 0 then
        return mendPetID  -- Spell is ready to cast
    end
    --local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    -- Spell is on cooldown
    local remaining = cd.startTime + cd.duration - GetTime()
    if remaining <= 0 then
        return mendPetID
    end

    return nil
end
--#endregion

--#region Hunter Self Healing Functions
function RuneReader:ShouldCastExhilaration()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return nil end

    local exhilarationID = 109304

    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 then return nil end

    local healthPct = health / maxHealth
    if healthPct > 0.50 then return nil end

    -- Check if the talent/spell is known
   -- if not RuneReader:HasTalentBySpellID(exhilarationID) then return nil end
    if not IsSpellKnown(exhilarationID) then return nil end

    -- Check if aura is already active (Exhilaration does not apply a long buff, but include for safety)
    local aura = RuneReader.GetPlayerAuraBySpellID(exhilarationID)
    if aura then return nil end

    -- Cooldown check with GCD buffer
    local cd = C_Spell.GetSpellCooldown(exhilarationID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return exhilarationID
end
--#endregion


--#region Death Knight Self Healing Functions
function RuneReader:ShouldCastDeathStrike()
    local _, class = UnitClass("player")
    if class ~= "DEATHKNIGHT" then return nil end

    local specID = GetSpecialization()
    if specID ~= 1 then return nil end  -- Blood only

    local deathStrikeID = 49998

    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 then return nil end

    -- Trigger if we lost ≥10% HP recently OR are under 60% HP
    if RuneReader:GetHealthLostInLast5Seconds() < 0.10 and (health / maxHealth) > 0.60 then
        return nil
    end

    local cd = C_Spell.GetSpellCooldown(deathStrikeID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    if UnitPower("player", Enum.PowerType.RunicPower) < 35 then
        return nil
    end

    return deathStrikeID
end

function RuneReader:ShouldCastMarrowrend()
    local _, class = UnitClass("player")
    if class ~= "DEATHKNIGHT" then return nil end

    local specID = GetSpecialization()
    if specID ~= 1 then return nil end -- Blood DK

    local marrowrendID = 195182
    local boneShieldID = 195181

    local stacks = 0
    local expiresIn = 0

    local aura = RuneReader.GetPlayerAuraBySpellID(boneShieldID)
    if aura then
        stacks = aura.applications or 0
        if aura.expirationTime and aura.expirationTime > 0 then
            expiresIn = aura.expirationTime - GetTime()
        end
    end

    -- Trigger if stacks are low OR duration is about to expire
    if stacks >= 5 and expiresIn > 5 then return nil end

    -- Require 4+ runes available
    local readyRunes = 0
    for i = 1, 6 do
        local _, _, ready = GetRuneCooldown(i)
        if ready then readyRunes = readyRunes + 1 end
    end
    if readyRunes < 4 then return nil end

    -- Talent check
   -- if not RuneReader:HasTalentBySpellID(marrowrendID) then return nil end
         if not IsSpellKnown(marrowrendID) then return nil end

    -- Cooldown + GCD gate
    local cd = C_Spell.GetSpellCooldown(marrowrendID)
   -- local GCD = RuneReader.GetSpellCooldown(61304).duration
     if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return marrowrendID
end
function RuneReader:ShouldCastRuneTap()
    local _, class = UnitClass("player")
    if class ~= "DEATHKNIGHT" then return nil end

    local specID = GetSpecialization()
    if specID ~= 1 then return nil end -- Blood

    local spellID = 194679 -- Rune Tap
    if not IsSpellKnown(spellID) then return nil end
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.60 then return nil end

    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    --if not cd or (cd.startTime > 0 and (cd.startTime + cd.duration) > 0) then return nil end
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end

--#endregion


--#region Monk Self Healing Functions
function RuneReader:ShouldCastExpelHarm()
    local _, class = UnitClass("player")
    if class ~= "MONK" then return nil end

    local expelHarmID = 322101
    local specID = GetSpecialization()
    local isBrew = specID == 1
    local isWW   = specID == 3

    -- Mistweaver typically won't use Expel Harm unless PvP/talented
    if not (isBrew or isWW) then return nil end

    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 then return nil end

    local healthPct = health / maxHealth
    if healthPct > 0.45 then return nil end

    -- Confirm the spell is available (talented / known)
    if not IsSpellKnown(expelHarmID) then return nil end

    -- Optional: ensure no active absorb/heal aura already on the player (Expel Harm doesn't persist)
    -- You may skip this if Expel Harm has no aura

    -- GCD-aware cooldown check
    local cd = C_Spell.GetSpellCooldown(expelHarmID)
    local GCD = RuneReader.GetSpellCooldown(61304).duration
    --print("Expel Harm CD", cd and cd.startTime or "No CD")
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    -- Optional: Brewmaster chi check (if you want to avoid overcapping)
    -- local chi = UnitPower("player", Enum.PowerType.Chi)
    -- if isBrew and chi >= 5 then return nil end
    --print("Expel Harm CD", cd and cd.startTime or "No CD")
    return expelHarmID
end

function RuneReader:ShouldCastPurifyingBrew()
    local _, class = UnitClass("player")
    if class ~= "MONK" then return nil end

    local specID = GetSpecialization()
    if specID ~= 1 then return nil end -- Brewmaster

    local spellID = 119582 -- Purifying Brew

    local stagger = UnitStagger("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    if (stagger / maxHealth) < 0.30 then return nil end

    -- if not RuneReader:HasTalentBySpellID(spellID) then return nil end
    if not IsSpellKnown(spellID) then return nil end

    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end

function RuneReader:ShouldCastVivifyBrewmaster()
    local _, class = UnitClass("player")
    if class ~= "MONK" then return nil end

    local specID = GetSpecialization()
    if specID ~= 1 then return nil end -- Brewmaster

    local spellID = 116670 -- Vivify

    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.60 then return nil end

   -- if not RuneReader:HasTalentBySpellID(spellID) then return nil end
     if not IsSpellKnown(spellID) then return nil end

    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end

function RuneReader:ShouldCastCelestialBrew()
    local _, class = UnitClass("player")
    if class ~= "MONK" then return nil end

    local specID = GetSpecialization()
    if specID ~= 1 then return nil end -- Brewmaster

    local spellID = 322507 -- Celestial Brew
     if not IsSpellKnown(spellID) then return nil end
    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end

--#endregion

--#region Rogue Self Healing Functions
function RuneReader:ShouldCastCrimsonVial()
    local _, class = UnitClass("player")
    if class ~= "ROGUE" then return nil end

    local crimsonVialID = 185311
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 then return nil end

    local healthPct = health / maxHealth
    if healthPct > 0.60 then return nil end

    -- Must know the spell
    --if not RuneReader:HasTalentBySpellID(crimsonVialID) then return nil end
    if not IsSpellKnown(crimsonVialID) then return nil end

    -- Check if it's already active
    local aura = RuneReader.GetPlayerAuraBySpellID(crimsonVialID)
    if aura then return nil end

    -- GCD-aware cooldown check
    local cd = C_Spell.GetSpellCooldown(crimsonVialID)
   -- local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return crimsonVialID
end
--#endregion

--#region Warrior Self Healing Functions
function RuneReader:ShouldCastImpendingVictory()
    local _, class = UnitClass("player")
    if class ~= "WARRIOR" then return nil end

    local spellID = 202168  -- Impending Victory
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.60 then return nil end

    --if not RuneReader:HasTalentBySpellID(spellID) then return nil end
    if not IsSpellKnown(spellID) then return nil end


    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
     if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end
function RuneReader:ShouldCastShieldBlock()
    local _, class = UnitClass("player")
    if class ~= "WARRIOR" then return nil end

    local specID = GetSpecialization()
    if specID ~= 3 then return nil end -- Protection

    local spellID = 2565 -- Shield Block

    -- Avoid casting if already active
    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    -- Check spell cooldown (Shield Block is 2 charges, but check CD)
    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
       if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end

--#endregion


--#region Shaman Self Healing Functions
function RuneReader:ShouldCastHealingSurge()
    local _, class = UnitClass("player")
    if class ~= "SHAMAN" then return nil end

    local spellID = 8004  -- Healing Surge
    local specID = GetSpecialization()
    if specID ~= 2 then return nil end -- Enhancement only

    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.50 then return nil end

    --if not RuneReader:HasTalentBySpellID(spellID) then return nil end
    if not IsSpellKnown(spellID) then return nil end
    -- Check for Maelstrom Weapon buff with 5+ stacks
    local aura = RuneReader.GetPlayerAuraBySpellID(344179) -- "Maelstrom Weapon"
    if not aura or (aura.applications or 0) < 5 then return nil end

    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end
--#endregion

--This is used to track health changes over time its dirty, and inaccurate but close enuf as blizzard will/has removed the ability to read auras in 12.0.0 (depending on when you read this)
C_Timer.NewTicker(0.5, function()
    local now = GetTime()
    local health = UnitHealth("player")
    table.insert(RuneReader.HealthHistory, { time = now, hp = health })

    -- Keep only the last 5 seconds of data
    for i = #RuneReader.HealthHistory, 1, -1 do
        if now - RuneReader.HealthHistory[i].time > 5 then
            table.remove(RuneReader.HealthHistory, i)
        end
    end
end)