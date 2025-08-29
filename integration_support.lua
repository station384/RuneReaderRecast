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

-- Known channel Spells
RuneReader.ChanneledSpells = {
    [5143] = true, -- Arcane Missiles
    [10] = true,   -- Blizzard
    [12051] = true, -- Evocation
    [15407] = true, -- Mind Flay
    [605] = true,  -- Mind Control
    [740] = true,  -- Tranquility
    [205065] = true, -- Void Torrent
    [257044] = true, -- Rapid Fire
    [198590] = true, -- Drain Soul
    [445468] = true, -- Unstable Affliction
    --Evoker
    [356995] = true,  -- Disintegrate
    [357208] = true, -- Fire Breath
    [359072] = true, -- Eternity Surge
    --Druid
    [190984] = true, --Wrath
    [194153] = true, --Starfire
    [8936] = true, -- Regrowth
    [274281] = true, -- Moon
    --Hunter
    [982] = true -- Revive Pet
    
}

-- Known Auras that allow casting during movement
RuneReader.MovementCastingBuffs = {
    [263725] = true, -- Clearcasting (Arcane)
    [79206] = true, -- Spiritwalker's Grace
    [108839] = true, -- Icy Floes
    [358267] = true, -- Hover
}




-- Due to the way wow handles cooldowns it will not show the cooldown of a spell till it has fired.
-- But it does report the max cooldown in the tooltip.  so we are going to try and create a defered process that updates out spell cooldowns
-- with the one found in the tooltip.
-- Prefer C_TooltipInfo (doesn't require showing a GameTooltip)
RuneReader.CooldownFromTooltipCache = RuneReader.CooldownFromTooltipCache or {}
RuneReader._tipQueue, RuneReader._tipQueued = {}, {}

-- Extract readable text from a C_TooltipInfo line without SurfaceArgs.
local function RR_ExtractLineText(line)
    if not line then return nil end
    local resultText = ""
    -- Some builds already expose line.leftText; grab it if present.
    if type(line.leftText) == "string" and line.leftText ~= "" then
        resultText = line.leftText
    end

    -- Some expose rightText too.
    if type(line.rightText) == "string" and line.rightText ~= "" then
        resultText = resultText .. " " .. line.rightText
    end

    if resultText ~= "" then
        return resultText
    end

    -- Otherwise dig through the raw args for a stringVal.
    if type(line.args) == "table" then
        for _, a in ipairs(line.args) do
            if a and type(a.stringVal) == "string" and a.stringVal ~= "" then
             
                return a.stringVal
            end
        end
    end
    return nil
end

-- Robust, version-safe cooldown reader (no TooltipUtil.SurfaceArgs).
local function RR_TooltipCooldownSync(spellID)
    if not spellID then return 0 end
    local best = 0

    -- 1) Modern tooltip API path (no SurfaceArgs required).
    if C_TooltipInfo and C_TooltipInfo.GetSpellByID then
        local data = C_TooltipInfo.GetSpellByID(spellID)
        if data and type(data.lines) == "table" then
            for _, line in ipairs(data.lines) do
                local t = RR_ExtractLineText(line)
                if t and t:find("ooldown") then -- match "Cooldown"/"cooldown" etc.
                    local s = t:lower()
                    local h = tonumber(s:match("(%d+)%s*hour")) or 0
                    local m = tonumber(s:match("(%d+)%s*min"))  or 0
                    local sec = tonumber(s:match("(%d+)%s*sec")) or 0
                    best = math.max(best, h * 3600 + m * 60 + sec)
                end
            end
        end
    end
    if best > 0 then
           --         print("Tooltip CD read (API):", spellID, best)
        return best
    end

    -- -- 2) Fallback: hidden GameTooltip scan (works everywhere).
    -- if not RuneReader._coolTip then
    --     RuneReader._coolTip = CreateFrame("GameTooltip", "RuneReader_ColdScanTip", UIParent, "GameTooltipTemplate")
    --     RuneReader._coolTip:SetOwner(UIParent, "ANCHOR_NONE")
    -- end
    -- local tip = RuneReader._coolTip
    -- tip:ClearLines()
    -- tip:SetSpellByID(spellID)

    -- for i = 1, tip:NumLines() do
    --     local fs = _G["RuneReader_ColdScanTipTextLeft"..i]
    --     if fs then
    --         local t = fs:GetText()
    --         if t and t:find("ooldown") then
    --             local s = t:lower()
    --             local h = tonumber(s:match("(%d+)%s*hour")) or 0
    --             local m = tonumber(s:match("(%d+)%s*min"))  or 0
    --             local sec = tonumber(s:match("(%d+)%s*sec")) or 0
    --             best = math.max(best, h * 3600 + m * 60 + sec)
    --         end
    --     end
    -- end

    return best
