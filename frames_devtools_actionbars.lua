-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

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
            SetBinding("", "ACTIONBUTTON" .. slot)
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






SLASH_RuneReaderDevTools1 = "/rdev"
SlashCmdList.RuneReaderDevTools = function()
    RuneReader:ShowActionBarDebugWindow()
end
SLASH_RuneReaderDevToolsBars1 = "/rdevbars"
SlashCmdList.RuneReaderDevToolsBars = function()
    RuneReader:ShowActionBarSlotsDebugWindow()
end