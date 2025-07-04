-- assistedcombat_integration.lua: Integration with Blizzard's AssistedCombat system
-- Total beta.   No real info on the API has been released yet.  This is all Guesswork



RuneReader = RuneReader or {}
RuneReader.AssistedCombatSpellInfo = RuneReader.AssistedCombatSpellInfo or {}
RuneReader.lastAssistedSpell = nil
RuneReader.Assisted_LastEncodedResult = "00000000"
RuneReader.Assisted_GenerationDelayTimeStamp = time()
RuneReader.Assisted_GenerationDelayAccumulator = 0


function RuneReader:IsActionBarPageVisible(barIndex)
    return GetActionBarPage() == barIndex
end

-- Example: is bar 10 visible?
if RuneReader:IsActionBarPageVisible(10) then
    print("Bar 10 is currently visible")
else
    print("Bar 10 is not visible (swapped out)")
end

function RuneReader:GetVisibleActionBarSlotRange()
    local page = GetActionBarPage()
    local startSlot = ((page - 1) * 12) + 1
    local endSlot = startSlot + 11
    return startSlot, endSlot
end



--[[
    File Path: /d:/Games/Blizzard/World of Warcraft/_retail_/Interface/AddOns/RuneReaderRecast/assistedcombat_integration.lua

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
    local button = ActionButtonUtil.GetActionButtonBySpellID(spellID)

    if button then --and button:IsVisible() and button.HotKey and button.HotKey:IsVisible() then
        if button.HotKey then
            local keyText = button.HotKey:GetText()
            if not keyText then keyText = "" end
            if keyText and keyText ~= "" and keyText ~= RANGE_INDICATOR then
                return keyText:gsub("-", ""):upper()
            end
        end
    end
    return ""
end



--[[
This function builds an assisted combat spell map for RuneReader.

It populates the `RuneReader.AssistedCombatSpellInfo` table by retrieving information about each 
spell from C_AssistedCombat.GetRotationSpells() and C_Spell.GetSpellInfo(). The collected data includes:
- Spell name (name)
- Cooldown duration in seconds (cooldown, converted to float if necessary)
- Cast time divided into milliseconds (castTime / 1000 for conversion), defaulting to zero
- Start time of the cooldown period or a fallback value set as needed by C_Spell.GetSpellInfo() 
- A hotkey assigned through RuneReader:GetHotkeyForSpell(spellID) 

The function iterates over each spell ID in `rotation`, which is obtained from an external source, presumably representing spells that can be used assisted combat. The resulting table maps these IDs to their respective properties for easy access and manipulation.

Note: Additional logic may need implementation regarding push/spike timing decisions based on GCD (Global Cooldown) considerations.
]]
function RuneReader:BuildAssistedSpellMap()
   -- RuneReader.AssistedCombatSpellInfo = {}
    local rotation = C_AssistedCombat.GetRotationSpells()
    if rotation then
        for _, spellID in ipairs(rotation) do
            local sSpellInfo = C_Spell.GetSpellInfo(spellID)
            local sSpellCoolDown = C_Spell.GetSpellCooldown(spellID)
            local hotkey = RuneReader:GetHotkeyForSpell(spellID)

            -- This info is going to need alot of work.   Mainly for push and hold spells like the evoker.
            -- Choosing the time will be a big deal as it will.
            -- also have to take into account GCD.

            RuneReader.AssistedCombatSpellInfo[spellID] = {
                name = sSpellInfo.name or "",
                cooldown = (sSpellCoolDown.duration or 0) ,
                castTime = (sSpellInfo.castTime or 0) / 1000,
                startTime = sSpellCoolDown.startTime or 0,
                hotkey = hotkey
            }
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
    RuneReader.Assisted_GenerationDelayAccumulator = RuneReader.Assisted_GenerationDelayAccumulator + (time() - RuneReader.Assisted_GenerationDelayTimeStamp)
    if RuneReader.Assisted_GenerationDelayAccumulator < RuneReaderRecastDB.UpdateValuesDelay then
        RuneReader.Assisted_GenerationDelayTimeStamp = time()
        return RuneReader.Assisted_LastEncodedResult
    end
    RuneReader.Assisted_GenerationDelayTimeStamp = time()
    local _, _, _, latencyWorld = GetNetStats()
    local curTime = GetTime()
    local spellID = C_AssistedCombat.GetNextCastSpell(true)

       -- local spellID = AssistedCombatManager.lastNextCastSpellID or C_AssistedCombat.GetNextCastSpell(true)
      --  local spellID =  C_AssistedCombat.GetNextCastSpell(true)
--        local NextSpellID = C_AssistedCombat.GetNextCastSpell(true)

    if not spellID then return RuneReader.Assisted_LastEncodedResult end
    local info = RuneReader.AssistedCombatSpellInfo[spellID]
    if not info then
        print("Building map")
        RuneReader:BuildAssistedSpellMap()
        info = RuneReader.AssistedCombatSpellInfo[spellID]
        if not info then return RuneReader.Assisted_LastEncodedResult end
    end
    if RuneReader.SpellIconFrame then
      RuneReader:SetSpellIconFrame(spellID, RuneReader.AssistedCombatSpellInfo[spellID].hotkey) 
    end
   local sCurrentSpellCooldown = C_Spell.GetSpellCooldown(spellID)
   --local sNextSpellCooldown = C_Spell.GetSpellCooldown(NextSpellID)
   --local GCD = C_Spell.GetSpellCooldown(61304).duration



   local sCooldownResult = C_Spell.GetSpellCooldown(61304) -- find the GCD
    -- Wait time until cooldown ends
    local wait = 0
    if sCurrentSpellCooldown.startTime > 0 then
        wait = sCurrentSpellCooldown.startTime + sCurrentSpellCooldown.duration - curTime  - (RuneReaderRecastDB.PrePressDelay or 0)
        if wait < 0 then wait = 0 end
        if wait > 9.99 then wait = 9.99 end
    end



    -- Encode fields
    local keytranslate = RuneReader:RuneReaderEnv_translateKey(info.hotkey)  -- 2 digits
    local cooldownEnc = string.format("%04d", math.min(9999, math.floor((info.cooldown or 0) * 10)))  -- 4 digits
    local castTimeEnc = string.format("%04d", math.min(9999, math.floor((info.castTime or 0) * 10)))  -- 4 digits
    local bitMask = 0
    if UnitCanAttack("player", "target") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 0)
    end
    if UnitAffectingCombat("player") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 1)
    end
    local source = "1"  -- 1 = AssistedCombat, 0 = Hekili

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

    RuneReader.Assisted_LastEncodedResult = full
    return full
end