end

RuneReader._tipQueue = RuneReader._tipQueue or {}           -- array of spellIDs
RuneReader._tipState = RuneReader._tipState or {}           -- [spellID] = { queued=true, tries=0, next=0 }
RuneReader._tipTicker = RuneReader._tipTicker or nil

local TICK_INTERVAL = 0.10   -- seconds between passes
local BUDGET        = 10     -- spells per tick
local MAX_TRIES     = 12     -- ~ progressively up to ~ a few seconds
local MAX_BACKOFF   = 8.0    -- seconds

local function RR_Schedule(id, delay)
    local st = RuneReader._tipState[id]
    if not st then
        st = { queued = true, tries = 0, next = 0 }
        RuneReader._tipState[id] = st
        table.insert(RuneReader._tipQueue, id)
    end
    st.next = GetTime() + (delay or 0)
end

local function RR_StartTipRunner()
    if RuneReader._tipTicker then return end
    RuneReader._tipTicker = C_Timer.NewTicker(TICK_INTERVAL, function()
        local now = GetTime()
        local processed = 0
        local q = RuneReader._tipQueue
        local st = RuneReader._tipState

        -- rotate through the queue, but only process 'due' items
        local n = #q
        if n == 0 then
            -- stop runner when empty
            RuneReader._tipTicker:Cancel()
            RuneReader._tipTicker = nil
            return
        end

        local i = 1
        while i <= n and processed < BUDGET do
            local id = q[i]
            local s = st[id]
            if not s then
                table.remove(q, i)
                n = n - 1
            elseif s.next <= now then
                -- due: attempt a scan
                table.remove(q, i)
                n = n - 1

                if RuneReader.CooldownFromTooltipCache[id] == nil then
                    local tipSec = RR_TooltipCooldownSync(id)  -- your reader; returns 0 if not ready
                    if tipSec and tipSec > 0 then
                        RuneReader.CooldownFromTooltipCache[id] = tipSec
                        -- Update maps if present
                        local info = RuneReader.SpellbookSpellInfo and RuneReader.SpellbookSpellInfo[id]
                        if info then info.cooldown = tipSec end
                        if RuneReader.SpellbookSpellInfoByName and info and info.name then
                            local byName = RuneReader.SpellbookSpellInfoByName[info.name]
                            if byName then byName.cooldown = tipSec end
                        end
                        st[id] = nil -- done
                    else
                        -- backoff and try again later
                        s.tries = (s.tries or 0) + 1
                        if s.tries <= MAX_TRIES then
                            local backoff = math.min(0.25 * (2 ^ (s.tries - 1)), MAX_BACKOFF)
                            RR_Schedule(id, backoff)
                        else
                            -- give up for this session; keep whatever provisional cooldown we had
                            st[id] = nil
                        end
                    end
                else
                    st[id] = nil -- already cached elsewhere; remove
                end

                processed = processed + 1
            else
                -- not due yet: rotate to end and continue
                table.remove(q, i)
                q[#q + 1] = id
                -- i not incremented; same position, new id
            end
        end

        -- stop runner if queue drained
        if #q == 0 then
            RuneReader._tipTicker:Cancel()
            RuneReader._tipTicker = nil
        end
    end)
end

-- Public: queue a spellID for tooltip cooldown discovery (idempotent)
local function RR_QueueTooltipCooldown(spellID)
    if not spellID then return end
    if RuneReader.CooldownFromTooltipCache[spellID] ~= nil then return end
    if RuneReader._tipState[spellID] then return end
    RR_Schedule(spellID, 0)
    RR_StartTipRunner()
end

-- Call this when talents/spells change (before rebuilding the map)
function RuneReader:InvalidateTooltipCooldowns()
    wipe(self.CooldownFromTooltipCache)
    -- stop any active runner & clear pending work
    if self._tipTicker then self._tipTicker:Cancel(); self._tipTicker = nil end
    wipe(self._tipQueue)
    wipe(self._tipState)
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


function RuneReader:IsSpellIDInChanneling(SpellID)
    if RuneReader.ChanneledSpells[SpellID] and RuneReader:IsMovementAllowedForChanneledSpell(SpellID) then
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


-- This kinda works.    Not perfect but should catch most cases.
function RuneReader:GetNextInstantCastSpell()
    --Bring the functions local for execution.  improves speed. (LUA thing)
    local spells = RuneReader.GetRotationSpells()
    for index, value in ipairs(spells) do
   --     print("GetNextInstantCastSpell: Checking spellID=", value)
        local spellInfo = C_Spell.GetSpellInfo(value)
        local sCurrentSpellCooldown = RuneReader.GetSpellCooldown(value)
        if RuneReader.SpellbookSpellInfo[value] ~= nil then
            if  RuneReader.SpellbookSpellInfo[value].enabled == true  then
                -- Calling IsMajorCooldown here is kinda breaking the abstraction layer but we need to filter out major cooldowns here.
                -- Have to fix this on a refactor.
                if (C_Spell.IsSpellHarmful(value) == true) then
                    if (C_Spell.IsSpellUsable(value) == true) then
                       -- print ("CastTime", spellInfo.castTime, "IsChanneling", RuneReader:IsSpellIDInChanneling(value), "Duration", sCurrentSpellCooldown.duration, "SpellID", value, "name", spellInfo.name)
                        if  (spellInfo.castTime == 0 and  RuneReader:IsSpellIDInChanneling(value) == false)  then
                            if (sCurrentSpellCooldown.duration == 0) then
                                if RuneReaderRecastDBPerChar.UseGlobalCooldowns == true then
                                    return value
                                elseif RuneReader:IsMajorCooldown(value) == false then
                                    return value
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return 0
end




function RuneReader:GetUpdatedValues()
    local fullResult = ""
    local SpellID = 0
    local hotkey = ""
    if Hekili and Hekili.baseName and (RuneReaderRecastDBPerChar.HelperSource == 0) then
         fullResult, SpellID, hotkey = RuneReader:Hekili_UpdateValues(1) --Standard code39 for now.....
    elseif ConRO and ConRO.Version and (RuneReaderRecastDBPerChar.HelperSource == 2) then
         fullResult, SpellID, hotkey = RuneReader:ConRO_UpdateValues(1) --Standard code39 for now.....
    elseif MaxDps and MaxDps.db and (RuneReaderRecastDBPerChar.HelperSource == 3) then
         fullResult, SpellID, hotkey = RuneReader:MaxDps_UpdateValues(1) --Standard code39 for now.....
    else
        -- Fallback to AssistedCombat as it should always be available. if prior arnt selected or not available
        fullResult, SpellID, hotkey = RuneReader:AssistedCombat_UpdateValues(1)
    end
    if RuneReader.SpellIconFrame then
        RuneReader:SetSpellIconFrame(SpellID, hotkey)
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
                icon = itemIcon,
                enabled   =  true
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

                                local baseMS = GetSpellBaseCooldown and GetSpellBaseCooldown(spellID)
                                local base   = (baseMS and baseMS > 0) and (baseMS/1000) or 0
                                local curDur = (sSpellCoolDown and sSpellCoolDown.duration) or 0
                                local cooldownSec = base > 0 and base or curDur

                                if sSpellInfo and sSpellInfo.name and hotkey and hotkey ~= "" then
                                    RuneReader.SpellbookSpellInfoByName[sSpellInfo.name] = {
                                        name = sSpellInfo.name,
                                        cooldown = cooldownSec,--sSpellCoolDown and sSpellCoolDown.duration or 0,
                                        castTime = (sSpellInfo.castTime or 0) / 1000,
                                        startTime = sSpellCoolDown and sSpellCoolDown.startTime or 0,
                                        hotkey = hotkey,
                                        spellID = sSpellInfo.spellID or spellID,
                                        enabled   = (C_Spell.IsSpellDisabled(spellID)) or true
                                    }
                                end

                                if hotkey and hotkey ~= "" then
                                    RuneReader.SpellbookSpellInfo[spellID] = {
                                        name = sSpellInfo and sSpellInfo.name or spellName or ("Flyout Spell " .. slot),
                                        cooldown = cooldownSec,--sSpellCoolDown and sSpellCoolDown.duration or 0,
                                        castTime = (sSpellInfo.castTime or 0) / 1000,
                                        startTime = sSpellCoolDown and sSpellCoolDown.startTime or 0,
                                        hotkey = hotkey,
                                        spellID = sSpellInfo.spellID or spellID,
                                        enabled   = (C_Spell.IsSpellDisabled(spellID)) or true
                                    }
                                end
                                RR_QueueTooltipCooldown(spellID)
                            end
                        end
                    end
                end

                spellID = spellID or actionId
                if spellID then
                    local sSpellInfo = RuneReader.GetSpellInfo(spellID)
                    local sSpellCoolDown = RuneReader.GetSpellCooldown(spellID)
                    local hotkey = RuneReader:GetHotkeyForSpell(spellID)
                    local baseMS = GetSpellBaseCooldown and GetSpellBaseCooldown(spellID)
                    local base   = (baseMS and baseMS > 0) and (baseMS/1000) or 0
                    local curDur = (sSpellCoolDown and sSpellCoolDown.duration) or 0
                    local cooldownSec = base > 0 and base or curDur


                    if (sSpellInfo and sSpellInfo.name and hotkey and hotkey ~= "") then
                        RuneReader.SpellbookSpellInfoByName[sSpellInfo.name] =
                        {
                            name      = (sSpellInfo and sSpellInfo.name) or "",
                            cooldown  = cooldownSec,--(sSpellCoolDown and sSpellCoolDown.duration) or 0,
                            castTime  = (sSpellInfo and sSpellInfo.castTime / 1000) or 0,
                            startTime = (sSpellCoolDown and sSpellCoolDown.startTime) or 0,
                            hotkey    = hotkey,
                            spellID   = (sSpellInfo and sSpellInfo.name) or spellID,
                            enabled   = (C_Spell.IsSpellDisabled(spellID)) or true
                        }
                    end

                    if (hotkey and hotkey ~= "") then
                        RuneReader.SpellbookSpellInfo[spellID] = {
                            name = (sSpellInfo and sSpellInfo.name or name) or "",
                            cooldown = cooldownSec,--(sSpellCoolDown and sSpellCoolDown.duration) or 0,
                            castTime = (sSpellInfo and sSpellInfo.castTime / 1000) or 0,
                            startTime = (sSpellCoolDown and sSpellCoolDown.startTime) or 0,
                            hotkey = hotkey,
                            spellID = spellID,
                            enabled   = (C_Spell.IsSpellDisabled(spellID)) or true
                        }
                    end
                    RR_QueueTooltipCooldown(spellID)
                end
            end
        end
    end
end


--[[
    Function: ShouldEnterShadowform
    Goal: If the player is a Shadow-spec Priest and NOT already in Shadowform,
          recommend casting Shadowform (return its spellID). Otherwise return nil.

    Notes:
      - Uses C_UnitAuras to check the Shadowform aura by spellID first (localization-safe).
      - Falls back to name-based lookup if the spellID aura isn't found.
      - Uses same cooldown pattern as your other helpers.
--]]
function RuneReader:ShouldEnterShadowform()
    -- Ensure player is a Priest
    local _, class = UnitClass("player")
    if class ~= "PRIEST" then return nil end

    -- Ensure Shadow specialization (1=Disc, 2=Holy, 3=Shadow)
    local specID = GetSpecialization()
    if specID ~= 3 then return nil end

    -- Shadowform spell (cast) ID. (Works fine in Retail.)
    local SHADOWFORM_ID = 15473

    -- Helper: is a spell ready to cast given your cooldown wrapper?
    local function IsSpellReady(spellID)
        if not spellID then return false end
        local cd = RuneReader.GetSpellCooldown(spellID)
        if not cd then return false end
        if cd.startTime == 0 or cd.duration == 0 then return true end
        return (cd.startTime + cd.duration - GetTime()) <= 0
    end

    -- 1) Check if Shadowform aura is already active by spellID (best/fastest).
    local hasShadow = false
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(SHADOWFORM_ID)
        hasShadow = aura ~= nil
    end

    -- 2) Fallback: check by localized name (if ID-based check didn’t work).
    if not hasShadow then
        local info = C_Spell.GetSpellInfo(SHADOWFORM_ID)
        if info and info.name and AuraUtil and AuraUtil.FindAuraByName then
            hasShadow = AuraUtil.FindAuraByName(info.name, "player") ~= nil
        end
    end

    -- If not in Shadowform and the spell is ready, recommend Shadowform.
    if not hasShadow and IsSpellReady(SHADOWFORM_ID) then
        return SHADOWFORM_ID
    end

    return nil
