function RuneReader:ApplyConfig()
    local cfg = RuneReaderRecastDB
    --print ("Applying RuneReader Recast configuration...")


    -- Update refresh delay for AssistedCombat or QR value updates
    RuneReaderRecastDB.UpdateValuesDelay = cfg.UpdateValuesDelay or 0.10

    -- Re-create visuals based on toggles
    RuneReader:DestroyQRWindow()
    RuneReader:DestroyBarcodeWindow()

    if cfg.BarCodeMode == 1 then
        local success, matrix = QRencode.qrcode(RuneReader.Assisted_LastEncodedResult)
        if success then
            RuneReader:CreateQRWindow(matrix, cfg.QRModuleSize, cfg.QRQuietZone)
        end
    end

    if cfg.BarCodeMode == 0 then
        RuneReader:CreateBarcodeWindow()
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
    RuneReader.HelperSource = cfg.HelperSource
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

    local function AddCheckbox(key, label, tooltip, default)
        local setting = Settings.RegisterAddOnSetting(category, label, key, RuneReaderRecastDB, type(default), label, default)
        setting:SetValueChangedCallback(Config_OnChanged)
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    local function AddSlider(key, label, tooltip, default, min, max, step, format)
        local setting = Settings.RegisterAddOnSetting(category, label, key, RuneReaderRecastDB, type(default), label, default)
        setting:SetValueChangedCallback(Config_OnChanged)
        local opts = Settings.CreateSliderOptions(min, max, step)
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value)
                return string.format(format, value) -- Format to 2 decimal places
            end
        );
        Settings.CreateSlider(category, setting, opts, tooltip) 
    end

    local function AddDropdown(key, label, tooltip, default, optionLabels)
        local setting = Settings.RegisterAddOnSetting(category, label, key, RuneReaderRecastDB, type(default), label, default)
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
    AddDropdown("HelperSource",  "Combat Assist Source",     "Combat helper engine",      0, {"Hekili", "Assisted Combat"})

    AddSlider("ScaleCode39",      "Code39 Scale (Size)",     "This effects the rendered size",           1.0, 0.3, 1.3, 0.005,"%.3f")
    AddSlider("ScaleQR",          "QRCode Scale (Size)",     "This effects the rendered size",           1.0, 0.3, 1.3, 0.005,"%.3f")

    AddSlider("UpdateValuesDelay", "Update Delay",    "Delay repoll interval",     0.10, 0.01, 1.0, 0.01,"%.2f ms")
    AddDropdown("BarCodeMode",  "Barcode Style", "Code39 Low CPU, QR More CPU but small",      0, {"Code39", "QRCode"})
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
    AddCheckbox("DEBUG",         "Enable Debug Mode", "Toggle debug logging",      false)




    Settings.RegisterAddOnCategory(category)
end

