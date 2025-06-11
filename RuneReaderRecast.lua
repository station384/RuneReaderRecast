-- HekiliRunreader.lua

-- Environment table mimicking aura_env
RuneReader = {}
RuneReader.last = GetTime()


RuneReader.DataLength = 7;

RuneReader.UseQRCode = true;
RuneReader.Ec_level = 7;
RuneReader.QRModuleSize=1;
RuneReader.QRQuietZone=2;
RuneReader.QRFrameDelayAccumulator = 0

RuneReader.config = { 
    PrePressDelay = 0 --C_CVar.GetCVar("SpellQueueWindow") / 1000  lets just report that info as is.
    } -- Lets get the spell SpellQueueWindow
RuneReader.haveUnitTargetAttackable = false
RuneReader.inCombat = false
RuneReader.lastSpell = 61304
RuneReader.lastC39EncodeResult = "1A2Z!U"
RuneReader.lastQREncodeResult = "1A2Z!U"
-- KEY WAIT BIT(0,1) CHECK
-- 00  000  0  0
-- BitMask 0=Target 1=Combat
-- Check quick check if of total values to the left
RuneReader.PrioritySpells = { 47528, 2139, 30449, 147362 }  --Interrupts
RuneReader.C39FrameDelayAccumulator = 0

RuneReader.DEBUG = false
RuneReader.LastDataPak = {};

RuneReader.UseCode39 = false;

RuneReader.GenerationDelayTimeStamp = time()
RuneReader.GenerationDelayAccumulator = 0
RuneReader.UpdateValuesDelay = 0.10





-- Check for Hekili addon
RuneReader.IsHekiliLoadedOrLoadeding, RuneReader.IsHekiliLoaded = C_AddOns.IsAddOnLoaded("Hekili")

if not RuneReader.IsHekiliLoaded then
    print("The Hekili Trigger will only work if Hekili is installed. Get it at www.curseforge.com/wow/addons/hekili.")
end
--Bringing this in as from the global just to keep my checker from telling me it is not defined.
if RuneReader.Hekili_GetRecommendedAbility == nil then
    print("Can't find hekili reccomended ability function")
end


-- Helper Funtions to pad a string out to a certain length
function  RuneReader:Pad_right( str1, len, pad )
    pad = pad or " "
    local pad_len = len - #str1
    if pad_len > 0 then
        return str1 .. string.rep(pad, pad_len)
    else
        return str1
    end
end

-- Helper function used for debuging
-- This adds info to an in game tool used for development
function RuneReader:AddToInspector(data, strName)
    if DevTool and RuneReader.DEBUG then
        DevTool:AddData(data, strName)
    end
end

