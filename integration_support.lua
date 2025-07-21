-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

RuneReader = RuneReader or {}
RuneReader.HealthHistory = {}
--#region Move globals to local for faster execution
RuneReader.GetSpellInfo = C_Spell.GetSpellInfo
RuneReader.GetSpellCooldown = C_Spell.GetSpellCooldown
RuneReader.IsSpellHarmful = C_Spell.IsSpellHarmful
RuneReader.UnitCanAttack = UnitCanAttack
RuneReader.UnitAffectingCombat = UnitAffectingCombat
RuneReader.GetRotationSpells = C_AssistedCombat.GetRotationSpells
RuneReader.GetNextCastSpell = C_AssistedCombat.GetNextCastSpell
RuneReader.GetTime = GetTime
RuneReader.GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
RuneReader.GetUnitSpeed = GetUnitSpeed
RuneReader.UnitInVehicle = UnitInVehicle
RuneReader.UnitClass = UnitClass
RuneReader.GetShapeshiftForm = GetShapeshiftForm
RuneReader.UnitHealth = UnitHealth
RuneReader.UnitHealthMax = UnitHealthMax
RuneReader.GetActionInfo = GetActionInfo
RuneReader.GetBindingKey = GetBindingKey
RuneReader.GetActionButtonBySpellID = ActionButtonUtil.GetActionButtonBySpellID
RuneReader.GetInventoryItemID = GetInventoryItemID
RuneReader.GetInventoryItemTexture = GetInventoryItemTexture
RuneReader.GetInventoryItemCooldown = GetInventoryItemCooldown
RuneReader.GetItemInfo = C_Item.GetItemInfo
RuneReader.GetNumSpellBookSkillLines = C_SpellBook.GetNumSpellBookSkillLines
RuneReader.GetSpellBookSkillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo
RuneReader.GetSpellBookItemName = C_SpellBook.GetSpellBookItemName
RuneReader.GetSpellBookItemType = C_SpellBook.GetSpellBookItemType
RuneReader.GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
--endregion

RuneReader.ChanneledSpells = {
    [5143] = true, -- Arcane Missiles
    [10] = true,   -- Blizzard
    [12051] = true, -- Evocation
    [15407] = true, -- Mind Flay
    [605] = true,  -- Mind Control
    [740] = true,  -- Tranquility
    [205065] = true, -- Void Torrent
    [257044] = true, -- Rapid Fire
    [113656] = true, -- Fists of Fury
    [198590] = true, -- Drain Soul
}
RuneReader.MovementCastingBuffs = {
    [263725] = true, -- Clearcasting (Arcane)
    [79206] = true, -- Spiritwalker's Grace
    [108839] = true, -- Icy Floes
}

-- function RuneReader:HasTalentBySpellID(spellID)
--     local configID = C_ClassTalents.GetActiveConfigID()
--     if not configID then return false end

--     local configInfo = C_Traits.GetConfigInfo(configID)
--     if not configInfo or not configInfo.treeIDs then return false end

--     for _, treeID in ipairs(configInfo.treeIDs) do
--         local nodes = C_Traits.GetTreeNodes(treeID)
--         for _, nodeID in ipairs(nodes) do
--             local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
--             if nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID then
--                 local entryInfo = C_Traits.GetEntryInfo(configID, nodeInfo.activeEntry.entryID)
--                 if entryInfo and entryInfo.definitionID then
--                     local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
--                     if defInfo and defInfo.spellID == spellID then
--                         return true
--                     end
--                 end
--             end
--         end
--     end

--     return false
-- end
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

function RuneReader:HasTalentBySpellID(spellID)
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return false end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs then return false end

    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodes = C_Traits.GetTreeNodes(treeID)
        for _, nodeID in ipairs(nodes) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)

            -- Only check nodes that are selected
            if nodeInfo and nodeInfo.activeRank and nodeInfo.activeRank > 0 then
                local entryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
                if entryID then
                    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                    if entryInfo and entryInfo.definitionID then
                        local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                        if defInfo and defInfo.spellID == spellID then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end



