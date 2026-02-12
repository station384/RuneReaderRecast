-- RuneReader Recast
-- Copyright (c) Michael Sutton 2026
-- Licensed under the GNU General Public License v3.0 (GPLv3)
-- See: https://www.gnu.org/licenses/gpl-3.0.en.html
-- note:  alot of this code was created with the help of AI (code39 encoder), using my existing pattern from the QR code.
--        sad I know...  
-- Just incase they do away with custom fonts.... also looks a little cleaner.  



RuneReader = RuneReader or {}

-- ------------------------------------------------------------
-- Module
-- ------------------------------------------------------------
RuneReader.Code39 = RuneReader.Code39 or {}
local M = RuneReader.Code39

-- Public handle to the frame
M.Frame = M.Frame or nil

-- (accumulator lives on RuneReader)
RuneReader.Code39FrameDelayAccumulator = RuneReader.Code39FrameDelayAccumulator or 0


-- Defaults (override via RuneReaderRecastDB fields if you want)
M.defaults = {
  width  = 600,
  height = 120,
  scale  = 1.0,

  -- Code39 rendering options
  narrow = 1,     -- unit width for narrow elements (units)
  wide   = 3,     -- unit width for wide elements (units); set to 2 or 3
  gap    = 1,     -- inter-character gap (narrow space units)
  quiet  = 10,    -- quiet zone on each side (narrow units)
  snap   = true,  -- snap to integer pixels (recommended for capture/post-processing)

  -- Dragging / positioning
  clampToScreen = true,
  strata = "FULLSCREEN_DIALOG",
  minNarrowPx = 1,
  minWidth    = 200,
  maxWidth    = 1600
}

-- DB keys (optional; keep consistent with your QR DB style)
local DB_POS_KEY    = "Code39Position"
local DB_SCALE_KEY  = "ScaleCode39"
local DB_WIDE_KEY   = "Code39Wide"    -- 2 or 3 (or >=2)
local DB_SNAP_KEY   = "Code39Snap"    -- boolean
local DB_QUIET_KEY  = "Code39Quiet"   -- number
local DB_GAP_KEY    = "Code39Gap"     -- number
local DB_NARROW_KEY = "Code39Narrow"  -- number
local DB_MIN_NARROW_PX = "Code39MinNarrowPx"  -- e.g. 2 or 3
local DB_MIN_WIDTH     = "Code39MinWidth"     -- optional clamp
local DB_MAX_WIDTH     = "Code39MaxWidth"     -- optional clamp

-- ------------------------------------------------------------
-- Code39 pattern table
-- 9 elements per character, alternating bar/space starting with bar
-- 'n' = narrow, 'w' = wide
-- ------------------------------------------------------------
local CODE39 = {
  ["0"]="nnnwwnwnn", ["1"]="wnnwnnnnw", ["2"]="nnwwnnnnw", ["3"]="wnwwnnnnn",
  ["4"]="nnnwwnnnw", ["5"]="wnnwwnnnn", ["6"]="nnwwwnnnn", ["7"]="nnnwnnwnw",
  ["8"]="wnnwnnwnn", ["9"]="nnwwnnwnn",

  ["A"]="wnnnnwnnw", ["B"]="nnwnnwnnw", ["C"]="wnwnnwnnn", ["D"]="nnnnwwnnw",
  ["E"]="wnnnwwnnn", ["F"]="nnwnwwnnn", ["G"]="nnnnnwwnw", ["H"]="wnnnnwwnn",
  ["I"]="nnwnnwwnn", ["J"]="nnnnwwwnn",

  ["K"]="wnnnnnnww", ["L"]="nnwnnnnww", ["M"]="wnwnnnnwn", ["N"]="nnnnwnnww",
  ["O"]="wnnnwnnwn", ["P"]="nnwnwnnwn", ["Q"]="nnnnnnwww", ["R"]="wnnnnnwwn",
  ["S"]="nnwnnnwwn", ["T"]="nnnnwnwwn",

  ["U"]="wwnnnnnnw", ["V"]="nwwnnnnnw", ["W"]="wwwnnnnnn", ["X"]="nwnnwnnnw",
  ["Y"]="wwnnwnnnn", ["Z"]="nwwnwnnnn",

  ["-"]="nwnnnnwnw", ["."]="wwnnnnwnn", [" "]="nwwnnnwnn", ["$"]="nwnwnwnnn",
  ["/"]="nwnwnnnwn", ["+"]="nwnnnwnwn", ["%"]="nnnwnwnwn",

  ["*"]="nwnnwnwnn", -- start/stop
}

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
local function db() return RuneReaderRecastDB end

