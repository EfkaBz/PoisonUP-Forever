-- Button.lua - PoisonUp (Forever) - par Daeler
-- Le bouton libre et le bouton de mini-carte.
--
-- Comme la version TBC : une pastille ronde à anneau doré, que l'on
-- pose où l'on veut sur l'interface ancré à UIParent,
-- avec en option un second bouton accroché à la mini-carte. Les deux ouvrent
-- la même barre de poisons ; l'onglet Menu décide duquel elle sort.

local ADDON_NAME, NS = ...
local L = NS.L

local RING = "Interface\\Minimap\\MiniMap-TrackingBorder"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- =========================================================
-- FABRIQUE COMMUNE
-- =========================================================
-- Le masque rend l'icône ronde, l'anneau par-dessus lui donne sa bordure
-- dorée : c'est l'aspect des boutons de mini-carte, et celui du bouton libre
-- de la version TBC.
local function DressRoundButton(button, size)
  button:SetSize(size, size)
  button:RegisterForClicks("AnyDown", "AnyUp")
  button:RegisterForDrag("LeftButton")

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetTexture(NS.ICON)
  button.icon:SetPoint("CENTER")
  button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  if button.CreateMaskTexture then
    local mask = button:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(button.icon)
    button.icon:AddMaskTexture(mask)
    button.mask = mask
  end

  button.ring = button:CreateTexture(nil, "OVERLAY")
  button.ring:SetTexture(RING)
  button.ring:SetPoint("CENTER", button, "CENTER", 10, -10)

  button.glow = button:CreateTexture(nil, "OVERLAY")
  button.glow:SetTexture("Interface\\Buttons\\CheckButtonGlow")
  button.glow:SetVertexColor(1, 0.2, 0.2)
  button.glow:Hide()

  -- Minuteurs des deux mains, en haut et en bas de la pastille.
  button.mhTime = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  button.mhTime:SetPoint("TOP", button, "TOP", 0, -1)
  button.ohTime = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  button.ohTime:SetPoint("BOTTOM", button, "BOTTOM", 0, 1)

  function button:ApplySize(newSize)
    self:SetSize(newSize, newSize)
    self.icon:SetSize(newSize * 0.62, newSize * 0.62)
    self.ring:SetSize(newSize * 1.75, newSize * 1.75)
    self.ring:ClearAllPoints()
    self.ring:SetPoint("CENTER", self, "CENTER", newSize * 0.33, -newSize * 0.33)
    self.glow:SetSize(newSize * 1.4, newSize * 1.4)
    self.glow:SetPoint("CENTER")
  end
  button:ApplySize(size)
end

local function Tooltip(button, title)
  GameTooltip:SetOwner(button, "ANCHOR_LEFT")
  GameTooltip:AddLine(title .. " |cff888888v" .. NS.VERSION .. "|r")
  local preset = NS.PresetLabel("default")
  if preset then GameTooltip:AddLine(preset, 0.4, 1, 0.4) end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L.TT_LEFT, 1, 1, 1)
  GameTooltip:AddLine(L.TT_RIGHT, 1, 1, 1)
  GameTooltip:AddLine(NS.DB().lockFreeButton and L.TT_LOCKED or L.TT_DRAG, 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

-- Clics communs aux deux boutons. PostClick et non PreClick : du code d'addon
-- exécuté avant l'action souille le déroulement du clic.
local function AttachClicks(button, movable)
  button:SetScript("PostClick", function(self, mouseButton, down)
    if down then return end
    if mouseButton == "LeftButton" then
      NS.ToggleMenu()
    elseif mouseButton == "RightButton" then
      if NS.ToggleOptions then NS.ToggleOptions() end
    end
  end)

  button:SetScript("OnEnter", function(self)
    Tooltip(self, L.TITLE)
    if NS.DB().menuOnHover then NS.OpenMenu() end
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
    NS.ScheduleAutoClose()
  end)
end

-- =========================================================
-- BOUTON LIBRE
-- =========================================================
local free = _G["PoisonUpForever_Button"]
if not free then
  free = CreateFrame("Button", "PoisonUpForever_Button", UIParent,
    "SecureActionButtonTemplate")
  NS.xmlMissing = true
end
free:SetFrameStrata("MEDIUM")
free:SetMovable(true)
free:SetClampedToScreen(true)
DressRoundButton(free, 32)
AttachClicks(free, true)
NS.button = free

local function SaveFreePosition()
  local point, _, _, x, y = free:GetPoint(1)
  if point then NS.DB().anchor = { point = point, x = x, y = y } end
end

free:SetScript("OnDragStart", function(self)
  if NS.DB().lockFreeButton or InCombatLockdown() then return end
  self:StartMoving()
  self.isMoving = true
end)

free:SetScript("OnDragStop", function(self)
  if not self.isMoving then return end
  self:StopMovingOrSizing()
  self.isMoving = false
  -- StopMovingOrSizing ancre au coin le plus proche : on renormalise pour
  -- sauvegarder quelque chose de stable d'une session à l'autre.
  local left, bottom = self:GetLeft(), self:GetBottom()
  if left and bottom then
    local ratio = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
  end
  SaveFreePosition()
end)

function NS.ResetFreeButton()
  NS.DB().anchor = nil
  NS.UpdateButtons()
end

-- =========================================================
-- BOUTON DE MINI-CARTE
-- =========================================================
local minimap = _G["PoisonUpForever_MinimapButton"]
if not minimap then
  minimap = CreateFrame("Button", "PoisonUpForever_MinimapButton", Minimap,
    "SecureActionButtonTemplate")
  NS.xmlMissing = true
end
minimap:SetFrameStrata("MEDIUM")
minimap:SetFrameLevel(8)
DressRoundButton(minimap, 31)
AttachClicks(minimap, false)
NS.minimapButton = minimap

local function PlaceMinimap()
  local angle = math.rad(NS.DB().minimapAngle or 150)
  local radius = (Minimap:GetWidth() / 2) + 6
  minimap:ClearAllPoints()
  minimap:SetPoint("CENTER", Minimap, "CENTER",
    radius * math.cos(angle), radius * math.sin(angle))
end

minimap:SetScript("OnDragStart", function(self)
  if InCombatLockdown() then return end
  self:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    -- NS.Atan2 : math.atan2 n'existe pas dans le Lua de ce client.
    NS.DB().minimapAngle = math.deg(NS.Atan2(py / scale - my, px / scale - mx))
    PlaceMinimap()
  end)
end)
minimap:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