-- This function will be going away in 12.0.0 of wow...    there eliminating the ability to read auras...
function RuneReader:IsMovementAllowedForChanneledSpell(spellID)
    if not RuneReader.ChanneledSpells[spellID] then return true end
    local data = RuneReader.GetPlayerAuraBySpellID(spellID)
    if not data then return false end

    for i = 1, #data do
        if RuneReader.MovementCastingBuffs[data.spellId] then
            return true
        end
    end
    return false
end



function RuneReader:IsSpellIDInChanneling(SpellID)
    if (RuneReader.ChanneledSpells[SpellID]) and RuneReader:IsMovementAllowedForChanneledSpell(SpellID) then
        return false
    elseif (RuneReader.ChanneledSpells[SpellID]) then
        return true
    end
    return false
end

--[[
    Function Name: RuneReader:IsPlayerMoving()

    Description:
        This function checks if the player is currently moving or in a vehicle. It returns true if the player is moving or in a vehicle, and false otherwise.

    Returns:
        - boolean: true if the player is moving or in a vehicle, false otherwise.
--]]
function RuneReader:IsPlayerMoving()
    -- Check if the player is moving
    local currentSpeed, runSpeed, flightSpeed, swimSpeed = RuneReader.GetUnitSpeed("player")
    local isMoving = currentSpeed > 0
    -- Check if the player is in a vehicle
    local isInVehicle = RuneReader.UnitInVehicle("player")
    -- Return true if the player is moving or in a vehicle, false otherwise
    return isMoving or isInVehicle
end

--[[
    Function Name: RuneReader:getPlayerClass()

    Description:
        This function retrieves the player's class information, including the localized class name, English class name, and class ID. 
    Returns:
    1 =	Warrior	WARRIOR	
    2 =	Paladin	PALADIN	
    3 =	Hunter	HUNTER	
    4 =	Rogue	ROGUE	
    5 =	Priest	PRIEST	
    6 =	Death Knight	DEATHKNIGHT	Added in 3.0.2
    7 =	Shaman	SHAMAN	
    8 =	Mage	MAGE	
    9 =	Warlock	WARLOCK	
    10 =	Monk	MONK	Added in 5.0.4
    11 =	Druid	DRUID	
    12 =	Demon Hunter	DEMONHUNTER	Added in 7.0.3
    13 =	Evoker	EVOKER	Added in 10.0.0
--]]
function RuneReader:getPlayerClass()
  -- Get the player's class information
  local localizedClassName, englishClassName, classID = RuneReader.UnitClass("player")
  -- Return the localized class name
  return classID
end

--[[
    Function Name: RuneReader:GetPlayerForm()

    Description:
        This function retrieves the player's current shapeshift form. It returns the form ID if the player is in a shapeshift form, or 0 if not.

    Returns:
        - number: The ID of the player's current shapeshift form, or 0 if not in a shapeshift form.

    Note: The form IDs correspond to specific forms for different classes as follows:
All classes
  0. humanoid form
  Druid
    1 = Bear Form
    2 = Cat Form
    3 = Travel Form / Aquatic Form / Flight Form (all 3 location-dependent versions of Travel Form count as Form 3)
    4 = The first known of: Moonkin Form, Treant Form, Stag Form (in order)
    5 = The second known of: Moonkin Form, Treant Form, Stag Form (in order)
    6 = The third known of: Moonkin Form, Treant Form, Stag Form (in order)
    Note: The last 3 are ordered. For example, if you know Stag Form only, it is form 4. If you know both Treant and Stag, Treant is 4 and Stag is 5. If you know all 3, Moonkin is 4, Treant 5, and Stag 6.
Priest
    1 = Shadowform
Rogue
    1 = Stealth
    2 = Vanish / Shadow Dance (for Subtlety rogues, both Vanish and Shadow Dance return as Form 1)
Shaman
    1 = Ghost Wolf
Warrior 
    1 = Battle Stance
    2 = Defensive Stance
    3 = Beserker Stance
Hunter  
    1 = Aspect of the Hawk
--]]
function RuneReader:GetPlayerForm()
    -- Get the player's current shapeshift form
    local form = RuneReader.GetShapeshiftForm()
    -- If the player is in a shapeshift form, return the form ID
    if form then
        return form
    end
    -- If not in a shapeshift form, return 0
    return 0
end

function RuneReader:GetPlayerHealthPct()
    -- Get the player's current health and maximum health
    local currentHealth = RuneReader.UnitHealth("player")
    local maxHealth = RuneReader.UnitHealthMax("player")
    -- Calculate and return the player's health percentage
    return (currentHealth / maxHealth) * 100    
