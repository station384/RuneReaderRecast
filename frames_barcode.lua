-- frames_barcode.lua: Barcode window management

RuneReader = RuneReader or {}

RuneReader.lastC39EncodeResult = "1A2Z!U"
RuneReader.C39FrameDelayAccumulator = 0

function RuneReader:CreateBarcodeWindow()
    if self.BarcodeFrame and self.BarcodeFrame:IsShown() then
        return
    elseif self.BarcodeFrame then
        self.BarcodeFrame:Show()
        return
    end

    local f = CreateFrame("Frame", "RuneReaderBarcodeFrame", UIParent, "BackdropTemplate")
    f:SetSize(220, 50)
    f:SetPoint("TOP", UIParent, "TOP", 0, 0)
    f:SetFrameStrata("TOOLTIP")
    f:SetMovable(true)
    f:SetResizable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if IsAltKeyDown() then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        RuneReaderRecastDB = RuneReaderRecastDB or {}
        RuneReaderRecastDB.C39Position = {
            point = point,
            relativeTo = "UIParent",
            relativePoint = relativePoint,
            x = xOfs,
            y = yOfs
        }
    end)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetBackdropColor(0.3, 0.2, 0, 1)
    f:SetResizeBounds(220,50)

    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont("Interface\\AddOns\\RuneReaderRecast\\Fonts\\LibreBarcode39Text-Regular.ttf", 40, "MONOCHROME")
    text:SetTextColor(0, 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetPoint("BOTTOMRIGHT", 0, 0)
    text:SetParent(f)
    f.Text = text

    local resize = CreateFrame("Frame", nil, f)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT")
    local tex = resize:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetScript("OnMouseDown", function(self)
        if IsAltKeyDown() then self:GetParent():StartSizing("BOTTOMRIGHT") end
    end)
    resize:SetScript("OnMouseUp", function(self)
        self:GetParent():StopMovingOrSizing()
    end)

    self.BarcodeFrame = f

    if RuneReaderRecastDB and RuneReaderRecastDB.C39Position then
        local pos = RuneReaderRecastDB.C39Position
        f:ClearAllPoints()
        f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    end

    f.Text:SetText("*SCANNED*")

    if not self.BarcodeFrame.hasBeenInitialized then
        self.BarcodeFrame:SetScript("OnUpdate", function(self, elapsed)
            if RuneReader then
                RuneReader.C39FrameDelayAccumulator = RuneReader.C39FrameDelayAccumulator + elapsed
                if RuneReader.C39FrameDelayAccumulator >= RuneReaderRecastDB.UpdateValuesDelay then
                    print("Updated")
                    RuneReader:UpdateC39Display()
                    RuneReader.C39FrameDelayAccumulator = 0
                end
            else
                RuneReader.BarcodeFrame:SetScript("OnUpdate", nil)
            end
        end)
        self.BarcodeFrame.hasBeenInitialized = true
    end

    f:Show()
end

function RuneReader:DestroyBarcodeWindow()
    if self.BarcodeFrame then self.BarcodeFrame:Hide() end
end

function RuneReader:SetBarcodeText(str)
    if self.BarcodeFrame and self.BarcodeFrame.Text then
        self.BarcodeFrame.Text:SetText(str)
    end
end

function RuneReader:UpdateC39Display()
    local fullResult = self:UpdateCodeValues()
    print("test")
    if self.lastC39EncodeResult ~= fullResult then
        self.lastC39EncodeResult = fullResult
        self:SetBarcodeText("*" .. self.lastC39EncodeResult .. "*")
    end
end
