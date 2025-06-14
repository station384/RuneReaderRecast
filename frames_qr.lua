-- frames_qr.lua: QR code window management

RuneReader = RuneReader or {}
RuneReader.lastQREncodeResult = "0000000"
RuneReader.QRFrameDelayAccumulator = 0


function RuneReader:CreateQRWindow(qrMatrix, moduleSize, quietZone)
    if RuneReader.QRFrame and RuneReader.QRFrame:IsShown() then
        return
    elseif RuneReader.QRFrame then
        RuneReader.QRFrame:Show()
        return
    end
    
    moduleSize = moduleSize or 6
    quietZone = quietZone or 4
    RuneReader:AddToInspector(moduleSize, "moduleSize Create")
    RuneReader:AddToInspector(quietZone, "quietZone Create")
    local qrSize = qrMatrix and #qrMatrix 
    local totalSize = (qrSize + 2 * quietZone) * moduleSize

   --Figure out an alternate totalSize
   local CodeWidth = #qrMatrix[1]
   local CodeHeight = #qrMatrix



    local f = CreateFrame("Frame", "RuneReaderQRFrame", UIParent, "BackdropTemplate")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetResizable(true)
    f:SetIgnoreParentScale(true)
    f:SetScale(0.60)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", tile=true})
    f:SetBackdropColor(1, 1, 1, 1)
    f:RegisterForDrag("LeftButton")


    f:SetPoint("CENTER")

    f.textures = {}

    f:SetScript("OnDragStart", function(self)
         if IsAltKeyDown() then self:StartMoving() end
        --self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        RuneReaderRecastDB = RuneReaderRecastDB or {}
        RuneReaderRecastDB.QRposition = {
            point = point,
            relativeTo = "UIParent",
            relativePoint = relativePoint,
            x = xOfs,
            y = yOfs
        }
    end)

    self.QRFrame = f

    if not RuneReader.QRFrame.hasBeenInitialized then
        RuneReader.QRFrame:SetScript("OnUpdate", function(self, elapsed)
            if RuneReader then
                RuneReader.QRFrameDelayAccumulator = RuneReader.QRFrameDelayAccumulator + elapsed
                if RuneReader.QRFrameDelayAccumulator >= RuneReaderRecastDB.UpdateValuesDelay then
                    RuneReader:UpdateQRDisplay()
                    RuneReader.QRFrameDelayAccumulator = 0
                end
            else
                RuneReader.QRFrame:SetScript("OnUpdate", nil)
            end
        end)
        RuneReader.QRFrame.hasBeenInitialized = true
    end

    if RuneReaderRecastDB and RuneReaderRecastDB.QRposition then
        local pos = RuneReaderRecastDB.QRposition
        f:ClearAllPoints()
        f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    end

    if qrMatrix then
        RuneReader:BuildQRCodeTextures(qrMatrix, quietZone, moduleSize)
    else
        f.textures = {}
    end

    RuneReader:AddToInspector(totalSize*totalSize, "Value encoded QRCode")
    f:SetSize(totalSize+4, totalSize+4)
    f:Hide()   
    f:Show()
end

function RuneReader:DestroyQRWindow()
    if RuneReader.QRFrame then
        RuneReader.QRFrame:Hide()
        RuneReader.QRFrame:SetParent(nil)
        RuneReader.QRFrame = nil;
    end
end

function RuneReader:BuildQRCodeTextures(qrMatrix, quietZone, moduleSize)
    moduleSize = moduleSize or 6
    quietZone = quietZone or 4

    RuneReader:AddToInspector(moduleSize, "moduleSize BuildQRCodeTextures")
    RuneReader:AddToInspector(quietZone, "quietZone BuildQRCodeTextures")

    local qrSize = #qrMatrix
    local totalSize = (qrSize + 2 * quietZone) * moduleSize

   local CodeWidth = #qrMatrix[1]
   local CodeHeight = #qrMatrix


    local f = RuneReader.QRFrame
    if not f then
           RuneReader:AddToInspector(true, "QRFrame Wasn't created yet.  SHouldn't happen.")
        RuneReader:CreateQRWindow(qrMatrix, moduleSize, quietZone)
        f = RuneReader.QRFrame
    end
    f:SetSize(totalSize, totalSize)


    if not f.textures or #f.textures ~= qrSize * qrSize then
        if f.textures then
            for _, tex in ipairs(f.textures) do
                tex:Hide()
                tex:SetParent(nil)
            end
            wipe(f.textures)
        end
        f.textures = {}
        for y = 1, qrSize do
            for x = 1, qrSize do
                local tex = f:CreateTexture(nil, "ARTWORK")
                tex:SetSize(moduleSize, moduleSize)
                tex:SetPoint("TOPLEFT",
                      (x - 1 + quietZone  ) * moduleSize + 2,   (-((y - 1 + quietZone  ) * moduleSize) - 2)
                )
                tex:Show()
                table.insert(f.textures, tex)
            end
        end
    end
    f:Hide()
    f:Show()
    RuneReader:UpdateQRCodeTextures(qrMatrix)


end

function RuneReader:UpdateQRCodeTextures(qrMatrix)
    if not RuneReader.QRFrame or not RuneReader.QRFrame.textures then return end
    local qrSize = #qrMatrix
    for y = 1, qrSize do
        for x = 1, qrSize do
            local i = (y - 1) * qrSize + x
            local tex = self.QRFrame.textures[i]
            if qrMatrix[y][x] > 0 then
                tex:SetColorTexture(0, 0, 0, 1)
            else
                tex:SetColorTexture(1, 1, 1, 0)   -- white, fully transparent
            end
        end
    end
end

function RuneReader:UpdateQRDisplay()
    local fullResult = RuneReader:UpdateCodeValues()
    if RuneReader.lastQREncodeResult ~= fullResult then
        RuneReader.lastQREncodeResult = fullResult
        local stringToEncode = RuneReader.lastQREncodeResult
        local success, matrix = QRencode.qrcode(stringToEncode)
        if success then
            -- if the size of the frame doesn't match (someone played with the config files), or the size of the barcode changed recreate the frame to the correct size.


            if  (string.len(RuneReader.lastQREncodeResult) ~= RuneReader.DataLength) then
                RuneReader.DataLength = #RuneReader.lastQREncodeResult
                RuneReader:AddToInspector(stringToEncode, "Value encoded QRCode")
                RuneReader:DestroyQRWindow()
                RuneReader:CreateQRWindow(matrix, RuneReaderRecastDB.QRQuietZone, RuneReaderRecastDB.QRModuleSize)
            end
            RuneReader:UpdateQRCodeTextures(matrix)
        end
    end
end
