-- hekili_integration.lua: Interfacing with Hekili and key translation

RuneReader = RuneReader or {}

RuneReader.haveUnitTargetAttackable = false
RuneReader.inCombat = false
RuneReader.lastSpell = 61304
RuneReader.PrioritySpells = { 47528, 2139, 30449, 147362 }  --Interrupts
RuneReader.LastDataPak = {};
RuneReader.GenerationDelayTimeStamp = time()
RuneReader.GenerationDelayAccumulator = 0

function RuneReader:RuneReaderEnv_translateKey(hotKey, wait)
    local encodedKey = "00"
    local encodedWait = "0.0"
    if wait == nil then wait = 0 end
    local keyMap = {
        ["1"] = "01", ["2"] = "02", ["3"] = "03", ["4"] = "04", ["5"] = "05",
        ["6"] = "06", ["7"] = "07", ["8"] = "08", ["9"] = "09", ["0"] = "10",
        ["-"] = "11", ["="] = "12",
        ["CF1"]="21",["CF2"]="22",["CF3"]="23",["CF4"]="24",["CF5"]="25",["CF6"]="26",["CF7"]="27",["CF8"]="28",["CF9"]="29",["CF10"]="30",["CF11"]="31",["CF12"]="32",
        ["AF1"]="41",["AF2"]="42",["AF3"]="43",["AF4"]="44",["AF5"]="45",["AF6"]="46",["AF7"]="47",["AF8"]="48",["AF9"]="49",["AF10"]="50",["AF11"]="51",["AF12"]="52",
        ["F1"]="61",["F2"]="62",["F3"]="63",["F4"]="64",["F5"]="65",["F6"]="66",["F7"]="67",["F8"]="68",["F9"]="69",["F10"]="70",["F11"]="71",["F12"]="72"
    }
    encodedKey = keyMap[hotKey] or "00"
    if wait > 9.99 then wait = 9.99 end
    if wait < 0 then wait = 0 end
    if wait ~= nil then encodedWait = string.format("%04.2f", wait):gsub("[.]", "") end
    return encodedKey .. encodedWait
end

function RuneReader:RuneReaderEnv_hasSpell(tbl, x)
    for _, v in ipairs(tbl) do
        if v == x then return true end
    end
    return false
end

--The returned string is in this format
-- KEY WAIT BIT(0,1) CHECK
-- 00  000  0  0
-- BitMask 0=Target 1=Combat
-- Check quick check if of total values to the left
function RuneReader:UpdateCodeValues()
    RuneReader.GenerationDelayAccumulator = RuneReader.GenerationDelayAccumulator + (time() - RuneReader.GenerationDelayTimeStamp)
    if RuneReader.GenerationDelayAccumulator < RuneReaderRecastDB.UpdateValuesDelay  then
        RuneReader.GenerationDelayTimeStamp = time()
        return RuneReader.LastEncodedResult
    end
    RuneReader.GenerationDelayTimeStamp = time()

    if not Hekili_GetRecommendedAbility then return end

    local curTime = GetTime()
    local _, _, _, latencyWorld = GetNetStats()

    local t1, t2, dataPacPrimary = Hekili_GetRecommendedAbility("Primary", 1)
    local _, _, dataPacNext = Hekili_GetRecommendedAbility("Primary", 2)
    local _, _, dataPacAoe = Hekili_GetRecommendedAbility("AOE", 1)

    if not t1 or not dataPacPrimary then
        dataPacPrimary = RuneReader.LastDataPak
    end

    if not dataPacPrimary then dataPacPrimary = {} end
    if dataPacPrimary.actionID == nil then
        dataPacPrimary.delay = 0; dataPacPrimary.wait = 0; dataPacPrimary.keybind = nil; dataPacPrimary.actionID = nil
    end

    RuneReader.LastDataPak = dataPacPrimary

    if dataPacNext and RuneReader:RuneReaderEnv_hasSpell(RuneReader.PrioritySpells, dataPacNext.actionID) then
        dataPacPrimary = dataPacNext
    end

    if not dataPacPrimary.delay then dataPacPrimary.delay = 0 end
    if not dataPacPrimary.wait then dataPacPrimary.wait = 0 end
    if not dataPacPrimary.exact_time then dataPacPrimary.exact_time = curTime end
    if not dataPacPrimary.keybind then dataPacPrimary.keybind = "" end

    local delay = dataPacPrimary.delay
    local wait = dataPacPrimary.wait

    if RuneReader.lastSpell ~= dataPacPrimary.actionID then RuneReader.lastSpell = dataPacPrimary.actionID end

    if wait == 0 then dataPacPrimary.exact_time = curTime end

    if UnitCanAttack("player", "target") then
        RuneReader.haveUnitTargetAttackable = true
    else
        RuneReader.haveUnitTargetAttackable = false
    end
    if dataPacPrimary.actionID ~= nil and C_Spell.IsSpellHarmful(dataPacPrimary.actionID) == false then
        RuneReader.haveUnitTargetAttackable = true
    end

    local exact_time = ((dataPacPrimary.exact_time + delay) - (wait)) - (RuneReaderRecastDB.PrePressDelay or 0)
    local countDown = (exact_time - curTime)
    if countDown <= 0 then countDown = 0 end

    local bitvalue = 0
    if RuneReader.haveUnitTargetAttackable then
        bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 0)
    end
    if RuneReader.inCombat then
        bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 1)
    end

    local keytranslate = RuneReader:RuneReaderEnv_translateKey(dataPacPrimary.keybind, countDown)
    if AuraUtil and AuraUtil.FindAuraByName then
        if AuraUtil.FindAuraByName("G-99 Breakneck", "player", "HELPFUL") then
            keytranslate = "00000"
        end
        if AuraUtil.FindAuraByName("Unstable Rocketpack", "player", "HELPFUL") then
            keytranslate = "00000"
        end
    end

    local combinedValues = keytranslate .. bitvalue
    local checkDigit = RuneReader:CalculateCheckDigit(combinedValues)
    local fullResult = combinedValues .. checkDigit
    RuneReader.LastEncodedResult = fullResult
    return fullResult
end
