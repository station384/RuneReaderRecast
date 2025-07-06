-- frames_devtools_actionbars.lua: Developer Action Bar Debug Tool (Internal Use)

RuneReader = RuneReader or {}

local ConfirmDialogs = {
    ClearSlot = {
        text = "Are you sure you want to clear the spell or macro from this slot?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function(data)
            local slotIndex = data.slotIndex
            PickupAction(slotIndex)
            PutItemInBackpack()
            ClearCursor()
            print("Cleared slot:", slotIndex)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    },
    ClearHotkey = {
        text = "Are you sure you want to clear the hotkey for this slot?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function(data)
            local slot = data.slot
            SetBinding(nil, "ACTIONBUTTON" .. slot)
            SaveBindings(GetCurrentBindingSet())
            print("Cleared hotkey for slot", slot)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
}

StaticPopupDialogs["RUNE_READER_CONFIRM_CLEAR_SLOT"] = ConfirmDialogs.ClearSlot
StaticPopupDialogs["RUNE_READER_CONFIRM_CLEAR_HOTKEY"] = ConfirmDialogs.ClearHotkey

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

function RuneReader:BuildAllSpellbookSpellMap()
    RuneReader.SpellbookSpellInfo = {}
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
        for j = offset+1, offset+numSlots do
            local name, subName = C_SpellBook.GetSpellBookItemName(j, Enum.SpellBookSpellBank.Player)
            local spellID = select(2, C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player))
            if spellID then
                local sSpellInfo = C_Spell.GetSpellInfo(spellID)
                local sSpellCoolDown = C_Spell.GetSpellCooldown(spellID)
                local hotkey = RuneReader:GetHotkeyForSpell(spellID)
                RuneReader.SpellbookSpellInfo[spellID] = {
                    name = (sSpellInfo and sSpellInfo.name) or name or "",
                    cooldown = (sSpellCoolDown and sSpellCoolDown.duration) or 0,
                    castTime = (sSpellInfo and sSpellInfo.castTime or 0) / 1000,
                    startTime = (sSpellCoolDown and sSpellCoolDown.startTime) or 0,
                    hotkey = hotkey
                }
            end
        end
    end
    -- Add trinkets from player inventory
    for slotID = 13, 14 do -- Trinket 1 and Trinket 2 slots
        local itemLocation = ItemLocation:CreateFromEquipmentSlot(slotID)
        if itemLocation and C_Item.DoesItemExist(itemLocation) then
            local itemName = C_Item.GetItemName(itemLocation)
            local itemIcon = C_Item.GetItemIcon(itemLocation)
            local startTime, duration, _ = GetInventoryItemCooldown("player", slotID)
            RuneReader.SpellbookSpellInfo[slotID] = {
                name = itemName or ("Trinket " .. slotID),
                cooldown = duration or 0,
                castTime = 0,
                startTime = startTime or 0,
                hotkey = "(Trinket Slot " .. slotID .. ")"
            }
        end
    end
end

function RuneReader:ShowActionBarDebugWindow()
    if self.ActionBarDebugFrame then
        self.ActionBarDebugFrame:Show()
        return
    end

    local frame = CreateFrame("Frame", "RuneReaderActionBarDebugFrame", UIParent, "BackdropTemplate")
    frame:SetSize(700, 900)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame")
    scrollFrame:SetScrollChild(content)
    content:SetSize(1, 1)

    local yOffset = -10

    local header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", 10, yOffset)
    header:SetText("All Spells & Trinkets")
    yOffset = yOffset - 40

    local xOffset = 10
    for spellID, info in pairs(RuneReader.SpellbookSpellInfo or {}) do
        local icon = content:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("TOPLEFT", xOffset, yOffset)
        local sSpellInfo = C_Spell.GetSpellInfo(spellID)
        icon:SetTexture(sSpellInfo and sSpellInfo.iconID or "Interface/Icons/INV_Misc_QuestionMark")

        local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", icon, "TOPRIGHT", 5, -5)
        text:SetJustifyH("LEFT")
        text:SetText((info.name or "Unknown") .. "\nHotkey: " .. (info.hotkey or "") .. "\nCooldown: " .. string.format("%.1f", info.cooldown))

        yOffset = yOffset - 50
    end

    content:SetHeight(-yOffset + 10)

    self.ActionBarDebugFrame = frame
end

function RuneReader:ShowActionBarSlotsDebugWindow()
    if self.ActionBarSlotsDebugFrame then
        self.ActionBarSlotsDebugFrame:Show()
        return
    end

    local frame = CreateFrame("Frame", "RuneReaderActionBarSlotsDebugFrame", UIParent, "BackdropTemplate")
    frame:SetSize(700, 900)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame")
    scrollFrame:SetScrollChild(content)
    content:SetSize(1, 1)

    local yOffset = -10

    local header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetPoint("TOPLEFT", 10, yOffset)
    header:SetText("Action Bar Slots")
    yOffset = yOffset - 40

    for page = 1, NUM_ACTIONBAR_PAGES + 4 do
        local barName = page <= NUM_ACTIONBAR_PAGES and ("Action Bar " .. page) or ("MultiActionBar " .. (page - NUM_ACTIONBAR_PAGES))
        local barHeader = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        barHeader:SetPoint("TOPLEFT", 10, yOffset)
        barHeader:SetText(barName)
        yOffset = yOffset - 30

        local xOffset = 10
        for slot = 1, NUM_ACTIONBAR_BUTTONS do
            local slotIndex
            if page <= NUM_ACTIONBAR_PAGES then
                slotIndex = ((page - 1) * NUM_ACTIONBAR_BUTTONS) + slot
            else
                slotIndex = 120 + ((page - NUM_ACTIONBAR_PAGES - 1) * NUM_ACTIONBAR_BUTTONS) + slot
            end

            local iconTexture = GetActionTexture(slotIndex)
            local hotkey = ""
            local actionType, id = GetActionInfo(slotIndex)
            if actionType == "spell" and id and RuneReader.SpellbookSpellInfo and RuneReader.SpellbookSpellInfo[id] then
                hotkey = RuneReader.SpellbookSpellInfo[id].hotkey or ""
            end

            local icon = content:CreateTexture(nil, "ARTWORK")
            icon:SetSize(36, 36)
            icon:SetPoint("TOPLEFT", xOffset, yOffset)
            icon:SetTexture(iconTexture or "Interface/Icons/INV_Misc_QuestionMark")

            local hotkeyText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            hotkeyText:SetPoint("BOTTOM", icon, "TOP", 0, 2)
            hotkeyText:SetText(hotkey)

            xOffset = xOffset + 42
        end
        yOffset = yOffset - 50
    end

    content:SetHeight(-yOffset + 10)

    self.ActionBarSlotsDebugFrame = frame
end




if not RuneReader.ActionBarSpellMapUpdater then
    RuneReader.ActionBarSpellMapUpdater = CreateFrame("Frame")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("PLAYER_ENTERING_WORLD")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("SPELLS_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    RuneReader.ActionBarSpellMapUpdater:SetScript("OnEvent", function()
        RuneReader:BuildAllSpellbookSpellMap()
    end)
end

SLASH_RuneReaderDevTools1 = "/rdev"
SlashCmdList.RuneReaderDevTools = function()
    RuneReader:ShowActionBarDebugWindow()
end
SLASH_RuneReaderDevToolsBars1 = "/rdevbars"
SlashCmdList.RuneReaderDevToolsBars = function()
    RuneReader:ShowActionBarSlotsDebugWindow()
end