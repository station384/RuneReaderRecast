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

    local spellID = 22842      -- Frenzied Regeneration
    local bearFormID = 5487            -- Bear Form
    local bearForm = 1                 -- FORM index for Bear (see below)

    -- Health check
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.60 then return nil end

    -- Has Frenzied Regeneration talent?
    --if not RuneReader:HasTalentBySpellID(frenziedRegenID) then return nil end
    if not C_SpellBook.IsSpellKnown (spellID )  then return nil end

    -- Is Frenzied Regeneration ready?
    local regenCD = C_Spell.GetSpellCooldown(spellID)
    local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    local regenReady = regenCD and (regenCD.startTime == 0 or regenCD.duration == 0 or (regenCD.startTime + regenCD.duration - GetTime()) <= GCD)
--print("Frenzied Regen CD", regenCD and regenCD.startTime or "No CD")
    if not regenReady then return nil end

    -- Check if player is in Bear Form
    if GetShapeshiftForm() == bearForm then
        return spellID
    else
        return bearFormID
    end
end

function RuneReader:ShouldCastRejuvenationIfNeeded()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return nil end

    local spellID = 774

    -- Health threshold (adjustable if needed)
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.70 then return nil end

    -- Check for existing Rejuvenation aura on player
   -- for i = 1, 40 do
        local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
      --  if then break end
        if aura and aura.spellId == spellID then
            return nil -- Already has Rejuvenation active
        end
    --end

    -- Has Rejuvenation in talent tree?
    --if not RuneReader:HasTalentBySpellID(rejuvenationID) then return nil end
    if not C_SpellBook.IsSpellKnown (spellID ) then return nil end

    -- Check cooldown (though Rejuvenation usually has no CD, this is for completeness)
    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
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

    local spellID = 85673
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
    if not C_SpellBook.IsSpellKnown (spellID ) then return nil end


    -- Cooldown check
    local cd = C_Spell.GetSpellCooldown(spellID)
     --local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    -- Ret or Prot: Check Holy Power
    if isRet or isProt then
        if UnitPower("player", Enum.PowerType.HolyPower) < 3 then
            return nil
        end
    end

    return spellID
end

--#endregion

--#region Hunter Pet Self Healing Functions


-- =========================
-- Shared config & helpers
-- =========================

local REVIVE_PET_ID = 982
local MEND_PET_ID   = 136
local CALL_PET_IDS  = { 883, 83242, 83243, 83244, 83245 } -- Call Pet 1..5

-- OPTIONAL: if you want MM to require a specific “pet-enabled” talent, set this to that spell ID
local PET_TALENT_ID = nil -- e.g., 123456; leave nil to disable this extra gate

local function IsHunter()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

local function HasTalent(spellID)
    if not spellID then return false end
    return ( C_SpellBook.IsSpellKnown (spellID )) or false
end

local function HasMarksmenPet()
    local UNBREAKABLE_BAND = 1223323 -- Marksmanship “no pet” passive
    return HasTalent(UNBREAKABLE_BAND)
end