-- Helper function: translateKey
-- The data needs to be encoded into Numerics.  (Not any more these codes can change when I get around to it.)
function RuneReader:RuneReaderEnv_translateKey(hotKey, wait)
    local encodedKey = "00"
    local encodedWait = "0.0"
    if wait == nil then wait = 0 end;
    if hotKey == '1' then
        encodedKey = '01'
    elseif hotKey == "2" then
        encodedKey = '02'
    elseif hotKey == '3' then
        encodedKey = '03'
    elseif hotKey == '4' then
        encodedKey = '04'
    elseif hotKey == '5' then
        encodedKey = '05'
    elseif hotKey == "6" then
        encodedKey = '06'
    elseif hotKey == '7' then
        encodedKey = '07'
    elseif hotKey == '8' then
        encodedKey = '08'
    elseif hotKey == '9' then
        encodedKey = '09'
    elseif hotKey == '0' then
        encodedKey = '10'
    elseif hotKey == '-' then
        encodedKey = '11'
    elseif hotKey == '=' then
        encodedKey = '12'
    elseif hotKey == 'CF1' then
        encodedKey = '21'
    elseif hotKey == 'CF2' then
        encodedKey = '22'
    elseif hotKey == 'CF3' then
        encodedKey = '23'
    elseif hotKey == 'CF4' then
        encodedKey = '24'
    elseif hotKey == 'CF5' then
        encodedKey = '25'
    elseif hotKey == 'CF6' then
        encodedKey = '26'
    elseif hotKey == 'CF7' then
        encodedKey = '27'
    elseif hotKey == 'CF8' then
        encodedKey = '28'
    elseif hotKey == 'CF9' then
        encodedKey = '29'
    elseif hotKey == 'CF10' then
        encodedKey = '30'
    elseif hotKey == 'CF11' then
        encodedKey = '31'
    elseif hotKey == 'CF12' then
        encodedKey = '32'
    elseif hotKey == 'AF1' then
        encodedKey = '41'
    elseif hotKey == 'AF2' then
        encodedKey = '42'
    elseif hotKey == 'AF3' then
        encodedKey = '43'
    elseif hotKey == 'AF4' then
        encodedKey = '44'
    elseif hotKey == 'AF5' then
        encodedKey = '45'
    elseif hotKey == 'AF6' then
        encodedKey = '46'
    elseif hotKey == 'AF7' then
        encodedKey = '47'
    elseif hotKey == 'AF8' then
        encodedKey = '48'
    elseif hotKey == 'AF9' then
        encodedKey = '49'
    elseif hotKey == 'AF10' then
        encodedKey = '50'
    elseif hotKey == 'AF11' then
        encodedKey = '51'
    elseif hotKey == 'AF12' then
        encodedKey = '52'
    elseif hotKey == 'F1' then
        encodedKey = '61'
    elseif hotKey == 'F2' then
        encodedKey = '62'
    elseif hotKey == 'F3' then
        encodedKey = '63'
    elseif hotKey == 'F4' then
        encodedKey = '64'
    elseif hotKey == 'F5' then
        encodedKey = '65'
    elseif hotKey == 'F6' then
        encodedKey = '66'
    elseif hotKey == 'F7' then
        encodedKey = '67'
    elseif hotKey == 'F8' then
        encodedKey = '68'
    elseif hotKey == 'F9' then
        encodedKey = '69'
    elseif hotKey == 'F10' then
        encodedKey = '70'
    elseif hotKey == 'F11' then
        encodedKey = '71'
    elseif hotKey == 'F12' then
        encodedKey = '72'
    elseif hotKey == nil then
        encodedKey = '00'
    end

    if wait > 9.99 then wait = 9.99 end
    if wait < 0 then wait = 0 end
    --Time is trimmed down to 2 digits in hundered milisecond time.    so 1.01 seconds would be 10 (its late my memory is going.  future self double check this and update this comment.)
    if wait ~= nil then encodedWait = string.format("%04.2f", wait):gsub("[.]", "") end

    return encodedKey .. encodedWait
end

-- Calculate check digit (returns 0-9)
-- todo:  This needs to handle the full code_39 character set.
-- Only needed for barcodes that don't have error correction
function RuneReader:CalculateCheckDigit(input)
    local sum = 0
    for i = 1, #input do
        local digit = tonumber(input:sub(i, i))
        if not digit then return nil, "Invalid character in input" end
        -- Alternate weights, e.g., 3,1,3,1,...
        local weight = (i % 2 == 0) and 1 or 3
        sum = sum + digit * weight
    end
    local check = (10 - (sum % 10)) % 10
    return check
end

-- Validate a string including check digit
-- Only needed for barcodes that don't have error correction
function RuneReader:ValidateWithCheckDigit(input)
    local base = input:sub(1, -2)
    local expected = tonumber(input:sub(-1))
    local actual = RuneReader:CalculateCheckDigit(base)
    return expected == actual
end

-- Helper function: set_bit
-- Some true/false values are encoded as bits to save space. Thou output of this has be able to be displayed as a character (char) that fits into the code_39 charater set.
function RuneReader:RuneReaderEnv_set_bit(byte, bit_position)
    local bit_mask = 2 ^ bit_position
    if byte % (bit_mask + bit_mask) >= bit_mask then
        return byte -- bit already set
    else
        return byte + bit_mask
    end
end

-- Helper function: hasSpell
-- reads a table of # that represents high priority spells tries to find value x in that table. if it is found it will return true.  otherwise false.
function RuneReader:RuneReaderEnv_hasSpell(tbl, x)
    for _, v in ipairs(tbl) do
        if v == x then
            return true
        end
    end
    return false
end



function RuneReader:GetHekiliReccomend(mode)

    if (mode == "primary") then
    end

    if (mode == "aoe") then
    end
end

