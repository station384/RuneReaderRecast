-- HekiliRunreader.lua

-- Environment table mimicking aura_env
RuneReader = {}
RuneReader.last = GetTime()
RuneReader.lastResult = "*000000*"
RuneReader.config = { PrePressDelay = 0 }
RuneReader.haveUnitTargetAttackable = false
RuneReader.incombat = false
RuneReader.lastSpell = 61304
RuneReader.PrioritySpells = { 47528, 2139, 30449, 147362 }
RuneReader.FrameDelayAccumulator = 0
RuneReader.lastResult = ""

-- Check for Hekili addon
RuneReader.IsHekiliLoadedOrLoadeding, RuneReader.IsHekiliLoaded = C_AddOns.IsAddOnLoaded("Hekili")

if not RuneReader.IsHekiliLoaded then
    print("The Hekili Trigger will only work if Hekili is installed. Get it at www.curseforge.com/wow/addons/hekili.")
end
--Bringing this in as from the global just to keep my checker from telling me it is not defined.
if RuneReader.Hekili_GetRecommendedAbility == nil then
    print("Can't find hekili reccomended ability function")
end


RuneReader.GlobalframeName =
    RuneReaderRecastFrame -- this is set later after the window is created using XML.   it is on a timer.
-- Helper function: translateKey
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
    end

    if wait > 9.99 then wait = 9.99 end
    if wait < 0 then wait = 0 end
    if wait ~= nil then encodedWait = string.format("%04.2f", wait):gsub("[.]", "") end

    return encodedKey .. encodedWait
end

-- Helper function: set_bit
function RuneReader:RuneReaderEnv_set_bit(byte, bit_position)
    local bit_mask = 2 ^ bit_position
    if byte % (bit_mask + bit_mask) >= bit_mask then
        return byte     -- bit already set
    else
        return byte + bit_mask
    end
end

-- Helper function: hasSpell
function RuneReader:RuneReaderEnv_hasSpell(tbl, x)
    for _, v in ipairs(tbl) do
        if v == x then
            return true
        end
    end
    return false
end

-- Main update function replicating the WeakAura's customText logic
function RuneReader:UpdateRuneReader()
    if not Hekili_GetRecommendedAbility then
        return
    end

    local curTime = GetTime()

    local _, _, _, latencyWorld = GetNetStats()

    -- this function changes  depending on if weakauras is loaded or not
    --WA is loaded
    local _, _, dataPac = Hekili_GetRecommendedAbility("Primary", 1)
    --WA NOT loaded
    --dataPac = Hekili_GetRecommendedAbility("Primary", 1)

    if not dataPac then
        return
    end
    --print("Display Update")
    --Always select the priority spells first.
    local _, _, dataPacNext = Hekili_GetRecommendedAbility("Primary", 2)
    if dataPacNext and RuneReader:RuneReaderEnv_hasSpell(RuneReader.PrioritySpells, dataPacNext.actionID) then
        dataPac = dataPacNext
    end

    --local actionName = dataPac.actionName
    --local index = dataPac.index
    if not dataPac.delay then dataPac.delay = 0 end
    if not dataPac.wait then dataPac.wait = 0 end
    if not dataPac.exact_time then dataPac.exact_time = curTime end
    if not dataPac.keybind then dataPac.keybind = "" end
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
    local delay = dataPac.delay
    --local since = dataPac.since
    if RuneReader.lastSpell ~= dataPac.actionID then RuneReader.lastSpell = dataPac.actionID end
    --    local spellCooldownInfo  = C_Spell.GetSpellCooldown(RuneReaderEnv.lastSpell)
    --    if not spellCooldownInfo then  spellCooldownInfo = C_Spell.GetSpellCooldown(61304) end
    --    print(tostring( dataPac.exact_time) .. ' ' .. tostring(spellCooldownInfo.startTime)..' '..tostring(spellCooldownInfo.duration).. ' '..tostring(spellCooldownInfo.isEnabled)..' '..tostring(spellCooldownInfo.modRate));


    if dataPac.wait == 0 then
        dataPac.exact_time = curTime
    end

    if UnitCanAttack("player", "target") then
        RuneReader.haveUnitTargetAttackable = true
    else
        RuneReader.haveUnitTargetAttackable = false
    end

    if C_Spell.IsSpellHarmful(dataPac.actionID) == false then
        RuneReader.haveUnitTargetAttackable = true
    end 

    local exact_time = dataPac.exact_time + delay
    local prePressDelay = RuneReader.config.PrePressDelay
    local countDown = (exact_time - curTime - prePressDelay)     --+ (latencyWorld / 1000)

    if countDown <= 0 then countDown = 0 end

    local bitvalue = 0
    if RuneReader.haveUnitTargetAttackable then
        bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 0)
    end
    if RuneReader.incombat then
        bitvalue = RuneReader:RuneReaderEnv_set_bit(bitvalue, 1)
    end

    local keytranslate = RuneReader:RuneReaderEnv_translateKey(dataPac.keybind, countDown)
    if AuraUtil.FindAuraByName("G-99 Breakneck", "player", "HELPFUL") then
        keytranslate = "000000"
    end
    if AuraUtil.FindAuraByName("Unstable Rocketpack", "player", "HELPFUL") then
        keytranslate = "000000"
    end
    RuneReader.lastResult = "*" .. keytranslate .. bitvalue .. "*"


    RuneReaderRecastFrameText:SetText(RuneReader.lastResult)
end

