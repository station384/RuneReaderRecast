-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

-- config.lua: Default settings and config initialization

RuneReader = RuneReader or {}
RuneReaderRecastDB = RuneReaderRecastDB or {}
RuneReaderRecastDBPerChar = RuneReaderRecastDBPerChar or {}
RuneReader.defaultConfig = {
    PrePressDelay = 0.100,
    UseCode39 = true,
    UseQRCode = false,
    Ec_level = 0,
    QRModuleSize = 1,
    QRQuietZone = 3,
    UpdateValuesDelay = 0.10,
    DEBUG=false,
    ScaleCode39 = 1.0,  -- Scale for the barcode frame
    ScaleQR = 1.0,  -- Scale for the barcode frame
    Code39Size = 40
}
RuneReader.defaultConfigPerChar = {
    HelperSource = 0, -- 0 =  Hekili, 1 = Commbat Assist
}


function RuneReader:InitConfig()
    for k,v in pairs(RuneReader.defaultConfig) do
        if RuneReaderRecastDB[k] == nil then
            RuneReaderRecastDB[k] = v
        end
    end
    for k,v in pairs(RuneReader.defaultConfigPerChar) do
        if RuneReaderRecastDBPerChar[k] == nil then
            RuneReaderRecastDBPerChar[k] = v
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
