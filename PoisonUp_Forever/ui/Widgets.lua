-- Widgets.lua - PoisonUp (Forever) - par Daeler
-- Petits éléments d'interface réutilisés par la fenêtre d'options.
--
-- Rien n'est repris des templates de Blizzard : leurs noms ont bougé d'une
-- version à l'autre (InterfaceOptionsCheckButtonTemplate, OptionsSliderTemplate
-- et consorts n'existent plus tels quels sur le moteur Retail). Tout est
-- dessiné à la main, ce qui rend l'addon insensible à ces changements et
-- permet de retrouver l'allure de la version TBC : libellés orangés, titres
-- jaunes, boutons rouges.

local ADDON_NAME, NS = ...

local W = {}
NS.W = W

-- Couleurs de la version TBC.
W.GOLD = { 1.0, 0.82, 0.0 }
W.ORANGE = { 1.0, 0.65, 0.3 }
W.YELLOW = { 1.0, 0.95, 0.4 }
W.WHITE = { 1.0, 1.0, 1.0 }

-- Fond et bordure dessinés à la main.
--
-- SetBackdrop n'existe QUE sur les cadres héritant de BackdropTemplate : sur
-- un CreateFrame("Frame") ordinaire la méthode est absente, et une fenêtre
-- entière se retrouve transparente sans le moindre message. Quatre textures
-- de bord et un fond plein font le même travail partout.
local function Edge(frame, point1, point2, horizontal, thickness, color)
  local edge = frame:CreateTexture(nil, "BORDER")
  edge:SetColorTexture(color[1], color[2], color[3], color[4])
  edge:SetPoint(point1)
  edge:SetPoint(point2)
  if horizontal then edge:SetHeight(thickness) else edge:SetWidth(thickness) end
  return edge
end

function W.Backdrop(frame, inset)
  if frame.poisonUpBackground then return frame end

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  if inset then
    background:SetColorTexture(0.04, 0.04, 0.05, 0.92)
  else
    background:SetColorTexture(0.06, 0.05, 0.04, 0.96)
  end
  frame.poisonUpBackground = background

  local color = inset and { 0.35, 0.32, 0.28, 0.9 } or { 0.62, 0.50, 0.22, 1 }
  local thickness = inset and 1 or 2
  Edge(frame, "TOPLEFT", "TOPRIGHT", true, thickness, color)
  Edge(frame, "BOTTOMLEFT", "BOTTOMRIGHT", true, thickness, color)
  Edge(frame, "TOPLEFT", "BOTTOMLEFT", false, thickness, color)
  Edge(frame, "TOPRIGHT", "BOTTOMRIGHT", false, thickness, color)

  -- Remplace SetBackdropColor pour les appelants qui veulent moduler le fond
  -- (les onglets assombrissent celui qui n'est pas actif).
  function frame:SetBackdropColor(r, g, b, a)
    self.poisonUpBackground:SetColorTexture(r, g, b, a)
  end
  return frame
end

-- Fenêtre façon Books on map : fond sombre de boîte de dialogue et bordure
-- dorée de Blizzard. Si le cadre n'a pas hérité de BackdropTemplate, on
-- retombe sur le fond dessiné à la main.
function W.Window(frame)
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
      tile = true, tileSize = 32, edgeSize = 24,
      insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
  else
    W.Backdrop(frame)
  end
  return frame
end

-- Zone encadrée plus sombre, comme la liste des livres de Books on map.
function W.Inset(frame)
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.5)
    frame:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)
  else
    W.Backdrop(frame, true)
  end
  return frame
end

-- Bandeau de section : fond doré léger et filet doré en dessous.
function W.Header(parent, text, width)
  local header = CreateFrame("Frame", nil, parent)
  header:SetSize(width, 22)

  local bg = header:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 0.82, 0, 0.12)

  local line = header:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetColorTexture(1, 0.82, 0, 0.5)

  header.label = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header.label:SetPoint("LEFT", 8, 0)
  header.label:SetText(text or "")
  return header
end

function W.Text(parent, text, color, font)
  local fontString = parent:CreateFontString(nil, "ARTWORK",
    font or "GameFontNormalSmall")
  fontString:SetText(text or "")
  fontString:SetJustifyH("LEFT")
  if color then fontString:SetTextColor(color[1], color[2], color[3]) end
  return fontString
