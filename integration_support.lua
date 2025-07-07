  -- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

  RuneReader = RuneReader or {}

  function RuneReader:GetUpdatedValues()
   local fullResult = ""
    if  Hekili  and (RuneReaderRecastDBPerChar.HelperSource == 0) then
      fullResult = RuneReader:Hekili_UpdateValues(1) --Standard code39 for now.....
    --  print("from Hekili", fullResult)
      return fullResult
    elseif ConRO and (RuneReaderRecastDBPerChar.HelperSource == 2) then
      fullResult = RuneReader:ConRO_UpdateValues(1) --Standard code39 for now.....
     -- print("from ConRo", fullResult)
      return fullResult
    else
    -- Fallback to AssistedCombat as it should always be available. if prior arnt selected or not available
    fullResult = RuneReader:AssistedCombat_UpdateValues(1)
       --   print("from Combat Assist", fullResult)
    end

    return fullResult
  end

  function RuneReader:GetActionBindingKey(page, slot, slotIndex)
    local actionType, id = GetActionInfo(slotIndex)
    if actionType == "spell" and id then
        return self:GetHotkeyForSpell(id)
    end

    if page <= NUM_ACTIONBAR_PAGES then
        return GetBindingKey("ACTIONBUTTON" .. slot)
    else
        local barIndex = page - NUM_ACTIONBAR_PAGES
        return GetBindingKey("MULTIACTIONBAR" .. barIndex .. "BUTTON" .. slot)
    end
end

-- Additional Item Mapping in Spellbook Map
function RuneReader:BuildAllSpellbookSpellMap()
    RuneReader.SpellbookSpellInfo = RuneReader.SpellbookSpellInfo or {}
    RuneReader.SpellbookSpellInfoByName = RuneReader.SpellbookSpellInfoByName or {}
   -- print ("Building Spellbook Spell Map...")
    -- Add equipped items to SpellbookSpellInfo
    for slotID = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local itemID = GetInventoryItemID("player", slotID)
        if itemID then
            local itemIcon = GetInventoryItemTexture("player", slotID)
            local startTime, duration = GetInventoryItemCooldown("player", slotID)

            RuneReader.SpellbookSpellInfo[-slotID] = {
                name = C_Item.GetItemInfo(itemID) or ("Item " .. slotID),
                cooldown = duration or 0,
                castTime = 0,
                startTime = startTime or 0,
                hotkey = "(Equipped Slot " .. slotID .. ")",
                icon = itemIcon
            }
        end
    end

    -- Add spellbook spells using modern Retail API
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        if  skillLineInfo then
            --print("No skill line info for index", i)
       
        
          local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
          for j = offset + 1, offset + numSlots do
              local name, subName = C_SpellBook.GetSpellBookItemName(j, Enum.SpellBookSpellBank.Player)
              local itemtype,actionId,spellID = C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player)
              local _, actionId, spellID = C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player)
              spellID = spellID or actionId
  --            local spellID =  spellID or actionId
              if spellID then
                  local sSpellInfo = C_Spell.GetSpellInfo(spellID)
                  local sSpellCoolDown = C_Spell.GetSpellCooldown(spellID)
                  local hotkey = RuneReader:GetHotkeyForSpell(spellID)
                  if (  sSpellInfo and sSpellInfo.name) then
                    RuneReader.SpellbookSpellInfoByName[sSpellInfo.name] =  
                    { name   = (sSpellInfo and sSpellInfo.name ) or "",
                      cooldown = (sSpellCoolDown and sSpellCoolDown.duration) or 0,
                      castTime = (sSpellInfo and sSpellInfo.castTime / 1000) or 0,
                      startTime = (sSpellCoolDown and sSpellCoolDown.startTime) or 0,
                      hotkey = hotkey
                  }
                  end
                  RuneReader.SpellbookSpellInfo[spellID] = {
                      name = (sSpellInfo and sSpellInfo.name or name) or "",
                      cooldown = (sSpellCoolDown and sSpellCoolDown.duration) or 0,
                      castTime = (sSpellInfo and sSpellInfo.castTime / 1000) or 0,
                      startTime = (sSpellCoolDown and sSpellCoolDown.startTime) or 0,
                      hotkey = hotkey
                  }
              end
        
          end 
        end
      end
end
if not RuneReader.ActionBarSpellMapUpdater then
    RuneReader.ActionBarSpellMapUpdater = CreateFrame("Frame")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("PLAYER_ENTERING_WORLD")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("SPELLS_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
    RuneReader.ActionBarSpellMapUpdater:SetScript("OnEvent", function()
        RuneReader:BuildAllSpellbookSpellMap()
    end)
end