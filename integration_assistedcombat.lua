-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html


-- assistedcombat_integration.lua: Integration with Blizzard's AssistedCombat system
-- Total beta.   No real info on the API has been released yet.  This is all Guesswork



RuneReader = RuneReader or {}
RuneReader.AssistedCombatSpellInfo = RuneReader.AssistedCombatSpellInfo or {}
RuneReader.Assisted_LastEncodedResult = "1,B0,W0001,K00"










--[[
AssistedCombat_UpdateValues
==========================

Purpose:
  Build and return a compact, encoded instruction string for the Assisted Combat output path.
  The string conveys the current "source mode", simple state flags, the pre-press-adjusted
  wait time until the recommended spell should be sent, and the translated hotkey.

High-level flow:
  1) Throttle by a configurable update delay to avoid excessive recomputation.
  2) Determine the next candidate spell (from the helper source) and resolve overrides:
     movement → exclusions → form checks → self-preservation/defensives.
  3) Ensure spellbook metadata exists (hotkey, cast/cooldown info), lazily rebuilding if needed.
  4) Update the UI icon (if available).
  5) Compute the "wait" value using spell cooldown start/duration, PrePressDelay, and the client
     SpellQueueWindow (converted to seconds).
  6) Encode fields into a compact string and cache it as the last result.

Inputs:
  - mode (number | nil): Optional source/mode indicator to prefix the encoded string.
    Defaults to 1 if not supplied or nil.

Outputs:
  - (string): Encoded "full" string on success; if the function is early-exited (throttle, no spell,
              missing metadata), it returns the previously cached "RuneReader.Assisted_LastEncodedResult".

Side effects / Global dependencies:
  - Reads/writes these globals:
      * RuneReader.Assisted_GenerationDelayAccumulator
      * RuneReader.Assisted_GenerationDelayTimeStamp
      * RuneReader.Assisted_LastEncodedResult
      * RuneReaderRecastDBPerChar.HelperSource
      * RuneReaderRecastDB.UpdateValuesDelay
      * RuneReaderRecastDB.PrePressDelay
  - Relies on several RuneReader helpers:
      * RuneReader.GetTime(), RuneReader.GetNextCastSpell(), RuneReader.GetSpellInfo()
      * RuneReader:ResolveOverrides(), RuneReader.GetSpellCooldown(), RuneReader:Clamp()
      * RuneReader:RuneReaderEnv_translateKey(), RuneReader:RuneReaderEnv_set_bit()
      * RuneReader.UnitCanAttack(), RuneReader.UnitAffectingCombat()
      * RuneReader:SetSpellIconFrame(), RuneReader:BuildAllSpellbookSpellMap()
  - Uses CVar "SpellQueueWindow" to account for client-side input queueing and the configured PrePressDelay.
  - Optionally updates a UI element via RuneReader.SpellIconFrame.

Assumptions:
  - RuneReader.SpellbookSpellInfo[spellID] is populated (auto-rebuilt if missing).
  - Cooldown/cast time fields used below are present in "info" or derivable from WoW APIs.
  - "mode" is representable as a string; numerics are acceptable.

Edge cases handled:
  - Throttle window not elapsed → returns last encoded result.
  - No next spell chosen / unknown spell metadata → returns last encoded result.
  - Hotkey resolution tries multiple fallbacks (by spellID first, then by name).

Encoding format (current fields):
  <mode>/B<bitMask>/W<waitNoDot>/K<key>
    - mode:        The provided "mode" (number coerced to string).
    - B<bitMask>:  bit 0 = player can attack target; bit 1 = player in combat.
    - W<wait>:     wait time (seconds) clamped to [0, 9.99], formatted with 3 decimals and '.' removed.
    - K<key>:      translated hotkey via RuneReader:RuneReaderEnv_translateKey().

Notes:  
    This is the format for code39
    Code39 -- Mode-0
    MODE KEY WAIT BIT(0,1) CHECK
    0    00  000  0        0
    Mode 0-Code39 1-QR
    BitMask 0=Target 1=Combat
    Check quick check if of total values to the left

    QR -- Mode-1 
    1st char is number for compatability with code39 mode check
    Comma seperated values, Alpha value mean, 
    All text can be alpha numberic ASCII
    No checksum needed for data validation as QR ECC takes care of that for us.
    A = Alpha numeric (A..Z,a..z,0..9,-,=)
    Only the first parameter (MODE) is a fixed position
    MODE bool(0,1) 
    1,B0,W0000,K00,D0000,
    B (N) BitMask(4Bit) 0=Target 1=Combat 2=Multi-Target
    W (0000) WaitTime (4 digit Mask of max value of 9999 or 9 seconds and 999 miliseconds)
    K (NN) Keymask Encoded Key value
    D (0000) Delay (4 digit Mask of max value of 9999 or 9 seconds and 999 miliseconds)
    A (N...) ActionID (spellID)
    G (0000) GCD (Global Cooldown Time) cooldown time 
    L (0000) World Latency
    T ServerTime (When event started) -Not sure how to represent this yet but it will have to be a fixed length as it changes all the time.
    E ExactTime (When event is expected to end (delay+wait+GCD) ) -Not sure how to represent this yet but it will have to be a fixed length as it changes all the time.
    M (AA:N...) Keymapping (Multiple) : seperated list of Keyvalues and spellIDs (F1:8193) example (MF1:8193,MF2:2323,MCF1:9949)
    S (N) Source 0 - Hekili, 1 - Combat Assist
    C (A) Keymapping Checksum quick calculation of Keymapping values, this will be "unique" to the total values in the keymapping parameter

