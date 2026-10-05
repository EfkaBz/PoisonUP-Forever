-- Options.lua - PoisonUp (Forever) - par Daeler
-- La fenêtre de réglages à quatre onglets, calquée sur celle de la version TBC :
-- Options, Menu, Timer, Sets de poison.
--
-- Tout est dessiné avec les éléments de Widgets.lua plutôt qu'avec les
-- templates de Blizzard, dont les noms ont disparu sur le moteur Retail.

local ADDON_NAME, NS = ...
local L, W = NS.L, NS.W

local PANEL_WIDTH, PANEL_HEIGHT = 440, 810
local LEFT = 22
local PAGE_TOP, PAGE_BOTTOM = -104, 50
local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil

local panel = CreateFrame("Frame", "PoisonUpForever_Options", UIParent, BACKDROP)
panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetClampedToScreen(true)
panel:Hide()
W.Window(panel)
tinsert(UISpecialFrames, panel:GetName())   -- Échap ferme la fenêtre

-- En-tête, comme Books on map : icône, titre, puis version et auteur.
local logo = panel:CreateTexture(nil, "ARTWORK")
logo:SetSize(40, 40)
logo:SetPoint("TOPLEFT", 16, -14)
logo:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\data\\poisonup_icon")

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -4)
title:SetText(L.TITLE)

local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
subtitle:SetTextColor(0.7, 0.7, 0.7)
subtitle:SetText("v" .. NS.VERSION .. "  |cff808080-|r  Daeler")

local hasCloseX, closeX = pcall(CreateFrame, "Button", nil, panel, "UIPanelCloseButton")
if hasCloseX and closeX then
  closeX:SetPoint("TOPRIGHT", -4, -4)
  closeX:SetScript("OnClick", function() panel:Hide() end)
end

-- Cadre sombre derrière le contenu des onglets.
local body = CreateFrame("Frame", nil, panel, BACKDROP)
body:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, PAGE_TOP + 6)
body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, PAGE_BOTTOM - 4)
W.Inset(body)

local close = W.Button(panel, L.CLOSE, 110)
close:SetPoint("BOTTOMRIGHT", -16, 16)
close:SetScript("OnClick", function() panel:Hide() end)

local save = W.Button(panel, L.SAVE, 130)
save:SetPoint("RIGHT", close, "LEFT", -8, 0)

-- Un conteneur par onglet ; un seul est visible à la fois.
local pages = {}
local function Page(index)
  local page = CreateFrame("Frame", nil, panel)
  page:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, PAGE_TOP)
  page:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, PAGE_BOTTOM)
  page:SetFrameLevel(body:GetFrameLevel() + 2)
  page:Hide()
  pages[index] = page
  return page
end

local optionsPage, menuPage, timerPage, presetPage = Page(1), Page(2), Page(3), Page(4)

-- =========================================================
-- AIDES DE MISE EN PAGE
-- =========================================================
-- Chaque page empile ses éléments de haut en bas ; ce petit curseur évite de
-- recalculer les positions à la main à chaque ajout.
local refreshers = {}

local function Cursor(page, startY)
  return { page = page, y = startY or -12 }
end

local function Section(cursor, text)
  local header = W.Header(cursor.page, text, PANEL_WIDTH - (LEFT - 2) * 2)
  header:SetPoint("TOPLEFT", cursor.page, "TOPLEFT", LEFT - 2, cursor.y)
  cursor.y = cursor.y - 26
  return header
end

local function Note(cursor, text, indent)
  local note = W.Text(cursor.page, text, { 0.6, 0.6, 0.6 })
  note:SetPoint("TOPLEFT", cursor.page, "TOPLEFT", LEFT + (indent or 0), cursor.y)
  note:SetWidth(PANEL_WIDTH - LEFT * 2 - (indent or 0))
  note:SetJustifyH("LEFT")
  cursor.y = cursor.y - 26
  return note
end

