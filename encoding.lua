-- encoding.lua: Encoding helpers for barcode/QR and check digits

RuneReader = RuneReader or {}

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

function RuneReader:RuneReaderEnv_set_bit(byte, bit_position)
    local bit_mask = 2 ^ bit_position
    if byte % (bit_mask + bit_mask) >= bit_mask then
        return byte -- bit already set
    else
        return byte + bit_mask
    end
end

-- Helper function used for debuging
-- This adds info to an in game tool used for development
function RuneReader:AddToInspector(data, strName)
    if DevTool and RuneReaderRecastDB.DEBUG then
        DevTool:AddData(data, strName)
    end
end