-- Widgets.lua - PoisonUp (Forever) - par Daeler
-- Petits éléments d'interface réutilisés par la fenêtre d'options.
--
-- Rien n'est repris des templates de Blizzard : tout passe par Skin.lua
-- (fenêtres arrondies, lueurs vertes, animations). Les fonctions gardent les
-- mêmes noms et les mêmes champs (.label, .title, .value, Refresh...) que
-- l'ancienne version, Options.lua n'a donc pas à savoir comment c'est dessiné.

local ADDON_NAME, NS = ...

local W = {}
NS.W = W

local S = NS.Skin
local C, color = S.C, S.Color
local MEDIA = S.MEDIA

-- Couleurs nommées utilisées par les appelants.
W.GOLD = C.gold        -- cases principales, titres
W.ORANGE = C.text      -- libellés courants
W.YELLOW = C.fill1
W.WHITE = { 1.0, 1.0, 1.0 }
W.MUTED = C.muted

-- =========================================================
-- CADRES
-- =========================================================
-- Ombre portée sur les bords intérieurs (vignettage de vieux livre).
local function Vignette(frame, depth, alpha)
  for _, t in pairs(S.Slice9(frame, MEDIA .. "RoundGlow", 128, 48, depth, "BACKGROUND", -4)) do
    t:SetVertexColor(0, 0, 0, alpha)
  end
end

-- Filet fin de bronze, `inset` px à l'intérieur du cadre.
local function InnerLine(frame, inset, alpha)
  local lines = {
    { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
    { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" },
  }
  for _, l in ipairs(lines) do
    local t = frame:CreateTexture(nil, "BORDER", nil, 2)
    t:SetColorTexture(C.trim[1], C.trim[2], C.trim[3], alpha)
    local sx1 = l[1]:find("LEFT") and inset or -inset
    local sy1 = l[1]:find("TOP") and -inset or inset
    local sx2 = l[2]:find("LEFT") and inset or -inset
    local sy2 = l[2]:find("TOP") and -inset or inset
    t:SetPoint(l[1], sx1, sy1)
    t:SetPoint(l[2], sx2, sy2)
    if l[3] then t:SetHeight(1) else t:SetWidth(1) end
  end
end

-- Coins ciselés en bronze, retournés pour chaque angle.
local CORNERS = {
  TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 },
  BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 },
}
local function Corners(frame, size, offset)
  local holder = CreateFrame("Frame", nil, frame)
  holder:SetAllPoints()
  holder:SetFrameLevel(frame:GetFrameLevel() + 1)
  for point, coords in pairs(CORNERS) do
    local t = holder:CreateTexture(nil, "OVERLAY", nil, 3)
    t:SetTexture(MEDIA .. "Corner")
    t:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    t:SetSize(size, size)
    t:SetPoint(point, point:find("LEFT") and offset or -offset,
      point:find("TOP") and -offset or offset)
    t:SetVertexColor(0.78, 0.6, 0.34, 0.95)
  end
  return holder
end

