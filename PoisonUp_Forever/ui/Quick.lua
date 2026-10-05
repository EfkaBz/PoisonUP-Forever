-- Quick.lua - PoisonUp (Forever) - par Daeler
-- Le bouton rapide.
--
-- Reprise du « bouton rapide » de la version TBC : un seul bouton applique les
-- deux mains d'un coup, et le jeu de poisons appliqué dépend du modificateur
-- tenu — Défaut, MAJ, CTRL, ALT — réglés dans l'onglet « Sets de poison ».
--
-- Les modificateurs sont bien transmis sur ce client, contrairement au bouton
-- de souris cliqué : [modifier:shift] et compagnie fonctionnent donc, alors
-- que la distinction des mains doit passer par les attributs suffixés. Voir
-- NS.QuickMacro dans Core.lua.

local ADDON_NAME, NS = ...
local L = NS.L

local button = _G["PoisonUpForever_QuickButton"]
if not button then
  button = CreateFrame("Button", "PoisonUpForever_QuickButton", UIParent,
    "SecureActionButtonTemplate")
  NS.xmlMissing = true
end
button:SetFrameStrata("MEDIUM")
button:SetMovable(true)
button:SetClampedToScreen(true)
button:RegisterForClicks("AnyDown", "AnyUp")
button:RegisterForDrag("LeftButton")
NS.quickButton = button

button.bg = button:CreateTexture(nil, "BACKGROUND")
button.bg:SetAllPoints(button)
button.bg:SetColorTexture(0, 0, 0, 0.85)

button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetPoint("TOPLEFT", 2, -2)
button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

button.border = button:CreateTexture(nil, "BORDER")
button.border:SetPoint("TOPLEFT", -1, 1)
button.border:SetPoint("BOTTOMRIGHT", 1, -1)
button.border:SetColorTexture(0.7, 0.55, 0.2, 0.9)

button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
local highlight = button:GetHighlightTexture()
if highlight then highlight:SetBlendMode("ADD") end

-- =========================================================
-- DÉPLACEMENT
-- =========================================================
button:SetScript("OnDragStart", function(self)
  if NS.DB().quickLocked or InCombatLockdown() then return end
  self:StartMoving()
  self.isMoving = true
end)

button:SetScript("OnDragStop", function(self)
  if not self.isMoving then return end
  self:StopMovingOrSizing()
  self.isMoving = false
  local left, bottom = self:GetLeft(), self:GetBottom()
  if left and bottom then
    local ratio = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
  end
  local point, _, _, x, y = self:GetPoint(1)
  if point then NS.DB().quickAnchor = { point = point, x = x, y = y } end
end)

-- =========================================================
-- INFOBULLE
-- =========================================================
button:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:AddLine(L.QUICK_TITLE)
  local any = false
  for _, key in ipairs(NS.PRESET_KEYS) do
    local label = NS.PresetLabel(key)
    if label then
      GameTooltip:AddLine(L["PRESET_" .. key:upper()] .. " - " .. label, 1, 1, 1)
      any = true
    end
  end
  if not any then
    GameTooltip:AddLine(L.QUICK_EMPTY, 1, 0.4, 0.4)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L.TT_APPLY_MH, 0.7, 0.7, 0.7)
  GameTooltip:AddLine(L.TT_APPLY_OH, 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- =========================================================
-- CÂBLAGE ET VISIBILITÉ
-- =========================================================
-- L'icône reprend celle du poison de main droite du jeu « Défaut », pour que
-- le bouton dise d'un coup d'œil ce qu'il va appliquer.
local function RefreshIcon()
  -- Guerrier : bouton à part, toujours la pierre à aiguiser.
  if NS.IsWarrior() then
    button.icon:SetTexture(NS.STONE_ICON)
    button.icon:SetDesaturated(false)
    return
  end
  local preset = NS.Preset("default")
  local itemID = preset.mh or preset.oh
  if itemID then
    local _, icon = NS.ItemInfo(itemID)
    button.icon:SetTexture(icon)
    button.icon:SetDesaturated(false)
  else
    button.icon:SetTexture(NS.ICON)
    button.icon:SetDesaturated(true)
  end
end

function NS.UpdateQuickMacro()
  if InCombatLockdown() then return end
  local macro = NS.QuickMacro()
  button:SetAttribute("type", macro and "macro" or nil)
  button:SetAttribute("macrotext", macro)
  -- Clic gauche = main droite, clic droit = main gauche, par les attributs
  -- suffixés : c'est la voie qu'emprunte ce client pour les boutons du menu.
  -- Préfixe « * » : sans lui, un MAJ/CTRL/ALT + clic cherche d'abord
  -- ctrl-type1 etc., puis retombe sur la macro commune au lieu de type1.
  -- Une macro simple par modificateur, posée sur les attributs préfixés
  -- (shift-type1, ctrl-macrotext2...), sans condition [modifier:...] : c'est
  -- exactement la forme des boutons du menu, qui fonctionne sur ce client.
  for suffix, hand in pairs({ ["1"] = "mh", ["2"] = "oh" }) do
    button:SetAttribute("*type" .. suffix, nil)
    button:SetAttribute("*macrotext" .. suffix, nil)
    local slot = (hand == "mh") and NS.SLOT_MAINHAND or NS.SLOT_OFFHAND
    for _, key in ipairs(NS.PRESET_KEYS) do
      local prefix = (key == "default") and "" or (key .. "-")
      local itemID = NS.Preset(key)[hand]
      local handMacro = itemID and NS.MacroFor(itemID, slot) or nil
      -- Valeur vide plutôt que nil sur un modificateur sans poison : sinon le
      -- clic retomberait sur la macro du jeu « Défaut ».
      button:SetAttribute(prefix .. "type" .. suffix, handMacro and "macro" or "")
      button:SetAttribute(prefix .. "macrotext" .. suffix, handMacro)
    end
  end
  RefreshIcon()
  NS.UpdateQuickButton()
end

function NS.UpdateQuickButton()
  local db = NS.DB()
  local size = 36 * (db.quickScale or 1)
  button:SetSize(size, size)
  button:SetAlpha(db.quickAlpha or 1)

  button:ClearAllPoints()
  local anchor = db.quickAnchor
  if type(anchor) == "table" and anchor.point then
    button:SetPoint(anchor.point, UIParent, anchor.point, anchor.x or 0, anchor.y or 0)
  else
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
  end

  button:SetShown(NS.IsEnabled() and db.showQuickButton and NS.QuickMacro() ~= nil)
end
