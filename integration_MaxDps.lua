-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html


RuneReader = RuneReader or {}

RuneReader.MaxDps_haveUnitTargetAttackable = false
RuneReader.MaxDps_inCombat = false
RuneReader.MaxDps_lastSpell = 61304
RuneReader.MaxDps_PrioritySpells = { 47528, 2139, 30449, 147362 }  --Interrupts
RuneReader.MaxDps_GenerationDelayTimeStamp = time()
RuneReader.MaxDps_GenerationDelayAccumulator = 0
-- RuneReader.hekili_LastEncodedResult = "1,B0,W0001,K00"


function RuneReader:CleanMaxDpsHotKey(HotKeyText)
    local keyText = HotKeyText
    if not keyText then keyText = "" end
    if keyText and keyText ~= "" and keyText ~= RANGE_INDICATOR then
        keyText = keyText:gsub("CTRL", "C")
        keyText = keyText:gsub("ALT", "A")
        return keyText:gsub("-", ""):upper()
    end
end

function RuneReader:MaxDps_GetSpell(item)

   local result = nil
   result = MaxDps.Spell or RuneReader.GetNextCastSpell(false)
   local intCount = 1
    for index, value in pairs(MaxDps.SpellsGlowing) do
        if (intCount == item and value == 1) then
            result = index
        end
        intCount = intCount + 1
    end
    return result
end

