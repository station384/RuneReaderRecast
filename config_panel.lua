-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

function RuneReader:ApplyConfig()
    local cfg = RuneReaderRecastDB
    local cfgPerChar = RuneReaderRecastDBPerChar

    --print ("Applying RuneReader Recast configuration...")


    -- Update refresh delay for AssistedCombat or QR value updates
    --cfg.UpdateValuesDelay = cfg.UpdateValuesDelay or 0.10
    RuneReader.HelperSource = cfg.HelperSource
    RuneReader.LastEncodedResult = ""

    -- Re-create visuals based on toggles
    RuneReader:DestroyQRWindow()
    RuneReader:DestroyBarcodeWindow()
    if RuneReader.SpellIconFrame then
       RuneReader:DestroySpellIconFrame()
     end
     

    if C_AssistedCombat and cfgPerChar.HelperSource == 1 then
            RuneReader:CreateSpellIconFrame()
    elseif ConRO and cfgPerChar.HelperSource == 2 then
            RuneReader:CreateSpellIconFrame()
    elseif MaxDps and cfgPerChar.HelperSource == 3 then
            RuneReader:CreateSpellIconFrame()
    elseif Hekili and cfgPerChar.HelperSource == 0 then
            RuneReader:CreateSpellIconFrame()

    end


      if cfg.BarCodeMode == 0 then
        -- Note to future self:  This is a hack to force the barcode window to be recreated WITH the proper scale on inital load of the game.
        -- DO NOT REMOVE THIS.
        -- IT IS NOT A BUG, IT IS A FEATURE.
        -- This is needed because the frame may not be created yet when the addon is loaded.  
        RuneReader:CreateBarcodeWindow()
    end
    if cfg.BarCodeMode == 1 then
        local success, matrix = QRencode.qrcode(RuneReader.Assisted_LastEncodedResult)
        if success then
            RuneReader:CreateQRWindow(matrix, cfg.QRModuleSize, cfg.QRQuietZone)
        end
    end



    -- Apply UI scale to any visible frames
    if RuneReader.QRFrame then
        RuneReader.QRFrame:SetScale(cfg.ScaleQR or 1.0)
    end
    if RuneReader.BarcodeFrame then
        RuneReader.BarcodeFrame:SetScale(cfg.ScaleCode39 or 1.0)
    end

    -- Save debug and helper source flags for logic use
    RuneReader.DEBUG = cfg.DEBUG

end
  


