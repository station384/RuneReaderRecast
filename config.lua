-- config.lua: Default settings and config initialization

RuneReader = RuneReader or {}
RuneReaderRecastDB = RuneReaderRecastDB or {}

RuneReader.defaultConfig = {
    PrePressDelay = 0.100,
    UseCode39 = true,
    UseQRCode = false,
    Ec_level = 0,
    QRModuleSize = 1,
    QRQuietZone = 3,
    UpdateValuesDelay = 0.10,
    DEBUG=false,
    HelperSource = 0, -- 0 =  Hekili, 1 = Commbat Assist
    Scale = 1.0,  -- Scale for the barcode frame
    Code39Size = 40
}

function RuneReader:InitConfig()
    for k,v in pairs(RuneReader.defaultConfig) do
        if RuneReaderRecastDB[k] == nil then
            RuneReaderRecastDB[k] = v
        end
    end
    -- for k,v in pairs(RuneReaderRecastDB) do
    --     print (k , " = ", v)
    -- end
    -- if RuneReaderRecastDB.UpdateValuesDelay == nil then
    --     RuneReaderRecastDB.UpdateValuesDelay = RuneReader.defaultConfig.UpdateValuesDelay
    -- end
    -- RuneReaderRecastDB.DEBUG=false
    -- RuneReaderRecastDB.QRModuleSize = 1
    -- RuneReaderRecastDB.QRQuietZone = 2
    -- RuneReaderRecastDB.UseCode39 = true
    -- RuneReaderRecastDB.UseQRCode = false
    -- RuneReaderRecastDB.HelperSource = 0
    -- RuneReaderRecastDB.UpdateValuesDelay = 0.30
    -- RuneReaderRecastDB.Scale = 1.0

end