end

-- =========================================================
-- CASE À COCHER
-- =========================================================
function W.Check(parent, label, color)
  local check = CreateFrame("CheckButton", nil, parent)
  check:SetSize(24, 24)
  check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")

  -- Pas de largeur imposée : le libellé s'ajuste à son texte. Une largeur
  -- fixe déborderait sur les éléments voisins, et comme la zone cliquable
  -- ci-dessous épouse le libellé, elle volerait leurs clics.
  check.label = W.Text(check, label, color or W.ORANGE)
  check.label:SetPoint("LEFT", check, "RIGHT", 2, 0)
  check.label:SetJustifyH("LEFT")

  -- Cliquer le libellé revient à cliquer la case : la cible est minuscule
  -- sinon, et l'original se comportait déjà ainsi.
  --
  -- La zone épouse EXACTEMENT le libellé. Elle est enfant de la case, donc son
  -- niveau d'affichage dépasse celui des cases voisines : le moindre
  -- débordement leur volerait le clic, même si elles ont été créées après.
  -- C'est ce qui empêchait de cocher « En bas à droite » dans la grille des
  -- positions, la zone du libellé « En bas » passant par-dessus.
  local hit = CreateFrame("Button", nil, check)
  hit:SetPoint("TOPLEFT", check.label, "TOPLEFT", 0, 0)
  hit:SetPoint("BOTTOMRIGHT", check.label, "BOTTOMRIGHT", 0, 0)
  hit:SetScript("OnClick", function() check:Click() end)
  check.hit = hit

  function check:SetLabelColor(c)
    self.label:SetTextColor(c[1], c[2], c[3])
  end
  return check
end

-- =========================================================
-- CURSEUR
-- =========================================================
-- Le titre est au-dessus avec la valeur courante, les bornes en dessous,
-- comme dans les fenêtres de la version TBC.
function W.Slider(parent, label, minValue, maxValue, step, format)
  local slider = CreateFrame("Slider", nil, parent)
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(240, 16)
  slider:SetHitRectInsets(0, 0, -6, -6)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0.25, 0.25, 0.25, 0.9)
  track:SetPoint("LEFT", 0, 0)
  track:SetPoint("RIGHT", 0, 0)
  track:SetHeight(4)

  -- Titre à gauche et valeur à droite, sur une seule ligne juste au-dessus
  -- de la barre : rien ne déborde sur la ligne précédente.
  slider.title = W.Text(slider, label, W.ORANGE)
  slider.title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 3)

  slider.value = W.Text(slider, "", W.WHITE)
  slider.value:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 3)
  slider.value:SetJustifyH("RIGHT")

  slider.format = format or tostring
  function slider:Refresh(value)
    self.value:SetText(self.format(value))
  end
  return slider
end

-- =========================================================
-- BOUTON
-- =========================================================
function W.Button(parent, label, width)
  local ok, button = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
  if ok and button then
    button:SetSize(width or 110, 22)
    button:SetText(label or "")
    return button
  end

  -- Repli si le template n'existe pas : bouton dessiné à la main.
  button = CreateFrame("Button", nil, parent)
  button:SetSize(width or 110, 22)
  W.Backdrop(button, true)
  button.label = W.Text(button, label, W.GOLD)
  button.label:SetPoint("CENTER")
  button.label:SetJustifyH("CENTER")
  button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  return button
end

-- =========================================================
-- LISTE DÉROULANTE
-- =========================================================
-- UIDropDownMenu n'existe plus sur ce moteur : on dessine une liste maison.
-- Elle sert à choisir un poison par main dans l'onglet « Sets de poison ».
local openDropdown