function RuneReader:MaxDps_UpdateValues(mode)
    if not MaxDps or not MaxDps.db then return nil end --MaxDps Doesn't exists just exit
    if RuneReaderRecastDBPerChar.HelperSource ~= 3 then return end
    mode = mode or 1

    RuneReader.MaxDps_GenerationDelayAccumulator = RuneReader.MaxDps_GenerationDelayAccumulator + (time() - RuneReader.MaxDps_GenerationDelayTimeStamp)
    if RuneReader.MaxDps_GenerationDelayAccumulator <= RuneReaderRecastDB.UpdateValuesDelay then
        RuneReader.MaxDps_GenerationDelayTimeStamp = time()
        return RuneReader.LastEncodedResult
    end

    RuneReader.MaxDps_GenerationDelayTimeStamp = time()

    local curTime                             = RuneReader.GetTime()
    --    local _, _, _, latencyWorld = GetNetStats()
    local keyBind                             = ""
    local SpellID                             = RuneReader:MaxDps_GetSpell(1)
    if not SpellID then return RuneReader.MaxDps_LastEncodedResult end

    if not SpellID then SpellID = 0 end

    local spellInfo1 = RuneReader.GetSpellInfo(SpellID)
    --#region Check for fallback on movement
    -- Check if were moving,  if we are we can't cast a spell with a cast time.  So lets check if any are in queue that are instant cast and use that instead.
    -- This is a totally dumb segment,  it doesn't check for any conditions,  it just checks if the spell is instant cast and uses that.

    if RuneReaderRecastDB.UseInstantWhenMoving == true then
        if (spellInfo1.castTime > 0 or RuneReader:IsSpellIDInChanneling(SpellID)) and RuneReader:IsPlayerMoving() then
            SpellID    = RuneReader:MaxDps_GetSpell(2) or SpellID
        end
        if (spellInfo1.castTime > 0 or RuneReader:IsSpellIDInChanneling(SpellID)) and RuneReader:IsPlayerMoving() then
            SpellID    = RuneReader:MaxDps_GetSpell(3) or SpellID
        end
        if (spellInfo1.castTime > 0 or RuneReader:IsSpellIDInChanneling(SpellID)) and RuneReader:IsPlayerMoving() then
            SpellID    = RuneReader:GetNextInstantCastSpell() or SpellID
        end
    end
    --#endregion



    --#region Spell Exlude checks
    if RuneReader:IsSpellExcluded(SpellID) then
        SpellID = RuneReader:MaxDps_GetSpell(2) or SpellID
        if RuneReader:IsSpellExcluded(SpellID) then
            SpellID = RuneReader:MaxDps_GetSpell(3) or SpellID
            if RuneReader:IsSpellExcluded(SpellID) then
                SpellID = RuneReader:GetNextInstantCastSpell() or SpellID
            end
        end
    end
    --#endregion


    --#region Should we self heal segment
    -- MaxDps doesn't have any self healing routines,  so we will just check if we are below 50% health and use a self heal if we are.
    -- So we will add some.    I am starting with the druid for now.   More will be added later.
    if RuneReaderRecastDB.UseSelfHealing == true then
        -- Hunter Pet healing
        -- print("Self Healding is enabled")
        
        --Hunter check
        local ShouldHealPet = RuneReader:ShouldCastMendPet()
        local ShouldRevivePet = RuneReader:ShouldCastRevivePet()
        local ShouldCastExhilaration = RuneReader:ShouldCastExhilaration()
        --Druid check
        local ShouldBearHeal = RuneReader:ShouldCastBearOrRegen()
        local ShouldCastRejuvenationIfNeeded = RuneReader:ShouldCastRejuvenationIfNeeded()
        local ShouldCastIronfur = RuneReader:ShouldCastIronfur()
        local ShouldCastNaturesVigil = RuneReader:ShouldCastNaturesVigil()
        local ShouldCastBarkskin = RuneReader:ShouldCastBarkskin()
        --Paladin check
        local ShouldCastWordOfGlory = RuneReader:ShouldCastWordOfGlory()
        --Death Knight check
        local ShouldCastDeathStrike = RuneReader:ShouldCastDeathStrike()
        local ShouldCastMarrowrend = RuneReader:ShouldCastMarrowrend()
        local ShouldCastRuneTap = RuneReader:ShouldCastRuneTap()
        --Mage check
        local ShouldCastMageDefensive = RuneReader:ShouldCastMageDefensive()
        --Monk check
        local ShouldCastExpelHarm = RuneReader:ShouldCastExpelHarm()
        local ShouldCastPurifyingBrew = RuneReader:ShouldCastPurifyingBrew()
        local ShouldCastVivifyBrewmaster = RuneReader:ShouldCastVivifyBrewmaster()
        local ShouldCastCelestialBrew = RuneReader:ShouldCastCelestialBrew()
        -- Rogue check
        local ShouldCastCrimsonVial = RuneReader:ShouldCastCrimsonVial()
        -- Warrior check
        local ShouldCastImpendingVictory = RuneReader:ShouldCastImpendingVictory()
        local ShouldCastShieldBlock = RuneReader:ShouldCastShieldBlock()
        -- Priest check
        local ShouldCastPowerWordShield = RuneReader:ShouldCastPowerWordShield()
        -- Shaman check
        local ShouldCastHealingSurge = RuneReader:ShouldCastHealingSurge()
        -- Evoker check
        local ShouldCastObsidianScales = RuneReader:ShouldCastObsidianScales()





        -- print("ShouldHealPet", ShouldHealPet, "ShouldRevivePet", ShouldRevivePet, "ShouldBearHeal", ShouldBearHeal)
        if ShouldHealPet then
            SpellID    = ShouldHealPet or SpellID
        elseif ShouldRevivePet then
            SpellID    = ShouldRevivePet or SpellID
        elseif ShouldCastExhilaration then
            SpellID    = ShouldCastExhilaration or SpellID
        elseif ShouldBearHeal then
            SpellID    = ShouldBearHeal or SpellID
        elseif ShouldCastRejuvenationIfNeeded then
            SpellID    = ShouldCastRejuvenationIfNeeded or SpellID
        elseif ShouldCastWordOfGlory then
            SpellID    = ShouldCastWordOfGlory or SpellID
        elseif ShouldCastDeathStrike then
            SpellID    = ShouldCastDeathStrike or SpellID
        elseif ShouldCastMarrowrend then
            SpellID = ShouldCastMarrowrend
        elseif ShouldCastRuneTap then
            SpellID = ShouldCastRuneTap
        elseif ShouldCastMageDefensive then
            SpellID    = ShouldCastMageDefensive or SpellID
        elseif ShouldCastExpelHarm then
            SpellID    = ShouldCastExpelHarm or SpellID
        elseif ShouldCastCelestialBrew then
            SpellID = ShouldCastCelestialBrew
        elseif ShouldCastCrimsonVial then
            SpellID    = ShouldCastCrimsonVial or SpellID
        elseif ShouldCastImpendingVictory then
            SpellID = ShouldCastImpendingVictory or SpellID
        elseif ShouldCastShieldBlock then
            SpellID = ShouldCastShieldBlock
        elseif ShouldCastPowerWordShield then
            SpellID = ShouldCastPowerWordShield or SpellID
        elseif ShouldCastHealingSurge then
            SpellID = ShouldCastHealingSurge or SpellID
        elseif ShouldCastObsidianScales then
            SpellID = ShouldCastObsidianScales or SpellID
        elseif ShouldCastIronfur then
            SpellID = ShouldCastIronfur or SpellID
        elseif ShouldCastNaturesVigil then
            SpellID = ShouldCastNaturesVigil or SpellID
        elseif ShouldCastBarkskin then
            SpellID = ShouldCastBarkskin or SpellID
       elseif ShouldCastPurifyingBrew then
            SpellID = ShouldCastPurifyingBrew or SpellID
        elseif ShouldCastVivifyBrewmaster then
            SpellID = ShouldCastVivifyBrewmaster or SpellID
        end

    end
    --#endregion
     spellInfo1 = RuneReader.GetSpellInfo(SpellID)
    if (RuneReader.SpellbookSpellInfo and RuneReader.SpellbookSpellInfo[SpellID] and RuneReader.SpellbookSpellInfo[SpellID].hotkey) then
        keyBind = RuneReader.SpellbookSpellInfo[SpellID].hotkey or ""
    else
      if (RuneReader.SpellbookSpellInfoByName and RuneReader.SpellbookSpellInfoByName[spellInfo1.name] and RuneReader.SpellbookSpellInfoByName[spellInfo1.name].hotkey) then
            keyBind = RuneReader.SpellbookSpellInfoByName[spellInfo1.name].hotkey or ""
      end
    end




    if RuneReader.SpellIconFrame then
        RuneReader:SetSpellIconFrame(SpellID, keyBind)
    end

    
    local sCurrentSpellCooldown = RuneReader.GetSpellCooldown(SpellID)
    local delay = (spellInfo1.castTime / 1000)
    local duration = sCurrentSpellCooldown.duration


    --  local GCD = RuneReader.GetSpellCooldown(61304).duration -- find the GCD
    if sCurrentSpellCooldown.duration == 0 or not sCurrentSpellCooldown.duration then GCD = 0 end

    local wait = 0 --=timeShift
    local queueMS = tonumber(GetCVar("SpellQueueWindow") ) or 50
    local queueSec = queueMS / 1000
    sCurrentSpellCooldown.startTime = (sCurrentSpellCooldown.startTime) + duration -
    ((RuneReaderRecastDB.PrePressDelay  or 0) + queueSec)
    wait = sCurrentSpellCooldown.startTime - curTime






    wait = RuneReader:Clamp(wait, 0, 9.99)
    --print (sCurrentSpellCooldown.duration,(spellInfo1.castTime/1000),wait)

    -- Encode fields
    local keytranslate = RuneReader:RuneReaderEnv_translateKey(keyBind) -- 2 digits
    -- local cooldownEnc = string.format("%04d", math.min(9999, math.floor((sCurrentSpellCooldown.duration or 0) * 10)))  -- 4 digits
    -- local castTimeEnc = string.format("%04d", math.min(9999, math.floor(((spellInfo1.castTime or 0) / 1000 or 0) * 10)))  -- 4 digits
    local bitMask = 0
    if RuneReader.UnitCanAttack("player", "target") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 0)
    end
    if RuneReader.UnitAffectingCombat("player") then
        bitMask = RuneReader:RuneReaderEnv_set_bit(bitMask, 1)
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
    return full
end