Usage:
  local encoded = RuneReader:AssistedCombat_UpdateValues(myModeNumber)
  -- Use "encoded" as your QR/overlay payload.

]]

function RuneReader:AssistedCombat_UpdateValues(mode)
    -- Guard: only run if Assisted Combat is the active helper source (1)
    if RuneReaderRecastDBPerChar.HelperSource ~= 1 then return end

    -- Default mode to 1 if nil was passed
    local mode = mode or 1

    -- ======================
    -- Candidate spell & time
    -- ======================
    local curTime = RuneReader.GetTime()                       -- monotonic "now" from addon helper
    local SpellID = RuneReader.GetNextCastSpell(false)         -- next spell suggestion from source
    -- If no spell is available, do not generate a new payload
--    if not SpellID then return RuneReader.Assisted_LastEncodedResult end

    -- Base spell info (used before and after overrides)
    local spellInfo1 = RuneReader.GetSpellInfo(SpellID)

    -- Apply movement/exclude/form/self-preservation overrides in priority via our helper
    local newSpellID, newSpellInfo1 = RuneReader:ResolveOverrides(SpellID, nil)
    

    if newSpellID ~= SpellID then
      SpellID = newSpellID
      spellInfo1 = newSpellInfo1
    end




    -- ======================
    -- Spellbook metadata map
    -- ======================
    -- Validate spellbook mapping for this spell; rebuild map on-demand if missing
    if not (RuneReader.SpellbookSpellInfo[SpellID] and RuneReader.SpellbookSpellInfo[SpellID].spellID) then
     -- print ("Missing spellbook metadata for spellID:", SpellID)
       return RuneReader.Assisted_LastEncodedResult
    end
    local info = RuneReader.SpellbookSpellInfo[SpellID]

    if not info then
        RuneReader:BuildAllSpellbookSpellMap()
        info = RuneReader.SpellbookSpellInfo[SpellID]
      -- print ("Rebuilt spellbook map for spellID:", SpellID)
        if not info then return RuneReader.Assisted_LastEncodedResult end
    end

    -- ======================
    -- Hotkey resolution
    -- ======================
    -- If hotkey missing, try to resolve by the current spell's spellID first
    if info.hotkey or info.hotkey == "" then
        info.hotkey = RuneReader.SpellbookSpellInfo[spellInfo1.spellID].hotkey or ""
    end
    -- Fallback: resolve hotkey by localized name if needed
    if not info.hotkey or info.hotkey == "" then
        info.hotkey = RuneReader.SpellbookSpellInfoByName[spellInfo1.name].hotkey or ""
    end



    -- ======================
    -- Cooldown & wait window
    -- ======================
    local sCurrentSpellCooldown = RuneReader.GetSpellCooldown(SpellID)
    spellInfo1 = RuneReader.GetSpellInfo(SpellID)  -- re-fetch in case overrides changed the target spell
    local duration = sCurrentSpellCooldown.duration

    -- Wait time until cooldown ends
    local wait = 0

    -- Pull the client SpellQueueWindow (ms) and convert to seconds; default to 50ms if missing
    local queueMS  = tonumber(GetCVar("SpellQueueWindow") / 1.2) or 50
    local queueSec = queueMS / 1000

    -- Adjust the effective "start time" by duration, PrePressDelay, and the client queue window.
    -- This models when the key should be pressed so the spell fires ASAP as GCD/cooldown frees up.
    sCurrentSpellCooldown.startTime =
        (sCurrentSpellCooldown.startTime) + duration - ((RuneReaderRecastDB.PrePressDelay or 0) + queueSec)

    -- Compute wait relative to our current time now that startTime has been adjusted
    wait = sCurrentSpellCooldown.startTime - curTime

    -- Clamp to a sane 0..9.99 range (encoded with 3 decimals below)
    wait = RuneReader:Clamp(wait, 0, 9.99)

    -- ======================
    -- Encoding
    -- ======================
    local keytranslate = RuneReader:RuneReaderEnv_translateKey(info.hotkey)                          -- 2 digits
    local cooldownEnc  = string.format("%04d", math.min(9999, math.floor((info.cooldown or 0) * 10))) -- 4 digits
    local castTimeEnc  = string.format("%04d", math.min(9999, math.floor((info.castTime or 0) * 10))) -- 4 digits

    -- Bitfield flags:
    --  bit 0 → player can attack target
    --  bit 1 → player is in combat
    local bitMask = 0
    if RuneReader.UnitCanAttack("player", "target") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 0)
    end
    if RuneReader.UnitAffectingCombat("player") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 1)
    end

    local source = "1" -- 1 = AssistedCombat, 0 = Hekili

    -- Assemble the compact payload. Keep your commented fields for future expansion.
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

    -- Cache and return
    --print("RuneReader:AssistedCombat_UpdateValues - Full Encoded Result: ", full)
    RuneReader.Assisted_LastEncodedResult = full
    

    return full, SpellID, info.hotkey