function RuneReader:CreateConfigPanel()
    RuneReaderRecastDB = RuneReaderRecastDB or {}
    local category = Settings.RegisterVerticalLayoutCategory("RuneReader Recast")

    local function Config_OnChanged(setting, value)
        --print("RuneReader Recast setting changed: " .. setting:GetName() .. " = " .. tostring(value))
        local var = setting:GetVariable()
        RuneReaderRecastDB[var] = value 
        RuneReader:ApplyConfig()
    end

    local function AddCheckbox(key, label, tooltip, default, Perchar)
        local setting = {}
        if (Perchar == 1 or not Perchar) then
         setting = Settings.RegisterAddOnSetting(category, label, key, RuneReaderRecastDBPerChar, type(default), label, default)
        
       else
             setting = Settings.RegisterAddOnSetting(category, label, key, RuneReaderRecastDB, type(default), label, default)
       end
       setting:SetValueChangedCallback(Config_OnChanged)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    local function AddSlider(key, label, tooltip, default, min, max, step, format, Perchar)
         local setting = {}
         if (Perchar == 1 or not Perchar) then
           setting = Settings.RegisterAddOnSetting(category, label, key, RuneReaderRecastDBPerChar, type(default), label, default)
         else
           setting = Settings.RegisterAddOnSetting(category, label, key, RuneReaderRecastDB, type(default), label, default)
         end
        setting:SetValueChangedCallback(Config_OnChanged)
        local opts = Settings.CreateSliderOptions(min, max, step)
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value)
                return string.format(format, value) -- Format to 2 decimal places
            end
        );
        Settings.CreateSlider(category, setting, opts, tooltip) 
    end

    local function AddDropdown(key, label, tooltip, default, optionLabels, Perchar)
       local setting = {}
        if (Perchar == 1 or not Perchar) then
           setting = Settings.RegisterAddOnSetting(category, label, key, RuneReaderRecastDBPerChar, type(default), label, default)
        else
           setting = Settings.RegisterAddOnSetting(category, label, key, RuneReaderRecastDB, type(default), label, default)
        end

        setting:SetValueChangedCallback(Config_OnChanged)
        Settings.CreateDropdown(category, setting, function()
            local container = Settings.CreateControlTextContainer()
            for idx, txt in ipairs(optionLabels) do
                container:Add(idx-1, txt)
            end
            return container:GetData()
        end, tooltip)
    end

    -- Add all your controls
    --  Settings.CreateCategory(category, "General Settings")
    Data = {}
    if Hekili then table.insert(Data,"Hekili") else table.insert(Data,"Hekili N/A") end
    if C_AssistedCombat then table.insert(Data,"WoW Assisted Combat") else table.insert(Data,"WoW Assisted Combat N/A") end
    if ConRO then table.insert(Data,"ConRO") else table.insert(Data,"ConRO N/A") end
    if MaxDps then table.insert(Data,"MaxDps") else table.insert(Data,"MaxDps N/A") end
    --Data = {"Hekili", "Assisted Combat"}
    AddDropdown("HelperSource",  "Combat Assist Source",     "Combat helper engine",      0, Data, 1)

    AddSlider("ScaleCode39",      "Code39 Scale (Size)",     "This effects the rendered size",           1.0, 0.3, 1.3, 0.005,"%.3f")
    AddSlider("ScaleQR",          "QRCode Scale (Size)",     "This effects the rendered size",           1.0, 0.3, 1.3, 0.005,"%.3f")

    AddSlider("UpdateValuesDelay", "Update Delay",    "Delay repoll interval",     0.10, 0.01, 1.0, 0.01,"%.2f ms")
    AddDropdown("BarCodeMode",  "Barcode Style", "Code39 Low CPU, QR More CPU but small",      0, {"Code39", "QRCode"},0)
    --  Settings.CreateCategory(category, "QR Code Settings")
    
    --AddSlider("Code39Size",    "Code39 size",    "Size of the Code39 Barcode",      40,   6,   60,   1, "%i")
    
    -- AddSlider("Ec_level",        "EC Level",          "QR error correction level", 4,    0,   4,   1,"%1.0f")
    -- AddSlider("QRModuleSize",    "QR Module Size",    "QR module pixel size",      2,   1,   10,   1,"%i")
    -- AddSlider("QRQuietZone",     "QR Quiet Zone",     "Quiet zone around QR",      3,   1,   10,   1,"%i")
    -- Settings.CreateCategory(category, "Timing")
    AddSlider("PrePressDelay",   "Spell Queue PrePress (sec)",   "Time in seconds to press the next spell before GCD finishes (sec)",        0,   0,  1,    0.001, "%.3f sec")

    -- AddCheckbox("UseQRCode",     "Use QR Code",       "Enable QR code output",     true)
    -- AddCheckbox("UseCode39",     "Use Code39",        "Enable Code39 barcodes",    false)
     --  Settings.CreateCategory(category, "Engine Settings")
         AddCheckbox("UseInstantWhenMoving",         "Use Instant Cast When moving", "If char is moving instant cast spell will be preferered",      true)
         AddCheckbox("UseSelfHealing",         "Use Self-Heal", "If char is below 40% health they will attempt to self heal if available",      true)
        AddCheckbox("UseUseFormCheck",         "Use Form check", "If char Has different forms suggest moving to that form (priest/shadow form etc)",      true, 1)

    AddCheckbox("DEBUG",         "Enable Debug Mode", "Toggle debug logging",      false)




    Settings.RegisterAddOnCategory(category)
end