-- key : clé de la base. indent : décalage pour les sous-options.
local function Check(cursor, key, label, indent, onChange, color)
  local check = W.Check(cursor.page, label, color)
  check:SetPoint("TOPLEFT", cursor.page, "TOPLEFT", LEFT + (indent or 0), cursor.y)
  cursor.y = cursor.y - 24

  check:SetScript("OnClick", function(self)
    NS.DB()[key] = self:GetChecked() and true or false
    if onChange then onChange(self:GetChecked()) end
  end)
  refreshers[#refreshers + 1] = function()
    check:SetChecked(NS.DB()[key] and true or false)
  end
  return check
end

local function Slider(cursor, key, label, minValue, maxValue, step, onChange, format, indent)
  cursor.y = cursor.y - 20
  local slider = W.Slider(cursor.page, label, minValue, maxValue, step, format)
  slider:SetPoint("TOPLEFT", cursor.page, "TOPLEFT", LEFT + (indent or 0) + 60, cursor.y)
  slider:SetWidth(PANEL_WIDTH - LEFT * 2 - (indent or 0) - 80)
  cursor.y = cursor.y - 28

  slider:SetScript("OnValueChanged", function(self, value)
    -- Rafraîchissement de la fenêtre : on affiche la valeur, sans rappliquer
    -- les réglages (sinon ouvrir les options en combat touchait aux boutons
    -- sécurisés).
    if self.refreshing then return end
    value = math.floor(value / step + 0.5) * step
    NS.DB()[key] = value
    self:Refresh(value)
    if onChange then onChange(value) end
  end)
  refreshers[#refreshers + 1] = function()
    local value = NS.DB()[key] or minValue
    slider.refreshing = true
    slider:SetValue(value)
    slider.refreshing = false
    slider:Refresh(value)
  end
  return slider
end

local function Rebuild()
  NS.dirty = true
  NS.RefreshSecureState()
end

-- =========================================================
-- ONGLET 1 : OPTIONS
-- =========================================================
do
  local cursor = Cursor(optionsPage)

  local enable = Check(cursor, "enabled", L.OPT_ENABLE, 0, function()
    NS.UpdateButtons()
    NS.UpdateQuickButton()
  end, W.GOLD)
  -- La valeur enregistrée vaut nil tant que le joueur n'a rien choisi : c'est
  -- alors la classe qui décide. La case doit montrer l'état effectif.
  refreshers[#refreshers] = function() enable:SetChecked(NS.IsEnabled()) end

  cursor.y = cursor.y - 8
  Section(cursor, L.OPT_BUTTONS)
  Check(cursor, "showMinimapButton", L.OPT_MINIMAP, 16, function() NS.UpdateButtons() end)
  -- Le bouton « Réinitialiser la position » partage la ligne de la case
  -- « Afficher le bouton libre » : on mémorise la hauteur avant que le
  -- curseur ne descende.
  local freeRow = cursor.y
  local freeCheck = Check(cursor, "showFreeButton", L.OPT_FREE, 16, function() NS.UpdateButtons() end)

  local reset = W.Button(optionsPage, L.OPT_RESET_POS, 150)
  reset:SetPoint("TOPRIGHT", optionsPage, "TOPRIGHT", -24, freeRow - 1)
  reset:SetScript("OnClick", function() NS.ResetFreeButton() end)

  Check(cursor, "lockFreeButton", L.OPT_LOCK_FREE, 32)
  Slider(cursor, "freeScale", L.OPT_SCALE, 0.1, 2, 0.1, function() NS.UpdateButtons() end,
    function(v) return string.format("%.1f", v) end, 16)
  Slider(cursor, "freeAlpha", L.OPT_ALPHA, 0.1, 1, 0.1, function() NS.UpdateButtons() end,
    function(v) return string.format("%.1f", v) end, 16)

  -- Les carrés d'arme sont un élément affiché à l'écran comme les boutons :
  -- ils tiennent ici, alors que l'onglet Timer est déjà plein.
  cursor.y = cursor.y - 8
  Section(cursor, L.IND_SECTION)
  Check(cursor, "showIndicators", L.IND_SHOW, 16, function()
    NS.UpdateIndicatorLayout()
    NS.UpdateIndicators()
  end)
  Check(cursor, "showWindfuryIndicator", L.IND_WINDFURY, 16, function()
    NS.UpdateIndicatorLayout()
    NS.UpdateIndicators()
  end)
  Check(cursor, "showStoneIndicators", L.IND_STONES, 16, function()
    NS.UpdateIndicatorLayout()
    NS.UpdateIndicators()
  end)
  Check(cursor, "indicatorsAlways", L.IND_ALWAYS, 16, function()
    NS.UpdateIndicators()
  end)
  Check(cursor, "indicatorsLocked", L.IND_LOCK, 16, function()
    NS.UpdateIndicatorLayout()
    NS.UpdateIndicators()
  end)
  Slider(cursor, "indicatorSize", L.IND_SIZE, 24, 96, 2, function()
    NS.UpdateIndicatorLayout()
  end, nil, 16)
  Slider(cursor, "indicatorFadeAlpha", L.IND_FADE, 0.1, 1, 0.05, function()
    NS.UpdateIndicators()
  end, function(v) return string.format("%.2f", v) end, 16)

  cursor.y = cursor.y - 8
  Check(cursor, "announceChat", L.OPT_ANNOUNCE, 0, nil, W.GOLD)

  cursor.y = cursor.y - 8
  Section(cursor, L.OPT_HOVER_SECTION)
  Check(cursor, "menuOnHover", L.OPT_HOVER, 16)

  cursor.y = cursor.y - 8
  Section(cursor, L.OPT_AUTOHIDE_SECTION)
  Check(cursor, "hideInCombat", L.OPT_AUTOHIDE, 16)
end

-- =========================================================
-- ONGLET 2 : MENU
-- =========================================================
do
  local cursor = Cursor(menuPage)

  Section(cursor, L.MENU_PARENT)
  local parentFree = W.Check(menuPage, L.MENU_PARENT_FREE)
  parentFree:SetPoint("TOPLEFT", menuPage, "TOPLEFT", LEFT + 16, cursor.y)
  local parentMinimap = W.Check(menuPage, L.MENU_PARENT_MINIMAP)
  parentMinimap:SetPoint("TOPLEFT", menuPage, "TOPLEFT", LEFT + 190, cursor.y)
  cursor.y = cursor.y - 30

  -- Deux cases exclusives plutôt qu'une liste : c'est ainsi que l'original
  -- présentait le choix.
  local function SetParent(value)
    NS.DB().menuParent = value
    parentFree:SetChecked(value == "free")
    parentMinimap:SetChecked(value == "minimap")
    if NS.MenuShown() then NS.OpenMenu() end
  end
  parentFree:SetScript("OnClick", function() SetParent("free") end)
  parentMinimap:SetScript("OnClick", function() SetParent("minimap") end)
  refreshers[#refreshers + 1] = function()
    local value = NS.DB().menuParent
    parentFree:SetChecked(value ~= "minimap")
    parentMinimap:SetChecked(value == "minimap")
  end

  Slider(cursor, "menuScale", L.OPT_SCALE, 0.1, 2, 0.1, function()
    if NS.MenuShown() then NS.OpenMenu() end
  end, function(v) return string.format("%.1f", v) end, 16)

  -- Grille 3x3 des positions du menu autour du bouton, comme l'original.
  Section(cursor, L.MENU_POSITION)
  local GRID = {
    { "TOPLEFT", -1, 1, L.POS_TOPLEFT, "LEFT" },
    { "TOP", 0, 1, L.POS_TOP, "CENTER" },
    { "TOPRIGHT", 1, 1, L.POS_TOPRIGHT, "RIGHT" },
    { "LEFT", -1, 0, L.POS_LEFT, "LEFT" },
    { "RIGHT", 1, 0, L.POS_RIGHT, "RIGHT" },
    { "BOTTOMLEFT", -1, -1, L.POS_BOTTOMLEFT, "LEFT" },
    { "BOTTOM", 0, -1, L.POS_BOTTOM, "UNDER" },
    { "BOTTOMRIGHT", 1, -1, L.POS_BOTTOMRIGHT, "RIGHT" },
  }
  local centerX, centerY = PANEL_WIDTH / 2, cursor.y - 60
  local positionChecks = {}

  local icon = menuPage:CreateTexture(nil, "ARTWORK")
  icon:SetSize(30, 30)
  icon:SetPoint("TOPLEFT", menuPage, "TOPLEFT", centerX - 15, centerY + 15)
  icon:SetTexture(NS.ICON)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  local function SetPosition(value)
    NS.DB().menuPosition = value
    for key, check in pairs(positionChecks) do
      check:SetChecked(key == value)
    end
    if NS.MenuShown() then NS.OpenMenu() end
  end

  for _, cell in ipairs(GRID) do
    local key, dx, dy, label, side = cell[1], cell[2], cell[3], cell[4], cell[5]
    local check = W.Check(menuPage, "")
    check:SetPoint("TOPLEFT", menuPage, "TOPLEFT",
      centerX - 12 + dx * 46, centerY + 12 + dy * 36)
    check.label:SetText(label)
    check.label:ClearAllPoints()
    if side == "RIGHT" then
      check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
      check.label:SetJustifyH("LEFT")
    elseif side == "LEFT" then
      check.label:SetPoint("RIGHT", check, "LEFT", -4, 0)
      check.label:SetJustifyH("RIGHT")
    elseif side == "UNDER" then
      check.label:SetPoint("TOP", check, "BOTTOM", 0, -2)
      check.label:SetJustifyH("CENTER")
    else
      check.label:SetPoint("BOTTOM", check, "TOP", 0, 2)
      check.label:SetJustifyH("CENTER")
    end
    check:SetScript("OnClick", function() SetPosition(key) end)
    positionChecks[key] = check
  end
  refreshers[#refreshers + 1] = function()
    local value = NS.DB().menuPosition or "RIGHT"
    for key, check in pairs(positionChecks) do check:SetChecked(key == value) end
  end
  cursor.y = centerY - 62

  Slider(cursor, "menuSpacing", L.MENU_SPACING, -20, 20, 1, function()
    if NS.MenuShown() then NS.OpenMenu() end
  end, nil, 16)

  Section(cursor, L.MENU_TOOLTIP)
  local tooltipFull = W.Check(menuPage, L.MENU_TOOLTIP_FULL)
  tooltipFull:SetPoint("TOPLEFT", menuPage, "TOPLEFT", LEFT + 16, cursor.y)
  local tooltipName = W.Check(menuPage, L.MENU_TOOLTIP_NAME)
  tooltipName:SetPoint("TOPLEFT", menuPage, "TOPLEFT", LEFT + 190, cursor.y)
  cursor.y = cursor.y - 32

  local function SetTooltip(value)
    NS.DB().tooltipMode = value
    tooltipFull:SetChecked(value == "full")
    tooltipName:SetChecked(value == "name")
  end
  tooltipFull:SetScript("OnClick", function() SetTooltip("full") end)
  tooltipName:SetScript("OnClick", function() SetTooltip("name") end)
  refreshers[#refreshers + 1] = function()
    local value = NS.DB().tooltipMode
    tooltipFull:SetChecked(value ~= "name")
    tooltipName:SetChecked(value == "name")
  end

  Section(cursor, L.MENU_QUICK_SECTION)
  Check(cursor, "overwritePresets", L.MENU_OVERWRITE, 16, function() Rebuild() end)
  Note(cursor, L.MENU_OVERWRITE_NOTE, 16)

  -- « Button Sorting » : réordonner les types de poison dans la barre.
  local sorting = W.Button(menuPage, L.MENU_SORTING, 130)
  sorting:SetPoint("TOPRIGHT", menuPage, "TOPRIGHT", -24, -12)
  sorting:SetScript("OnClick", function() NS.ToggleSorting() end)
end

-- =========================================================
-- ONGLET 3 : TIMER
-- =========================================================
do
  local cursor = Cursor(timerPage)

  Check(cursor, "showTimer", L.TIMER_SHOW, 0, function() NS.UpdateTimers() end, W.GOLD)
  Slider(cursor, "warnMinutes", L.TIMER_THRESHOLD, 1, 25, 1, nil,
    function(v) return tostring(v) end, 0)
  Check(cursor, "ignoreFishing", L.TIMER_FISHING, 0)
  Check(cursor, "warnInstanceOnly", L.TIMER_INSTANCE, 0)

  cursor.y = cursor.y - 8
  Section(cursor, L.TIMER_WEAPONS)
  Check(cursor, "checkMainHand", L.MAINHAND, 16)
  Check(cursor, "checkOffHand", L.OFFHAND, 16)

  cursor.y = cursor.y - 8
  Section(cursor, L.TIMER_CHANNELS)
  Check(cursor, "warnEnabled", L.TIMER_ENABLED, 0)
  Check(cursor, "warnChat", L.TIMER_CHAT, 16)
  Check(cursor, "warnError", L.TIMER_ERROR, 16)
  Check(cursor, "warnAura", L.TIMER_AURA, 16)
  Check(cursor, "auraLocked", L.TIMER_AURA_LOCK, 16, function() NS.UpdateAura() end)

  Slider(cursor, "auraScale", L.OPT_SCALE, 0.1, 2, 0.1, function() NS.UpdateAura() end,
    function(v) return string.format("%.1f", v) end, 16)
  Slider(cursor, "auraAlpha", L.OPT_ALPHA, 0.1, 1, 0.1, function() NS.UpdateAura() end,
    function(v) return string.format("%.1f", v) end, 16)
end

-- =========================================================
-- ONGLET 4 : SETS DE POISON
-- =========================================================
do
  local cursor = Cursor(presetPage)
  local dropdowns = {}

  -- La liste proposée : « Aucun », puis tout ce qui est dans les sacs.
  local function Entries()
    local entries = { { text = NONE or "Aucun", value = false } }
    for _, entry in ipairs(NS.Inventory()) do
      entries[#entries + 1] = {
        text = entry.name, icon = entry.icon, value = entry.itemID,
      }
    end
    return entries
  end

  for _, key in ipairs(NS.PRESET_KEYS) do
    Section(cursor, L["PRESET_" .. key:upper()])

    local row = cursor.y
    for offset, hand in ipairs({ "mh", "oh" }) do
      local column = LEFT + 8 + (offset - 1) * 190
      local label = W.Text(presetPage,
        hand == "mh" and L.MAINHAND or L.OFFHAND, W.ORANGE)
      label:SetPoint("TOPLEFT", presetPage, "TOPLEFT", column, row)

      local dropdown = W.Dropdown(presetPage, 170)
      dropdown:SetPoint("TOPLEFT", presetPage, "TOPLEFT", column, row - 18)
      dropdown:SetScript("OnClick", function(self)
        self:SetEntries(Entries(), function(value)
          NS.SetPresetItem(key, hand, value or nil)
        end)
        self:Toggle()
      end)
      dropdowns[#dropdowns + 1] = { widget = dropdown, key = key, hand = hand }
    end
    cursor.y = row - 54
  end

  refreshers[#refreshers + 1] = function()
    for _, item in ipairs(dropdowns) do
      local itemID = NS.Preset(item.key)[item.hand]
      if itemID then
        local name, icon = NS.ItemInfo(itemID)
        item.widget:SetSelection(name, icon)
      else
        item.widget:SetSelection(nil)
      end
    end
  end

  cursor.y = cursor.y - 4
  Check(cursor, "showQuickButton", L.PRESET_SHOW_QUICK, 0, function()
    NS.UpdateQuickButton()
  end, W.GOLD)
  Check(cursor, "quickLocked", L.PRESET_LOCK_QUICK, 0)
  Slider(cursor, "quickScale", L.OPT_SCALE, 0.1, 2, 0.1, function() NS.UpdateQuickButton() end,
    function(v) return string.format("%.1f", v) end, 0)
  Slider(cursor, "quickAlpha", L.OPT_ALPHA, 0.1, 1, 0.1, function() NS.UpdateQuickButton() end,
    function(v) return string.format("%.1f", v) end, 0)
end

-- =========================================================
-- ONGLETS ET OUVERTURE
-- =========================================================
local TAB_TITLES = { L.TAB_OPTIONS, L.TAB_MENU, L.TAB_TIMER, L.TAB_PRESETS }

local tabBar = W.TabBar(panel, TAB_TITLES, function(index)
  for position, page in ipairs(pages) do
    page:SetShown(position == index)
  end
end)
tabBar.tabs[1]:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -68)

function NS.RefreshOptions()
  for _, refresh in ipairs(refreshers) do
    local ok, err = pcall(refresh)
    if not ok then NS.Debug("rafraîchissement : " .. tostring(err)) end
  end
end

save:SetScript("OnClick", function()
  -- L'espacement et l'échelle ne se voient qu'après reconstruction de la
  -- barre : c'est ce que faisait « Sauvegarder » dans l'original.
  Rebuild()
  NS.UpdateButtons()
  NS.UpdateQuickMacro()
  NS.UpdateAura()
  NS.UpdateIndicatorLayout()
  NS.UpdateIndicators()
  NS.RefreshOptions()
  NS.Print(L.SAVED)
end)

function NS.ToggleOptions()
  if panel:IsShown() then
    panel:Hide()
  else
    NS.dirty = true
    NS.RefreshOptions()
    panel:Show()
  end
end

tabBar:Select(1)

-- =========================================================
-- BUTTON SORTING
-- =========================================================
-- Petite fenêtre pour réordonner les types de poison dans la barre.
local sorter

local function FillSorter()
  -- La liste commence sous l'aide, quelle que soit sa hauteur.
  local y = -34 - math.ceil(sorter.hint:GetStringHeight()) - 12
  for index, category in ipairs(NS.OrderedCategories()) do
    local row = sorter.rows[index]
    if not row then
      row = CreateFrame("Frame", nil, sorter)
      row:SetSize(208, 20)
      row.label = W.Text(row, "", W.WHITE)
      row.label:SetPoint("LEFT", 0, 0)
      row.up = W.Button(row, "^", 22)
      row.up:SetPoint("RIGHT", row, "RIGHT", -26, 0)
      row.down = W.Button(row, "v", 22)
      row.down:SetPoint("RIGHT", row, "RIGHT", 0, 0)
      sorter.rows[index] = row
    end
    row:SetPoint("TOPLEFT", sorter, "TOPLEFT", 16, y)
    row.label:SetText(NS.CategoryLabel(category))
    row.up:SetScript("OnClick", function()
      if NS.MoveCategory(category, -1) then Rebuild() FillSorter() end
    end)
    row.down:SetScript("OnClick", function()
      if NS.MoveCategory(category, 1) then Rebuild() FillSorter() end
    end)
    row:Show()
    y = y - 22
  end
end

function NS.ToggleSorting()
  if sorter and sorter:IsShown() then sorter:Hide() return end

  if not sorter then
    sorter = CreateFrame("Frame", "PoisonUpForever_Sorting", UIParent, BACKDROP)
    sorter:SetSize(240, 340)
    sorter:SetPoint("LEFT", panel, "RIGHT", 8, 0)
    sorter:SetFrameStrata("DIALOG")
    sorter:EnableMouse(true)
    W.Window(sorter)
    sorter.rows = {}

    local heading = W.Text(sorter, L.MENU_SORTING, W.GOLD, "GameFontNormal")
    heading:SetPoint("TOP", 0, -14)

    local hint = W.Text(sorter, L.SORTING_HINT, { 0.6, 0.6, 0.6 })
    hint:SetPoint("TOPLEFT", 16, -34)
    hint:SetWidth(208)
    sorter.hint = hint

    local shut = W.Button(sorter, L.CLOSE, 80)
    shut:SetPoint("BOTTOM", 0, 12)
    shut:SetScript("OnClick", function() sorter:Hide() end)
  end

  FillSorter()
  sorter:Show()
end

-- =========================================================
-- COMMANDES
-- =========================================================
local function Usage()
  NS.Print(L.TITLE .. " - commandes :")
  print("  |cffffd100/poisonup|r - ouvre les options")
  print("  |cffffd100/poisonup on|off|r - active ou désactive l'addon")
  print("  |cffffd100/poisonup lock|unlock|r - verrouille le bouton libre")
  print("  |cffffd100/poisonup reset|r - replace les cadres au centre de l'écran")
  print("  |cffffd100/poisonup sets|r - affiche les jeux de poisons")
  print("  |cffffd100/poisonup clearsets|r - efface tous les jeux")
  print("  |cffffd100/poisonup status|r - état du câblage (diagnostic)")
  print("  |cffffd100/poisonup debug|r - trace les clics dans le chat")
end

SLASH_POISONUPFOREVER1 = "/poisonup"
SLASH_POISONUPFOREVER2 = "/pup"
SlashCmdList["POISONUPFOREVER"] = function(input)
  local command = ((input or ""):lower():match("^(%S*)") or "")
  local db = NS.DB()

  if command == "" then
    NS.ToggleOptions()
  elseif command == "on" or command == "enable" then
    db.enabled = true
    NS.UpdateButtons()
    NS.UpdateQuickButton()
    NS.Print(L.ENABLED)
  elseif command == "off" or command == "disable" then
    db.enabled = false
    NS.UpdateButtons()
    NS.UpdateQuickButton()
    NS.Print(L.DISABLED)
  elseif command == "lock" then
    db.lockFreeButton = true
    NS.RefreshOptions()
  elseif command == "unlock" then
    db.lockFreeButton = false
    NS.RefreshOptions()
  elseif command == "reset" then
    db.anchor, db.quickAnchor = nil, nil
    db.auraAnchor, db.indicatorsAnchor = nil, nil
    db.freeScale, db.menuScale = 1.0, 1.0
    NS.UpdateButtons()
    NS.UpdateQuickButton()
    NS.UpdateAura()
    NS.UpdateIndicatorLayout()
    NS.RefreshOptions()
    NS.Print(L.RESET)
  elseif command == "sets" then
    for _, key in ipairs(NS.PRESET_KEYS) do
      print("  " .. L["PRESET_" .. key:upper()] .. " : "
        .. (NS.PresetLabel(key) or (NONE or "Aucun")))
    end
  elseif command == "clearsets" then
    for _, key in ipairs(NS.PRESET_KEYS) do NS.Presets()[key] = {} end
    NS.UpdateQuickMacro()
    NS.RefreshOptions()
    NS.Print(L.PRESETS_CLEARED)
  elseif command == "debug" then
    db.debug = not db.debug
    Rebuild()
    NS.Print("debug " .. (db.debug and "activé" or "désactivé"))
  elseif command == "status" then
    NS.Print("objets détectés dans les sacs : " .. #NS.Inventory()
      .. " | boutons XML : " .. (NS.xmlMissing and "NON" or "oui"))
    print("  " .. L.MAINHAND .. " : "
      .. (NS.EquippedName(NS.SLOT_MAINHAND) or "|cffff4040RIEN|r"))
    print("  " .. L.OFFHAND .. " : "
      .. (NS.EquippedName(NS.SLOT_OFFHAND) or "|cffff4040RIEN|r"))
    local first = _G["PoisonUpForever_Item1"]
    if first and first.itemID then
      print("  clic gauche -> " .. NS.DescribeWiring(first, "1"))
      print("  clic droit  -> " .. NS.DescribeWiring(first, "2"))
    end
    -- Bouton rapide : visibilité et macros réellement posées sur le bouton.
    local quick = NS.quickButton
    if quick then
      print(("  bouton rapide : affiché=%s option=%s type1=%s type2=%s"):format(
        tostring(quick:IsShown()), tostring(NS.DB().showQuickButton),
        tostring(quick:GetAttribute("type1")), tostring(quick:GetAttribute("type2"))))
      for _, attribute in ipairs({ "macrotext1", "macrotext2" }) do
        local text = quick:GetAttribute(attribute)
        print("  " .. attribute .. " :")
        for line in tostring(text):gmatch("[^\n]+") do print("    " .. line) end
      end
    end
    -- État des poisons posés, et par quelle voie il a été obtenu.
    local db = NS.DB()
    print(("  carrés : option=%s verrouillés=%s combat=%s affichés=%s main gauche suivie=%s"):format(
      tostring(db.showIndicators), tostring(db.indicatorsLocked),
      tostring(InCombatLockdown and InCombatLockdown()),
      tostring(NS.indicators and NS.indicators:IsShown()), tostring(db.checkOffHand)))
    local state = NS.WeaponEnchants()
    for _, hand in ipairs({ { "mh", L.MAINHAND }, { "oh", L.OFFHAND } }) do
      local slot = state[hand[1]]
      print(("  %s : actif=%s reste=%s source=%s %s"):format(
        hand[2], tostring(slot.active), NS.FormatTime(slot.remaining),
        slot.fromTooltip and "infobulle" or "API",
        slot.label and ("| " .. slot.label) or ""))
      local wf = slot.windfury or {}
      print(("    furie-des-vents : actif=%s %s"):format(
        tostring(wf.active), wf.label and ("| " .. wf.label) or ""))
      local stone = slot.stone or {}
      print(("    pierre/huile : actif=%s reste=%s %s"):format(
        tostring(stone.active), NS.FormatTime(stone.remaining),
        stone.label and ("| " .. stone.label) or ""))
    end
  else
    Usage()
  end
end