end


function RuneReader:GetNextInstantCastSpell()
    --Bring the functions local for execution.  improves speed. (LUA thing)
    local spells = RuneReader.GetRotationSpells()
    for index, value in ipairs(spells) do
        local spellInfo = RuneReader.GetSpellInfo(value)
        local sCurrentSpellCooldown = RuneReader.GetSpellCooldown(value)
        if sCurrentSpellCooldown and sCurrentSpellCooldown.duration == 0 then
            if spellInfo and (spellInfo.castTime == 0 or RuneReader:IsSpellIDInChanneling(value)) and RuneReader.IsSpellHarmful(value) then
                return value
            end
        end
    end
end

function RuneReader:IsSpellExcluded(SpellID)
    if SpellID == 198793 then
        return true -- Exclude "Vengful Retreat" for all classes
    elseif SpellID == 195072 then
            return true -- Exclude "Felrush" for all classes
    end
    return false
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
    if maxHealth == 0 or (health / maxHealth) > 0.70 then return nil end

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

function RuneReader:ShouldCastIronfur()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return nil end

    local specID = GetSpecialization()
    if specID ~= 3 then return nil end -- Guardian

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

function RuneReader:ShouldCastNaturesVigil()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return nil end

    local spellID = 124974 -- Nature's Vigil
    if not RuneReader:HasTalentBySpellID(spellID) then return nil end

    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.50 then return nil end

    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

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

-- function RuneReader:ShouldCastMarrowrend()
--     local _, class = UnitClass("player")
--     if class ~= "DEATHKNIGHT" then return nil end

--     local specID = GetSpecialization()
--     if specID ~= 1 then return nil end -- Blood spec

--     local spellID = 195182 -- Marrowrend
--     local aura = RuneReader.GetPlayerAuraBySpellID(195181) -- Bone Shield

--     local stacks = aura and aura.applications or 0
--     if stacks >= 5 then return nil end

--     -- Count runes ready
--     local readyRunes = 0
--     for i = 1, 6 do
--         local start, duration, runeReady = GetRuneCooldown(i)
--         if runeReady then
--             readyRunes = readyRunes + 1
--         end
--     end
--     if readyRunes < 4 then return nil end

--     if not RuneReader:HasTalentBySpellID(spellID) then return nil end

--     local cd = C_Spell.GetSpellCooldown(spellID)
--     local GCD = RuneReader.GetSpellCooldown(61304).duration
--     if cd and (cd.startTime > 0 and (cd.startTime + cd.duration) > GCD) then return nil end

--     return spellID
-- end
--#endregion

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

    local shieldID = nil
    if specID == 1 then       -- Arcane
        shieldID = prismaticBarrierID
    elseif specID == 2 then   -- Fire
        shieldID = blazingBarrierID
    elseif specID == 3 then   -- Frost
        shieldID = iceBarrierID
    else
        return nil -- Unknown spec
    end
     if not IsSpellKnown(shieldID) then return nil end
    -- Barrier: trigger at 50% health
    if healthPct <= 0.70  then
        local aura = RuneReader.GetPlayerAuraBySpellID(shieldID)
        if not aura then
            local cd = C_Spell.GetSpellCooldown(shieldID)
            --local GCD = RuneReader.GetSpellCooldown(61304).duration
            --print("Shield CD", cd and cd.startTime or "No CD")
            if cd and (cd.startTime <= 0 and (cd.startTime + cd.duration) <= GetTime()) then
                return shieldID
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
--#region Priest Self Healing Functions
function RuneReader:ShouldCastPowerWordShield()
    local _, class = UnitClass("player")
    if class ~= "PRIEST" then return nil end

    local spellID = 17  -- Power Word: Shield
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.50 then return nil end

    --if not RuneReader:HasTalentBySpellID(spellID) then return nil end
    if not IsSpellKnown(spellID) then return nil end

    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

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
--#region Evoker Self Healing Functions
function RuneReader:ShouldCastObsidianScales()
    local _, class = UnitClass("player")
    if class ~= "EVOKER" then return nil end

    local spellID = 363916  -- Obsidian Scales
    local health = UnitHealth("player")
    local maxHealth = UnitHealthMax("player")
    if maxHealth == 0 or (health / maxHealth) > 0.50 then return nil end

    --if not RuneReader:HasTalentBySpellID(spellID) then return nil end
    if not IsSpellKnown(spellID) then return nil end

    local aura = RuneReader.GetPlayerAuraBySpellID(spellID)
    if aura then return nil end

    -- Obsidian Scales has 2 charges — ensure at least one is usable
    local charges = C_Spell.GetSpellCharges(spellID)
    if not charges or charges.currentCharges < 1 then return nil end

    return spellID
