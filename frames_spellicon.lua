-- frames_spellicon.lua: Spell icon window with text label

RuneReader = RuneReader or {}

function RuneReader:CreateSpellIconFrame()
    if self.SpellIconFrame then return end

    local f = CreateFrame("Frame", "RuneReaderSpellIconFrame", UIParent, "BackdropTemplate")
    f:SetSize(64, 64)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0, 0, 0, 0.8)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart",function(self) 
        if IsAltKeyDown() then self:StartMoving() end    
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        RuneReaderRecastDB.SpellIconPosition = {
            point = point,
            relativeTo = "UIParent",
            relativePoint = relativePoint,
            x = xOfs,
            y = yOfs
        }
    end)

    if RuneReaderRecastDB and RuneReaderRecastDB.SpellIconPosition then
        local pos = RuneReaderRecastDB.SpellIconPosition
        f:ClearAllPoints()
        f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    end

    -- Text label above icon
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", f, "TOP", 0, 12)
    label:SetText("")

    -- Spell icon
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(48, 48)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    icon:EnableMouse(false)
  

    f:SetScript("OnEnter", function(self)
        if f.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(f.spellID)
            GameTooltip:Show()
        end
    end)

    f:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    f.Label = label
    f.Icon = icon

    self.SpellIconFrame = f
end

function RuneReader:DestroySpellIconFrame()
    if self.SpellIconFrame then
        self.SpellIconFrame:Hide()
        self.SpellIconFrame:SetParent(nil)
        self.SpellIconFrame = nil
    end
end

function RuneReader:SetSpellIconFrame(spellID, labelText)
    if not self.SpellIconFrame then return end

    local data = C_Spell.GetSpellInfo(spellID)
    if data.iconID then
        self.SpellIconFrame.Icon:SetTexture(data.iconID)
    else
        self.SpellIconFrame.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    self.SpellIconFrame.Label:SetText(labelText or "")
     self.SpellIconFrame.spellID = spellID
end

