-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

-- hekili_integration.lua: Interfacing with Hekili and key translation

RuneReader = RuneReader or {}

RuneReader.hekili_haveUnitTargetAttackable = false
local hekili_inCombat = false
local hekili_LastDataPak = {};


 
local function Hekili_RuneReaderEnv_hasSpell(tbl, x)
    for _, v in ipairs(tbl) do
        if v == x then return true end
    end
    return false
end

local function Hekili_GetRecommendedAbilityPrimary(index)
  local rec = Hekili
  if not rec or not rec.DisplayPool or not rec.DisplayPool.Primary then
    return nil
  end

  local recs = rec.DisplayPool.Primary.Recommendations
  if not recs then return nil end

  local dpak = recs[index]
  if not dpak then return nil end

  if not (dpak.actionID and dpak.keybind ~= "" and dpak.wait and dpak.delay and dpak.exact_time) then
    return nil
  end

  return {
    actionID   = dpak.actionID,
    delay      = dpak.delay,
    wait       = dpak.wait,
    time       = dpak.time,
    keybind    = dpak.keybind,
    exact_time = dpak.exact_time
  }
end

local function Hekili_GetRecommendedAbilityAOE(index)
  local rec = Hekili
  if not rec or not rec.DisplayPool or not rec.DisplayPool.AOE then
    return nil
  end

  local recs = rec.DisplayPool.AOE.Recommendations
  if not recs then return nil end

  local dpak = recs[index]
  if not dpak then return nil end

  if not (dpak.actionID and dpak.keybind ~= "" and dpak.wait and dpak.delay and dpak.exact_time) then
    return nil
  end

  return {
    actionID   = dpak.actionID,
    delay      = dpak.delay,
    wait       = dpak.wait,
    time       = dpak.time,
    keybind    = dpak.keybind,
    exact_time = dpak.exact_time
  }
end




--The returned string is in this format
--This is the format for code39
--Code39 -- Mode-0
-- MODE KEY WAIT BIT(0,1) CHECK
-- 0    00  000  0        0
-- Mode 0-Code39 1-QR
-- BitMask 0=Target 1=Combat
-- Check quick check if of total values to the left

--QR -- Mode-1 
--1st char is number for compatability with code39 mode check
--Comma seperated values, Alpha value mean, 
--All text can be alpha numberic ASCII
--No checksum needed for data validation as QR ECC takes care of that for us.
-- A = Alpha numeric (A..Z,a..z,0..9,-,=)
-- Only the first parameter (MODE) is a fixed position
--MODE bool(0,1) 
--1,B0,W0000,K00,D0000,
--B (N) BitMask(4Bit) 0=Target 1=Combat 2=Multi-Target
--W (0000) WaitTime (4 digit Mask of max value of 9999 or 9 seconds and 999 miliseconds)
--K (NN) Keymask Encoded Key value
--D (0000) Delay (4 digit Mask of max value of 9999 or 9 seconds and 999 miliseconds)
--A (N...) ActionID (spellID)
--G (0000) GCD (Global Cooldown Time) cooldown time 
--L (0000) World Latency
--T ServerTime (When event started) -Not sure how to represent this yet but it will have to be a fixed length as it changes all the time.
--E ExactTime (When event is expected to end (delay+wait+GCD) ) -Not sure how to represent this yet but it will have to be a fixed length as it changes all the time.
--M (AA:N...) Keymapping (Multiple) : seperated list of Keyvalues and spellIDs (F1:8193) example (MF1:8193,MF2:2323,MCF1:9949)
--C (A) Keymapping Checksum quick calculation of Keymapping values, this will be "unique" to the total values in the keymapping parameter



-- function RuneReader:Hekili_UpdateValues(mode)
--     if not Hekili or not Hekili.baseName then return nil end
--     if RuneReaderRecastDBPerChar.HelperSource ~= 0 then return nil end

--    local mode = mode or 0


--     if not Hekili_GetRecommendedAbility then return end

--     local curTime = GetTime()

--     local dataPacPrimary = Hekili_GetRecommendedAbilityPrimary( 1)
--     local dataPacNext = Hekili_GetRecommendedAbilityPrimary(2)
--     local dataPacAoe = Hekili_GetRecommendedAbilityAOE( 1)
    

--     if  not dataPacPrimary then
--         dataPacPrimary = hekili_LastDataPak
--     end

--     if not dataPacPrimary then dataPacPrimary = {} end
    
--     if dataPacPrimary.actionID == nil then
--         dataPacPrimary.delay = 0
--         dataPacPrimary.wait = 0
--         dataPacPrimary.keybind = nil
--         dataPacPrimary.actionID = nil
--         if hekili_LastDataPak then
--             dataPacPrimary = hekili_LastDataPak
--         end
--     end

--     hekili_LastDataPak = dataPacPrimary



--     if not dataPacPrimary.delay then dataPacPrimary.delay = 0 end
--     if not dataPacPrimary.wait then dataPacPrimary.wait = 0 end
--     if not dataPacPrimary.exact_time then dataPacPrimary.exact_time = curTime end
--     if not dataPacPrimary.keybind then dataPacPrimary.keybind = "" end