-- Fenêtre façon vieux grimoire : couverture de cuir patiné, double filet et
-- coins de bronze, gemme de poison sertie en haut qui luit doucement, lueur
-- verte très légère sur les bords, animation d'ouverture.
function W.Window(frame)
  if frame.poisonUpSkinned then return frame end
  frame.poisonUpSkinned = true
  S.Shadow(frame, 14, 0.7)
  -- Halo vert très léger autour de la couverture, pour la faire luire.
  local aura = S.Shadow(frame, 18, 0.16, { 0.45, 0.9, 0.2 })
  aura:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
  S.Rounded(frame, 12)

  local leather = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
  leather:SetPoint("TOPLEFT", 3, -3)
  leather:SetPoint("BOTTOMRIGHT", -3, 3)
  leather:SetTexture(MEDIA .. "Leather", "REPEAT", "REPEAT")
  leather:SetHorizTile(true)
  leather:SetVertTile(true)
  frame:HookScript("OnSizeChanged", function(self, w, h)
    leather:SetTexCoord(0, (w or 256) / 256, 0, (h or 256) / 256)
  end)
  leather:SetTexCoord(0, frame:GetWidth() / 256, 0, frame:GetHeight() / 256)

  Vignette(frame, 48, 0.75)
  S.EdgeGlow(frame, 40, 0.1)
  InnerLine(frame, 6, 0.7)
  frame.corners = Corners(frame, 30, 2)

  -- Gemme verte sertie au milieu du bord supérieur.
  local gem = frame.corners:CreateTexture(nil, "OVERLAY", nil, 5)
  gem:SetTexture(MEDIA .. "Gem")
  gem:SetSize(14, 14)
  gem:SetPoint("CENTER", frame, "TOP", 0, -2)
  gem:SetVertexColor(0.55, 0.95, 0.25, 1)
  local setting = frame.corners:CreateTexture(nil, "OVERLAY", nil, 4)
  setting:SetTexture(MEDIA .. "Gem")
  setting:SetSize(20, 20)
  setting:SetPoint("CENTER", gem)
  setting:SetVertexColor(0.55, 0.4, 0.2, 1)
  local halo = frame.corners:CreateTexture(nil, "OVERLAY", nil, 2)
  halo:SetTexture(MEDIA .. "Glow")
  halo:SetBlendMode("ADD")
  halo:SetSize(46, 46)
  halo:SetPoint("CENTER", gem)
  halo:SetVertexColor(0.55, 0.95, 0.25, 0.6)
  local clock = math.random() * 6
  frame.corners:SetScript("OnUpdate", function(_, elapsed)
    clock = clock + elapsed
    halo:SetAlpha(0.45 + 0.35 * math.sin(clock * 1.8))
  end)

  frame:HookScript("OnShow", function(self) S.AnimateOpen(self, 0, -12) end)
  return frame
end

-- Ferme une fenêtre en glissant, comme elle s'est ouverte.
function W.CloseWindow(frame)
  S.AnimateClose(frame, 0, -12)
end

-- Page de vélin vieilli derrière le contenu, bordée de bronze.
function W.Inset(frame)
  S.Rounded(frame, 6, { 0, 0, 0, 1 }, { 0, 0, 0, 1 },
    { C.trim[1], C.trim[2], C.trim[3], 0.85 })
  local page = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
  page:SetPoint("TOPLEFT", 2, -2)
  page:SetPoint("BOTTOMRIGHT", -2, 2)
  page:SetTexture(MEDIA .. "Page")
  Vignette(frame, 32, 0.6)
  InnerLine(frame, 4, 0.35)
  return frame
end

-- Petit cadre carré (listes déroulantes, boutons de la barre).
function W.Backdrop(frame)
  S.Box(frame, { C.btn1, C.btn2 }, C.trim)
  return frame
end

-- Bandeau de section : point vert, libellé, filet qui s'efface vers la droite.
function W.Header(parent, text, width)
  local header = S.Section(parent, text)
  header:SetWidth(width)
  S.TitleFont(header.label, 15)
  return header
end

function W.Text(parent, text, col, font)
  local size = (font == "GameFontNormal") and 13 or 12
  local fontString = S.Text(parent, size)
  fontString:SetText(text or "")
  if col then fontString:SetTextColor(col[1], col[2], col[3]) end
  return fontString
end

