-- BenchCrow_RWR_Export.lua  -  Bench Crow(TM) RWR display, DCS World export script
-- Sends your aircraft's radar warning picture to the Bench Crow RWR display over your home WiFi.
-- Install: see README at https://github.com/mjh1063/BenchCrow-DCS
--   1. Save this file as  Saved Games\DCS\Scripts\BenchCrow_RWR_Export.lua
--   2. Add this line to the END of  Saved Games\DCS\Scripts\Export.lua  (create the file if missing):
--        dofile(lfs.writedir()..[[Scripts\BenchCrow_RWR_Export.lua]])
-- (c) Bench Crow. For use with Bench Crow displays.

local ESP_IP   = ""               -- leave "" to reach the display anywhere on your home network,
                                  -- or put the address it shows at power-up, e.g. "192.168.1.160"
local ESP_PORT = 7778
local RATE_HZ  = 20
local AZ_SIGN  = 1                -- set to -1 if threats show mirrored left/right

package.path  = package.path  .. ";" .. lfs.currentdir() .. "/LuaSocket/?.lua"
package.cpath = package.cpath .. ";" .. lfs.currentdir() .. "/LuaSocket/?.dll"
local socket = require("socket")

-- DCS unit type name -> display symbol. Edit/extend freely.
-- Unmatched aircraft use the number in their name (MiG-29 -> 29); unmatched ships -> N; anything else -> U.
local CODES = {
  ["S-300PS 40B6M tr"]    = "10", ["S-300PS 40B6MD sr"]   = "10", ["S-300PS 64H6E sr"] = "10",
  ["SA-11 Buk SR 9S18M1"] = "11", ["SA-11 Buk LN 9A310M1"] = "11",
  ["Kub 1S91 str"]        = "6",
  ["Tor 9A331"]           = "15",
  ["Osa 9A33 ln"]         = "8",
  ["2S6 Tunguska"]        = "19",
  ["ZSU-23-4 Shilka"]     = "A",
  ["snr s-125 tr"]        = "3",
  ["SNR_75V"]             = "2",
  ["Hawk tr"]             = "HK", ["Hawk sr"] = "HK",
  ["Patriot str"]         = "P",
  ["Roland ADS"]          = "RO",
  ["Gepard"]              = "GP",
  ["1L13 EWR"]            = "S",  ["55G6 EWR"] = "S", ["Dog Ear radar"] = "S",
  -- more SAM / AAA radars
  ["S-300PS 5H63C 30H6_tr"] = "10", ["S-300PS 40B6MD MAST sr"] = "10",
  ["SA-11 Buk CC 9S470M1"]  = "11",
  ["p-19 s-125 sr"]         = "3",
  ["RPC_5N62V"]             = "5",  ["RLS_19J6"] = "5",
  ["Roland Radar"]          = "RO",
  ["Vulcan"]                = "A",
  ["HQ-7_STR_SP"]           = "HQ", ["HQ-7_LN_SP"] = "HQ",
  ["NASAMS_Radar_MPQ64F1"]  = "NA",
  ["rapier_fsa_blindfire_radar"] = "RA", ["rapier_fsa_launcher"] = "RA",
  ["Hawk cwar"]             = "HK", ["Hawk pcp"] = "HK",
}

-- match names regardless of capitals ("gepard" and "Gepard" both work)
local CODES_LC = {}
for k, v in pairs(CODES) do CODES_LC[k:lower()] = v end
local function lookup(n) return n and CODES_LC[n:lower()] end

-- ring 0 = inner (most lethal) .. 2 = outer
local RING = { missile_radio_guided = 0, lock = 0, track_while_scan = 1, scan = 2 }

local function codeFor(name, objName, air, naval)
  local c = lookup(name) or lookup(objName)
  if c then return c end
  if air then
    local num = (name and name:match("(%d+)")) or (objName and objName:match("(%d+)"))
    if num then return num:sub(1, 3) end
    return "AI"
  end
  if naval then return "N" end                 -- warships without their own entry
  return "U"
