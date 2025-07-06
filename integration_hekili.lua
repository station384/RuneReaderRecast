-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

-- hekili_integration.lua: Interfacing with Hekili and key translation

RuneReader = RuneReader or {}

RuneReader.hekili_haveUnitTargetAttackable = false
RuneReader.hekili_inCombat = false
RuneReader.hekili_lastSpell = 61304
RuneReader.hekili_PrioritySpells = { 47528, 2139, 30449, 147362 }  --Interrupts
RuneReader.hekili_LastDataPak = {};
RuneReader.hekili_GenerationDelayTimeStamp = time()
RuneReader.hekili_GenerationDelayAccumulator = 0
RuneReader.hekili_LastEncodedResult = "1,B0,W0001,K00"


function RuneReader:Hekili_RuneReaderEnv_hasSpell(tbl, x)
    for _, v in ipairs(tbl) do
        if v == x then return true end
    end
    return false
end

function RuneReader:Hekili_GetRecommendedAbilityPrimary(index)
    if not Hekili or not Hekili.DisplayPool or not Hekili.DisplayPool.Primary or not Hekili.DisplayPool.Primary.Recommendations then
        return nil
    end
    local dpak = Hekili.DisplayPool.Primary.Recommendations[index]
    if not dpak then
        return nil
    end
    if dpak.actionID == nil or dpak.keybind == nil or dpak.keybind == "" or dpak.wait == nil or dpak.delay == nil or dpak.exact_time == nil then
        return nil
    end
    return {
        actionID = dpak.actionID,
        delay = dpak.delay,
        wait = dpak.wait,
        time = dpak.time,
        keybind = dpak.keybind,
        exact_time = dpak.exact_time
    }
end

function RuneReader:Hekili_GetRecommendedAbilityAOE(index)
    if not Hekili or not Hekili.DisplayPool or not Hekili.DisplayPool.AOE or not Hekili.DisplayPool.AOE.Recommendations then
        return nil
    end
    local dpak = Hekili.DisplayPool.AOE.Recommendations[index]
    if not dpak then return nil end
    if dpak.actionID == nil or dpak.keybind == nil or dpak.keybind == "" or dpak.wait == nil or dpak.delay == nil or dpak.exact_time == nil then
        return nil
    end
    return {
        actionID = dpak.actionID,
        delay = dpak.delay,
        wait = dpak.wait,
        time = dpak.time,
        keybind = dpak.keybind,
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



function RuneReader:Hekili_UpdateValues(mode)
   local mode = mode or 0

    RuneReader.hekili_GenerationDelayAccumulator = RuneReader.hekili_GenerationDelayAccumulator + (time() - RuneReader.hekili_GenerationDelayTimeStamp)
    if RuneReader.hekili_GenerationDelayAccumulator <= RuneReaderRecastDB.UpdateValuesDelay  then
        RuneReader.hekili_GenerationDelayTimeStamp = time()
        return RuneReader.hekili_LastEncodedResult
    end

    RuneReader.hekili_GenerationDelayTimeStamp = time()

    if not Hekili_GetRecommendedAbility then return end

    local curTime = GetTime()
    local _, _, _, latencyWorld = GetNetStats()

    local dataPacPrimary = RuneReader:Hekili_GetRecommendedAbilityPrimary( 1)
    local dataPacNext = RuneReader:Hekili_GetRecommendedAbilityPrimary(2)
    local dataPacAoe = RuneReader:Hekili_GetRecommendedAbilityAOE( 1)
    

    if  not dataPacPrimary then
        dataPacPrimary = RuneReader.hekili_LastDataPak
    end

    if not dataPacPrimary then dataPacPrimary = {} end
    
    if dataPacPrimary.actionID == nil then
        dataPacPrimary.delay = 0
        dataPacPrimary.wait = 0
        dataPacPrimary.keybind = nil
        dataPacPrimary.actionID = nil
        if RuneReader.hekili_LastDataPak then
            dataPacPrimary = RuneReader.hekili_LastDataPak
        end
    end

    RuneReader.hekili_LastDataPak = dataPacPrimary



    if not dataPacPrimary.delay then dataPacPrimary.delay = 0 end
    if not dataPacPrimary.wait then dataPacPrimary.wait = 0 end
    if not dataPacPrimary.exact_time then dataPacPrimary.exact_time = curTime end
    if not dataPacPrimary.keybind then dataPacPrimary.keybind = "" end

    local delay = dataPacPrimary.delay
    local wait = dataPacPrimary.wait

    -- if RuneReader.hekili_lastSpell ~= dataPacPrimary.actionID then 
    --     RuneReader.hekili_lastSpell = dataPacPrimary.actionID 

    --     end

    if wait == 0 then dataPacPrimary.exact_time = curTime end

    if UnitCanAttack("player", "target") then
        RuneReader.hekili_haveUnitTargetAttackable = true
    else
        RuneReader.hekili_haveUnitTargetAttackable = false
    end
    if dataPacPrimary.actionID ~= nil and C_Spell.IsSpellHarmful(dataPacPrimary.actionID) == false then
        RuneReader.hekili_haveUnitTargetAttackable = true
    end
  -- Check if the player is in combat
    local isInCombat = UnitAffectingCombat("player")

    if isInCombat then
        RuneReader.hekili_inCombat = true
    else
        RuneReader.hekili_inCombat = false
    end

    local exact_time = ((dataPacPrimary.exact_time + delay) - (wait)) - (RuneReaderRecastDB.PrePressDelay or 0)
    local countDown = (exact_time - curTime) 

        countDown = RuneReader:Clamp(countDown, 0, 9.99)

    local bitvalue = 0
    -- if dataPacPrimary.actionID ~= nil and C_Spell.IsSpellHarmful(dataPacPrimary.actionID) == false then
    --     RuneReader.hekili_haveUnitTargetAttackable = true
    -- end

    if RuneReader.hekili_haveUnitTargetAttackable then
        bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 0)
    end
    if RuneReader.hekili_inCombat then
        bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 1)
    end