--The returned string is in this format
-- KEY WAIT BIT(0,1) CHECK
-- 00  000  0  0
-- BitMask 0=Target 1=Combat
-- Check quick check if of total values to the left
function RuneReader:UpdateCodeValues()
    --Only gather data every 10 MS.  Otherwise just return the last result.  
    --Don't need excessive calls to the api to get information that mostlikly hasn't changed.
    --The first time this function is called it will get the values after that it will honor the update time delay
     RuneReader.GenerationDelayAccumulator = RuneReader.GenerationDelayAccumulator + (time() - RuneReader.GenerationDelayTimeStamp)
        if RuneReader.GenerationDelayAccumulator < RuneReader.UpdateValuesDelay  then
            RuneReader.GenerationDelayTimeStamp = time()
            return RuneReader.LastEncodedResult
        end
        RuneReader.GenerationDelayTimeStamp = time()

        -- reset the timer                
    if not Hekili_GetRecommendedAbility then
        return
    end

    local curTime = GetTime()

    -- We can use this here to tweak the delay times depending on world and home latency
    local _, _, _, latencyWorld = GetNetStats()


    --Grabs the current reccommended ability and store the datapac in dataPacPrimary,  will be nill if no recommendation is found.
    local t1, t2, dataPacPrimary = Hekili_GetRecommendedAbility("Primary", 1)
    --This grabs the next recommended ability.  this is ued to check for certain spells and execute them immediately (like interupts, think there may be a better way of doing this.)
    local _, _, dataPacNext = Hekili_GetRecommendedAbility("Primary", 2) -- Used for detecting interupts
    local _, _, dataPacAoe = Hekili_GetRecommendedAbility("AOE", 1)
    if t1 then RuneReader:AddToInspector(t1,'Hekili_GetRecommendedAbility("Primary", 1) t1') end 
    if dataPacPrimary then RuneReader:AddToInspector(dataPacPrimary,'Hekili_GetRecommendedAbility("Primary", 1) dataPacPrimary') end
    if dataPacNext then RuneReader:AddToInspector(dataPacNext,'Hekili_GetRecommendedAbility("Primary", 2) dataPacNext') end


    -- This is if hekili doesn't have a suggesion we use the last one.
    if not t1 or not dataPacPrimary then
        dataPacPrimary = RuneReader.LastDataPak;
        -- Hekili Sometimes returns a NIL even tough it still predicting on the screen.  I suspect its limiter cuts off the code
        -- this is here so it just reuses the last value.
        --return
    end;

    if dataPacPrimary.actionID == nil then
        dataPacPrimary.delay = 0;
        dataPacPrimary.wait = 0;
        dataPacPrimary.keybind = nil;
        dataPacPrimary.actionID = nil;
    end

    RuneReader.LastDataPak = dataPacPrimary;

    --print("Display Update")
    --Always select the priority spells first.

    if dataPacNext and RuneReader:RuneReaderEnv_hasSpell(RuneReader.PrioritySpells, dataPacNext.actionID) then
        dataPacPrimary = dataPacNext
    end

    --local actionName = dataPac.actionName
    --local index = dataPac.index
    if not dataPacPrimary.delay then dataPacPrimary.delay = 0 end
    if not dataPacPrimary.wait then dataPacPrimary.wait = 0 end
    if not dataPacPrimary.exact_time then dataPacPrimary.exact_time = curTime end
    if not dataPacPrimary.keybind then dataPacPrimary.keybind = "" end
    --local scriptType = dataPac.scriptType
    --local time = dataPac.time
    --local display = dataPac.display
    --local depth = dataPac.depth
    --local list = dataPac.list
    --local listName = dataPac.listName
    --local resources = dataPac.resources --table
    --local script = dataPac.script
    --local pack = dataPac.pack
    --local actionID = dataPac.actionID
    --local wait = dataPac.wait
    --local keybindFrom = dataPac.keybindFrom
    --local hook = dataPac.hook
    --local action = dataPac.action
    --local display = dataPac.display
    local delay = dataPacPrimary.delay
    local wait = dataPacPrimary.wait
    --local since = dataPac.since
    if RuneReader.lastSpell ~= dataPacPrimary.actionID then RuneReader.lastSpell = dataPacPrimary.actionID end
    --    local spellCooldownInfo  = C_Spell.GetSpellCooldown(RuneReaderEnv.lastSpell)
    --    if not spellCooldownInfo then  spellCooldownInfo = C_Spell.GetSpellCooldown(61304) end



    if wait == 0 then
        dataPacPrimary.exact_time = curTime
    end

    if UnitCanAttack("player", "target") then
        RuneReader.haveUnitTargetAttackable = true
    else
        RuneReader.haveUnitTargetAttackable = false
    end

    if dataPacPrimary.actionID ~= nil then
        if C_Spell.IsSpellHarmful(dataPacPrimary.actionID) == false then
            RuneReader.haveUnitTargetAttackable = true
        end
    end

    --print (dataPac.exact_time .. " - " .. delay .. " - " .. wait)
    local exact_time = ((dataPacPrimary.exact_time + delay) - (wait)) - RuneReader.config.PrePressDelay

    --local countDown = ((exact_time) - (curTime + (latencyWorld / 1000))) // lets ignore out latency.  I will move this to an output later.  
    local countDown = (exact_time - curTime)


    if countDown <= 0 then countDown = 0 end

    local bitvalue = 0
    if RuneReader.haveUnitTargetAttackable then
        bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 0)
    end
    if RuneReader.inCombat then
        bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 1)
    end

    local keytranslate = RuneReader:RuneReaderEnv_translateKey(dataPacPrimary.keybind, countDown)

    --These are some cheats.   there isn't any events for these to track,  so we have to look to see if the player has these auras.   if they do the barcodes are useless and should be disabled.
    --I am currently doing that by putting in what is in essence a null return,  it should hide the barcodes and bring them back.
    if AuraUtil.FindAuraByName("G-99 Breakneck", "player", "HELPFUL") then
        keytranslate = "00000"
    end
    if AuraUtil.FindAuraByName("Unstable Rocketpack", "player", "HELPFUL") then
        keytranslate = "00000"
    end

    local combinedValues = keytranslate .. bitvalue
    local checkDigit = RuneReader:CalculateCheckDigit(combinedValues)
    local fullResult = combinedValues .. checkDigit    
    RuneReader.LastEncodedResult = fullResult
    return fullResult

