-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

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
function RuneReader:SetScaleKeepCenter(frame, newScale)
  local cx, cy = frame:GetCenter()
  if not cx or not cy then
    frame:SetScale(newScale)
    return
  end

  -- Convert center to UIParent pixel coords
  local parentScale = UIParent:GetEffectiveScale()
  cx, cy = cx * parentScale, cy * parentScale

  frame:SetScale(newScale)

  -- Restore center
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / parentScale, cy / parentScale)
end

 function RuneReader:SavePos(frame)
  RuneReaderRecastDB = RuneReaderRecastDB or {}
  RuneReaderRecastDB.QRposition = RuneReaderRecastDB.QRposition or {}

  local cx, cy = frame:GetCenter()
  if not cx or not cy then return end

  -- convert to screen pixels using the frame's effective scale (important!)
  local eff = frame:GetEffectiveScale()
  RuneReaderRecastDB.QRposition.screenX = cx * eff
  RuneReaderRecastDB.QRposition.screenY = cy * eff
end

 function RuneReader:RestorePos(frame)
  local pos = RuneReaderRecastDB and RuneReaderRecastDB.QRposition
  if not (pos and pos.screenX and pos.screenY) then
    frame:SetPoint("CENTER")
    return
  end

  local parentEff = UIParent:GetEffectiveScale()
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.screenX / parentEff, pos.screenY / parentEff)
end

function RuneReader:SetScaleKeepCenter_ClampSafe(frame, newScale)
  local wasClamped = frame:IsClampedToScreen()
  frame:SetClampedToScreen(false)
  RuneReader:SetScaleKeepCenter(frame, newScale)
  frame:SetClampedToScreen(wasClamped)
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
        end
    end


    if RuneReaderRecastDB.BarCodeMode == 2 then
            RuneReader:CreateCode39Window( 5)
            RuneReader:SetBarcodeText(RuneReader.DefaultCode)
            RuneReader.lastDisplayedCode39 = RuneReader.lastDisplayedCode39
            RuneReader:DisposeCode39Window()
            RuneReader:CreateCode39Window( 5)
    end




    if C_AssistedCombat and (RuneReaderRecastDBPerChar.HelperSource == 1) then
         RuneReader:CreateSpellIconFrame()
         RuneReader:DestroySpellIconFrame()
         RuneReader:CreateSpellIconFrame()
    -- elseif ConRO and (RuneReaderRecastDBPerChar.HelperSource == 2) then
    --      RuneReader:CreateSpellIconFrame()
    --      RuneReader:DestroySpellIconFrame()
    --      RuneReader:CreateSpellIconFrame()
    elseif MaxDps and (RuneReaderRecastDBPerChar.HelperSource == 3) then
         RuneReader:CreateSpellIconFrame()
         RuneReader:DestroySpellIconFrame()
         RuneReader:CreateSpellIconFrame()
    -- elseif Hekili and (RuneReaderRecastDBPerChar.HelperSource == 0) then
    --      RuneReader:CreateSpellIconFrame()
    --      RuneReader:DestroySpellIconFrame()
    --      RuneReader:CreateSpellIconFrame()
         

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

-- used to detect player bar changes
-- RuneReaderInit:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
-- RuneReaderInit:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
-- RuneReaderInit:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
-- RuneReaderInit:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
-- RuneReaderInit:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
-- RuneReaderInit:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
-- RuneReaderInit:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
-- RuneReaderInit:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
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
    -- elseif event == "ACTIONBAR_PAGE_CHANGED" or
    -- event == "UPDATE_BONUS_ACTIONBAR" or
    -- event == "UPDATE_OVERRIDE_ACTIONBAR" or
    -- event == "UPDATE_EXTRA_ACTIONBAR" or
    -- event == "ACTIONBAR_SLOT_CHANGED" or
    -- event == "UPDATE_SHAPESHIFT_FORM" or
    -- event == "UPDATE_SHAPESHIFT_FORMS" or
    -- event == "ACTIONBAR_SLOT_CHANGED" then
    --     if RuneReaderRecastDB.HelperSource == 1 then
    --         RuneReader:BuildAssistedSpellMap()
    --     end
    -- end
end
)