--    local keytranslate = RuneReader:RuneReaderEnv_translateKey(dataPacPrimary.keybind)
--print(dataPacPrimary.actionID)
local key = ""
if ( RuneReader.SpellbookSpellInfo[dataPacPrimary.actionID]) then
key = RuneReader.SpellbookSpellInfo[dataPacPrimary.actionID].hotkey
else
    key = dataPacPrimary.keybind
end
 local keytranslate = RuneReader:RuneReaderEnv_translateKey(key )  -- 2 digits

    if AuraUtil and AuraUtil.FindAuraByName then
        if AuraUtil.FindAuraByName("G-99 Breakneck", "player", "HELPFUL") then
            keytranslate = "00"
        end
        if AuraUtil.FindAuraByName("Unstable Rocketpack", "player", "HELPFUL") then
            keytranslate = "00"
        end
    end

    local sCooldownResult = C_Spell.GetSpellCooldown(61304) -- find the GCD
     local source = "1"  -- 1 = AssistedCombat, 0 = Hekili
    --print ( duration .. enable) 
    local combinedValues =  mode .. 
                            '/B' .. bitvalue  
                            .. '/W' .. string.format("%04.3f", countDown ):gsub("[.]", "") 
                            .. '/K' .. keytranslate

                            --.. '/D' .. string.format("%04.3f", delay):gsub("[.]", "") 
                            --.. '/G' .. string.format("%04.3f", sCooldownResult.duration/100):gsub("[.]", "") 
                            --.. '/L' .. string.format("%04.3f", latencyWorld/1000):gsub("[.]", "") 
                            --.. '/A' .. string.format("%08i", dataPacPrimary.actionID or 0):gsub("[.]", "") 
                            --.. '/S' .. source                

    --mode .. keytranslate .. waitTranslate .. bitvalue 
    --local checkDigit = RuneReader:CalculateCheckDigit(combinedValues)
    local fullResult = combinedValues --.. checkDigit
    RuneReader.hekili_LastEncodedResult = fullResult

    return fullResult
end