end

-- Records each emitter type DCS reports (once per type) to Saved Games\DCS\Logs\APR39_types.txt
-- so the CODES table above can be matched to the names DCS actually uses.
local LOG_TYPES = true
local seenTypes = {}
local function logType(e, name, objName, code)
  if not LOG_TYPES then return end
  local t = e.Type or {}
  local key = string.format("%s.%s.%s.%s", tostring(t.level1), tostring(t.level2), tostring(t.level3), tostring(t.level4))
  if seenTypes[key] then return end
  seenTypes[key] = true
  local f = io.open(lfs.writedir() .. "Logs\\APR39_types.txt", "a")
  if f then
    f:write(string.format("type=%s | name=%s | object=%s | signal=%s | shown as=%s\n",
      key, tostring(name), tostring(objName), tostring(e.SignalType), code))
    f:close()
  end
end

local function buildPacket()
  local parts = { "RWR" }
  local tws = LoGetTWSInfo()
  if tws and tws.Emitters then
    local function isLaser(e)
      return tostring(e.SignalType or ""):lower():find("laser") ~= nil
    end
    local best, bestP = nil, -math.huge
    for i, e in ipairs(tws.Emitters) do
      local p = e.Priority or 0
      if p > bestP and not isLaser(e) then best, bestP = i, p end
    end
    for i, e in ipairs(tws.Emitters) do
      if i > 16 then break end
      local name
      if e.Type then
        name = LoGetNameByType(e.Type.level1, e.Type.level2, e.Type.level3, e.Type.level4)
      end
      local objName
      if e.ID and LoGetObjectById then
        local ok, o = pcall(LoGetObjectById, e.ID)
        if ok and type(o) == "table" then objName = o.Name end
      end
      local air   = e.Type and e.Type.level1 == 1
      local naval = e.Type and e.Type.level1 == 3
      local code  = codeFor(name, objName, air, naval):gsub("[|,]", "")
      logType(e, name, objName, code)
      local sig  = e.SignalType or "scan"
      local az   = (math.deg(e.Azimuth or 0) * AZ_SIGN) % 360
      if isLaser(e) then
        -- laser warning: shown as a snowflake in that quadrant. DCS doesn't report the laser type,
        -- so send "L" (type unknown). Edit here if your module reports rangefinder/designator/beamrider.
        parts[#parts + 1] = string.format("L,%.0f,0,X", az)
      else
        local flags = ""
        if i == best then flags = flags .. "P" end
        if air then flags = flags .. "A" end
        if sig == "missile_radio_guided" then flags = flags .. "L" end
        parts[#parts + 1] = string.format("%s,%.0f,%d,%s", code, az, RING[sig] or 2, flags)
      end
    end
  end
  return table.concat(parts, "|")
end

-- chain with any existing exports (DCS-BIOS, SRS, etc.)
local udp, nextSend = nil, 0
local prevStart, prevAfter, prevStop = LuaExportStart, LuaExportAfterNextFrame, LuaExportStop

LuaExportStart = function()
  if prevStart then prevStart() end
  udp = socket.udp()
  udp:settimeout(0)
  if ESP_IP == "" then
    udp:setoption("broadcast", true)   -- send to every device on the home network
  end
  nextSend = 0
end

LuaExportAfterNextFrame = function()
  if prevAfter then prevAfter() end
  local t = LoGetModelTime()
  if udp and t >= nextSend then
    nextSend = t + 1 / RATE_HZ
    local ok, msg = pcall(buildPacket)
    if ok and msg then udp:sendto(msg, ESP_IP ~= "" and ESP_IP or "255.255.255.255", ESP_PORT) end
  end
end

LuaExportStop = function()
  if prevStop then prevStop() end
  if udp then udp:close(); udp = nil end
end