-- =========================================================
-- CASE À COCHER
-- =========================================================
-- Coche verte qui apparaît en fondu avec un éclat ; le libellé est cliquable.
function W.Check(parent, label, col)
  local check = S.Check(parent, nil, 16)
  local base = col or C.text

  check.label = S.Text(check, 12)
  check.label:SetTextColor(color(base))
  check.label:SetText(label or "")
  check.label:SetPoint("LEFT", check, "RIGHT", 8, 0)

  -- La zone cliquable épouse EXACTEMENT le libellé : enfant de la case, elle
  -- passe au-dessus des cases voisines et leur volerait le clic au moindre
  -- débordement (grille des positions de l'onglet Menu).
  local hit = CreateFrame("Button", nil, check)
  hit:SetPoint("TOPLEFT", check.label, "TOPLEFT", 0, 2)
  hit:SetPoint("BOTTOMRIGHT", check.label, "BOTTOMRIGHT", 0, -2)
  hit:SetScript("OnClick", function() check:Click() end)
  check.hit = hit

  local function enter()
    check:SetBorderColor(color(C.gold))
    check.label:SetTextColor(1, 1, 1)
  end
  local function leave()
    check:SetBorderColor(color(C.trim))
    check.label:SetTextColor(color(base))
  end
  check:HookScript("OnEnter", enter)
  check:HookScript("OnLeave", leave)
  hit:SetScript("OnEnter", enter)
  hit:SetScript("OnLeave", leave)

  function check:SetLabelColor(c)
    base = c
    self.label:SetTextColor(c[1], c[2], c[3])
  end
  return check
end

-- =========================================================
-- CURSEUR
-- =========================================================
-- Piste sombre, remplissage vert en dégradé, poignée lumineuse avec halo au
-- survol. Titre à gauche, valeur à droite, juste au-dessus de la piste.
function W.Slider(parent, label, minValue, maxValue, step, format)
  local slider = CreateFrame("Slider", nil, parent)
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(240, 14)
  slider:SetHitRectInsets(0, 0, -6, -6)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
  slider:EnableMouseWheel(true)

  local track = CreateFrame("Frame", nil, slider)
  track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(6)
  track:SetFrameLevel(slider:GetFrameLevel())
  S.Box(track, C.well, C.trim)

  local fill = slider:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 1, 1)
  S.Gradient(fill, C.fill2, C.fill1, true)

  -- La poignée réelle du curseur reste invisible : le moteur la recolore et
  -- la ré-empile à chaque affichage (elle virait au noir en changeant
  -- d'onglet). Ce qu'on voit est une gemme verte posée par-dessus.
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(0, 0, 0, 0)
  thumb:SetSize(14, 14)
  slider:SetThumbTexture(thumb)
  fill:SetPoint("RIGHT", thumb, "CENTER")

  local knob = CreateFrame("Frame", nil, slider)
  knob:SetSize(14, 14)
  knob:SetPoint("CENTER", thumb)
  knob:SetFrameLevel(slider:GetFrameLevel() + 3)

  local glow = knob:CreateTexture(nil, "BACKGROUND")
  glow:SetTexture(MEDIA .. "Glow")
  glow:SetBlendMode("ADD")
  glow:SetSize(34, 34)
  glow:SetPoint("CENTER")
  glow:SetVertexColor(0.55, 0.95, 0.25, 1)

  local setting = knob:CreateTexture(nil, "ARTWORK", nil, 0)
  setting:SetTexture(MEDIA .. "Gem")
  setting:SetSize(15, 15)
  setting:SetPoint("CENTER")
  setting:SetVertexColor(0.45, 0.32, 0.16, 1)
  local gem = knob:CreateTexture(nil, "ARTWORK", nil, 1)
  gem:SetTexture(MEDIA .. "Gem")
  gem:SetSize(11, 11)
  gem:SetPoint("CENTER")
  gem:SetVertexColor(0.62, 1, 0.3, 1)

  -- Lueur au repos, plus vive au survol.
  local REST, HOVER = 0.35, 0.9
  glow:SetAlpha(REST)
  slider:HookScript("OnEnter", function() S.FadeTo(glow, HOVER, 0.12) end)
  slider:HookScript("OnLeave", function() S.FadeTo(glow, REST, 0.25) end)

  -- À l'affichage (changement d'onglet) : la gemme éclot avec un éclat de
  -- lumière, le remplissage monte en fondu.
  slider:HookScript("OnShow", function()
    fill:SetAlpha(0)
    S.Tween(knob, { dur = 0.45, from = 0, to = 1, ease = "outBack", set = function(v, p)
      local size = 11 * math.max(0.01, v)
      gem:SetSize(size, size)
      glow:SetAlpha(REST + (1 - REST) * (1 - p))
      fill:SetAlpha(math.min(1, p * 1.6))
    end, done = function()
      gem:SetSize(11, 11)
      glow:SetAlpha(slider:IsMouseOver() and HOVER or REST)
      fill:SetAlpha(1)
    end })
  end)

  slider.title = S.Text(slider, 12)
  slider.title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
  slider.title:SetText(label or "")

  slider.value = S.Text(slider, 12, "gold")
  slider.value:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 5)
  slider.value:SetJustifyH("RIGHT")

  slider:HookScript("OnEnter", function(self) self.title:SetTextColor(1, 1, 1) end)
  slider:HookScript("OnLeave", function(self) self.title:SetTextColor(color(C.text)) end)
  slider:SetScript("OnMouseWheel", function(self, delta)
    self:SetValue(self:GetValue() + delta * step)
  end)

  slider.format = format or tostring
  function slider:Refresh(value)
    self.value:SetText(self.format(value))
  end
  return slider
