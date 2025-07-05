RuneReader = RuneReader or {}

RuneReader.ConRO_haveUnitTargetAttackable = false
RuneReader.ConRO_inCombat = false
RuneReader.ConRO_lastSpell = 61304
RuneReader.ConRO_PrioritySpells = { 47528, 2139, 30449, 147362 }  --Interrupts
RuneReader.ConRO_GenerationDelayTimeStamp = time()
RuneReader.ConRO_GenerationDelayAccumulator = 0




function RuneReader:ConRO_UpdateValues(mode)
   local mode = mode or 0

    RuneReader.ConRO_GenerationDelayAccumulator = RuneReader.ConRO_GenerationDelayAccumulator + (time() - RuneReader.ConRO_GenerationDelayTimeStamp)
    if RuneReader.ConRO_GenerationDelayAccumulator < RuneReaderRecastDB.UpdateValuesDelay  then
        RuneReader.ConRO_GenerationDelayTimeStamp = time()
        return RuneReader.LastEncodedResult
    end

    RuneReader.ConRO_GenerationDelayTimeStamp = time()
    if not ConRO then return end --ConRO Doesn't exists just exit


    local curTime = GetTime()
    local _, _, _, latencyWorld = GetNetStats()
    local keyBind = ""
    local SpellID  = ConRO.Spell
-- ConRO Specfic 
	--local oldSkill = self.Spell;




	--local timeShift, currentSpell, gcd = ConRO:EndCast();
	--local iterate = ConRO:NextSpell(timeShift, currentSpell, gcd, self.PlayerTalents, self.PvPTalents);
	--ConRO.Spell = ConRO.SuggestedSpells[1];

	--ConRO:GetTimeToDie();
--	ConRO:UpdateRotation();
--	ConRO:UpdateButtonGlow();

	local spellName, spellTexture;
	-- Get info for the first suggested spell
	if SpellID then
		if type(SpellID) == "string" then
			ConRO.Spell = tonumber(SpellID)
			--spellName, _, _, _, _, _, _, _, _, spellTexture = C_Item.GetItemInfo(SpellID);
		else
			local spellInfo1 = C_Spell.GetSpellInfo(SpellID);
			--spellName = spellInfo1 and spellInfo1.name;
			--spellTexture = spellInfo1 and spellInfo1.originalIconID;
		end
	end
    keyBind =  ConRO:FindKeybinding(SpellID)



-- End ConRO Specific


   
  if not SpellID then return RuneReader.ConRO_LastEncodedResult end

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
local spellInfo1 = C_Spell.GetSpellInfo(SpellID);

   local sCooldownResult = C_Spell.GetSpellCooldown(61304) -- find the GCD
    -- Wait time until cooldown ends
    local wait = 0
    if sCurrentSpellCooldown.startTime > 0 then
        wait = sCurrentSpellCooldown.startTime + sCurrentSpellCooldown.duration - curTime  - (RuneReaderRecastDB.PrePressDelay or 0)
        if wait < 0 then wait = 0 end
        if wait > 9.99 then wait = 9.99 end
    end



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