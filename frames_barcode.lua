-- frames_barcode.lua: Barcode window management

RuneReader = RuneReader or {}

RuneReader.lastC39EncodeResult = "1,B0,W0000,K00"
RuneReader.C39FrameDelayAccumulator = 0

function RuneReader:CreateBarcodeWindow()
    if RuneReader.BarcodeFrame and RuneReader.BarcodeFrame:IsShown() then
        return
    elseif RuneReader.BarcodeFrame then
        RuneReader.BarcodeFrame:Show()
        return
    end

    local f = CreateFrame("Frame", "RuneReaderBarcodeFrame", UIParent, "BackdropTemplate")
    --f:SetSize(220, 50)
    f:SetScale(RuneReaderRecastDB.Scale or 1.0)
    f:SetPoint("TOP", UIParent, "TOP", 0, 0)
    f:SetFrameStrata("TOOLTIP")
    f:SetMovable(true)
    f:SetResizable(true)
    f:EnableMouse(true)
    f:SetIgnoreParentScale(true)
    f:SetClampedToScreen(true)
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
    f:SetResizeBounds(220,20)

    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont("Interface\\AddOns\\RuneReaderRecast\\Fonts\\LibreBarcode39-Regular.ttf", RuneReaderRecastDB.Code39Size or 40, "MONOCHROME")
    
    text:SetTextColor(0, 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetParent(f)
    text:SetShadowColor(255,255,255,0)
    text:SetDrawLayer("BACKGROUND")
    text:ClearAllPoints() 
    local container = CreateFrame("Frame", nil, f)
    container:SetAllPoints()
    container:SetFrameLevel(f:GetFrameLevel() )

    text:SetParent(container)
    text:ClearAllPoints()
    text:SetPoint("CENTER", container, "CENTER", 0, -7) -- nudge down slightly

    -- Auto Resize frame function
    f.Text = text
    f.Text:SetText("*" .. RuneReader.lastC39EncodeResult .. "*")
    local width = f.Text:GetStringWidth()
    local height = f.Text:GetStringHeight()

    -- Optional padding
    local padX, padY = 40, 0

    f:SetSize(width + padX, height + padY)
    f:SetResizeBounds(text:GetWidth(true),text:GetHeight(true))


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

    RuneReader.BarcodeFrame = f

    if RuneReaderRecastDB and RuneReaderRecastDB.C39Position then
        local pos = RuneReaderRecastDB.C39Position
        f:ClearAllPoints()
        f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    end

    -- f.Text:SetText("*SCANNED*")

    if not RuneReader.BarcodeFrame.hasBeenInitialized then
        RuneReader.BarcodeFrame:SetScript("OnUpdate", function(self, elapsed)
            if RuneReader then
                RuneReader.C39FrameDelayAccumulator = RuneReader.C39FrameDelayAccumulator + elapsed
                if RuneReader.C39FrameDelayAccumulator >= RuneReaderRecastDB.UpdateValuesDelay and RuneReader.BarcodeFrame:IsShown() then
                    RuneReader:UpdateC39Display()
                    RuneReader.C39FrameDelayAccumulator = 0
                end
            else
                RuneReader.BarcodeFrame:SetScript("OnUpdate", nil)
            end
        end)
        RuneReader.BarcodeFrame.hasBeenInitialized = true
    end

    f:Show()
end

function RuneReader:DestroyBarcodeWindow()
   -- if RuneReader.BarcodeFrame then RuneReader.BarcodeFrame:Hide() end
        if RuneReader.BarcodeFrame then
        RuneReader.BarcodeFrame:Hide()
        RuneReader.BarcodeFrame:SetParent(nil)
        RuneReader.BarcodeFrame = nil;
    end
end

function RuneReader:SetBarcodeText(str)
    if self.BarcodeFrame and self.BarcodeFrame.Text then
        self.BarcodeFrame.Text:SetText(str)
    end
end

function RuneReader:UpdateC39Display()
   local fullResult = ""
    if RuneReaderRecastDB.HelperSource == 0 then
      fullResult = self:Hekili_UpdateValues(1) --Standard code39 for now.....
    end
    if RuneReaderRecastDB.HelperSource == 1 then
        fullResult = RuneReader:AssistedCombat_UpdateValues(1)
    end

 
    if self.lastC39EncodeResult ~= fullResult then
        self.lastC39EncodeResult = fullResult
        self:SetBarcodeText("*" .. self.lastC39EncodeResult .. "*")
    end
end
