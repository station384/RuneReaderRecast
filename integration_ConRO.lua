-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html


RuneReader = RuneReader or {}

RuneReader.ConRO_haveUnitTargetAttackable = false
RuneReader.ConRO_inCombat = false
RuneReader.ConRO_lastSpell = 61304
RuneReader.ConRO_PrioritySpells = { 47528, 2139, 30449, 147362 }  --Interrupts
RuneReader.ConRO_GenerationDelayTimeStamp = time()
RuneReader.ConRO_GenerationDelayAccumulator = 0


function RuneReader:CleanConROHotKey(HotKeyText)

            local keyText = HotKeyText
            if not keyText then keyText = "" end
            if keyText and keyText ~= "" and keyText ~= RANGE_INDICATOR then
                keyText = keyText:gsub("CTRL", "C")
                keyText = keyText:gsub("ALT", "A")
                return keyText:gsub("-", ""):upper()
            end

end

function RuneReader:ConRO_UpdateValues(mode)
   local mode = mode or 1

    RuneReader.ConRO_GenerationDelayAccumulator = RuneReader.ConRO_GenerationDelayAccumulator + (time() - RuneReader.ConRO_GenerationDelayTimeStamp)
    if RuneReader.ConRO_GenerationDelayAccumulator <= RuneReaderRecastDB.UpdateValuesDelay  then
        RuneReader.ConRO_GenerationDelayTimeStamp = time()
        return RuneReader.LastEncodedResult
    end

    RuneReader.ConRO_GenerationDelayTimeStamp = time()
    if not ConRO then return end --ConRO Doesn't exists just exit


    local curTime = GetTime()
    local _, _, _, latencyWorld = GetNetStats()
    local keyBind = ""
    local SpellID  = ConRO.SuggestedSpells[1];
   
  if not SpellID then return RuneReader.ConRO_LastEncodedResult end
-- ConRO Specfic 
  --  keyBind =  RuneReader:CleanConROHotKey(ConRO:FindKeybinding(SpellID))
 --     print("ConRO SpellID", SpellID, "Keybind",  RuneReader.SpellbookSpellInfo[SpellID] and RuneReader.SpellbookSpellInfo[SpellID].hotkey or "No Keybind")
  keyBind = RuneReader.SpellbookSpellInfo[SpellID].hotkey or ""
-- End ConRO Specific




    -- if not info then
    --     print("Building map")
    --     RuneReader:BuildAssistedSpellMap()
    --     info = RuneReader.AssistedCombatSpellInfo[spellID]
    --     if not info then return RuneReader.Assisted_LastEncodedResult end
    -- end
    if RuneReader.SpellIconFrame then

      RuneReader:SetSpellIconFrame(SpellID, keyBind) 
    end
   local sCurrentSpellCooldown = C_Spell.GetSpellCooldown(SpellID)
--  local timeShift, spellId, gcd = ConRO:EndCast("player")
   local spellInfo1 = C_Spell.GetSpellInfo(SpellID);
   local delay = (spellInfo1.castTime/1000)
   local duration = sCurrentSpellCooldown.duration


   local GCD = C_Spell.GetSpellCooldown(61304).duration -- find the GCD
   if sCurrentSpellCooldown.duration == 0 or not sCurrentSpellCooldown.duration then GCD = 0 end
    -- Wait time until cooldown ends
    local wait =0--=timeShift
    --if sCurrentSpellCooldown.startTime > 0 then

       -- Works well wait = sCurrentSpellCooldown.startTime + (sCurrentSpellCooldown.duration+(spellInfo1.castTime/1000)) - curTime  - (RuneReaderRecastDB.PrePressDelay or 0)

             sCurrentSpellCooldown.startTime = (sCurrentSpellCooldown.startTime ) + duration  - (RuneReaderRecastDB.PrePressDelay or 0)
            wait = sCurrentSpellCooldown.startTime  - curTime 
       --wait = (wait-GCD) 


    --end


    wait = RuneReader:Clamp(wait, 0, 9.99)
--print (sCurrentSpellCooldown.duration,(spellInfo1.castTime/1000),wait)

    -- Encode fields
    local keytranslate = RuneReader:RuneReaderEnv_translateKey(keyBind)  -- 2 digits
    local cooldownEnc = string.format("%04d", math.min(9999, math.floor((sCurrentSpellCooldown.duration or 0) * 10)))  -- 4 digits
    local castTimeEnc = string.format("%04d", math.min(9999, math.floor(((spellInfo1.castTime or 0) / 1000 or 0) * 10)))  -- 4 digits
    local bitMask = 0
    if UnitCanAttack("player", "target") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 0)
    end
    if UnitAffectingCombat("player") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 1)
    end
    local source = "3"  -- 1 = AssistedCombat, 0 = Hekili, 3 = ConRo

    local combinedValues =  mode 
                            .. '/B' .. bitMask 
                            .. '/W' .. string.format("%04.3f", wait):gsub("[.]", "") 
                            .. '/K' .. keytranslate 
                            --.. '/D' .. string.format("%04.3f", 0):gsub("[.]", "") 
                            --.. '/G' .. string.format("%04.3f", sCooldownResult.duration):gsub("[.]", "") 
                            --.. '/L' .. string.format("%04.3f", latencyWorld/1000):gsub("[.]", "") 
                            --.. '/A' .. string.format("%08i", spellID or 0):gsub("[.]", "") 
                            --.. '/S' .. source


    local full = combinedValues

    RuneReader.ConRO_LastEncodedResult = full
    return full










end