-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html


RuneReader = RuneReader or {}

local MaxDps_haveUnitTargetAttackable = false
local MaxDps_inCombat = false
local MaxDps_lastSpell = 61304
local MaxDps_PrioritySpells = { 47528, 2139, 30449, 147362 }  --Interrupts

-- RuneReader.hekili_LastEncodedResult = "1,B0,W0001,K00"

local gsub  = string.gsub
local upper = string.upper

local function CleanMaxDpsHotKey(HotKeyText)
    local keyText = HotKeyText or ""
--    if keyText then keyText = "" end
    if keyText ~= "" and keyText ~= RANGE_INDICATOR then
        keyText = gsub(keyText, "CTRL", "C")
        keyText = gsub(keyText, "ALT", "A")
        return upper(gsub(keyText, "-", ""))
    end
    return nil
end


local function MaxDps_GetSpell(item)
  -- MaxDps doesnt activate till in combat, so Spell will be nil.  So we will get the next instant cast spell Bliz recommends to start things out.
  local result = RuneReader.GetNextCastSpell(false)
  if item == 1 then
    result = MaxDps.Spell or result
  end

  local glowing = MaxDps.SpellsGlowing

  -- Scan the table; if the requested index has a 1 flag, override the result.
  local count = 2
   for idx, flag in pairs(glowing) do
     if count == item and flag == 1 then
       result = idx
     end
     count = count + 1
   end
  return result
end


 local function MaxDps_GetNextMajorCooldown(spellID)
    local flags = MaxDps.Flags
    for key, isEnabled in pairs(flags) do
        if isEnabled  then
            if (C_Spell.IsSpellHarmful(key) or C_Spell.IsSpellHelpful(key)) and not RuneReader:IsSpellExcluded(key) then  -- Dont really need this for MaxDPS.  lets let it figure it out.
                return key
            end
        end
    end
    return spellID
end

local function MaxDps_GetAlwaysUseMajorCooldowns(spellID)
 for key, isEnabled in pairs(MaxDps.Flags) do
    if isEnabled  then
        if RuneReader:IsMajorCooldownAlwaysUse(key)  and not RuneReader:IsSpellExcluded(key)  then
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

local function MaxDps_GetEmpowermentLevel(SpellID)
  if not SpellID then return 0 end
  if not MaxDps.FrameData  then return 0 end
  if not MaxDps.FrameData.empowerLevel then return 0 end
  return MaxDps.FrameData.empowerLevel[SpellID] or 0
end

-- Spell Queue Window Divisor
-- Is used to adjust the spell queue window time to match the pre-press delay
-- But leaves some room for latencyWorld screen refresh etc. 
local spellQueueWindowDivisor = 1  

function RuneReader:MaxDps_UpdateValues(mode)
    if not MaxDps or not MaxDps.db then return nil end --MaxDps Doesn't exists just exit
    if RuneReaderRecastDBPerChar.HelperSource ~= 3 then return nil end
    mode = mode or 1

   local spellInfo1 = nil
    local curTime                             = RuneReader.GetTime()
    local keyBind                             = ""
    local SpellID                             = MaxDps_GetSpell(1)


    --MaxDps does not automaticly handle major cooldown spells.   
    -- Take them into account here and stub them in if there ready and we have the setting to use them
    if RuneReaderRecastDBPerChar.UseGlobalCooldowns then
        SpellID =  MaxDps_GetNextMajorCooldown(SpellID)
    end
    SpellID = MaxDps_GetAlwaysUseMajorCooldowns(SpellID)

    SpellID = RuneReader:ResolveOverrides(SpellID, nil)

    if not SpellID then return RuneReader.MaxDps_LastEncodedResult end
--    if not SpellID then SpellID = 0 end


-- try and use MaxDPS go get our keybind first
    keyBind = MaxDps_GetKeyBind(SpellID)

    
    spellInfo1 = RuneReader.GetSpellInfo(SpellID)


-- Don't have a keybind so lets fall back on our parse.
if not keyBind or keyBind == "" then
    if (RuneReader.SpellbookSpellInfo and RuneReader.SpellbookSpellInfo[SpellID] and RuneReader.SpellbookSpellInfo[SpellID].hotkey) then
        keyBind = RuneReader.SpellbookSpellInfo[SpellID].hotkey or ""
    else
      if (RuneReader.SpellbookSpellInfo and spellInfo1 and RuneReader.SpellbookSpellInfoByName and RuneReader.SpellbookSpellInfoByName[spellInfo1.name] and RuneReader.SpellbookSpellInfoByName[spellInfo1.name].hotkey) then
            keyBind = RuneReader.SpellbookSpellInfoByName[spellInfo1.name].hotkey or ""
      end
    end
end
 
    if not SpellID then return RuneReader.MaxDps_LastEncodedResult end
    if not SpellID then SpellID = 0 end

    local sCurrentSpellCooldown =     RuneReader.GetSpellCooldown(SpellID) or {} 
    sCurrentSpellCooldown.duration = sCurrentSpellCooldown.duration or spellInfo1.castTime
    sCurrentSpellCooldown.startTime = sCurrentSpellCooldown.startTime or 0

    --local delay = (spellInfo1.castTime / 1000)
  
    local duration = sCurrentSpellCooldown.duration


    --  local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    if sCurrentSpellCooldown.duration == 0 or not sCurrentSpellCooldown.duration then GCD = 0 end


    -- handle Empowerment spells
    if MaxDps_GetEmpowermentLevel(SpellID) ~= 0  then 
      --  print ("Charge To:",MaxDps_GetEmpowermentLevel(SpellID),  "Time To Charge:", MaxDps_GetEmpowermentLevel(SpellID) /  (2.1/4))
        duration = (MaxDps_GetEmpowermentLevel(SpellID) / (2.1/5)) 

    end


    local wait = 0 --=timeShift
    local queueMS = tonumber(GetCVar("SpellQueueWindow") / spellQueueWindowDivisor) or 50
    local queueSec = queueMS / 1000
    sCurrentSpellCooldown.startTime = (sCurrentSpellCooldown.startTime) + duration -
    ((RuneReaderRecastDB.PrePressDelay  or 0) + queueSec)
    wait = sCurrentSpellCooldown.startTime - curTime






    wait = RuneReader:Clamp(wait, 0, 9.99)
    


    -- Encode fields
    local keytranslate = RuneReader:RuneReaderEnv_translateKey(keyBind) -- 2 digits
    local bitMask = 0
    
    if RuneReader.UnitCanAttack("player", "target") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 0)
    end

    if RuneReader.UnitAffectingCombat("player") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 1)
    end

    if AuraUtil and AuraUtil.FindAuraByName then
    local find = AuraUtil.FindAuraByName
    if find("G-99 Breakneck", "player", "HELPFUL") or
       find("Unstable Rocketpack", "player", "HELPFUL") then
      keytranslate = "00"
    end
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
