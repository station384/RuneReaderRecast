-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html


-- assistedcombat_integration.lua: Integration with Blizzard's AssistedCombat system
-- Total beta.   No real info on the API has been released yet.  This is all Guesswork



RuneReader = RuneReader or {}
RuneReader.AssistedCombatSpellInfo = RuneReader.AssistedCombatSpellInfo or {}
RuneReader.lastAssistedSpell = nil
RuneReader.Assisted_LastEncodedResult = "1,B0,W0001,K00"
RuneReader.Assisted_GenerationDelayTimeStamp = time()
RuneReader.Assisted_GenerationDelayAccumulator = 0



-- This just gets the first instant cast spell.  
-- that doesn't have a cooldown.  it doesn't really care what it is.  this is just filler for when your moving.
function RuneReader:AssistedCombat_GetNextInstantCastSpell()
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
--S (N) Source 0 - Hekili, 1 - Combat Assist
--C (A) Keymapping Checksum quick calculation of Keymapping values, this will be "unique" to the total values in the keymapping parameter


function RuneReader:AssistedCombat_UpdateValues(mode)
    local mode = mode or 1
    RuneReader.Assisted_GenerationDelayAccumulator = RuneReader.Assisted_GenerationDelayAccumulator +
    (time() - RuneReader.Assisted_GenerationDelayTimeStamp)
    if RuneReader.Assisted_GenerationDelayAccumulator <= RuneReaderRecastDB.UpdateValuesDelay then
        RuneReader.Assisted_GenerationDelayTimeStamp = time()
        return RuneReader.Assisted_LastEncodedResult
    end
    RuneReader.Assisted_GenerationDelayTimeStamp = time()


    --   local _, _, _, latencyWorld = GetNetStats()
    local curTime = RuneReader.GetTime()
    local SpellID = RuneReader.GetNextCastSpell(false)
    local spellInfo1 = RuneReader.GetSpellInfo(SpellID);


    -- Very dirty implementation.
    if RuneReaderRecastDB.UseInstantWhenMoving == true then
        if (spellInfo1.castTime > 0 or RuneReader:IsSpellIDInChanneling(SpellID)) and RuneReader:IsPlayerMoving() then
            SpellID    = RuneReader:AssistedCombat_GetNextInstantCastSpell() or SpellID
            spellInfo1 = RuneReader.GetSpellInfo(SpellID)
        end
    end

        --#region Should we self heal segment
    -- ConRO doesn't have any self healing routines,  so we will just check if we are below 50% health and use a self heal if we are.
    -- So we will add some.    I am starting with the druid for now.   More will be added later.
    if RuneReaderRecastDB.UseSelfHealing == true then
        -- Hunter Pet healing
        -- print("Self Healding is enabled")
        local ShouldHealPet = RuneReader:ShouldCastMendPet()
        local ShouldRevivePet = RuneReader:ShouldCastRevivePet()
        local ShouldBearHeal = RuneReader:ShouldCastBearOrRegen()
        local ShouldCastRejuvenationIfNeeded = RuneReader:ShouldCastRejuvenationIfNeeded()
        -- print("ShouldHealPet", ShouldHealPet, "ShouldRevivePet", ShouldRevivePet, "ShouldBearHeal", ShouldBearHeal)
        if ShouldHealPet then
            SpellID    = ShouldHealPet or SpellID
            spellInfo1 = RuneReader.GetSpellInfo(SpellID)
        elseif ShouldRevivePet then
            SpellID    = ShouldRevivePet or SpellID
            spellInfo1 = RuneReader.GetSpellInfo(SpellID)
        elseif ShouldBearHeal then
            SpellID    = ShouldBearHeal or SpellID
            spellInfo1 = RuneReader.GetSpellInfo(SpellID)
        elseif ShouldCastRejuvenationIfNeeded then
            SpellID    = ShouldCastRejuvenationIfNeeded or SpellID
            spellInfo1 = RuneReader.GetSpellInfo(SpellID)
        end
    end
    --#endregion



    if not SpellID then return RuneReader.Assisted_LastEncodedResult end
    if not (RuneReader.SpellbookSpellInfo[SpellID] and RuneReader.SpellbookSpellInfo[SpellID].spellID) then
        -- print ("RuneReader:AssistedCombat_UpdateValues - Spell ID not found in SpellbookSpellInfo. Building Spellbook Spell Map.", spellID)
        return RuneReader.Assisted_LastEncodedResult
    end
    local info = RuneReader.SpellbookSpellInfo[SpellID]
    if not info then
        --        print ("RuneReader:AssistedCombat_UpdateValues - Spell ID not found in AssistedCombatSpellInfo. Building Spellbook Spell Map.")
        RuneReader:BuildAllSpellbookSpellMap()
        info = RuneReader.SpellbookSpellInfo[SpellID]
        if not info then return RuneReader.Assisted_LastEncodedResult end
    end
    if RuneReader.SpellIconFrame then
        RuneReader:SetSpellIconFrame(SpellID, info.hotkey)
    end
    -- print("RuneReader:AssistedCombat_UpdateValues - Spell ID: ", spellID, "Hotkey: ", info.hotkey, "Mode: ", mode)
    local sCurrentSpellCooldown = RuneReader.GetSpellCooldown(SpellID)
    spellInfo1 = RuneReader.GetSpellInfo(SpellID);
    --local delay = (spellInfo1.castTime/1000)
    local duration = sCurrentSpellCooldown.duration



    local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD



    if sCurrentSpellCooldown.duration == 0 or not sCurrentSpellCooldown.duration then GCD = 0 end
    -- Wait time until cooldown ends
    local wait = 0

    sCurrentSpellCooldown.startTime = (sCurrentSpellCooldown.startTime) + duration -
    (RuneReaderRecastDB.PrePressDelay or 0)
    wait = sCurrentSpellCooldown.startTime - curTime

    wait = RuneReader:Clamp(wait, 0, 9.99)
    -- Encode fields
    local keytranslate = RuneReader:RuneReaderEnv_translateKey(info.hotkey)                          -- 2 digits
    local cooldownEnc = string.format("%04d", math.min(9999, math.floor((info.cooldown or 0) * 10))) -- 4 digits
    local castTimeEnc = string.format("%04d", math.min(9999, math.floor((info.castTime or 0) * 10))) -- 4 digits
    local bitMask = 0
    if RuneReader.UnitCanAttack("player", "target") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 0)
    end
    if RuneReader.UnitAffectingCombat("player") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 1)
    end
    local source = "1" -- 1 = AssistedCombat, 0 = Hekili

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
    --print("RuneReader:AssistedCombat_UpdateValues - Full Encoded Result: ", full)
    RuneReader.Assisted_LastEncodedResult = full
    return full
end