--     local delay = dataPacPrimary.delay
--     local wait = dataPacPrimary.wait
   
-- -- Going to try and insert overrides I provide in recast
--     local  SpellID = dataPacPrimary.actionID
--     SpellID = RuneReader:ResolveOverrides(SpellID, nil)
--     local spellInfo1 = RuneReader.GetSpellInfo(SpellID)
        
--     if SpellID ~= dataPacPrimary.actionID then
--         if (RuneReader.SpellbookSpellInfo and RuneReader.SpellbookSpellInfo[SpellID] and RuneReader.SpellbookSpellInfo[SpellID].hotkey) then
--             dataPacPrimary.keybind  = RuneReader.SpellbookSpellInfo[SpellID].hotkey or ""
--         else
--             if (RuneReader.SpellbookSpellInfoByName and RuneReader.SpellbookSpellInfoByName[spellInfo1.name] and RuneReader.SpellbookSpellInfoByName[spellInfo1.name].hotkey) then
--                 dataPacPrimary.keybind  = RuneReader.SpellbookSpellInfoByName[spellInfo1.name].hotkey or ""
--             end
--         end
--         dataPacPrimary.delay = 0
--         dataPacPrimary.wait = spellInfo1.castTime or 0
--         dataPacPrimary.keybind = nil
--         dataPacPrimary.actionID = SpellID
--     end
 

--     if wait == 0 then dataPacPrimary.exact_time = curTime end

--     if UnitCanAttack("player", "target") then
--         RuneReader.hekili_haveUnitTargetAttackable = true
--     else
--         RuneReader.hekili_haveUnitTargetAttackable = false
--     end
--     if dataPacPrimary.actionID ~= nil and C_Spell.IsSpellHarmful(dataPacPrimary.actionID) == false then
--         RuneReader.hekili_haveUnitTargetAttackable = true
--     end
--   -- Check if the player is in combat
--     local isInCombat = UnitAffectingCombat("player")

--     if isInCombat then
--         hekili_inCombat = true
--     else
--         hekili_inCombat = false
--     end
--     local queueMS = tonumber(GetCVar("SpellQueueWindow") / 1.2) or 50
--     local queueSec = queueMS / 1000

--     local exact_time = ((dataPacPrimary.exact_time + delay) - (wait)) - ((RuneReaderRecastDB.PrePressDelay or 0) + queueSec)
--     local countDown = (exact_time - curTime) 

--         countDown = RuneReader:Clamp(countDown, 0, 9.99)

--     local bitvalue = 0
--     -- if dataPacPrimary.actionID ~= nil and C_Spell.IsSpellHarmful(dataPacPrimary.actionID) == false then
--     --     RuneReader.hekili_haveUnitTargetAttackable = true
--     -- end

--     if RuneReader.hekili_haveUnitTargetAttackable then
--         bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 0)
--     end
--     if hekili_inCombat then
--         bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 1)
--     end



--     local key = ""
--     if ( RuneReader.SpellbookSpellInfo[dataPacPrimary.actionID]) then
--     key = RuneReader.SpellbookSpellInfo[dataPacPrimary.actionID].hotkey
--     else
--         key = dataPacPrimary.keybind
--     end




--     local keytranslate = RuneReader:RuneReaderEnv_translateKey(key )  -- 2 digits

--     if AuraUtil and AuraUtil.FindAuraByName then
--         if AuraUtil.FindAuraByName("G-99 Breakneck", "player", "HELPFUL") then
--             keytranslate = "00"
--         end
--         if AuraUtil.FindAuraByName("Unstable Rocketpack", "player", "HELPFUL") then
--             keytranslate = "00"
--         end
--     end




--     local combinedValues =  mode .. 
--                             '/B' .. bitvalue  
--                             .. '/W' .. string.format("%04.3f", countDown ):gsub("[.]", "") 
--                             .. '/K' .. keytranslate

--                             --.. '/D' .. string.format("%04.3f", delay):gsub("[.]", "") 
--                             --.. '/G' .. string.format("%04.3f", sCooldownResult.duration/100):gsub("[.]", "") 
--                             --.. '/L' .. string.format("%04.3f", latencyWorld/1000):gsub("[.]", "") 
--                             --.. '/A' .. string.format("%08i", dataPacPrimary.actionID or 0):gsub("[.]", "") 
--                             --.. '/S' .. source                

--     local fullResult = combinedValues --.. checkDigit

--     return fullResult, dataPacPrimary.actionID, key
-- end

-- Cache frequently‑used globals
local GetTime           = GetTime
local UnitCanAttack     = UnitCanAttack
local UnitAffectingCombat = UnitAffectingCombat
local GetCVar           = GetCVar
local string_format     = string.format
local C_Spell           = C_Spell
local RuneReader        = RuneReader


