-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

function RuneReader:RuneReaderEnv_translateKey(hotKey, wait)
    local encodedKey = "00"


    local keyMap = {
        ["1"] = "01", ["2"] = "02", ["3"] = "03", ["4"] = "04", ["5"] = "05",
        ["6"] = "06", ["7"] = "07", ["8"] = "08", ["9"] = "09", ["0"] = "10",
        ["-"] = "11", ["="] = "12",
        ["CF1"]="21",["CF2"]="22",["CF3"]="23",["CF4"]="24",["CF5"]="25",["CF6"]="26",["CF7"]="27",["CF8"]="28",["CF9"]="29",["CF10"]="30",["CF11"]="31",["CF12"]="32",
        ["AF1"]="41",["AF2"]="42",["AF3"]="43",["AF4"]="44",["AF5"]="45",["AF6"]="46",["AF7"]="47",["AF8"]="48",["AF9"]="49",["AF10"]="50",["AF11"]="51",["AF12"]="52",
        ["F1"]="61",["F2"]="62",["F3"]="63",["F4"]="64",["F5"]="65",["F6"]="66",["F7"]="67",["F8"]="68",["F9"]="69",["F10"]="70",["F11"]="71",["F12"]="72"
    }
    encodedKey = keyMap[hotKey] or "00"

    return encodedKey
end