function W.Dropdown(parent, width)
  local dropdown = CreateFrame("Button", nil, parent)
  dropdown:SetSize(width or 150, 24)
  W.Backdrop(dropdown, true)

  dropdown.label = W.Text(dropdown, NONE or "Aucun", W.WHITE)
  dropdown.label:SetPoint("LEFT", 8, 0)
  dropdown.label:SetPoint("RIGHT", -20, 0)
  dropdown.label:SetJustifyH("LEFT")

  dropdown.icon = dropdown:CreateTexture(nil, "ARTWORK")
  dropdown.icon:SetSize(16, 16)
  dropdown.icon:SetPoint("LEFT", 6, 0)
  dropdown.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  dropdown.icon:Hide()

  local arrow = dropdown:CreateTexture(nil, "OVERLAY")
  arrow:SetSize(16, 16)
  arrow:SetPoint("RIGHT", -4, 0)
  arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

  local list = CreateFrame("Frame", nil, dropdown)
  list:SetFrameStrata("FULLSCREEN_DIALOG")
  list:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
  list:SetWidth(dropdown:GetWidth())
  list:Hide()
  W.Backdrop(list, true)
  dropdown.list = list
  list.rows = {}

  local function CloseList()
    list:Hide()
    if openDropdown == dropdown then openDropdown = nil end
  end

  -- Fermer la liste dès qu'on clique ailleurs.
  list:SetScript("OnHide", function() if openDropdown == dropdown then openDropdown = nil end end)

  function dropdown:SetSelection(text, icon)
    self.label:SetText(text or (NONE or "Aucun"))
    if icon then
      self.icon:SetTexture(icon)
      self.icon:Show()
      self.label:SetPoint("LEFT", 26, 0)
    else
      self.icon:Hide()
      self.label:SetPoint("LEFT", 8, 0)
    end
  end

  -- entries : liste de { text, icon, value }
  function dropdown:SetEntries(entries, onSelect)
    self.entries, self.onSelect = entries, onSelect
  end

  function dropdown:Toggle()
    if list:IsShown() then CloseList() return end
    if openDropdown and openDropdown ~= self then openDropdown.list:Hide() end
    openDropdown = self

    local entries = self.entries or {}
    for index, entry in ipairs(entries) do
      local row = list.rows[index]
      if not row then
        row = CreateFrame("Button", nil, list)
        row:SetHeight(20)
        row:SetPoint("LEFT", list, "LEFT", 4, 0)
        row:SetPoint("RIGHT", list, "RIGHT", -4, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 2, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.text = W.Text(row, "", W.WHITE)
        row.text:SetPoint("LEFT", 22, 0)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        list.rows[index] = row
      end
      row:SetPoint("TOPLEFT", list, "TOPLEFT", 4, -4 - (index - 1) * 20)
      row.text:SetText(entry.text)
      if entry.icon then row.icon:SetTexture(entry.icon) row.icon:Show()
      else row.icon:Hide() end
      row:SetScript("OnClick", function()
        CloseList()
        if self.onSelect then self.onSelect(entry.value, entry) end
      end)
      row:Show()
    end
    for index = #entries + 1, #list.rows do list.rows[index]:Hide() end

    list:SetHeight(math.max(24, #entries * 20 + 8))
    list:Show()
  end

  dropdown:SetScript("OnClick", function(self) self:Toggle() end)
  return dropdown
end

-- =========================================================
-- ONGLETS
-- =========================================================
-- Onglets en haut de la fenêtre : l'actif est doré et souligné.
-- Le premier onglet est placé par l'appelant.
function W.TabBar(parent, names, onSelect)
  local bar = { tabs = {}, current = 1 }
  local previous

  for index, name in ipairs(names) do
    local tab = CreateFrame("Button", nil, parent)
    tab:SetHeight(24)

    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints()

    tab.line = tab:CreateTexture(nil, "ARTWORK")
    tab.line:SetHeight(2)
    tab.line:SetPoint("BOTTOMLEFT")
    tab.line:SetPoint("BOTTOMRIGHT")
    tab.line:SetColorTexture(1, 0.82, 0, 0.9)

    tab:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.label:SetText(name)
    tab.label:SetPoint("CENTER")
    tab:SetWidth(math.max(80, tab.label:GetStringWidth() + 28))

    if previous then
      tab:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    end
    tab:SetScript("OnClick", function() bar:Select(index) end)

    bar.tabs[index] = tab
    previous = tab
  end

  function bar:Select(index)
    self.current = index
    for position, tab in ipairs(self.tabs) do
      if position == index then
        tab.bg:SetColorTexture(1, 0.82, 0, 0.18)
        tab.label:SetTextColor(1, 0.82, 0)
        tab.line:Show()
      else
        tab.bg:SetColorTexture(0, 0, 0, 0.45)
        tab.label:SetTextColor(0.6, 0.6, 0.6)
        tab.line:Hide()
      end
    end
    if onSelect then onSelect(index) end
  end

  return bar
end
