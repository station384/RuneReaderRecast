-- assistedcombat_integration.lua: Integration with Blizzard's AssistedCombat system
-- Total beta.   No real info on the API has been released yet.  This is all Guesswork



RuneReader = RuneReader or {}
RuneReader.AssistedCombatSpellInfo = RuneReader.AssistedCombatSpellInfo or {}
RuneReader.lastAssistedSpell = nil
RuneReader.Assisted_LastEncodedResult = "00000000"
RuneReader.Assisted_GenerationDelayTimeStamp = time()
RuneReader.Assisted_GenerationDelayAccumulator = 0

local function GetHotkeyForSpell(spellID)
    for i = 1, 120 do
        if HasAction(i) then
            local actionType, id, _ = GetActionInfo(i)
            if actionType == "spell" and id == spellID then
                local buttonName = "ActionButton" .. i
                local hotkey = GetBindingKey("CLICK " .. buttonName .. ":LeftButton")
                return hotkey or ""
            end
        end
    end
    return ""
end


function RuneReader:BuildAssistedSpellMap()
    RuneReader.AssistedCombatSpellInfo = {}
    local rotation = C_AssistedCombat.GetRotationSpells()
    for _, spellID in ipairs(rotation or {}) do
        local name, _, icon, castTime = C_Spell.GetSpellInfo(spellID)
        local start, duration, enabled = GetSpellCooldown(spellID)
        local hotkey = GetHotkeyForSpell(spellID)

        -- This info is going to need alot of work.   Mainly for push and hold spells like the evoker.
        -- Choosing the time will be a big deal as it will.
        -- also have to take into account GCD.
        RuneReader.AssistedCombatSpellInfo[spellID] = {
            name = name or "",
            cooldown = (duration or 0),
            castTime = (castTime or 0) / 1000,
            startTime = start or 0,
            hotkey = hotkey
        }
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
--C (A) Keymapping Checksum quick calculation of Keymapping values, this will be "unique" to the total values in the keymapping parameter

function RuneReader:UpdateAssistedCombatValues()
    RuneReader.Assisted_GenerationDelayAccumulator = RuneReader.Assisted_GenerationDelayAccumulator + (time() - RuneReader.Assisted_GenerationDelayTimeStamp)
    if RuneReader.Assisted_GenerationDelayAccumulator < RuneReaderRecastDB.UpdateValuesDelay then
        RuneReader.Assisted_GenerationDelayTimeStamp = time()
        return RuneReader.Assisted_LastEncodedResult
    end
    RuneReader.Assisted_GenerationDelayTimeStamp = time()

    local curTime = GetTime()
    local spellID = C_AssistedCombat.GetNextCastSpell(true)
    if not spellID then return RuneReader.Assisted_LastEncodedResult end

    local info = RuneReader.AssistedCombatSpellInfo[spellID]
    if not info then
        RuneReader:BuildAssistedSpellMap()
        info = RuneReader.AssistedCombatSpellInfo[spellID]
        if not info then return RuneReader.Assisted_LastEncodedResult end
    end

    -- Wait time until cooldown ends
    local wait = 0
    if info.startTime > 0 then
        wait = info.startTime + info.cooldown - curTime
    end
    if wait < 0 then wait = 0 end
    if wait > 9.99 then wait = 9.99 end

    -- Encode fields
    local keytranslate = RuneReader:RuneReaderEnv_translateKey(info.hotkey, wait)  -- 5 digits
    local cooldownEnc = string.format("%03d", math.min(999, math.floor((info.cooldown or 0) * 10)))  -- 3 digits
    local castTimeEnc = string.format("%02d", math.min(99, math.floor((info.castTime or 0) * 10)))  -- 2 digits
    local bitMask = 0
    if UnitCanAttack("player", "target") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 0)
    end
    if UnitAffectingCombat("player") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 1)
    end
    local source = "1"  -- 1 = AssistedCombat, 0 = Hekili
    local baseStr = keytranslate .. cooldownEnc .. castTimeEnc .. bitMask .. source
    local checkDigit = RuneReader:CalculateCheckDigit(baseStr)
    local full = baseStr .. tostring(checkDigit)

    RuneReader.Assisted_LastEncodedResult = full
    return full
end