local function clamp(n, lo, hi)
  n = tonumber(n)
  if not n then return lo end
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function getOpt(key, fallback)
  local d = db()
  if not d then return fallback end
  local v = d[key]
  if v == nil then return fallback end
  return v
end

local function getOptions()
  local o = {}
  o.narrow = clamp(getOpt(DB_NARROW_KEY, M.defaults.narrow), 1, 10)
  o.wide   = clamp(getOpt(DB_WIDE_KEY,   M.defaults.wide),   2, 10) -- >=2
  o.gap    = clamp(getOpt(DB_GAP_KEY,    M.defaults.gap),    0, 10)
  o.quiet  = clamp(getOpt(DB_QUIET_KEY,  M.defaults.quiet),  0, 100)

  local snap = getOpt(DB_SNAP_KEY, M.defaults.snap)
  o.snap = (snap == true)

  return o
end

-- Build a run list: { {bar=true, units=n}, {bar=false, units=n}, ... }, plus total units
local function buildRuns(text, opts)
  opts = opts or {}
  local narrow = opts.narrow or 1
  local wide   = opts.wide   or 3
  local gap    = opts.gap    or 1
  local quiet  = opts.quiet  or 10

  text = tostring(text or ""):upper()
  local full = "*" .. text .. "*"

  local runs, totalUnits = {}, 0

  local function push(isBar, units)
    if units <= 0 then return end
    local last = runs[#runs]
    if last and last.bar == isBar then
      last.units = last.units + units
    else
      runs[#runs+1] = { bar = isBar, units = units }
    end
    totalUnits = totalUnits + units
  end

  if quiet > 0 then push(false, quiet) end

  for i = 1, #full do
    local ch = full:sub(i,i)
    local pat = CODE39[ch]
    if not pat then
      return nil, ("Code39: unsupported character '%s'"):format(ch)
    end

    for j = 1, 9 do
      local isBar = (j % 2 == 1)
      local sym = pat:sub(j,j)
      push(isBar, (sym == "w") and wide or narrow)
    end

    if i < #full and gap > 0 then
      push(false, gap)
    end
  end

  if quiet > 0 then push(false, quiet) end

  return runs, totalUnits
end

local function ensureBarPool(frame, needed)
  frame._bars = frame._bars or {}
  for i = #frame._bars + 1, needed do
    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetColorTexture(0, 0, 0, 1)
    frame._bars[i] = tex
  end
end

local function hideUnusedBars(frame, fromIndex)
  if not frame._bars then return end
  for i = fromIndex, #frame._bars do
    frame._bars[i]:Hide()
  end
end

-- Render: position/size bar textures to fill frame width/height
local function renderIntoFrame(frame, text)
  local opts = getOptions()
  local runs, totalOrErr = buildRuns(text, opts)
  if not runs then
    hideUnusedBars(frame, 1)
    if RuneReader and RuneReader.AddToInspector then
      RuneReader:AddToInspector(totalOrErr, "Code39 Error")
    else
      print(totalOrErr)
    end
    return false
  end

  local W = frame:GetWidth()
  local H = frame:GetHeight()
  if not W or W <= 1 or not H or H <= 1 then return false end

  -- Count bars (textures needed)
  local barRuns = 0
  for _, r in ipairs(runs) do
    if r.bar then barRuns = barRuns + 1 end
  end
  ensureBarPool(frame, barRuns)

  local pxPerUnit = W / totalOrErr
  local x = 0
  local barIndex = 0

  if not opts.snap then
    for _, r in ipairs(runs) do
      local w = r.units * pxPerUnit
      if r.bar and w > 0 then
        barIndex = barIndex + 1
        local tex = frame._bars[barIndex]
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
        tex:SetSize(w, H)
        tex:Show()
      end
      x = x + w
    end
  else
    -- snap run widths to integer pixels while preserving total width
    local widths = {}
    local used = 0
    for i, r in ipairs(runs) do
      local ideal = r.units * pxPerUnit
      local flo = math.floor(ideal)
      widths[i] = { bar = r.bar, w = flo, frac = ideal - flo }
      used = used + flo
    end

    local leftover = math.floor(W) - used
    if leftover > 0 then
      local idx = {}
      for i = 1, #widths do idx[i] = i end
      table.sort(idx, function(i, j) return widths[i].frac > widths[j].frac end)
      for k = 1, math.min(leftover, #idx) do
        widths[idx[k]].w = widths[idx[k]].w + 1
      end
    end

    for i = 1, #widths do
      local w = widths[i].w
      if widths[i].bar and w > 0 then
        barIndex = barIndex + 1
        local tex = frame._bars[barIndex]
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
        tex:SetSize(w, H)
        tex:Show()
      end
      x = x + w
    end
  end

  hideUnusedBars(frame, barIndex + 1)
  return true
end

local function savePosition(frame)
  local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
  RuneReaderRecastDB = RuneReaderRecastDB or {}
  RuneReaderRecastDB[DB_POS_KEY] = {
    point = point,
    relativeTo = "UIParent",
    relativePoint = relativePoint,
    x = xOfs,
    y = yOfs,
  }
end

local function restorePosition(frame)
  local pos = db() and db()[DB_POS_KEY]
  frame:ClearAllPoints()
  if pos then
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or 0)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end
local function calcAutoWidthPx(text)
  local opts = getOptions()
  local _, totalOrErr = buildRuns(text, opts)
  if type(totalOrErr) ~= "number" then
    return M.defaults.width -- fallback
  end

  local minNarrowPx = clamp(getOpt(DB_MIN_NARROW_PX, M.defaults.minNarrowPx), 1, 10)
  local minWidth    = clamp(getOpt(DB_MIN_WIDTH,     M.defaults.minWidth),    50, 5000)
  local maxWidth    = clamp(getOpt(DB_MAX_WIDTH,     M.defaults.maxWidth),    minWidth, 8000)

  local w = math.floor(totalOrErr * minNarrowPx + 0.5)
  return clamp(w, minWidth, maxWidth)
end
-- ------------------------------------------------------------
-- Public API
-- ------------------------------------------------------------

function M:Create( height)
  if self.Frame then
    -- like QR: if already exists, just show it
    if self.Frame:IsShown() then return self.Frame end
    self.Frame:Show()
    return self.Frame
  end


  local f = CreateFrame("Frame", "RuneReaderCode39Frame", UIParent, "BackdropTemplate")

  local autoW = calcAutoWidthPx(RuneReader.DefaultCode)
    local h = tonumber(height) or M.defaults.height
    f:SetSize(autoW, h)

  --f:SetSize(width or M.defaults.width, height or M.defaults.height)
  --f:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", tile = true })
    f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 3, edgeSize = 3,
    insets = { left = 0, right = 0, top = 0, bottom = 0}
    })
   
  --f:SetBackdropColor(1, 1, 1, 1)
   f:SetBackdropColor(0.3, 0.2, 0, 1)

  restorePosition(f)

  f:SetIgnoreParentScale(true)
  f:SetScale(getOpt(DB_SCALE_KEY, M.defaults.scale) or 1.0)

  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetResizable(false)
  f:SetClampedToScreen(getOpt("Code39ClampToScreen", M.defaults.clampToScreen) == true)
  f:SetFrameStrata(getOpt("Code39Strata", M.defaults.strata) or M.defaults.strata)

  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if IsAltKeyDown() then self:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    savePosition(self)
  end)

  f._bars = {}
  f._lastText = nil

  self.Frame = f
  f:Hide()
  f:Show()


  if not f.hasBeenInitialized then

        f:SetScript("OnUpdate", function(self, elapsed)
        
            if RuneReader then
                if RuneReader.Code39FrameDelayAccumulator >= RuneReaderRecastDB.UpdateValuesDelay + elapsed  then
                    RuneReader:UpdateCode39Display()
                    RuneReader.Code39FrameDelayAccumulator = 0
                end
            else
                RuneReader.BarcodeFrame:SetScript("OnUpdate", nil)
            end
            RuneReader.Code39FrameDelayAccumulator = RuneReader.Code39FrameDelayAccumulator + elapsed
        
        
        end)
    f.hasBeenInitialized = true
  end

  return f