end
--#endregion


function RuneReader:GetUpdatedValues()
    local fullResult = ""
    if Hekili and (RuneReaderRecastDBPerChar.HelperSource == 0) then
        fullResult = RuneReader:Hekili_UpdateValues(1) --Standard code39 for now.....
        --  print("from Hekili", fullResult)
        return fullResult
    elseif ConRO and (RuneReaderRecastDBPerChar.HelperSource == 2) then
        fullResult = RuneReader:ConRO_UpdateValues(1) --Standard code39 for now.....
        -- print("from ConRo", fullResult)
        return fullResult
    else
        -- Fallback to AssistedCombat as it should always be available. if prior arnt selected or not available
        fullResult = RuneReader:AssistedCombat_UpdateValues(1)
        --   print("from Combat Assist", fullResult)
    end

    return fullResult
end

function RuneReader:GetActionBindingKey(page, slot, slotIndex)
    local actionType, id = RuneReader.GetActionInfo(slotIndex)
    if actionType == "spell" and id then
        return RuneReader:GetHotkeyForSpell(id)
    end

    if page <= NUM_ACTIONBAR_PAGES then
        return RuneReader.GetBindingKey("ACTIONBUTTON" .. slot)
    else
        local barIndex = page - NUM_ACTIONBAR_PAGES
        return RuneReader.GetBindingKey("MULTIACTIONBAR" .. barIndex .. "BUTTON" .. slot)
    end
end

--[[
    Function Name: RuneReader:GetHotkeyForSpell(spellID)

    Description:
        This function retrieves the hotkey associated with a given spell ID for use in assisted combat integration. It checks if there is an action button linked to that specific spell and then extracts its visible, non-empty text representation as the key.

    Parameters:
        - spellID (number): The unique identifier of the desired spell whose corresponding hotkey needs to be retrieved.
    
    Returns: 
        A string representing the uppercase version of the extracted hotkey without any hyphens. If no valid button is found or if there are issues with visibility, it returns an empty string.

    Usage Example:
        local hotkey = RuneReader:GetHotkeyForSpell(12345)
]]
function RuneReader:GetHotkeyForSpell(spellID)
    local button = RuneReader.GetActionButtonBySpellID(spellID)

    if button then --and button:IsVisible() and button.HotKey and button.HotKey:IsVisible() then
        if button.HotKey then
            local keyText = button.HotKey:GetText()
            if not keyText then keyText = "" end
            if keyText and keyText == RANGE_INDICATOR  then keyText = "" end
            if keyText and keyText ~= "" then
                return keyText:gsub("-", ""):upper()
            end
        end
    end
    return ""
end

