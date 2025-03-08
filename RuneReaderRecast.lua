-- HekiliRunreader.lua

-- Environment table mimicking aura_env
RuneReaderEnv = {}
RuneReaderEnv.last = GetTime()
RuneReaderEnv.lastResult = "*000000*"
RuneReaderEnv.config = { PrePressDelay = 0 }
RuneReaderEnv.haveUnitTargetAttackable = false
RuneReaderEnv.incombat = false
RuneReaderEnv.lastSpell = 61304
RuneReaderEnv.PrioritySpells = { 47528, 2139, 30449, 147362 }

-- Check for Hekili addon
RuneReaderEnv.IsHekiliLoadedOrLoadeding, RuneReaderEnv.IsHekiliLoaded = C_AddOns.IsAddOnLoaded("Hekili")

if not RuneReaderEnv.IsHekiliLoaded then
    print("The Hekili Trigger will only work if Hekili is installed. Get it at www.curseforge.com/wow/addons/hekili.")
end
local Hekili_GetRecommendedAbility = _G
["Hekili_GetRecommendedAbility"]                                        --Bringing this in as from the global just to keep my checker from telling me it is not defined.
local GlobalframeName = nil                                             -- this is set later after the window is created using XML.   it is on a timer.
-- Helper function: translateKey
local function RuneReaderEnv_translateKey(hotKey, wait)
    local encodedKey = "00"
    local encodedWait = "0.0"
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

    if wait ~= nil then encodedWait = string.format("%04.1f", wait):gsub("[.]", "") end

    return encodedKey .. encodedWait
end

-- Helper function: set_bit
local function RuneReaderEnv_set_bit(byte, bit_position)
    local bit_mask = 2 ^ bit_position
    if byte % (bit_mask + bit_mask) >= bit_mask then
        return byte -- bit already set
    else
        return byte + bit_mask
    end
end

-- Helper function: hasSpell
local function RuneReaderEnv_hasSpell(tbl, x)
    for _, v in ipairs(tbl) do
        if v == x then
            return true
        end
    end
    return false
end

-- Main update function replicating the WeakAura's customText logic
local function UpdateRuneReader()
    if not Hekili_GetRecommendedAbility then
        return
    end

    if not dataPac then
        return
    end
    local curTime = GetTime()
    local _, _, _, latencyWorld = GetNetStats()
    local _, _, dataPac = Hekili_GetRecommendedAbility("Primary", 1)

    --Always select the priority spells first.
    local _, _, dataPacNext = Hekili_GetRecommendedAbility("Primary", 2)
    if dataPacNext and RuneReaderEnv_hasSpell(RuneReaderEnv.PrioritySpells, dataPacNext.actionID) then
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
    if RuneReaderEnv.lastSpell ~= dataPac.actionID then RuneReaderEnv.lastSpell = dataPac.actionID end
    --    local spellCooldownInfo  = C_Spell.GetSpellCooldown(RuneReaderEnv.lastSpell)
    --    if not spellCooldownInfo then  spellCooldownInfo = C_Spell.GetSpellCooldown(61304) end
    --    print(tostring( dataPac.exact_time) .. ' ' .. tostring(spellCooldownInfo.startTime)..' '..tostring(spellCooldownInfo.duration).. ' '..tostring(spellCooldownInfo.isEnabled)..' '..tostring(spellCooldownInfo.modRate));


    if dataPac.wait == 0 then
        dataPac.exact_time = curTime
    end

    if UnitCanAttack("player", "target") then
        RuneReaderEnv.haveUnitTargetAttackable = true
    else
        RuneReaderEnv.haveUnitTargetAttackable = false
    end

    local exact_time = dataPac.exact_time + delay
    local prePressDelay = RuneReaderEnv.config.PrePressDelay
    local countDown = (exact_time - curTime - prePressDelay) --+ (latencyWorld / 1000)

    if countDown <= 0 then countDown = 0 end

    local bitvalue = 0
    if RuneReaderEnv.haveUnitTargetAttackable then
        bitvalue = RuneReaderEnv_set_bit(bitvalue, 0)
    end
    if RuneReaderEnv.incombat then
        bitvalue = RuneReaderEnv_set_bit(bitvalue, 1)
    end

    local keytranslate = RuneReaderEnv_translateKey(dataPac.keybind, countDown)
    if AuraUtil.FindAuraByName("G-99 Breakneck", "player", "HELPFUL") then
        keytranslate = "000000"
    end
    if AuraUtil.FindAuraByName("Unstable Rocketpack", "player", "HELPFUL") then
        keytranslate = "000000"
    end
    RuneReaderEnv.lastResult = "*" .. keytranslate .. bitvalue .. "*"

    -- end
    RuneReaderRecastFrameText:SetText(RuneReaderEnv.lastResult)
