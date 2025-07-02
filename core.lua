-- core.lua: Main entry, global events, glue logic

RuneReader = RuneReader or {}


function RuneReader:HandleMapShow()
    if RuneReader.BarcodeFrame then
        RuneReader.BarcodeFrame:SetFrameStrata("LOW")
    end
    if RuneReader.QRFrame then
        RuneReader.QRFrame:SetFrameStrata("LOW")
    end
end

function RuneReader:HandleMapHide()
    if RuneReader.BarcodeFrame then
        RuneReader.BarcodeFrame:SetFrameStrata("TOOLTIP")
    end
    if RuneReader.QRFrame then
        RuneReader.QRFrame:SetFrameStrata("TOOLTIP")
    end
end

function RuneReader:RegisterMapHooks()
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() RuneReader:HandleMapShow() end)
        WorldMapFrame:HookScript("OnHide", function() RuneReader:HandleMapHide() end)
    else
        print("ERROR: WorldMapFrame not found!")
    end
end

function RuneReader:InitializeAddon()
    RuneReader:InitConfig()
    RuneReader:RegisterMapHooks()
    RuneReader:CreateConfigPanel()
    if RuneReaderRecastDB.BarCodeMode == 0 then
        RuneReader:CreateBarcodeWindow()
    end
    if RuneReaderRecastDB.BarCodeMode == 1 then
        local success, matrix = QRencode.qrcode(RuneReader.lastC39EncodeResult, RuneReaderRecastDB.Ec_level or 7)
        if success then
            RuneReader:CreateQRWindow(matrix, RuneReaderRecastDB.QRQuietZone, RuneReaderRecastDB.QRModuleSize)
        end
    end
end

local RuneReaderInit = CreateFrame("Frame")
RuneReaderInit:RegisterEvent("PET_BATTLE_OPENING_START")
RuneReaderInit:RegisterEvent("PET_BATTLE_CLOSE")
RuneReaderInit:RegisterEvent("ADDON_LOADED")
RuneReaderInit:SetScript("OnEvent",
    function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "RuneReaderRecast" then
            print("Loading Rune Reader")
            RuneReader:InitializeAddon()
        elseif event == "PET_BATTLE_OPENING_START" then
               if RuneReader.BarcodeFrame then
                RuneReader.BarcodeFrame:Hide()
                end
                if RuneReader.QRFrame then
                    RuneReader.QRFrame:Hide()
                end
        elseif event == "PET_BATTLE_CLOSE" then
               if RuneReader.BarcodeFrame then
                RuneReader.BarcodeFrame:Show()
                end
                if RuneReader.QRFrame then
                    RuneReader.QRFrame:Show()
                end

        end
    end
)
