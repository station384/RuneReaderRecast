-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

-- frames_barcode.lua: Barcode window management

RuneReader = RuneReader or {}

RuneReader.lastC39EncodeResult = "1,B0,W0001,K00"
RuneReader.lastDisplayedC39Encode = ""
RuneReader.C39FrameDelayAccumulator = 0




function RuneReader:CreateBarcodeWindow()

    RuneReader.lastC39EncodeResult = "1,B0,W0001,K00"
    if RuneReader.BarcodeFrame and RuneReader.BarcodeFrame:IsShown() then
        RuneReader.C39FrameDelayAccumulator = 0
                   RuneReader.lastC39EncodeResult = ""
           RuneReader.lastDisplayedC39Encode = ""
        return
    elseif RuneReader.BarcodeFrame then
        RuneReader.C39FrameDelayAccumulator = 0
           RuneReader.lastC39EncodeResult = ""
           RuneReader.lastDisplayedC39Encode = ""
        RuneReader.BarcodeFrame:Show()
        return
    end

    local f = CreateFrame("Frame", "RuneReaderBarcodeFrame", UIParent, "BackdropTemplate")
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    if RuneReaderRecastDB and RuneReaderRecastDB.C39Position then
        local pos = RuneReaderRecastDB.C39Position
        f:ClearAllPoints()
        f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    end
    f:SetIgnoreParentScale(true)
    f:SetScale(RuneReaderRecastDB.ScaleCode39 or 1.0)
    f:SetFrameStrata( "TOOLTIP")
    f:SetMovable(true)
    f:SetResizable(false)
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
        tile = true, tileSize = 3, edgeSize = 3,
        insets = { left = 0, right = 0, top = 0, bottom = 0}
    })
   
    f:SetBackdropColor(0.3, 0.2, 0, 1)

    --f:SetResizeBounds(220,20)

    -- Create ScrollFrame inside the barcode frame
     local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetAllPoints(f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -1)

    

    -- Create container frame for the text
    local textHolder = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(textHolder)
    textHolder:SetAllPoints(f)
    
    local text = textHolder:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    text:SetFont("Interface\\AddOns\\RuneReaderRecast\\Fonts\\LibreBarcode39-Regular.ttf", RuneReaderRecastDB.Code39Size or 40, "MONOCHROME")
    text:SetTextColor(0, 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    text:SetShadowColor(255,255,255,0)
    text:SetDrawLayer("BACKGROUND")
    text:SetText("*" .. RuneReader.lastC39EncodeResult .. "*")
    text:SetPoint("CENTER", textHolder, "CENTER", 0, -0)
    --text:SetParent(f)


    local width = text:GetStringWidth()
    local height = text:GetStringHeight()
    --f:SetSize(width, height)


    -- text:SetAllPoints(textHolder)



    -- Optional padding
    local padX, padY = 20, 0

   f:SetSize(width + padX, height /3)







    f.Text = text
    f:Hide()
    f:Show()
    RuneReader.BarcodeFrame = f



    -- f.Text:SetText("*SCANNED*")

    if not RuneReader.BarcodeFrame.hasBeenInitialized then
        RuneReader.BarcodeFrame:SetScript("OnUpdate", function(self, elapsed)
            if RuneReader then
                RuneReader.C39FrameDelayAccumulator = RuneReader.C39FrameDelayAccumulator + elapsed
                if RuneReader.C39FrameDelayAccumulator >= RuneReaderRecastDB.UpdateValuesDelay  then
                    RuneReader:UpdateC39Display()
                    RuneReader.C39FrameDelayAccumulator = 0
                end
            else
                RuneReader.BarcodeFrame:SetScript("OnUpdate", nil)
            end
        end)
        RuneReader.BarcodeFrame.hasBeenInitialized = true
    end



    -- if RuneReaderRecastDB and RuneReaderRecastDB.C39Position then
    --     local pos = RuneReaderRecastDB.C39Position
    --     f:ClearAllPoints()
    --     f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    -- end
        RuneReader.C39FrameDelayAccumulator = 0
           RuneReader.lastC39EncodeResult = ""
           RuneReader.lastDisplayedC39Encode = ""
 --   RuneReader:AddToInspector(220*50, "Value encoded Code39")


end

function RuneReader:DestroyBarcodeWindow()
--     if RuneReader.BarcodeFrame then 
    
--         RuneReader.BarcodeFrame:Hide()

-- end
        if RuneReader.BarcodeFrame then
        RuneReader.BarcodeFrame:Hide()
        RuneReader.BarcodeFrame:SetParent(nil)
        RuneReader.BarcodeFrame = nil;
    end
end

function RuneReader:SetBarcodeText(str)
    if RuneReader.BarcodeFrame and RuneReader.BarcodeFrame.Text then
        RuneReader.BarcodeFrame.Text:SetText(str)
    end
end

function RuneReader:UpdateC39Display()
   local fullResult = ""
    -- if  Hekili  and (not RuneReaderRecastDBPerChar.HelperSource  or RuneReaderRecastDBPerChar.HelperSource == 0) then
    --   fullResult = RuneReader:Hekili_UpdateValues(1) --Standard code39 for now.....
    -- end
    -- if (not Hekili and RuneReaderRecastDBPerChar.HelperSource == 0) or RuneReaderRecastDBPerChar.HelperSource == 1 then
    --     fullResult = RuneReader:AssistedCombat_UpdateValues(1)
    -- end
   fullResult = RuneReader:GetUpdatedValues()

  
        if fullResult then
                RuneReader:SetBarcodeText("*" .. RuneReader.lastC39EncodeResult .. "*")
                RuneReader.lastDisplayedC39Encode= fullResult;
        end

  
    RuneReader.lastC39EncodeResult = fullResult or RuneReader.lastC39EncodeResult
end