end



-- function RuneReader:AssistedCombat_UpdateValues(mode)
--     if RuneReaderRecastDBPerChar.HelperSource ~= 1 then return end
--     local mode = mode or 1
--     RuneReader.Assisted_GenerationDelayAccumulator = RuneReader.Assisted_GenerationDelayAccumulator +
--     (time() - RuneReader.Assisted_GenerationDelayTimeStamp)
--     if RuneReader.Assisted_GenerationDelayAccumulator <= RuneReaderRecastDB.UpdateValuesDelay then
--         RuneReader.Assisted_GenerationDelayTimeStamp = time()
--         return RuneReader.Assisted_LastEncodedResult
--     end
--     RuneReader.Assisted_GenerationDelayTimeStamp = time()


--     --   local _, _, _, latencyWorld = GetNetStats()
--     local curTime = RuneReader.GetTime()
--     local SpellID = RuneReader.GetNextCastSpell(false)
    
--     if not SpellID then return RuneReader.Assisted_LastEncodedResult end
--     local spellInfo1 = RuneReader.GetSpellInfo(SpellID);


--     SpellID, spellInfo1 = RuneReader:ResolveOverrides(SpellID)


--     if not (RuneReader.SpellbookSpellInfo[SpellID] and RuneReader.SpellbookSpellInfo[SpellID].spellID) then
--         return RuneReader.Assisted_LastEncodedResult
--     end
--     local info = RuneReader.SpellbookSpellInfo[SpellID]
   
--     if not info then
--         RuneReader:BuildAllSpellbookSpellMap()
--         info = RuneReader.SpellbookSpellInfo[SpellID]
--         if not info then return RuneReader.Assisted_LastEncodedResult end
--     end

--     if info.hotkey or info.hotkey == "" then
--         info.hotkey = RuneReader.SpellbookSpellInfo[spellInfo1.spellID].hotkey or ""
--     end 
--     if not info.hotkey or info.hotkey == "" then
--         info.hotkey = RuneReader.SpellbookSpellInfoByName[spellInfo1.name].hotkey or ""
--     end


--     if RuneReader.SpellIconFrame then
--         RuneReader:SetSpellIconFrame(SpellID, info.hotkey)
--     end
--     local sCurrentSpellCooldown = RuneReader.GetSpellCooldown(SpellID)
--     spellInfo1 = RuneReader.GetSpellInfo(SpellID);
--     local duration = sCurrentSpellCooldown.duration







--     -- Wait time until cooldown ends
--     local wait = 0
--     local queueMS = tonumber(GetCVar("SpellQueueWindow")  ) or 50
--     local queueSec = queueMS / 1000
--     sCurrentSpellCooldown.startTime = (sCurrentSpellCooldown.startTime) + duration - ((RuneReaderRecastDB.PrePressDelay or 0) + queueSec)

--     wait = sCurrentSpellCooldown.startTime - curTime

--     wait = RuneReader:Clamp(wait, 0, 9.99)
--     -- Encode fields
--     local keytranslate = RuneReader:RuneReaderEnv_translateKey(info.hotkey)                          -- 2 digits
--     local cooldownEnc = string.format("%04d", math.min(9999, math.floor((info.cooldown or 0) * 10))) -- 4 digits
--     local castTimeEnc = string.format("%04d", math.min(9999, math.floor((info.castTime or 0) * 10))) -- 4 digits
--     local bitMask = 0
--     if RuneReader.UnitCanAttack("player", "target") then
--         bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 0)
--     end
--     if RuneReader.UnitAffectingCombat("player") then
--         bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 1)
--     end
--     local source = "1" -- 1 = AssistedCombat, 0 = Hekili

--     local combinedValues = mode
--         .. '/B' .. bitMask
--         .. '/W' .. string.format("%04.3f", wait):gsub("[.]", "")
--         .. '/K' .. keytranslate
--     --.. '/D' .. string.format("%04.3f", 0):gsub("[.]", "")
--     --.. '/G' .. string.format("%04.3f", sCooldownResult.duration):gsub("[.]", "")
--     --.. '/L' .. string.format("%04.3f", latencyWorld/1000):gsub("[.]", "")
--     --.. '/A' .. string.format("%08i", spellID or 0):gsub("[.]", "")
--     --.. '/S' .. source


--     local full = combinedValues
--     --print("RuneReader:AssistedCombat_UpdateValues - Full Encoded Result: ", full)
--     RuneReader.Assisted_LastEncodedResult = full
--     return full
-- end
