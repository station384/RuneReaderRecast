-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

-- frames_qr.lua: QR code window management

RuneReader = RuneReader or {}
RuneReader.lastQREncodeResult = RuneReader.DefaultCode
RuneReader.QRFrameDelayAccumulator = 0


function RuneReader:CreateQRWindow(qrMatrix, moduleSize, quietZone)

    if RuneReader.QRFrame and RuneReader.QRFrame:IsShown() then
        return
    elseif RuneReader.QRFrame then
        RuneReader.QRFrame:Show()
        return
    end
    RuneReader.lastQREncodeResult = RuneReader.DefaultCode
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
    f:SetPoint("TOPLEFT")
    if RuneReaderRecastDB and RuneReaderRecastDB.QRposition then
        local pos = RuneReaderRecastDB.QRposition
        f:ClearAllPoints()
        f:SetPoint(pos.point or "TOPLEFT", UIParent, pos.relativePoint or "TOPLEFT", pos.x or 0, pos.y or 0)

        --f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x or 0, pos.y or 0)
    end
    f:SetIgnoreParentScale(true)
    f:SetScale(RuneReaderRecastDB.ScaleQR or 1.0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetResizable(false)
 
    f:SetClampedToScreen(true)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", tile=true})
    f:SetBackdropColor(1, 1, 1, 1)

    
    f:RegisterForDrag("LeftButton")




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





    if qrMatrix then
        RuneReader:BuildQRCodeTextures(qrMatrix, quietZone, moduleSize)
    else
        f.textures = {}
    end

    RuneReader:AddToInspector(totalSize*totalSize, "Value encoded QRCode")
    f:SetSize(totalSize+4, totalSize+4)
    f:Hide()   
    f:Show()

    if not RuneReader.QRFrame.hasBeenInitialized then
        RuneReader.QRFrame:SetScript("OnUpdate", function(self, elapsed)
            if RuneReader then
                if RuneReader.QRFrameDelayAccumulator >=  RuneReaderRecastDB.UpdateValuesDelay + elapsed  then
                    RuneReader:UpdateQRDisplay()
                    RuneReader.QRFrameDelayAccumulator =  0
                end
            else
                RuneReader.QRFrame:SetScript("OnUpdate", nil)
            end
            RuneReader.QRFrameDelayAccumulator = RuneReader.QRFrameDelayAccumulator + elapsed
        end)
        RuneReader.QRFrame.hasBeenInitialized = true
    end

end






function RuneReader:DestroyQRWindow()
    --   if RuneReader.QRFrame then RuneReader.QRFrame:Hide() end
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
           RuneReader:CreateQRWindow(qrMatrix, RuneReaderRecastDB.QRModuleSize,RuneReaderRecastDB.QRQuietZone )
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
  local textures = self.QRFrame.textures
  if not textures then return end

  local qrSize = #qrMatrix
  for y = 1, qrSize do
    local row = qrMatrix[y]
    for x = 1, qrSize do
      local i   = (y - 1) * qrSize + x
      local tex = textures[i]
      if row[x] > 0 then
        tex:SetColorTexture(0, 0, 0, 1)   -- black, opaque
      else
        tex:SetColorTexture(1, 1, 1, 0)   -- white, fully transparent
      end
    end
  end
end

function RuneReader:UpdateQRDisplay()
  -- Cache local references to avoid repeated table lookups
  local self = RuneReader
  local db   = RuneReaderRecastDB
  local qr   = QRencode
  local lastResult   = self.lastQREncodeResult
  local lastDisplayed = self.lastDisplayedQREncode
  local dataLen      = self.DataLength

  local fullResult = self:GetUpdatedValues()

 -- if lastResult ~= fullResult or lastDisplayed ~= fullResult then
    local success, matrix = qr.qrcode(fullResult, db.Ec_level or 7)
    if success then
      -- Re‑create the window only if the encoded string length changed
      if #fullResult ~= dataLen then
        self.DataLength = #fullResult
        self:AddToInspector(fullResult, "Value encoded QRCode")
        self:DestroyQRWindow()
        self:CreateQRWindow(matrix, db.QRModuleSize, db.QRQuietZone)
      end
      self:UpdateQRCodeTextures(matrix)
      self.lastDisplayedQREncode = fullResult
    end
  --end

  self.lastQREncodeResult = fullResult
end