end

-- One-stop spell override: movement -> exclude -> form -> self-preservation
function RuneReader:ResolveOverrides(SpellID,  suggestedQueue)
    local newSpellID = SpellID
    -- fetch info safely
    local function GetInfo(id)
        return (RuneReader.GetSpellInfo and RuneReader.GetSpellInfo(id)) or {}
    end

    local spellInfo1 = GetInfo(newSpellID)


    -- ===== Major cooldown filter (per-character toggle) =====
    if RuneReaderRecastDBPerChar and RuneReaderRecastDBPerChar.UseGlobalCooldowns == false then
        if self.IsMajorCooldown and RuneReader.GetNextNonMajorSpell then
            if self:IsMajorCooldown(newSpellID) then
                local alt = self:GetNextNonMajorSpell(newSpellID, suggestedQueue)
                if alt then
                    newSpellID    = alt
                    spellInfo1 = GetInfo(newSpellID)
                end
            end
        end
    end

    -- ===== Movement: prefer instant while moving =====
    if RuneReaderRecastDB and RuneReaderRecastDB.UseInstantWhenMoving == true then
        local castTime = (spellInfo1.castTime or 0)
        if (castTime > 0 or (self.IsSpellIDInChanneling and self:IsSpellIDInChanneling(newSpellID)))
           and (self.IsPlayerMoving and self:IsPlayerMoving()) then
            local inst = self.GetNextInstantCastSpell and self:GetNextInstantCastSpell()
            if inst then
                newSpellID    = inst
                spellInfo1 = GetInfo(newSpellID)
            end
        end
    end

    -- ===== Exclude list: swap to next instant if excluded =====
    if self.IsSpellExcluded and self:IsSpellExcluded(newSpellID) then
        local inst = self.GetNextInstantCastSpell and self:GetNextInstantCastSpell()
        if inst then
            newSpellID    = inst
            spellInfo1 = GetInfo(newSpellID)
        end
    end

    -- ===== Form check (e.g., Shadowform) =====
    if RuneReaderRecastDB and RuneReaderRecastDB.UseFormCheck == true then
        local formSpell = self.ShouldEnterShadowform and self:ShouldEnterShadowform()
        if formSpell then
            newSpellID    = formSpell
            spellInfo1 = GetInfo(newSpellID)
        end
    end

    -- ===== Self-preservation / defensives (priority order) =====
    if RuneReaderRecastDBPerChar and RuneReaderRecastDBPerChar.UseSelfHealing == true then
        -- Priority list by function name; first non-nil wins.
        local priority = {
            "ShouldCastRevivePet",
            "ShouldCallPet",
            "ShouldCastMendPet",
            "ShouldCastExhilaration",
            "ShouldCastBearOrRegen",
            "ShouldCastRejuvenationIfNeeded",
            "ShouldCastWordOfGlory",
            "ShouldCastDeathStrike",
            "ShouldCastMarrowrend",
            "ShouldCastRuneTap",
            "ShouldCastMageDefensive",
            "ShouldCastExpelHarm",
            "ShouldCastCelestialBrew",
            "ShouldCastCrimsonVial",
            "ShouldCastImpendingVictory",
            "ShouldCastShieldBlock",
            "ShouldCastPowerWordShield",
            "ShouldCastHealingSurge",
            "ShouldCastObsidianScales",
            "ShouldCastIronfur",
            "ShouldCastNaturesVigil",
            "ShouldCastBarkskin",
            "ShouldCastPurifyingBrew",
            "ShouldCastVivifyBrewmaster",
        }

        for _, fname in ipairs(priority) do
            local fn = self[fname]
            if type(fn) == "function" then
                local id = fn(self)
                if id then
                    newSpellID    = id
                    spellInfo1 = GetInfo(newSpellID)
                    break
                end
            end
        end
    end
--print("Final SpellID", SpellID, spellInfo1 and spellInfo1.name)

    return newSpellID, spellInfo1
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
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("PLAYER_TALENT_UPDATE")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:SetScript("OnEvent", function()
    RuneReader.SpellbookSpellInfo = {}
    RuneReader.SpellbookSpellInfoByName = {}
        RuneReader:BuildAllSpellbookSpellMap()
    end)

    RuneReader.ActionBarSpellMapInvalidator = CreateFrame("Frame")
    RuneReader.ActionBarSpellMapInvalidator:RegisterEvent("SPELLS_CHANGED")
    RuneReader.ActionBarSpellMapInvalidator:RegisterEvent("PLAYER_TALENT_UPDATE")
    RuneReader.ActionBarSpellMapInvalidator:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
            RuneReader:InvalidateTooltipCooldowns()


end