-- =========================================================
-- MINUTEURS ET ALERTE VISUELLE
-- =========================================================
local function Colorize(remaining, active)
  if not active then return "|cffff4040--|r" end
  local threshold = (NS.DB().warnMinutes or 2) * 60
  local text = NS.FormatTime(remaining)
  if remaining <= threshold then return "|cffff4040" .. text .. "|r" end
  if remaining <= threshold * 3 then return "|cffffd100" .. text .. "|r" end
  return "|cff40ff40" .. text .. "|r"
end

function NS.UpdateTimers()
  local db = NS.DB()
  local state = NS.enchantState or NS.WeaponEnchants()
  for _, button in ipairs({ free, minimap }) do
    if not db.showTimer or not NS.IsEnabled() then
      button.mhTime:SetText("")
      button.ohTime:SetText("")
    else
      button.mhTime:SetText(NS.HasWeapon(NS.SLOT_MAINHAND)
        and Colorize(state.mh.remaining or 0, state.mh.active) or "")
      button.ohTime:SetText(NS.HasWeapon(NS.SLOT_OFFHAND)
        and Colorize(state.oh.remaining or 0, state.oh.active) or "")
    end
  end
end

local flashTicker
function NS.FlashButton()
  if flashTicker then return end
  local target = free:IsShown() and free or minimap
  target.glow:Show()
  local step = 0
  flashTicker = C_Timer.NewTicker(0.25, function(ticker)
    step = step + 1
    target.glow:SetAlpha((step % 2 == 0) and 0.2 or 0.9)
    if step >= 8 then
      target.glow:Hide()
      ticker:Cancel()
      flashTicker = nil
    end
  end)
end

-- =========================================================
-- VISIBILITÉ
-- =========================================================
function NS.UpdateButtons()
  -- Les boutons sont sécurisés : taille, position et visibilité sont
  -- interdites en combat (ADDON_ACTION_BLOCKED). On reporte à la sortie de
  -- combat, où Core.lua rappelle cette fonction.
  if InCombatLockdown() then
    NS.buttonsPending = true
    if NS.UpdateTimers then NS.UpdateTimers() end
    return
  end
  NS.buttonsPending = false

  local db = NS.DB()
  local enabled = NS.IsEnabled()

  free:ApplySize(32 * (db.freeScale or 1))
  free:SetAlpha(db.freeAlpha or 1)
  free:ClearAllPoints()
  local anchor = db.anchor
  if type(anchor) == "table" and anchor.point then
    free:SetPoint(anchor.point, UIParent, anchor.point, anchor.x or 0, anchor.y or 0)
  else
    free:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
  end
  free:SetShown(enabled and db.showFreeButton)

  minimap:SetAlpha(db.freeAlpha or 1)
  PlaceMinimap()
  minimap:SetShown(enabled and db.showMinimapButton)

  if not enabled or (not db.showFreeButton and not db.showMinimapButton) then
    if NS.CloseMenu then NS.CloseMenu() end
  end
  NS.UpdateTimers()
end

-- Appelée depuis Core.lua à PLAYER_LOGIN : sur Forever les SavedVariables
-- peuvent n'être disponibles qu'à ce moment-là.
function NS.Boot()
  NS.dirty = true
  -- La classe peut n'être connue qu'ici : on remet l'icône du guerrier.
  if NS.IsWarrior() then
    NS.ICON = NS.STONE_ICON
    free.icon:SetTexture(NS.ICON)
    minimap.icon:SetTexture(NS.ICON)
    if NS.aura and NS.aura.icon then NS.aura.icon:SetTexture(NS.ICON) end
  end
  -- Chaque étape est isolée : sur cette bêta, une fonction qui casse ne doit
  -- pas laisser l'addon à moitié initialisé et silencieux.
  for _, step in ipairs({
    { "boutons", NS.UpdateButtons },
    { "bouton rapide", NS.UpdateQuickMacro },
    { "cadre d'aura", NS.UpdateAura },
    { "enchantements", NS.CheckEnchants },
    { "minuteurs", NS.UpdateTimers },
    -- Le placement des carrés n'était appelé qu'au chargement du fichier,
    -- donc jamais avec les réglages du joueur.
    { "placement des carrés", NS.UpdateIndicatorLayout },
    { "carrés d'arme", NS.UpdateIndicators },
  }) do
    if type(step[2]) == "function" then
      local ok, err = pcall(step[2])
      if not ok then
        NS.Print("|cffff4040erreur au chargement (" .. step[1] .. ")|r : " .. tostring(err))
      end
    end
  end
  NS.DB().welcomeShown = true
  NS.Print(L.WELCOME)
end

NS.UpdateButtons()