end


--#region Code39 Frame 
function RuneReader:CreateBarcodeWindow()
    if self.BarcodeFrame and self.BarcodeFrame:IsShown() then
        return -- Already shown
    elseif self.BarcodeFrame then
        self.BarcodeFrame:Show()
        return
    end

    local f = CreateFrame("Frame", "RuneReaderBarcodeFrame", UIParent, "BackdropTemplate")
    f:SetSize(220, 50)
    f:SetPoint("TOP", UIParent, "TOP", 0, 0)
    f:SetFrameStrata("TOOLTIP")
    f:SetMovable(true)
    f:SetResizable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(self)
        if IsAltKeyDown() then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position for reload/persistence
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        RuneReaderRecastDB = RuneReaderRecastDB or {}
        RuneReaderRecastDB.C39Position = {
            point = point,
            relativeTo = "UIParent",
            relativePoint = relativePoint,
            x = xOfs,
            y = yOfs
        }
    end)

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetBackdropColor(0.3, 0.2, 0, 1)
    f:SetResizeBounds(220,50)
   

          

    -- Barcode text region
    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetFont("Interface\\AddOns\\RuneReaderRecast\\Fonts\\LibreBarcode39Text-Regular.ttf", 40, "MONOCHROME")
    text:SetTextColor(0, 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetPoint("BOTTOMRIGHT", 0, 0)
    text:SetParent(f)
    f.Text = text

    -- Resize grip (bottom right)
    local resize = CreateFrame("Frame", nil, f)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT")
    local tex = resize:CreateTexture(nil, "OVERLAY")
    --tex:SetAllPoints(true)
    tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")


    resize:SetScript("OnMouseDown", function(self)
        if IsAltKeyDown() then self:GetParent():StartSizing("BOTTOMRIGHT") end
    end)

    resize:SetScript("OnMouseUp", function(self)
        self:GetParent():StopMovingOrSizing()
    end)

    -- Save reference for easy access
    self.BarcodeFrame = f

    -- Restore previous position if available
    if RuneReaderRecastDB and RuneReaderRecastDB.C39Position then
        local pos = RuneReaderRecastDB.C39Position
        f:ClearAllPoints()
        f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    end

    -- Initialize text if you wish
    f.Text:SetText("*SCANNED*")

        -- Call per-frame on-load logic, if needed:
    if not self.BarcodeFrame.hasBeenInitialized then
        -- Any logic you previously put in <OnLoad> (that is window-specific)

        -- If the frame is already created when the Lua file loads, initialize it immediately.
        if self.BarcodeFrame then

            self.BarcodeFrame:SetScript("OnUpdate", function(self, elapsed)
                if RuneReader then
                    RuneReader.C39FrameDelayAccumulator = RuneReader.C39FrameDelayAccumulator + elapsed
                    if RuneReader.C39FrameDelayAccumulator >= RuneReader.UpdateValuesDelay then
                        RuneReader:UpdateC39Display()
                        RuneReader.C39FrameDelayAccumulator = 0
                    end
                else
                    RuneReader.BarcodeFrame:SetScript("OnUpdate", nil)
                end
            end)
           
            -- For example, register frame-specific events here
            self.BarcodeFrame.hasBeenInitialized = true
        end
    end

    f:Show()
    
end

function RuneReader:DestroyBarcodeWindow()
    if self.BarcodeFrame then
        self.BarcodeFrame:Hide()
        -- Optionally, fully remove:
        -- self.BarcodeFrame:SetParent(nil)
        -- self.BarcodeFrame = nil
    end
end

-- Update barcode text:
function RuneReader:SetBarcodeText(str)
    if self.BarcodeFrame and self.BarcodeFrame.Text then
        self.BarcodeFrame.Text:SetText(str)
    end
end

-- Main update function replicating the WeakAura's customText logic
function RuneReader:UpdateC39Display()
    -- only updated the code if the code accually changed.  This saves on qrcode processing time
    -- also,  why do extra when we don't have to?
    local fullResult = RuneReader:UpdateCodeValues()

    if RuneReader.lastC39EncodeResult ~= fullResult  then
        RuneReader.lastC39EncodeResult =  fullResult
        RuneReader:SetBarcodeText("*" .. RuneReader.lastC39EncodeResult .. "*")
    end

end
--#endregion



--#region QRCode Frame 
function RuneReader:UpdateQRDisplay()
    -- only updated the code if the code accually changed.  This saves on qrcode processing time
    -- also,  why do extra when we don't have to?
    local fullResult = RuneReader:UpdateCodeValues()

    if RuneReader.lastQREncodeResult ~= fullResult  then
        RuneReader.lastQREncodeResult =  fullResult
        local success, matrix = QRencode.qrcode(RuneReader.lastQREncodeResult)--, RuneReader.Ec_level, "L")

        if success then
        if string.len(RuneReader.lastQREncodeResult) ~= RuneReader.DataLength then
            print ("old len " .. RuneReader.DataLength .. "new length" .. #RuneReader.lastQREncodeResult)
            RuneReader.DataLength = #RuneReader.lastQREncodeResult
            RuneReader:BuildQRCodeTextures(matrix,RuneReader.QRQuietZone,RuneReader.QRModuleSize)
        end
        RuneReader:UpdateQRCodeTextures(matrix)
        end
    end
end

function RuneReader:CreateQRWindow(qrMatrix, moduleSize, quietZone)
    if self.QRFrame and self.QRFrame:IsShown() then
        return -- Already shown
    elseif self.QRFrame then
        self.QRFrame:Show()
        return
    end

    moduleSize = moduleSize or 6
    quietZone = quietZone or 4

    local qrSize = qrMatrix and #qrMatrix or 21 -- Default to version 1
    local totalSize = (qrSize + 2 * quietZone) * moduleSize

    local f = CreateFrame("Frame", "RuneReaderQRFrame", UIParent, "BackdropTemplate")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetResizable(false)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
    f:SetBackdropColor(1, 1, 1, 1)
    f:RegisterForDrag("LeftButton")
    f:SetPoint("CENTER")
    f:SetSize(totalSize, totalSize)

    -- Dragging
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position for reload/persistence
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        RuneReaderRecastDB = RuneReaderRecastDB or {}
        RuneReaderRecastDB.QRposition = {
            point = point,
            relativeTo = "UIParent",
            relativePoint = relativePoint,
            x = xOfs,
            y = yOfs
        }
    end)

    self.QRFrame = f
    
    if not self.QRFrame.hasBeenInitialized then
        -- Register events, setup scripts, etc.
        self.QRFrame:SetScript("OnUpdate", function(self, elapsed)
            if RuneReader then
                RuneReader.QRFrameDelayAccumulator = RuneReader.QRFrameDelayAccumulator + elapsed
                if RuneReader.QRFrameDelayAccumulator >= RuneReader.UpdateValuesDelay then
                    RuneReader:UpdateQRDisplay()
                    RuneReader.QRFrameDelayAccumulator = 0
                end
            else
                RuneReader.QRFrame:SetScript("OnUpdate", nil)
            end
        end)

        self.QRFrame.hasBeenInitialized = true
    end

    -- Restore previous position if available
    if RuneReaderRecastDB and RuneReaderRecastDB.QRposition then
        local pos = RuneReaderRecastDB.QRposition
        f:ClearAllPoints()
        f:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
    end

    -- Initial fill (if qrMatrix supplied)
    if qrMatrix then
        self:BuildQRCodeTextures(qrMatrix, quietZone, moduleSize)
    else
        f.textures = {}
    end

    f:Show()
