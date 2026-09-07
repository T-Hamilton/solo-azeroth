-- SoloErrorLog: keep the last 200 Lua errors of a session in SavedVariables (WTF\Account\<acct>\SavedVariables\SoloErrorLog.lua)
SoloErrorLogDB = SoloErrorLogDB or {}
local seen, order = {}, {}
local function record(msg)
  msg = tostring(msg)
  local stack = debugstack(3, 12, 6) or ""
  if seen[msg] then seen[msg].count = seen[msg].count + 1; return end
  local e = { msg = msg, stack = stack, count = 1, t = date("%H:%M:%S") }
  seen[msg] = e; table.insert(order, e)
  if #order > 200 then table.remove(order, 1) end
end
local prev = geterrorhandler()
seterrorhandler(function(msg) record(msg); if prev then return prev(msg) end end)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(_, ev)
  if ev == "PLAYER_ENTERING_WORLD" then SoloErrorLogDB = { session = date("%Y-%m-%d %H:%M:%S"), errors = order } end
  if ev == "PLAYER_LOGOUT" then SoloErrorLogDB = { session = SoloErrorLogDB.session, errors = order } end
end)
SLASH_SOLOERR1 = "/errs"
SlashCmdList.SOLOERR = function()
  print("SoloErrorLog: " .. #order .. " distinct errors this session")
  for i = math.max(1, #order - 4), #order do print(i .. ": " .. order[i].msg) end
end