end

-- =========================================================
-- BOUTON
-- =========================================================
-- Dégradé avec reflet ; au survol la bordure vire au vert vif et une lueur
-- monte du bas. L'appelant pose son propre OnClick.
function W.Button(parent, label, width, primary)
  return S.Button(parent, label or "", width or 110, 22, nil, primary)
end

-- =========================================================
-- LISTE DÉROULANTE
-- =========================================================
-- UIDropDownMenu n'existe plus sur ce moteur : liste maison qui se déplie en
-- fondu, flèche qui pivote, lignes surlignées en vert.
local openDropdown

function W.Dropdown(parent, width)
  local dropdown = CreateFrame("Button", nil, parent)
  dropdown:SetSize(width or 150, 24)
  S.Box(dropdown, { C.btn1, C.btn2 }, C.trim)

  local gloss = dropdown:CreateTexture(nil, "ARTWORK", nil, 1)
  gloss:SetPoint("TOPLEFT", 1, -1); gloss:SetPoint("BOTTOMRIGHT", -1, 1)
  gloss:SetTexture(MEDIA .. "Gloss")
  local glow = dropdown:CreateTexture(nil, "ARTWORK", nil, 2)
  glow:SetPoint("TOPLEFT", 1, -1); glow:SetPoint("BOTTOMRIGHT", -1, 1)
  S.Gradient(glow, { 0.61, 0.92, 0.24, 0 }, { 0.61, 0.92, 0.24, 0.16 })
  glow:SetBlendMode("ADD")
  S.HoverFade(dropdown, glow)

  dropdown.label = W.Text(dropdown, NONE or "Aucun", C.text)
  dropdown.label:SetPoint("LEFT", 8, 0)
  dropdown.label:SetPoint("RIGHT", -20, 0)
  dropdown.label:SetWordWrap(false)

  dropdown.icon = dropdown:CreateTexture(nil, "OVERLAY")
  dropdown.icon:SetSize(16, 16)
  dropdown.icon:SetPoint("LEFT", 5, 0)
  dropdown.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  dropdown.icon:Hide()

  -- Chevron dessiné avec deux traits : il pivote à l'ouverture.
  local arrow = CreateFrame("Frame", nil, dropdown)
  arrow:SetSize(10, 10)
  arrow:SetPoint("RIGHT", -8, 0)
  local strokes = {}
  for index, angle in ipairs({ 45, -45 }) do
    local stroke = arrow:CreateTexture(nil, "OVERLAY")
    stroke:SetTexture("Interface\\Buttons\\WHITE8x8")
    stroke:SetSize(6, 1.6)
    stroke:SetPoint("CENTER", index == 1 and -2 or 2, 0)
    stroke:SetRotation(math.rad(angle))
    stroke:SetVertexColor(color(C.muted))
    stroke.angle = angle
    strokes[index] = stroke
  end
  local function Turn(open)
    local from = arrow.turn or 0
    S.Tween(arrow, { dur = 0.2, from = from, to = open and 1 or 0, set = function(v)
      arrow.turn = v
      for _, stroke in ipairs(strokes) do
        stroke:SetRotation(math.rad(stroke.angle * (1 - 2 * v)))
      end
    end })
  end

  dropdown:HookScript("OnEnter", function(self)
    self:SetBorderColor(color(C.gold))
    for _, stroke in ipairs(strokes) do stroke:SetVertexColor(color(C.gold)) end
  end)
  dropdown:HookScript("OnLeave", function(self)
    self:SetBorderColor(color(C.trim))
    for _, stroke in ipairs(strokes) do stroke:SetVertexColor(color(C.muted)) end
  end)

  local list = CreateFrame("Frame", nil, dropdown)
  list:SetFrameStrata("FULLSCREEN_DIALOG")
  list:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -3)
  list:SetWidth(dropdown:GetWidth())
  list:EnableMouse(true)
  list:Hide()
  S.Shadow(list, 10, 0.6)
  S.Rounded(list, 6)
  dropdown.list = list
  list.rows = {}

  local function CloseList()
    if not list:IsShown() then return end
    Turn(false)
    S.FadeTo(list, 0, 0.12, function() list:Hide() end)
    if openDropdown == dropdown then openDropdown = nil end
  end
  dropdown.CloseList = CloseList

  list:SetScript("OnHide", function()
    if openDropdown == dropdown then openDropdown = nil end
    arrow.turn = 0
    for _, stroke in ipairs(strokes) do stroke:SetRotation(math.rad(stroke.angle)) end
  end)

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
    if list:IsShown() and openDropdown == self then CloseList() return end
    if openDropdown and openDropdown ~= self then openDropdown.CloseList() end
    openDropdown = self

    -- Liste longue : plusieurs colonnes (dropdown.columns) plutôt qu'une
    -- seule bande qui sortirait de l'écran. Elle s'ouvre alors vers la
    -- gauche, ancrée au bord droit du bouton.
    local entries = self.entries or {}
    local columns = math.max(1, self.columns or 1)
    local perColumn = math.ceil(#entries / columns)
    local columnWidth = self:GetWidth()
    list:ClearAllPoints()
    if columns > 1 then
      list:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -3)
    else
      list:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -3)
    end
    list:SetWidth(columnWidth * columns)
    for index, entry in ipairs(entries) do
      local row = list.rows[index]
      if not row then
        row = CreateFrame("Button", nil, list)
        row:SetHeight(20)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        row.text = W.Text(row, "", C.text)
        row.text.defaultFont = row.text:GetFontObject()
        row.text:SetPoint("LEFT", 24, 0)
        row.text:SetPoint("RIGHT", -4, 0)
        row.text:SetWordWrap(false)
        S.RowHighlight(row)
        row:HookScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
        row:HookScript("OnLeave", function(self) self.text:SetTextColor(color(C.text)) end)
        list.rows[index] = row
      end
      local column = math.floor((index - 1) / perColumn)
      local line = (index - 1) % perColumn
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", list, "TOPLEFT", 4 + column * columnWidth, -5 - line * 20)
      row:SetWidth(columnWidth - 8)
      -- Une entrée en cyrillique (« Русский ») prend la police de base du
      -- jeu, les autres gardent celle de l'addon.
      if entry.cyrillic then
        row.text:SetFont(S.CyrillicFont(), 12, "")
      else
        row.text:SetFontObject(row.text.defaultFont)
      end
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

    list:SetHeight(math.max(24, perColumn * 20 + 10))
    list:SetAlpha(0)
    list:Show()
    S.FadeTo(list, 1, 0.15)
    Turn(true)
  end

  dropdown:SetScript("OnClick", function(self) self:Toggle() end)
  return dropdown