end

function RuneReader:DestroyQRWindow()
    if self.QRFrame then
        self.QRFrame:Hide()
        -- Optionally fully remove:
        -- self.QRFrame:SetParent(nil)
        -- self.QRFrame = nil
    end
end

function RuneReader:BuildQRCodeTextures(qrMatrix, quietZone, moduleSize)
    moduleSize = moduleSize or 6
    quietZone = quietZone or 4
    local qrSize = #qrMatrix
    local totalSize = (qrSize + 2 * quietZone) * moduleSize

    local f = self.QRFrame
    if not f then
        self:CreateQRWindow(qrMatrix, moduleSize, quietZone)
        f = self.QRFrame
    end
    f:SetSize(totalSize, totalSize)

    -- Only build textures if first time or matrix size has changed
    if not f.textures or #f.textures ~= qrSize * qrSize then
        -- Remove old textures if any
        if f.textures then
            for _, tex in ipairs(f.textures) do
                tex:Hide()
                tex:SetParent(nil)
            end
            wipe(f.textures)
        end
        f.textures = {}
        for y = 1, qrSize do
            for x = 1, qrSize do
                local tex = f:CreateTexture(nil, "ARTWORK")
                tex:SetSize(moduleSize, moduleSize)
                tex:SetPoint("TOPLEFT",
                    (x - 1 + quietZone) * moduleSize,
                    -((y - 1 + quietZone) * moduleSize)
                )
                tex:Show()
                table.insert(f.textures, tex)
            end
        end
    end

    self:UpdateQRCodeTextures(qrMatrix)
