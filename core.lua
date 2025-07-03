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
function RuneReader:PrecacheAssests()
    local f = CreateFrame("Frame", "RuneReaderCache", UIParent, "BackdropTemplate")
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, -100)
    local text = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    text:SetFont("Interface\\AddOns\\RuneReaderRecast\\Fonts\\LibreBarcode39-Regular.ttf", RuneReaderRecastDB.Code39Size or 40, "MONOCHROME")
    f.Text = text
    f:Show()
    f:Hide()
end

local addonInitalized = false
function RuneReader:InitializeAddon()

    RuneReader:InitConfig()
    RuneReader:RegisterMapHooks()
    RuneReader:CreateConfigPanel()
    if RuneReaderRecastDB.BarCodeMode == 0 then
        -- Note to future self:  This is a hack to force the barcode window to be recreated WITH the proper scale on inital load of the game.
        -- DO NOT REMOVE THIS.
        -- IT IS NOT A BUG, IT IS A FEATURE.
        -- This is needed because the frame may not be created yet when the addon is loaded.    
        RuneReader:CreateBarcodeWindow()
        RuneReader:DestroyBarcodeWindow()
        RuneReader:CreateBarcodeWindow()

    end
    if RuneReaderRecastDB.BarCodeMode == 1 then
        local success, matrix = QRencode.qrcode(RuneReader.lastC39EncodeResult, RuneReaderRecastDB.Ec_level or 7)
        if success then
            -- Note to future self:  This is a hack to force the barcode window to be recreated WITH the proper scale on inital load of the game.
            -- DO NOT REMOVE THIS.
            -- IT IS NOT A BUG, IT IS A FEATURE.
            -- This is needed because the frame may not be created yet when the addon is loaded.    

            RuneReader:CreateQRWindow(matrix, RuneReaderRecastDB.QRModuleSize, RuneReaderRecastDB.QRQuietZone)
            RuneReader.lastDisplayedQREncode = RuneReader.lastC39EncodeResult;
            RuneReader:DestroyQRWindow()
            RuneReader:CreateQRWindow(matrix, RuneReaderRecastDB.QRModuleSize, RuneReaderRecastDB.QRQuietZone)
            RuneReader.lastDisplayedQREncode = RuneReader.lastC39EncodeResult;

        end
    end
    addonInitalized =true
end

local addonLoaded = false
local playIsInWorld = false

local RuneReaderInit = CreateFrame("Frame")
RuneReaderInit:RegisterEvent("PET_BATTLE_OPENING_START")
RuneReaderInit:RegisterEvent("PET_BATTLE_CLOSE")
RuneReaderInit:RegisterEvent("ADDON_LOADED")
RuneReaderInit:RegisterEvent("PLAYER_ENTERING_WORLD")
RuneReaderInit:RegisterEvent("FIRST_FRAME_RENDERED")
RuneReaderInit:SetScript("OnEvent",
    function(self, event, addonName)
        if event == "ADDON_LOADED" then
            if addonName == "RuneReaderRecast" then
                --print("RuneReaderRecast: Addon loaded.")
                addonLoaded = true
                RuneReader:PrecacheAssests()
            end
       
        elseif event == "PLAYER_ENTERING_WORLD" then
            playIsInWorld = true
            --print("RuneReaderRecast: Player entered world.")
        elseif event == "FIRST_FRAME_RENDERED" then
            --print("RuneReaderRecast: First frame rendered.")
            if addonLoaded and playIsInWorld then
                if not addonInitalized then
                    --print("RuneReaderRecast: First frame rendered, initializing addon.")
                    C_Timer.After(0.2, function()
                        RuneReader:InitializeAddon()
                    end)
                end
            end
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
