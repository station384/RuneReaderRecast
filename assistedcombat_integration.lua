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

--  function RuneReader:GetHotkeyForSpell(spellID)
--     for i = 120, 1, -1 do
--         if HasAction(i) then
--             local actionType, id, _ = GetActionInfo(i)
--             if actionType == "spell" and id == spellID then
--            --     print(i .. "found " .. spellID)
--                 local buttonName = "ActionButton" .. i
--                 local hotkey1, hotkey2 = GetBindingKey("CLICK " .. buttonName .. ":LeftButton")

--           --       print("found " .. hotkey1)
--                 return hotkey1 or ""
--             end
--         end
--     end
--     return ""
-- end


-- function RuneReader:GetBindingNameForActionSlot(slot)
--     -- Slot 1-12: Action Bar
--     if slot >= 1 and slot <= 12 then
--         return "ACTIONBUTTON" .. slot
--     end

--     -- MultiBars: calculate offsets
--    local slotMap = {
--         [13] = "MULTIACTIONBAR1BUTTON",  -- Bar 2
--         [25] = "MULTIACTIONBAR2BUTTON",  -- Bar 3
--         [37] = "MULTIACTIONBAR3BUTTON",  -- Bar 4
--         [49] = "MULTIACTIONBAR4BUTTON",  -- Bar 5
--         [61] = "MULTIACTIONBAR5BUTTON",  -- Bar 6
--         [73] = "MULTIACTIONBAR6BUTTON",  -- Bar 7
--         [85] = "MULTIACTIONBAR7BUTTON",  -- Bar 8
--     }


--     for baseSlot, prefix in pairs(slotMap) do
--         if slot >= baseSlot and slot < baseSlot + 12 then
--             return prefix .. (slot - baseSlot + 1)
--         end
--     end

--     return nil -- Unsupported binding range
-- end

-- function RuneReader:GetHotkeyForSpell(spellID)
--     for slot = 1, 120 do
--         if HasAction(slot) then
--             local actionType, id  = GetActionInfo(slot)
--             if (actionType == "spell" or actionType == "macro" or actionType == "item") and id == spellID then
--                 local bindingName = RuneReader:GetBindingNameForActionSlot(slot)
--                     print(actionType .." ".. id .. " " .. spellID .. " ".. bindingName)
--                 if bindingName then
--                     local key1, key2 = GetBindingKey(bindingName)
--                     return key1 or key2 or ""
--                 end
--             end
--         end
--     end
--     return ""
-- end


--GOING TO BRUTE FORCE THIS.
-- function RuneReader:GetHotkeyForSpell(spellID)
--   -- I don't care about slots.   I only want to know what the user sees and for that I am going to it the _G till bliz shuts me down.
--   -- ActionBar1
-- --  for slot = 1,12 do
-- --  end
--    local result =  ActionButtonUtil.GetActionButtonBySpellID(spellID)
--    local keyBind = ""
--     if result then
--         keyBind = result.HotKey:GetText()
--         print(keyBind)
--         keyBind = keyBind or ""
--     end
--   return keyBind:gsub("-", ""):upper()
-- end

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


function RuneReader:BuildAssistedSpellMap()
    RuneReader.AssistedCombatSpellInfo = {}
    local rotation = C_AssistedCombat.GetRotationSpells()
    for _, spellID in ipairs(rotation or {}) do
        local sSpellInfo = C_Spell.GetSpellInfo(spellID)
        local sSpellCoolDown = C_Spell.GetSpellCooldown(spellID)
        local hotkey = RuneReader:GetHotkeyForSpell(spellID)
       --  print(hotkey)
       -- print(spellID .. " " .. sSpellInfo.name.." "..sSpellCoolDown.duration.." "..hotkey)
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
    -- for i = 1, 12 do
    -- local key = GetBindingKey("MULTIACTIONBAR7BUTTON" .. i)
    -- print("Bar 7 slot", i, "bound to:", key)
    -- end
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
        local spellID = AssistedCombatManager.lastNextCastSpellID or C_AssistedCombat.GetNextCastSpell(true)

    if not spellID then return RuneReader.Assisted_LastEncodedResult end
    local info = RuneReader.AssistedCombatSpellInfo[spellID]
    if not info then
        print("Building map")
        RuneReader:BuildAssistedSpellMap()
        info = RuneReader.AssistedCombatSpellInfo[spellID]
        if not info then return RuneReader.Assisted_LastEncodedResult end
    end
 local sCurrentSpellCooldown = C_Spell.GetSpellCooldown(spellID)

    -- Wait time until cooldown ends
    local wait = 0
    if sCurrentSpellCooldown.startTime > 0 then
        wait = sCurrentSpellCooldown.startTime + sCurrentSpellCooldown.duration - curTime
    end
    if wait < 0 then wait = 0 end
    if wait > 9.99 then wait = 9.99 end
    local sCooldownResult = C_Spell.GetSpellCooldown(61304) -- find the GCD
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

    local combinedValues =  mode .. 
                            ',B' .. bitMask .. 
                            ',W' .. string.format("%04.3f", wait):gsub("[.]", "") ..
                            ',K' .. keytranslate .. 
                            ',D' .. string.format("%04.3f", 0):gsub("[.]", "") ..
                            ',G' .. string.format("%04.3f", sCooldownResult.duration):gsub("[.]", "") ..
                            ',L' .. string.format("%04.3f", latencyWorld/1000):gsub("[.]", "") ..
                            ',A' .. string.format("%08i", spellID or 0):gsub("[.]", "") ..
                            ',S' .. source


    local full = combinedValues

    RuneReader.Assisted_LastEncodedResult = full
    return full
end