end



function RuneReader:UpdateQRCodeTextures(qrMatrix)
    if not self.QRFrame or not self.QRFrame.textures then return end
    local qrSize = #qrMatrix
    for y = 1, qrSize do
        for x = 1, qrSize do
            local i = (y - 1) * qrSize + x
            local tex = self.QRFrame.textures[i]
            if qrMatrix[y][x] > 0 then
                tex:SetColorTexture(0, 0, 0, 1)
      
            else
                tex:SetColorTexture(1, 1, 1, 0)   -- white, fully transparent
            end
        end
    end
end



--#endregion



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

--Setup conditions when the map is shown or hidden.   We want the codes to appear under the map when it is open,  but on top of everything when the map is closed.
function RuneReader:RegisterMapHooks()
    if WorldMapFrame then
        --  print("Registering World Map hooks...")           -- Debug message
        WorldMapFrame:HookScript("OnShow", RuneReader.HandleMapShow) -- Detect when the map is opened
        WorldMapFrame:HookScript("OnHide", RuneReader.HandleMapHide) -- Detect when the map is closed
    else
        print("ERROR: WorldMapFrame not found!")
    end
end




-- OnLoad function to set up the frame and its update logic
function RuneReader:RuneReaderRecast_OnLoad()
    if not C_AddOns.IsAddOnLoaded("Hekili") then
        print("Hekili is not loaded. HekiliRunreader is disabled.")
        return
    end

    -- Ensure the saved variables exist This should not be nil if prior values have been saved.
    if not RuneReaderRecastDB then
        RuneReaderRecastDB = {}
    end

    if not RuneReaderRecastDB.C39Position then
        RuneReaderRecastDB.C39Position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 }
    end
    if not RuneReaderRecastDB.QRposition then
        RuneReaderRecastDB.QRposition = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 }
    end
    RuneReader:RegisterMapHooks()
