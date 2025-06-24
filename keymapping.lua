function RuneReader:RuneReaderEnv_translateKey(hotKey, wait)
    local encodedKey = "00"
    local encodedWait = "0.0"
    if wait == nil then wait = 0 end
    local keyMap = {
        ["1"] = "01", ["2"] = "02", ["3"] = "03", ["4"] = "04", ["5"] = "05",
        ["6"] = "06", ["7"] = "07", ["8"] = "08", ["9"] = "09", ["0"] = "10",
        ["-"] = "11", ["="] = "12",
        ["CF1"]="21",["CF2"]="22",["CF3"]="23",["CF4"]="24",["CF5"]="25",["CF6"]="26",["CF7"]="27",["CF8"]="28",["CF9"]="29",["CF10"]="30",["CF11"]="31",["CF12"]="32",
        ["AF1"]="41",["AF2"]="42",["AF3"]="43",["AF4"]="44",["AF5"]="45",["AF6"]="46",["AF7"]="47",["AF8"]="48",["AF9"]="49",["AF10"]="50",["AF11"]="51",["AF12"]="52",
        ["F1"]="61",["F2"]="62",["F3"]="63",["F4"]="64",["F5"]="65",["F6"]="66",["F7"]="67",["F8"]="68",["F9"]="69",["F10"]="70",["F11"]="71",["F12"]="72"
    }
    encodedKey = keyMap[hotKey] or "00"
    if wait > 9.99 then wait = 9.99 end
    if wait < 0 then wait = 0 end
    if wait ~= nil then encodedWait = string.format("%04.2f", wait):gsub("[.]", "") end
    return encodedKey .. encodedWait
end