-- Additional Item Mapping in Spellbook Map
function RuneReader:BuildAllSpellbookSpellMap()
    RuneReader.SpellbookSpellInfo = RuneReader.SpellbookSpellInfo or {}
    RuneReader.SpellbookSpellInfoByName = RuneReader.SpellbookSpellInfoByName or {}
    -- print ("Building Spellbook Spell Map...")
    -- Add equipped items to SpellbookSpellInfo
    for slotID = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local itemID = RuneReader.GetInventoryItemID("player", slotID)
        if itemID then
            local itemIcon = RuneReader.GetInventoryItemTexture("player", slotID)
            local startTime, duration = RuneReader.GetInventoryItemCooldown("player", slotID)

            RuneReader.SpellbookSpellInfo[-slotID] = {
                name = RuneReader.GetItemInfo(itemID) or ("Item " .. slotID),
                cooldown = duration or 0,
                castTime = 0,
                startTime = startTime or 0,
                hotkey = "(Equipped Slot " .. slotID .. ")",
                icon = itemIcon
            }
        end
    end

    -- Add spellbook spells using modern Retail API
    for i = 1, RuneReader.GetNumSpellBookSkillLines() do
        local skillLineInfo = RuneReader.GetSpellBookSkillLineInfo(i)
        if skillLineInfo then
            local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
            for j = offset + 1, offset + numSlots do
                local name, subName = RuneReader.GetSpellBookItemName(j, Enum.SpellBookSpellBank.Player)
        
                local itemType, actionId, spellID = RuneReader.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player)

                if itemType == Enum.SpellBookItemType.Flyout and actionId then
                    local flyoutID = actionId
                    local _, _, numSlots, isKnown = GetFlyoutInfo(flyoutID)

                    if isKnown and numSlots and numSlots > 0 then
                        for slot = 1, numSlots do
                            local spellID, overrideSpellID, isKnownSlot, spellName = GetFlyoutSlotInfo(flyoutID, slot)
                            spellID = overrideSpellID or spellID
                            if spellID and isKnownSlot then
                                local sSpellInfo = RuneReader.GetSpellInfo(spellID)
                                local sSpellCoolDown = RuneReader.GetSpellCooldown(spellID)
                                local hotkey = RuneReader:GetHotkeyForSpell(spellID)

                                if sSpellInfo and sSpellInfo.name and hotkey and hotkey ~= "" then
                                    RuneReader.SpellbookSpellInfoByName[sSpellInfo.name] = {
                                        name = sSpellInfo.name,
                                        cooldown = sSpellCoolDown and sSpellCoolDown.duration or 0,
                                        castTime = (sSpellInfo.castTime or 0) / 1000,
                                        startTime = sSpellCoolDown and sSpellCoolDown.startTime or 0,
                                        hotkey = hotkey,
                                        spellID = spellID
                                    }
                                end

                                if hotkey and hotkey ~= "" then
                                    RuneReader.SpellbookSpellInfo[spellID] = {
                                        name = sSpellInfo and sSpellInfo.name or spellName or ("Flyout Spell " .. slot),
                                        cooldown = sSpellCoolDown and sSpellCoolDown.duration or 0,
                                        castTime = (sSpellInfo.castTime or 0) / 1000,
                                        startTime = sSpellCoolDown and sSpellCoolDown.startTime or 0,
                                        hotkey = hotkey,
                                        spellID = spellID
                                    }
                                end
                            end
                        end
                    end
                end













                
 
                spellID = spellID or actionId
                if spellID then
                    local sSpellInfo = RuneReader.GetSpellInfo(spellID)
                    local sSpellCoolDown = RuneReader.GetSpellCooldown(spellID)
                    local hotkey = RuneReader:GetHotkeyForSpell(spellID)
                    if (sSpellInfo and sSpellInfo.name and hotkey and hotkey ~= "") then
                        RuneReader.SpellbookSpellInfoByName[sSpellInfo.name] =
                        {
                            name      = (sSpellInfo and sSpellInfo.name) or "",
                            cooldown  = (sSpellCoolDown and sSpellCoolDown.duration) or 0,
                            castTime  = (sSpellInfo and sSpellInfo.castTime / 1000) or 0,
                            startTime = (sSpellCoolDown and sSpellCoolDown.startTime) or 0,
                            hotkey    = hotkey,
                            spellID   = (sSpellInfo and sSpellInfo.name),
                        }
                    end
                    if (hotkey and hotkey ~= "") then
                        RuneReader.SpellbookSpellInfo[spellID] = {
                            name = (sSpellInfo and sSpellInfo.name or name) or "",
                            cooldown = (sSpellCoolDown and sSpellCoolDown.duration) or 0,
                            castTime = (sSpellInfo and sSpellInfo.castTime / 1000) or 0,
                            startTime = (sSpellCoolDown and sSpellCoolDown.startTime) or 0,
                            hotkey = hotkey,
                            spellID = spellID
                        }
                    end
                end
            end
        end
    end
end


if not RuneReader.ActionBarSpellMapUpdater then
    RuneReader.ActionBarSpellMapUpdater = CreateFrame("Frame")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("PLAYER_ENTERING_WORLD")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("SPELLS_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
    RuneReader.ActionBarSpellMapUpdater:SetScript("OnEvent", function()
        RuneReader:BuildAllSpellbookSpellMap()
    end)
end
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