local function GetSpellCooldownSafe(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        return C_Spell.GetSpellCooldown(spellID)
    end
    if RuneReader and RuneReader.GetSpellCooldown then
        return RuneReader.GetSpellCooldown(spellID)
    end
    return nil
end

local function SpellReady(spellID)
    local cd = GetSpellCooldownSafe(spellID)
    if not cd then return true end                    -- assume ready if API not available
    if cd.startTime == 0 or cd.duration == 0 then
        return true
    end
    return (cd.startTime + cd.duration - GetTime()) <= 0
end

-- Single place to decide if this player *uses pets*.
-- BM (1) & SV (3) always true. MM (2) only if not Lone Wolf and (optionally) has PET_TALENT_ID.
local function UsesPets()
    if not IsHunter() then return false end
    local specID = GetSpecialization()
    if not specID then return false end

    if specID == 1 or specID == 3 then
        return true
    elseif specID == 2 then
        if HasMarksmenPet() then return true end
        return false
    end
    return false
end

local function GetAvailableCallPetSpell()
    for _, sid in ipairs(CALL_PET_IDS) do
        if HasTalent(sid) and SpellReady(sid) then
            return sid
        end
    end
    return nil
end


function RuneReader:ShouldCallPet()
    if not UsesPets() then return nil end
    if UnitExists("pet") then return nil end
    return GetAvailableCallPetSpell()
end


function RuneReader:ShouldCastRevivePet()
    if not UsesPets() then return nil end
    if  UnitExists("pet") and ( UnitHealth("pet") >= 1) then return nil end
    if  UnitIsDead("pet") == false then return nil end -- Pet is alive, no need to revive

    if SpellReady(REVIVE_PET_ID) then
        return REVIVE_PET_ID
    end
    return nil
end


function RuneReader:ShouldCastMendPet()
    if not UsesPets() then return nil end
    if not UnitExists("pet") or UnitIsDead("pet") then return nil end

    local health    = UnitHealth("pet")
    local maxHealth = UnitHealthMax("pet")
    if maxHealth == 0 then return nil end

    -- Heal if below 80% (tweak as desired)
    if (health / maxHealth) >= 0.80 then return nil end

    if SpellReady(MEND_PET_ID) then
        return MEND_PET_ID
    end
    return nil
end

--#endregion

--#region Hunter Self Healing Functions
function RuneReader:ShouldCastExhilaration()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return nil end

    local spellID = 109304

    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 then return nil end

    local healthPct = health / maxHealth
    if healthPct > 0.50 then return nil end

    -- Check if the talent/spell is known
   -- if not RuneReader:HasTalentBySpellID(exhilarationID) then return nil end
    if not C_SpellBook.IsSpellKnown (spellID ) then return nil end

    -- Check if aura is already active (Exhilaration does not apply a long buff, but include for safety)
    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    -- Cooldown check with GCD buffer
    local cd = C_Spell.GetSpellCooldown(spellID)
    --local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
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

    local spellID = 195182
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
         if not C_SpellBook.IsSpellKnown (spellID ) then return nil end

    -- Cooldown + GCD gate
    local cd = C_Spell.GetSpellCooldown(spellID)
   -- local GCD = RuneReader.GetSpellCooldown(61304).duration
     if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end
function RuneReader:ShouldCastRuneTap()
    local _, class = UnitClass("player")
    if class ~= "DEATHKNIGHT" then return nil end

    local specID = GetSpecialization()
    if specID ~= 1 then return nil end -- Blood

    local spellID = 194679 -- Rune Tap
    if not  C_SpellBook.IsSpellKnown (spellID ) then return nil end
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

    local spellID = 322101
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
    if not  C_SpellBook.IsSpellKnown (spellID ) then return nil end

    -- Optional: ensure no active absorb/heal aura already on the player (Expel Harm doesn't persist)
    -- You may skip this if Expel Harm has no aura

    -- GCD-aware cooldown check
    local cd = C_Spell.GetSpellCooldown(spellID)
    local GCD = RuneReader.GetSpellCooldown(61304).duration
    --print("Expel Harm CD", cd and cd.startTime or "No CD")
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    -- Optional: Brewmaster chi check (if you want to avoid overcapping)
    -- local chi = UnitPower("player", Enum.PowerType.Chi)
    -- if isBrew and chi >= 5 then return nil end
    --print("Expel Harm CD", cd and cd.startTime or "No CD")
    return spellID
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
    if not  C_SpellBook.IsSpellKnown (spellID ) then return nil end

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
     if not C_SpellBook.IsSpellKnown (spellID )  then return nil end

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
    if not C_SpellBook.IsSpellKnown (spellID ) then return nil end
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

    local spellID = 185311
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 then return nil end

    local healthPct = health / maxHealth
    if healthPct > 0.60 then return nil end

    -- Must know the spell
    --if not RuneReader:HasTalentBySpellID(crimsonVialID) then return nil end
    if not C_SpellBook.IsSpellKnown (spellID )  then return nil end

    -- Check if it's already active
    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    -- GCD-aware cooldown check
    local cd = C_Spell.GetSpellCooldown(spellID)
   -- local GCD = RuneReader.GetSpellCooldown(61304).duration
    if not cd or (cd.startTime >= 0 and (cd.startTime + cd.duration) >= GetTime()) then return nil end

    return spellID
end
--#endregion

--#region Warrior Self Healing Functions111111
function RuneReader:ShouldCastImpendingVictory()
    local _, class = UnitClass("player")
    if class ~= "WARRIOR" then return nil end

    local spellID = 202168  -- Impending Victory
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.60 then return nil end

    --if not RuneReader:HasTalentBySpellID(spellID) then return nil end
    if not C_SpellBook.IsSpellKnown (spellID )  then return nil end


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

--#region Evoker Self Healing Functions
function RuneReader:ShouldCastVerdantEmbrace()
    local _, class = UnitClass("player")
    if class ~= "EVOKER" then return nil end
    local spellID = 360995  -- Verdant Embrace
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.60 then return nil end

    if not  C_SpellBook.IsSpellKnown (spellID ) then return nil end
    local cd = C_Spell.GetSpellCooldown(spellID)

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
    if not  C_SpellBook.IsSpellKnown (spellID ) then return nil end
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