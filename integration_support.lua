-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

RuneReader = RuneReader or {}
RuneReader.HealthHistory =  RuneReader.HealthHistory or {}
--#region Move globals to local object (table) for faster execution
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
    [445468] = true, -- Unstable Affliction
}

RuneReader.MovementCastingBuffs = {
    [263725] = true, -- Clearcasting (Arcane)
    [79206] = true, -- Spiritwalker's Grace
    [108839] = true, -- Icy Floes
}


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