end

function M:Dispose()
  local f = self.Frame
  if not f then return end

  f:SetScript("OnUpdate", nil)
  f:SetScript("OnDragStart", nil)
  f:SetScript("OnDragStop", nil)

  if f._bars then
    for _, tex in ipairs(f._bars) do
      tex:Hide()
      tex:SetParent(nil)
    end
    wipe(f._bars)
  end

  f:Hide()
  f:SetParent(nil)
  self.Frame = nil
end

function M:Show()
  if not self.Frame then self:Create() end
  self.Frame:Show()
end

function M:Hide()
  if self.Frame then self.Frame:Hide() end
end

-- Update the barcode contents NOW (does not recreate frame; just updates bar pool)
function M:UpdateCode39(text)
  if not self.Frame then self:Create() end
  local f = self.Frame
  if not f then return false end

  -- Optionally update scale live from DB (if your settings UI changes it)
  local sc = getOpt(DB_SCALE_KEY, M.defaults.scale) or 1.0
  if f:GetScale() ~= sc then
    f:SetScale(sc)
  end

  text = tostring(text or "")
    local desiredW = calcAutoWidthPx(text)
  local curW = f:GetWidth()
  if not curW or math.abs(curW - desiredW) > 0.5 then
    f:SetWidth(desiredW)
  end

  f._lastText = text

  return renderIntoFrame(f, text)
