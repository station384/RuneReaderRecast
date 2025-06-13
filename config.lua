-- config.lua: Default settings and config initialization

RuneReader = RuneReader or {}

RuneReader.defaultConfig = {
    PrePressDelay = 0,
    UseCode39 = false,
    UseQRCode = true,
    Ec_level = 7,
    QRModuleSize = 2,
    QRQuietZone = 3,
    UpdateValuesDelay = 0.10,
    DEBUG=false
}

function RuneReader:InitConfig()
    RuneReaderRecastDB = RuneReaderRecastDB or {}
    for k,v in pairs(self.defaultConfig) do
        if RuneReaderRecastDB[k] == nil then
            RuneReaderRecastDB[k] = v
        end
    end
    if RuneReaderRecastDB.UpdateValuesDelay == nil then
        RuneReaderRecastDB.UpdateValuesDelay = RuneReader.defaultConfig.UpdateValuesDelay
    end
     RuneReaderRecastDB.DEBUG=false
    RuneReaderRecastDB.QRModuleSize = 1
    RuneReaderRecastDB.QRQuietZone = 2
    RuneReaderRecastDB.UseCode39 = false
end