end

-- =========================================================
-- ONGLETS
-- =========================================================
-- Onglets en haut de la fenêtre : un trait vert lumineux glisse sous l'onglet
-- actif, les autres s'éclairent en fondu au survol.
-- Le premier onglet est placé par l'appelant.
function W.TabBar(parent, names, onSelect)
  local bar = { tabs = {}, current = 1 }
  local previous

  -- Trait coulissant, avec son halo.
  local slider = CreateFrame("Frame", nil, parent)
  slider:SetHeight(2)
  local line = slider:CreateTexture(nil, "OVERLAY", nil, 2)
  line:SetAllPoints()
  S.Gradient(line, { C.gold[1], C.gold[2], C.gold[3], 0.3 }, C.gold, true)
  local halo = slider:CreateTexture(nil, "OVERLAY", nil, 1)
  halo:SetTexture(MEDIA .. "Glow")
  halo:SetBlendMode("ADD")
  halo:SetPoint("TOPLEFT", -10, 10)
  halo:SetPoint("BOTTOMRIGHT", 10, -10)
  halo:SetVertexColor(0.55, 0.95, 0.25, 0.45)

  for index, name in ipairs(names) do
    local tab = CreateFrame("Button", nil, parent)
    tab:SetHeight(26)

    tab.wash = tab:CreateTexture(nil, "BACKGROUND", nil, 1)
    tab.wash:SetAllPoints()
    S.Gradient(tab.wash, { 0.61, 0.92, 0.24, 0 }, { 0.61, 0.92, 0.24, 0.16 })

    tab.hover = tab:CreateTexture(nil, "BACKGROUND", nil, 2)
    tab.hover:SetAllPoints()
    S.Gradient(tab.hover, { 0.61, 0.92, 0.24, 0 }, { 0.61, 0.92, 0.24, 0.10 })
    S.HoverFade(tab, tab.hover)

    tab.label = S.Text(tab, 13)
    S.TitleFont(tab.label, 14)
    tab.label:SetText(name)
    tab.label:SetPoint("CENTER", 0, 1)
    tab:SetWidth(math.max(80, tab.label:GetStringWidth() + 28))

    if previous then
      tab:SetPoint("LEFT", previous, "RIGHT", 4, 0)
    end
    tab:SetScript("OnClick", function() bar:Select(index) end)
    tab:HookScript("OnEnter", function(self)
      if bar.current ~= index then self.label:SetTextColor(1, 1, 1) end
    end)
    tab:HookScript("OnLeave", function(self)
      if bar.current ~= index then self.label:SetTextColor(color(C.muted)) end
    end)

    bar.tabs[index] = tab
    previous = tab
  end

  -- Au-dessus des onglets, sinon leur fond voilerait le trait.
  slider:SetFrameLevel(previous:GetFrameLevel() + 2)

  local placed
  local function Place(tab, animate)
    local parentLeft = parent:GetLeft()
    local left, width = tab:GetLeft(), tab:GetWidth()
    if not parentLeft or not left then
      -- Pas encore de géométrie (fenêtre jamais affichée) : on s'ancre à l'onglet.
      slider:ClearAllPoints()
      slider:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT")
      slider:SetWidth(width)
      placed = nil
      return
    end
    local x = left - parentLeft
    -- Ancré au haut du parent : la fenêtre d'options change de hauteur selon
    -- l'onglet, un ancrage par le bas ferait dériver le trait.
    local top = tab:GetBottom() - parent:GetTop()
    local function at(px, w)
      slider:ClearAllPoints()
      slider:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", px, top)
      slider:SetWidth(w)
    end
    if animate and placed then
      local fx, fw = placed[1], placed[2]
      S.Tween(slider, { dur = 0.3, from = 0, to = 1, ease = "outBack", set = function(v)
        at(fx + (x - fx) * v, fw + (width - fw) * v)
      end })
    else
      at(x, width)
    end
    placed = { x, width }
  end

  function bar:Select(index)
    local animate = self.current ~= index
    self.current = index
    for position, tab in ipairs(self.tabs) do
      local on = position == index
      tab.label:SetTextColor(color(on and C.gold or C.muted))
      S.FadeTo(tab.wash, on and 1 or 0, 0.2)
      if on then Place(tab, animate) end
    end
    if onSelect then onSelect(index) end
  end

  parent:HookScript("OnShow", function()
    placed = nil
    Place(bar.tabs[bar.current], false)
  end)

  return bar
