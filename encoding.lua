-- RuneReader Recast
-- Copyright (c) Michael Sutton 2025
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- You may use, modify, and distribute this file under the terms of the GPLv3 license.
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html

-- encoding.lua: Encoding helpers for barcode/QR and check digits

RuneReader = RuneReader or {}

function RuneReader:Clamp(value, minVal, maxVal)
    return math.max(minVal, math.min(value, maxVal))
end

function RuneReader:ToBase36(num)
    local chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local result = ''
    repeat
        local rem = (num % 36) + 1
        result = chars:sub(rem, rem) .. result
        num = math.floor(num / 36)
    until num == 0
    return result
end

function RuneReader:Pad_right(str1, len, pad)
    pad = pad or " "
    local pad_len = len - #str1
    if pad_len > 0 then
        return str1 .. string.rep(pad, pad_len)
    else
        return str1
    end
end

function RuneReader:CalculateCheckDigit(input)
    local sum = 0
    for i = 1, #input do
        local digit = tonumber(input:sub(i, i))
        if not digit then return nil, "Invalid character in input" end
        local weight = (i % 2 == 0) and 1 or 3
        sum = sum + digit * weight
    end
    local check = (10 - (sum % 10)) % 10
    return check
end

function RuneReader:CalculateCheckDigitASCII(input)
    local sum = 0
    for i = 1, #input do
        local ascii = string.byte(input, i) -- Full ASCII support
        local weight = (i % 2 == 0) and 1 or 3
        sum = sum + ascii * weight
    end
    local check = (10 - (sum % 10)) % 10
    return check
end

function RuneReader:ValidateWithCheckDigit(input)
    local base = input:sub(1, -2)
    local expected = tonumber(input:sub(-1))
    local actual = self:CalculateCheckDigit(base)
    return expected == actual
end

function RuneReader:ValidateWithCheckDigitASCII(input)
    if not input or #input < 2 then return false end

    local base = input:sub(1, -2)
    local expected = tonumber(input:sub(-1))
    if not expected then return false end

    local actual = self:CalculateCheckDigit(base)
    return expected == actual
end

-- Pre‑computed masks (bit_position + 1 → 2^bit_position)
local bitMasks = {
  1,          2,          4,          8,          16,
  32,         64,         128,        256,        512,
  1024,       2048,       4096,       8192,       16384,
  32768,      65536,      131072,     262144,     524288,
  1048576,    2097152,    4194304,    8388608,    16777216,
  33554432,   67108864,   134217728,  268435456,  536870912,
  1073741824
}

--Set‑bit helper 
function RuneReader:RuneReaderEnv_set_bit(byte, bit_position)
  -- Get the power‑of‑two mask for the requested bit.
  local mask = bitMasks[bit_position + 1]   -- Lua indices start at 1

  -- If the bit is already set, just return the original value.
  if byte % (mask * 2) < mask then
    return byte + mask     -- bit was clear → set it
  else
    return byte            -- bit already set
  end
end



-- Helper function used for debuging
-- This adds info to an in game tool used for development
function RuneReader:AddToInspector(data, strName)
    if DevTool and RuneReaderRecastDB.DEBUG then
        DevTool:AddData(data, strName)
    end
end