end

-- ------------------------------------------------------------
-- RuneReader-facing helpers (callable from elsewhere)
-- ------------------------------------------------------------

function RuneReader:CreateCode39Window(width, height) return M:Create(width, height) end
function RuneReader:DisposeCode39Window() return M:Dispose() end
function RuneReader:ShowCode39Window() return M:Show() end
function RuneReader:HideCode39Window() return M:Hide() end

-- Call this from your code to push content immediately
function RuneReader:UpdateCode39(text) return M:UpdateCode39(text) end

-- ------------------------------------------------------------
-- Update loop target (mirrors QR UpdateQRDisplay pattern)
-- ------------------------------------------------------------
-- This is the function the OnUpdate loop calls every UpdateValuesDelay.
-- Implement it to match your QR display pipeline (GetUpdatedValues etc).
--
-- Default behavior:
--   - uses RuneReader:GetUpdatedValues() if present
--   - renders that string as Code39
--
function RuneReader:UpdateCode39Display()
  local d = RuneReaderRecastDB
  if not d then return end

  -- You can swap this to RuneReader:GetUpdatedValues() or another function.
  local text
  if RuneReader.GetUpdatedValues then
    text = RuneReader:GetUpdatedValues()
  else
    -- fallback: if you store a value somewhere else, set it here
    text = d.Code39Value or ""
  end

  -- If you want to avoid redraw when unchanged:
  -- (Unlike QR, Code39 updates are cheap; still, we'll avoid doing it if stable)
  if M.Frame and M.Frame._lastText == text then
    return
  end

  M:UpdateCode39(text)
end

return M
