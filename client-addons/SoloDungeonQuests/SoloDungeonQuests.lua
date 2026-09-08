-- Solo Dungeon Quests: a GM panel that grants every quest tied to a chosen dungeon.
-- Data (dungeon -> quest ids) is generated from the world DB by tools/build_dungeon_quests.py into DungeonQuestsData.lua.
-- Granting uses ".quest add <id>", which only works on a GM account. Open with /dq (or /dungeonquests).

local DATA = SoloDungeonQuestsData or {}
SoloDungeonQuestsUI = SoloDungeonQuestsUI or {}

local ROWS = 15
local ROW_H = 21
local filter = "All"                 -- All | Classic | Burning Crusade | Wrath

-- ---- throttled ".quest add" queue (avoid the chat flood limit) -----------------------------------------------
local queue, qi, acc = {}, 0, 0
local runner = CreateFrame("Frame")
runner:Hide()
runner:SetScript("OnUpdate", function(self, dt)
  acc = acc + dt
  if acc < 0.15 then return end
  acc = 0
  qi = qi + 1
  if not queue[qi] then queue, qi = {}, 0; self:Hide(); return end
  SendChatMessage(queue[qi], "SAY")
end)

local function GrantDungeon(d)
  if not d or not d.quests then return end
  for _, q in ipairs(d.quests) do queue[#queue + 1] = ".quest add " .. q.id end
  runner:Show()
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99SoloDungeonQuests|r: adding " .. #d.quests ..
    " quests for |cffffd100" .. d.name .. "|r. The quest log holds 25 at a time; turn some in if it fills.")
end

-- ---- filtered dungeon list ------------------------------------------------------------------------------------
local function List()
  local out = {}
  for _, d in ipairs(DATA) do
    if filter == "All" or d.expansion == filter then out[#out + 1] = d end
  end
  return out
end

-- ---- frame ----------------------------------------------------------------------------------------------------
local f = CreateFrame("Frame", "SoloDungeonQuestsFrame", UIParent)
f:SetWidth(360); f:SetHeight(ROWS * ROW_H + 96)
f:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
f:SetPoint(SoloDungeonQuestsUI.point or "CENTER", UIParent,
  SoloDungeonQuestsUI.point or "CENTER", SoloDungeonQuestsUI.x or 0, SoloDungeonQuestsUI.y or 0)
f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, _, x, y = self:GetPoint()
  SoloDungeonQuestsUI.point, SoloDungeonQuestsUI.x, SoloDungeonQuestsUI.y = p, x, y
end)
f:Hide()
tinsert(UISpecialFrames, "SoloDungeonQuestsFrame")   -- Esc closes it

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -18)
title:SetText("Dungeon Quests")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -8, -8)

-- expansion filter buttons
local FILTERS = { "All", "Classic", "Burning Crusade", "Wrath" }
local fbtns = {}
local function Refresh() end   -- forward declare
local x = 16
for _, name in ipairs(FILTERS) do
  local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  local w = (name == "All") and 40 or (name == "Burning Crusade" and 104 or 66)
  b:SetWidth(w); b:SetHeight(20)
  b:SetPoint("TOPLEFT", x, -44); x = x + w + 4
  b:SetText(name == "Burning Crusade" and "Burning C." or name)
  b:SetScript("OnClick", function() filter = name; FauxScrollFrame_SetOffset(f.scroll, 0); Refresh() end)
  fbtns[name] = b
end

-- scroll list
f.scroll = CreateFrame("ScrollFrame", "SoloDungeonQuestsScroll", f, "FauxScrollFrameTemplate")
f.scroll:SetPoint("TOPLEFT", 16, -72)
f.scroll:SetPoint("BOTTOMRIGHT", -34, 16)
f.scroll:SetScript("OnVerticalScroll", function(self, offset)
  FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, Refresh)
end)

f.rows = {}
for i = 1, ROWS do
  local r = CreateFrame("Button", nil, f)
  r:SetWidth(300); r:SetHeight(ROW_H)
  r:SetPoint("TOPLEFT", f.scroll, "TOPLEFT", 0, -(i - 1) * ROW_H)
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  local t = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  t:SetPoint("LEFT", 4, 0); t:SetJustifyH("LEFT"); t:SetWidth(290)
  r.text = t
  r:SetScript("OnClick", function(self) if self.d then GrantDungeon(self.d) end end)
  r:SetScript("OnEnter", function(self)
    if not self.d then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.d.name, 1, 0.82, 0)
    GameTooltip:AddLine(self.d.expansion .. "  -  level " .. self.d.level, 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")
    for _, q in ipairs(self.d.quests) do
      GameTooltip:AddDoubleLine(q.title, "lvl " .. q.level, 1, 1, 1, 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to add all " .. #self.d.quests .. " quests to your log.", 0.2, 1, 0.4)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.rows[i] = r
end

Refresh = function()
  local list = List()
  local offset = FauxScrollFrame_GetOffset(f.scroll)
  FauxScrollFrame_Update(f.scroll, #list, ROWS, ROW_H)
  for i = 1, ROWS do
    local d = list[i + offset]
    local r = f.rows[i]
    if d then
      r.d = d
      r.text:SetText(d.name .. "  |cff888888(lvl " .. d.level .. ", " .. #d.quests .. "q)|r")
      r:Show()
    else
      r.d = nil; r:Hide()
    end
  end
  for name, b in pairs(fbtns) do
    if name == filter then b:LockHighlight() else b:UnlockHighlight() end
  end
end

f:SetScript("OnShow", Refresh)

local function Toggle()
  if f:IsShown() then f:Hide() else f:Show() end
end

SLASH_SOLODQ1 = "/dq"
SLASH_SOLODQ2 = "/dungeonquests"
SlashCmdList.SOLODQ = Toggle

-- one-time hint
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
  if not SoloDungeonQuestsUI.seen then
    SoloDungeonQuestsUI.seen = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99SoloDungeonQuests|r loaded. Type |cffffd100/dq|r to open the dungeon quest panel.")
  end
end)