function RuneReader:HandleWindowEvents(self, event)
    print("Event received: " .. event)     -- Debugging message
    if RuneReaderRecastFrame then
        if event == "PET_BATTLE_OPENING_START" then
            --  print("Hiding RuneReaderRecastFrame for pet battle.")
            self:Hide()
        elseif event == "PET_BATTLE_CLOSE" then
            --  print("Showing RuneReaderRecastFrame after pet battle.")
            self:Show()
        end
    else
        print("RuneReaderRecastFrame not found!")
    end
end

function RuneReader:HandleMapShow()
    if RuneReaderRecastFrame then
        --      print("Map opened: Moving frame under the map")
        RuneReaderRecastFrame:SetFrameStrata("LOW")     -- Move under the map
    end
end

function RuneReader:HandleMapHide()
    if RuneReaderRecastFrame then
        --     print("Map closed: Moving frame to top")
        RuneReaderRecastFrame:SetFrameStrata("TOOLTIP")     -- Move to top
    end
end

function RuneReader:RegisterMapHooks()
    if WorldMapFrame then
        --  print("Registering World Map hooks...")           -- Debug message
        WorldMapFrame:HookScript("OnShow", RuneReader.HandleMapShow)     -- Detect when the map is opened
        WorldMapFrame:HookScript("OnHide", RuneReader.HandleMapHide)     -- Detect when the map is closed
    else
        print("ERROR: WorldMapFrame not found!")
    end
end

function RuneReader:RegisterWindowEvents()
    if RuneReaderRecastFrame then
        print("Registering window battle events...")     -- Debug message

        RuneReaderRecastFrame:RegisterEvent("PET_BATTLE_OPENING_START")
        RuneReaderRecastFrame:RegisterEvent("PET_BATTLE_CLOSE")
        RuneReaderRecastFrame:SetScript("OnEvent", function(self, event)
            RuneReader:HandleWindowEvents(self, event)     -- Pet battle handling
        end)
        RuneReader:RegisterMapHooks()
    else
        print("RuneReaderRecastFrame not found!")
    end
end

-- OnLoad function to set up the frame and its update logic
function RuneReader:RuneReaderRecast_OnLoad()
    if not C_AddOns.IsAddOnLoaded("Hekili") then
        print("Hekili is not loaded. HekiliRunreader is disabled.")
        return
    end


    -- Ensure the saved variables exist
    if not RuneReaderRecastDB then
        RuneReaderRecastDB = {}
    end

    if not RuneReaderRecastDB.position then
        RuneReaderRecastDB.position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 }
    end
    -- Restore saved position
    RuneReaderRecastFrame:ClearAllPoints()
    RuneReaderRecastFrame:SetPoint(RuneReaderRecastDB.position.point, UIParent, RuneReaderRecastDB.position
        .relativePoint,
        RuneReaderRecastDB.position.x, RuneReaderRecastDB.position.y)


    if RuneReaderRecastFrame then
        RuneReaderRecastFrame:SetScript("OnUpdate", function(self, elapsed)
            if RuneReader then
                RuneReader.FrameDelayAccumulator = RuneReader.FrameDelayAccumulator + elapsed
                if RuneReader.FrameDelayAccumulator >= 0.05 then
                    RuneReader:UpdateRuneReader()
                    RuneReader.FrameDelayAccumulator = 0
                end
            else
                print("RuneReader not found, stopping OnUpdate.")
                self:SetScript("OnUpdate", nil)
            end
        end)
    end
end

-- Check if Hekili is loaded; if not, delay initialization
function RuneReader:DelayLoadRuneReaderRecast()
    if not C_AddOns.IsAddOnLoaded("Hekili") then
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("ADDON_LOADED")
        waitFrame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "Hekili" then
                RuneReader:RuneReaderRecast_OnLoad()     -- Now that Hekili is loaded, initialize our addon
                RuneReader:RegisterWindowEvents();
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    else
        -- Hekili is already loaded, so initialize immediately
        RuneReader:RuneReaderRecast_OnLoad()
        RuneReader:RegisterWindowEvents();
    end




    -- If the frame is already created when the Lua file loads, initialize it immediately.
    if RuneReaderRecastFrame then
        -- Apply the backdrop mixin manually
        Mixin(RuneReaderRecastFrame, BackdropTemplateMixin)

        -- Now set the backdrop and its colors
        RuneReaderRecastFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 16,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
        RuneReaderRecastFrame:SetBackdropColor(0.2, 0.2, 0.2, 1)
        RuneReaderRecastFrame:SetBackdropBorderColor(0, 0, 0, 1)
        RuneReaderRecastFrameText:SetShadowOffset(0, 0)
        RuneReaderRecastFrame:SetResizable(true)
        local minWidth, minHeight = 200, 50

        --These events are needed for savinging the layout values.
        RuneReaderRecastFrame:SetScript("OnSizeChanged", function(self, width, height)
            if width < minWidth or height < minHeight then
                local newWidth = math.max(width, minWidth)
                local newHeight = math.max(height, minHeight)
                self:SetSize(newWidth, newHeight)
            end
        end)
        RuneReaderRecastFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()

            -- Get the new position
            local point, _, relativePoint, xOfs, yOfs = self:GetPoint()

            -- Save it
            RuneReaderRecastDB.position = {
                point = point,
                relativeTo = "UIParent",
                relativePoint = relativePoint,
                x = xOfs,
                y = yOfs
            }
        end)
    end

    -- This is some fakeout code if WeakAuras are not loaded as the function Im using wont fire unless its loaded
    -- I hate this hack but not much I can do about it as I have no control over hekili
    if not WeakAuras then
        WeakAuras = {}
        WeakAuras.ScanEvents = function(p1, p2, p3, p4, p5, p6)
        end
    end
end