function RuneReader:Hekili_UpdateValues(mode)
  if not Hekili or not Hekili.baseName then return nil end
  if RuneReaderRecastDBPerChar.HelperSource ~= 0 then return nil end

  local mode = mode or 0
  local curTime = GetTime()

  -- Quick guard for the helper function
  if not Hekili_GetRecommendedAbility then return end

  -- --- Fetch recommendations --------------------------------------------
  local dataPacPrimary = Hekili_GetRecommendedAbilityPrimary(1)
  local dataPacNext    = Hekili_GetRecommendedAbilityPrimary(2)
  local dataPacAoe     = Hekili_GetRecommendedAbilityAOE(1)

  if not dataPacPrimary then
    dataPacPrimary = hekili_LastDataPak
  end
  if not dataPacPrimary then dataPacPrimary = {} end

  -- Normalise missing fields
  local pk = dataPacPrimary
  if pk.actionID == nil then
    pk.delay     = 0
    pk.wait      = 0
    pk.keybind   = nil
    pk.actionID  = nil
    if hekili_LastDataPak then pk = hekili_LastDataPak end
  end
  hekili_LastDataPak = pk

  if not pk.delay        then pk.delay        = 0 end
  if not pk.wait         then pk.wait         = 0 end
  if not pk.exact_time   then pk.exact_time   = curTime end
  if not pk.keybind      then pk.keybind      = "" end

  -- --- Resolve overrides -----------------------------------------------
  local SpellID = pk.actionID
  SpellID = RuneReader:ResolveOverrides(SpellID, nil)
  local spellInfo1 = RuneReader.GetSpellInfo(SpellID)

  if SpellID ~= pk.actionID then
    local sbInfo  = RuneReader.SpellbookSpellInfo
    local sbInfoByName = RuneReader.SpellbookSpellInfoByName

    if sbInfo and sbInfo[SpellID] and sbInfo[SpellID].hotkey then
      pk.keybind = sbInfo[SpellID].hotkey or ""
    elseif sbInfoByName and sbInfoByName[spellInfo1.name] and sbInfoByName[spellInfo1.name].hotkey then
      pk.keybind = sbInfoByName[spellInfo1.name].hotkey or ""
    end

    pk.delay      = 0
    pk.wait       = spellInfo1.castTime or 0
    pk.keybind    = nil
    pk.actionID   = SpellID
  end

  if pk.wait == 0 then pk.exact_time = curTime end

  -- --- Target & combat flags --------------------------------------------
  RuneReader.hekili_haveUnitTargetAttackable =
      UnitCanAttack("player", "target") or
      (pk.actionID and not C_Spell.IsSpellHarmful(pk.actionID))

  local inCombat = UnitAffectingCombat("player")
  hekili_inCombat = inCombat

  -- --- Timing calculations ---------------------------------------------
  local queueMS  = tonumber(GetCVar("SpellQueueWindow") / 1.2) or 50
  local queueSec = queueMS / 1000

  local exact_time = ((pk.exact_time + pk.delay) - pk.wait) -
                     ((RuneReaderRecastDB.PrePressDelay or 0) + queueSec)
  local countDown  = RuneReader:Clamp(exact_time - curTime, 0, 9.99)

  -- --- Bit flags --------------------------------------------------------
  local bitvalue = 0
  if RuneReader.hekili_haveUnitTargetAttackable then
    bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 0)   -- set bit‑0
  end
  if hekili_inCombat then
    bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 1)   -- set bit‑1
  end

  -- --- Key handling -----------------------------------------------------
  local key = RuneReader.SpellbookSpellInfo[pk.actionID] and
              RuneReader.SpellbookSpellInfo[pk.actionID].hotkey or
              pk.keybind

  local keytranslate = RuneReader:RuneReaderEnv_translateKey(key)  -- 2 digits

  if AuraUtil and AuraUtil.FindAuraByName then
    local find = AuraUtil.FindAuraByName
    if find("G-99 Breakneck", "player", "HELPFUL") or
       find("Unstable Rocketpack", "player", "HELPFUL") then
      keytranslate = "00"
    end
  end

  -- --- Build the output string -----------------------------------------
  local parts = {
    mode,
    "/B" .. bitvalue,
    "/W" .. string_format("%04.3f", countDown):gsub("[.]", ""),
    "/K" .. keytranslate
  }
  -- (Optional parts are commented out in the original; keep them commented.)
  -- table.insert(parts, "/D" .. string_format("%04.3f", pk.delay):gsub("[.]", ""))
  -- table.insert(parts, "/G" .. string_format("%04.3f", sCooldownResult.duration/100):gsub("[.]", ""))
  -- table.insert(parts, "/L" .. string_format("%04.3f", latencyWorld/1000):gsub("[.]", ""))
  -- table.insert(parts, "/A" .. string_format("%08i", pk.actionID or 0):gsub("[.]", ""))
  -- table.insert(parts, "/S" .. source)

  local fullResult = table.concat(parts)  -- no check digit for now

  return fullResult, pk.actionID, key
end