end

-- =========================================================
-- BOUTONS À L'ÉCRAN (carrés d'arme, barre, bouton rapide, bouton rond)
-- =========================================================
-- Même cuir et même bronze que la fenêtre. Tout est créé au chargement, hors
-- combat : rien ici ne touche aux attributs des boutons sécurisés.

-- Petit cadre carré façon grimoire autour d'une icône déjà posée en
-- frame.icon. Renvoie le cadre ; frame:SetGlow(couleur, pulse) colore le
-- halo (nil pour l'éteindre), frame:SetTrim(couleur) la bordure.
function W.SkinSquare(frame, cornerSize, pad)
  pad = pad or 3
  local back = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
  back:SetPoint("TOPLEFT", -pad, pad)
  back:SetPoint("BOTTOMRIGHT", pad, -pad)
  back:SetTexture(MEDIA .. "Leather")
  back:SetTexCoord(0, 0.25, 0, 0.25)

  -- Bordure : bronze à l'extérieur, filet noir contre l'icône.
  local holder = CreateFrame("Frame", nil, frame)
  holder:SetPoint("TOPLEFT", -pad, pad)
  holder:SetPoint("BOTTOMRIGHT", pad, -pad)
  holder:SetFrameLevel(frame:GetFrameLevel() + 1)
  S.Box(holder, { 0, 0, 0, 0 }, C.trim)
  local inner = CreateFrame("Frame", nil, frame)
  inner:SetPoint("TOPLEFT", frame.icon, -1, 1)
  inner:SetPoint("BOTTOMRIGHT", frame.icon, 1, -1)
  inner:SetFrameLevel(frame:GetFrameLevel() + 1)
  S.Box(inner, { 0, 0, 0, 0 }, { 0, 0, 0, 0.95 })

  -- Reflet sur l'icône, sous les textes (minuteur, quantité).
  local gloss = frame:CreateTexture(nil, "ARTWORK", nil, 7)
  gloss:SetAllPoints(frame.icon)
  gloss:SetTexture(MEDIA .. "Gloss")
  gloss:SetAlpha(0.6)

  -- Coins de bronze.
  cornerSize = cornerSize or 12
  for point, coords in pairs(CORNERS) do
    local t = holder:CreateTexture(nil, "OVERLAY", nil, 3)
    t:SetTexture(MEDIA .. "Corner")
    t:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    t:SetSize(cornerSize, cornerSize)
    t:SetPoint(point, point:find("LEFT") and -1 or 1, point:find("TOP") and 1 or -1)
    t:SetVertexColor(0.85, 0.66, 0.38, 1)
  end

  -- Halo derrière le cadre, qui peut battre doucement.
  local glow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  glow:SetTexture(MEDIA .. "Glow")
  glow:SetBlendMode("ADD")
  glow:SetPoint("TOPLEFT", -14, 14)
  glow:SetPoint("BOTTOMRIGHT", 14, -14)
  glow:Hide()
  local pulser = CreateFrame("Frame", nil, holder)
  local clock, pulsing = 0, false
  pulser:SetScript("OnUpdate", function(_, elapsed)
    if not pulsing then return end
    clock = clock + elapsed
    glow:SetAlpha(0.5 + 0.4 * math.sin(clock * 4))
  end)

  -- spread : débord du halo autour du cadre (14 par défaut).
  function frame:SetGlow(col, pulse, spread)
    if not col then glow:Hide() pulsing = false return end
    spread = spread or 14
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", -spread, spread)
    glow:SetPoint("BOTTOMRIGHT", spread, -spread)
    glow:SetVertexColor(col[1], col[2], col[3], col[4] or 0.8)
    glow:SetAlpha(1)
    glow:Show()
    pulsing = pulse and true or false
  end
  function frame:SetTrim(col)
    holder:SetBorderColor(col[1], col[2], col[3], col[4] or 1)
  end
  frame.skinHolder = holder
  return frame
end

-- Bouton rond : disque de cuir, icône masquée en rond, anneau de bronze
-- ciselé, halo vert au survol.
function W.SkinRound(button)
  button.disc = button:CreateTexture(nil, "BACKGROUND", nil, -6)
  button.disc:SetTexture(MEDIA .. "Disc")
  button.disc:SetPoint("CENTER")
  button.disc:SetVertexColor(0.18, 0.12, 0.08, 1)

  button.halo = button:CreateTexture(nil, "BACKGROUND", nil, -8)
  button.halo:SetTexture(MEDIA .. "Glow")
  button.halo:SetBlendMode("ADD")
  button.halo:SetPoint("CENTER")
  button.halo:SetVertexColor(0.55, 0.95, 0.25, 0.8)
  button.halo:SetAlpha(0)
  -- Appelé par les OnEnter / OnLeave du bouton (un HookScript serait effacé
  -- par leur SetScript).
  function button:HoverGlow(on)
    S.FadeTo(self.halo, on and 0.9 or 0, on and 0.12 or 0.25)
  end

  button.bronze = button:CreateTexture(nil, "OVERLAY", nil, 2)
  button.bronze:SetTexture(MEDIA .. "Ring")
  button.bronze:SetPoint("CENTER")
  button.bronze:SetVertexColor(0.85, 0.66, 0.38, 1)

  function button:SizeSkin(size)
    self.disc:SetSize(size * 1.12, size * 1.12)
    self.bronze:SetSize(size * 1.12, size * 1.12)
    self.halo:SetSize(size * 2.1, size * 2.1)
  end
end