end




-- Check if Hekili is loaded; if not, delay initialization
-- Need to think about seperating hekili.    Use it if its available, if not use our own.  (to be coded)
function RuneReader:DelayLoadRuneReaderRecast()
        if not C_AddOns.IsAddOnLoaded("Hekili") then
            local waitFrame = CreateFrame("Frame")
            waitFrame:RegisterEvent("ADDON_LOADED")
            waitFrame:SetScript("OnEvent", function(self, event, addonName)
                if addonName == "Hekili" then
                    RuneReader:RuneReaderRecast_OnLoad() -- Now that Hekili is loaded, initialize our addon
                    self:UnregisterEvent("ADDON_LOADED")
                end
            end)
        else
        -- Hekili is already loaded, so initialize immediately
        RuneReader:RuneReaderRecast_OnLoad()

        if (RuneReader.UseCode39) then
          RuneReader:CreateBarcodeWindow();
        end
        
        if (RuneReader.UseQRCode) then
            local success, matrix1 = QRencode.qrcode(RuneReader.lastC39EncodeResult)--,7,"L")
            if success then
                RuneReader:CreateQRWindow(matrix1, RuneReader.QRQuietZone, RuneReader.QRModuleSize)
            end
        end

    end
end





function RuneReader:InitializeAddon()
    RuneReader:DelayLoadRuneReaderRecast()
end


local RuneReaderInit = CreateFrame("Frame")
RuneReaderInit:RegisterEvent("PET_BATTLE_OPENING_START")
RuneReaderInit:RegisterEvent("PET_BATTLE_CLOSE")
RuneReaderInit:RegisterEvent("ADDON_LOADED")
RuneReaderInit:SetScript("OnEvent",
    function(self, event, addonName)
        if event == "ADDON_LOADED" then
            if addonName == "RuneReaderRecast" then
                -- Addon is loading for the first time. Do all global setup.
                RuneReader:AddToInspector(event .. " " .. addonName,"EventFired")
                RuneReader:InitializeAddon()  -- Your new init method

                -- This is some fakeout code if WeakAuras are not loaded as the function Im using wont fire unless its loaded
                -- I hate this hack but not much I can do about it as I have no control over hekili
                -- I am going to rework this so I call Hekili Directly and not use the WeakAura event handling.
                -- That is a left over from when I originally did this addon using weakauras
                if not WeakAuras then
                    WeakAuras = {}
                    WeakAuras.ScanEvents = function(p1, p2, p3, p4, p5, p6)
                    end
                end
            end
        elseif event == "PET_BATTLE_OPENING_START" then
            --  print("Hiding Codes for pet battle.")
            if RuneReader.BarcodeFrame then
               RuneReader.BarcodeFrame:Hide()
            end
            if RuneReader.QRFrame then
                  RuneReader.QRFrame:Hide()
            end
        elseif event == "PET_BATTLE_CLOSE" then
            --  print("Showing Codes after pet battle.")
            if RuneReader.BarcodeFrame then
                RuneReader.BarcodeFrame:Show()
            end
            if RuneReader.QRFrame then
                RuneReader.QRFrame:Show()
            end
        end
            RuneReader:AddToInspector(event,"EventFired")
    end
)


-- SLASH_SHOWQR1 = "/showqr"
-- SlashCmdList["SHOWQR"] = function(msg)

--     local success, lmatrix = QRencode.qrcode("Updated QR", 7, "L")
--     if success then
--         RuneReader.UpdateQRCodeTextures(matrix)
--     end
--     -- local success, matrix = QRencode.qrcode(msg ~= "" and msg or "https://github.com/speedata/luaqrcode", 7, "L")
--     -- if success then
--     --     ShowQRCodeOnScreen(matrix, 6, 4)
--     -- else
--     --     print("QR Error: input too long?")
--     -- end
-- end

-- SLASH_HIDEQR1 = "/hideqr"
-- SlashCmdList["HIDEQR"] = function()
--     if QRFrame then QRFrame:Hide() end
-- end

-- local success, matrix = QRencode.qrcode("Hello World!", 5, "L")
-- if success then
--     ShowQRCodeOnScreen(matrix, 4, 2)
-- end

-- First time setup:

