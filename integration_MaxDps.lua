-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html


RuneReader = RuneReader or {}

RuneReader.MaxDps_haveUnitTargetAttackable = false
RuneReader.MaxDps_inCombat = false
RuneReader.MaxDps_lastSpell = 61304
RuneReader.MaxDps_PrioritySpells = { 47528, 2139, 30449, 147362 }  --Interrupts

-- RuneReader.hekili_LastEncodedResult = "1,B0,W0001,K00"


local function CleanMaxDpsHotKey(HotKeyText)
    local keyText = HotKeyText
    if not keyText then keyText = "" end
    if keyText and keyText ~= "" and keyText ~= RANGE_INDICATOR then
        keyText = keyText:gsub("CTRL", "C")
        keyText = keyText:gsub("ALT", "A")
        return keyText:gsub("-", ""):upper()
    end
end

local function MaxDps_GetSpell(item)

   local result = nil
   result = MaxDps.Spell or RuneReader.GetNextCastSpell(false)
   local intCount = 1
    for index, value in pairs(MaxDps.SpellsGlowing) do
        if (intCount == item and value == 1) then
            result = index
        end
        intCount = intCount + 1
    end
    return result
end

 local function MaxDps_GetNextMajorCooldown(spellID)
 for key, isEnabled in pairs(MaxDps.Flags) do

    if isEnabled  then
        if C_Spell.IsSpellHarmful(key) then  -- Dont really need this for MaxDPS.  lets let it figure it out.
             --   print ("MaxDps Flag", key, isEnabled)
            return key
        end
    end
 end
-- print("MaxDps No Major Cooldown Found")
 return spellID
end

local function MaxDps_GetAlwaysUseMajorCooldowns(spellID)
 for key, isEnabled in pairs(MaxDps.Flags) do
    if isEnabled  then
        if RuneReader:IsMajorCooldownAlwaysUse(key)    then
            return key
        end
    end
 end
 return spellID
end

local function MaxDps_GetKeyBind(spellID)
    if not spellID then return nil end
    if not MaxDps.Spells then return nil end
    local keyBind = ""
    for key, value in pairs(MaxDps.Spells) do
        if key == spellID  and value[1].HotKey then
            keyBind = value[1].HotKey:GetText()
            keyBind = CleanMaxDpsHotKey(keyBind)
            -- print("MaxDps KeyBind for ", spellID, " is ", keyBind)
            break
        end
    end 
    return keyBind
end

function RuneReader:MaxDps_UpdateValues(mode)
    if not MaxDps or not MaxDps.db then return nil end --MaxDps Doesn't exists just exit
    if RuneReaderRecastDBPerChar.HelperSource ~= 3 then return nil end
    mode = mode or 1


    local curTime                             = RuneReader.GetTime()
    local keyBind                             = ""
    local SpellID                             = MaxDps_GetSpell(1)


    --MaxDps does not automaticly handle major cooldown spells.   
    -- Take them into account here and stub them in if there ready and we have the setting to use them
    if RuneReaderRecastDBPerChar.UseGlobalCooldowns then
        SpellID =  MaxDps_GetNextMajorCooldown(SpellID)
    end
    SpellID = MaxDps_GetAlwaysUseMajorCooldowns(SpellID) 
    if not SpellID then return RuneReader.MaxDps_LastEncodedResult end



    if not SpellID then SpellID = 0 end
    local spellInfo1 = RuneReader.GetSpellInfo(SpellID)

    SpellID, spellInfo1 = RuneReader:ResolveOverrides(SpellID, nil)

-- try and use MaxDPS go get our keybind first
    keyBind = MaxDps_GetKeyBind(SpellID)



-- Don't have a keybind so lets fall back on our parse.
    if (RuneReader.SpellbookSpellInfo and RuneReader.SpellbookSpellInfo[SpellID] and RuneReader.SpellbookSpellInfo[SpellID].hotkey) then
        keyBind = RuneReader.SpellbookSpellInfo[SpellID].hotkey or ""
    else
      if (RuneReader.SpellbookSpellInfoByName and RuneReader.SpellbookSpellInfoByName[spellInfo1.name] and RuneReader.SpellbookSpellInfoByName[spellInfo1.name].hotkey) then
            keyBind = RuneReader.SpellbookSpellInfoByName[spellInfo1.name].hotkey or ""
      end
    end





    
    local sCurrentSpellCooldown = RuneReader.GetSpellCooldown(SpellID)
    local delay = (spellInfo1.castTime / 1000)
    local duration = sCurrentSpellCooldown.duration


    --  local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    if sCurrentSpellCooldown.duration == 0 or not sCurrentSpellCooldown.duration then GCD = 0 end

    local wait = 0 --=timeShift
    local queueMS = tonumber(GetCVar("SpellQueueWindow") / 1.2) or 50
    local queueSec = queueMS / 1000
    sCurrentSpellCooldown.startTime = (sCurrentSpellCooldown.startTime) + duration -
    ((RuneReaderRecastDB.PrePressDelay  or 0) + queueSec)
    wait = sCurrentSpellCooldown.startTime - curTime






    wait = RuneReader:Clamp(wait, 0, 9.99)


    -- Encode fields
    local keytranslate = RuneReader:RuneReaderEnv_translateKey(keyBind) -- 2 digits
    -- local cooldownEnc = string.format("%04d", math.min(9999, math.floor((sCurrentSpellCooldown.duration or 0) * 10)))  -- 4 digits
    -- local castTimeEnc = string.format("%04d", math.min(9999, math.floor(((spellInfo1.castTime or 0) / 1000 or 0) * 10)))  -- 4 digits
    local bitMask = 0
    if RuneReader.UnitCanAttack("player", "target") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 0)
    end
    if RuneReader.UnitAffectingCombat("player") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 1)
    end
    local source = "3" -- 1 = AssistedCombat, 0 = Hekili, 3 = ConRo, 4 = MaxDps
    --Just playing around going to base36 encode the numbers to save space
    local combinedValues = mode
        .. '/B' .. bitMask
        .. '/W' .. string.format("%04.3f", wait):gsub("[.]", "")
        .. '/K' .. keytranslate
    --.. '/D' .. string.format("%04.3f", 0):gsub("[.]", "")
    --.. '/G' .. string.format("%04.3f", sCooldownResult.duration):gsub("[.]", "")
    --.. '/L' .. string.format("%04.3f", latencyWorld/1000):gsub("[.]", "")
    --.. '/A' .. string.format("%08i", spellID or 0):gsub("[.]", "")
    --.. '/S' .. source


    local full = combinedValues

    RuneReader.MaxDps_LastEncodedResult = full
    return full, SpellID, keyBind
end
