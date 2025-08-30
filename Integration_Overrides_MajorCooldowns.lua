-- Integration_Overrides_MajorCooldowns.lua
RuneReader = RuneReader or {}

RuneReader.MajorCooldownThreshold = 30
RuneReader.MajorCooldownExceptions = {
    [19574] = true, -- Bestial Wrath (cast often despite long base)
    -- add more exceptions here
}

-- Classifier: uses precomputed cooldown from the spell map
function RuneReader:IsMajorCooldown(spellID)
    if not spellID then return false end

    if RuneReader.MajorCooldownExceptions[spellID] == nil then return false end
    if RuneReader.SpellbookSpellInfo[spellID].cooldown == nil then return false end

    local cd = 0
    cd = tonumber(RuneReader.SpellbookSpellInfo[spellID].cooldown) --or 0
    return cd > (RuneReader.MajorCooldownThreshold or 30)
end

function RuneReader:IsMajorCooldownAlwaysUse(spellID)
    if not spellID then return false end
    if RuneReader.MajorCooldownExceptions[spellID] then return true end 
    return false
end




-- Candidate-aware chooser: prefer provided queue (Assisted/Hekili), else fallback
function RuneReader:GetNextNonMajorSpell(currentSpellID, candidates)
    -- 1) walk candidates first
    if candidates and type(candidates) == "table" then
        for _, id in ipairs(candidates) do
            if id and (id ~= currentSpellID) and not RuneReader:IsMajorCooldown(id) then
                return id
            end
        end
    end
    
   -- print("Fallback to rotation provider")
    -- 2) fallback: ask the active provider for its rotation list
    if RuneReader.GetNextInstantCastSpell then
        return RuneReader:GetNextInstantCastSpell()
        --local spells = RuneReader.GetRotationSpells()
        -- if spells and #spells > 0 then
        --     for _, id in ipairs(spells) do
        --         if id and (id ~= currentSpellID) and not RuneReader:IsMajorCooldown(id) then
        --             return id
        --         end
        --     end
        -- end
    end

    return nil
end