end

local function HandleWindowEvents(self, event)
    print("Event received: " .. event) -- Debugging message
    if GlobalframeName then
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

local function HandleMapShow()
    if GlobalframeName then
        --      print("Map opened: Moving frame under the map")
        GlobalframeName:SetFrameStrata("LOW") -- Move under the map
    end
end

local function HandleMapHide()
    if GlobalframeName then
        --     print("Map closed: Moving frame to top")
        GlobalframeName:SetFrameStrata("TOOLTIP") -- Move to top
    end
end



local function RegisterMapHooks()
    if WorldMapFrame then
        --  print("Registering World Map hooks...")           -- Debug message
        WorldMapFrame:HookScript("OnShow", HandleMapShow) -- Detect when the map is opened
        WorldMapFrame:HookScript("OnHide", HandleMapHide) -- Detect when the map is closed
    else
        print("ERROR: WorldMapFrame not found!")
    end
end

local function RegisterWindowEvents()
    if GlobalframeName then
        -- print("Registering pet battle events...")  -- Debug message
        GlobalframeName:RegisterEvent("PET_BATTLE_OPENING_START")
        GlobalframeName:RegisterEvent("PET_BATTLE_CLOSE")
        GlobalframeName:SetScript("OnEvent", function(self, event)
            HandleWindowEvents(self, event) -- Pet battle handling
        end)
        -- Register the map visibility hooks
        RegisterMapHooks()
    else
        print("RuneReaderRecastFrame not found!")
    end
end

-- OnLoad function to set up the frame and its update logic
function RuneReaderRecast_OnLoad()
    if not C_AddOns.IsAddOnLoaded("Hekili") then
        print("Hekili is not loaded. HekiliRunreader is disabled.")
        return -- Stop execution of your addon code
    end
    GlobalframeName = _G["RuneReaderRecastFrame"]

    -- Ensure the saved variables exist
    if not RuneReaderRecastDB then
        RuneReaderRecastDB = {}
    end

    if not RuneReaderRecastDB.position then
        RuneReaderRecastDB.position = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", x = 0, y = 0 }
    end
    -- Restore saved position
    GlobalframeName:ClearAllPoints()
    GlobalframeName:SetPoint(RuneReaderRecastDB.position.point, UIParent, RuneReaderRecastDB.position.relativePoint,
        RuneReaderRecastDB.position.x, RuneReaderRecastDB.position.y)


    GlobalframeName.accumulator = 0
    GlobalframeName:SetScript("OnUpdate", function(self, elapsed)
        self.accumulator = self.accumulator + elapsed
        if self.accumulator >= 0.05 then
            --     print("OnUpdate fired", self.accumulator)  -- Debug print
            UpdateRuneReader()
            self.accumulator = 0
        end
    end)


    RegisterWindowEvents()
    GlobalframeName:SetScript("OnEvent", function(self, event, ...)
        UpdateRuneReader()
    end)
end

-- Check if Hekili is loaded; if not, delay initialization
function DelayLoadRuneReaderRecast()
    if not C_AddOns.IsAddOnLoaded("Hekili") then
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("ADDON_LOADED")
        waitFrame:SetScript("OnEvent", function(self, event, addonName)
            if addonName == "Hekili" then
                RuneReaderRecast_OnLoad() -- Now that Hekili is loaded, initialize our addon
                self:UnregisterEvent("ADDON_LOADED")
            end
        end)
    else
        -- Hekili is already loaded, so initialize immediately
        RuneReaderRecast_OnLoad()
    end

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
end

-- If the frame is already created when the Lua file loads, initialize it immediately.
C_Timer.After(1, RegisterWindowEvents)
