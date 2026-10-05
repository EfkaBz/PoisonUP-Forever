-- Indicators.lua - PoisonUp (Forever) - par Daeler
-- Les carrés d'arme.
--
-- Reprise du repère visuel de la version TBC : un carré par main, montrant
-- l'arme concernée.
--
--   par défaut : le poison / la pierre qui va bientôt expirer (carré
--                estompé), en combat comme hors combat ; en combat, aussi
--                ce qui manque complètement (carré rouge)
--   option « toujours » : tous les carrés, en combat et hors combat
--                (rouge sans rien, estompé si bientôt expiré, sinon minuteur)
--
-- « Bientôt » est le seuil d'avertissement de l'onglet Timer, deux minutes par
-- défaut. Le groupe se déplace d'un bloc et se redimensionne dans les options.
--
-- Sur Forever, pierre à aiguiser / huile se cumulent au poison : deux carrés de
-- plus suivent la pierre de chaque main avec les mêmes règles.

local ADDON_NAME, NS = ...
local L = NS.L

local HANDS = {
  { key = "mh", slot = NS.SLOT_MAINHAND, label = "MAINHAND", windfury = true },
  { key = "mh", slot = NS.SLOT_MAINHAND, label = "MAINHAND" },
  { key = "oh", slot = NS.SLOT_OFFHAND, label = "OFFHAND" },
  { key = "mh", slot = NS.SLOT_MAINHAND, label = "MAINHAND", stone = true },
  { key = "oh", slot = NS.SLOT_OFFHAND, label = "OFFHAND", stone = true },
}

local group = CreateFrame("Frame", "PoisonUpForever_Indicators", UIParent)
group:SetFrameStrata("MEDIUM")
group:SetMovable(true)
group:SetClampedToScreen(true)
group:Hide()
NS.indicators = group

group.hint = group:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
group.hint:SetPoint("BOTTOM", group, "TOP", 0, 4)
group.hint:SetText(L.IND_HINT)
group.hint:Hide()

-- =========================================================
-- LES QUATRE CARRÉS (poison MH/OH, pierre MH/OH)
-- =========================================================
local squares = {}
for index, hand in ipairs(HANDS) do
  local square = CreateFrame("Frame", nil, group)

  square.icon = square:CreateTexture(nil, "ARTWORK")
  square.icon:SetPoint("TOPLEFT", 2, -2)
  square.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  square.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  square.border = square:CreateTexture(nil, "BORDER")
  square.border:SetPoint("TOPLEFT", -1, 1)
  square.border:SetPoint("BOTTOMRIGHT", 1, -1)

  -- Temps restant, pour savoir s'il reste dix secondes ou deux minutes.
  square.time = square:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  square.time:SetPoint("BOTTOM", square, "BOTTOM", 0, 2)

  -- Petit badge en bas à gauche : poison ou pierre, pour distinguer les
  -- carrés d'un coup d'œil.
  square.badge = square:CreateTexture(nil, "OVERLAY", nil, 2)
  square.badge:SetPoint("BOTTOMLEFT", square, "BOTTOMLEFT", 2, 2)
  square.badge:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  square.badge:SetTexture(
    (hand.windfury and "Interface\\Icons\\Spell_Nature_Windfury")
    or (hand.stone and "Interface\\Icons\\INV_Stone_SharpeningStone_01")
    or "Interface\\Icons\\Ability_Poisons")
  square.badgeBorder = square:CreateTexture(nil, "OVERLAY", nil, 1)
  square.badgeBorder:SetPoint("TOPLEFT", square.badge, "TOPLEFT", -1, 1)
  square.badgeBorder:SetPoint("BOTTOMRIGHT", square.badge, "BOTTOMRIGHT", 1, -1)
  square.badgeBorder:SetColorTexture(0, 0, 0, 0.9)

  square.hand = hand
  squares[index] = square
end

-- =========================================================
-- DÉPLACEMENT
-- =========================================================
group:SetScript("OnDragStart", function(self)
  if NS.DB().indicatorsLocked then return end
  self:StartMoving()
  self.isMoving = true
end)

group:SetScript("OnDragStop", function(self)
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
  if point then NS.DB().indicatorsAnchor = { point = point, x = x, y = y } end
end)

-- =========================================================
-- OPTIONS PAR TYPE DE CARRÉ
-- =========================================================
function NS.IndicatorEnabled(hand)
  local db = NS.DB()
  if hand.windfury then return db.showWindfuryIndicator and true or false end
  if hand.stone then return db.showStoneIndicators and true or false end
  -- Guerrier : pas de poison, donc pas de carrés poison.
  if NS.IsWarrior() then return false end
  return true
end

-- Un shaman dans le groupe ? Sans lui, pas de totem à attendre.
local function ShamanInGroup()
  if not UnitClass then return false end
  for i = 1, 4 do
    local unit = "party" .. i
    if UnitExists and UnitExists(unit) then
      local _, class = UnitClass(unit)
      if class == "SHAMAN" then return true end
    end
  end
  return false
end

-- =========================================================
-- GÉOMÉTRIE
-- =========================================================
-- Appelée quand la taille ou la position changent dans les options.
function NS.UpdateIndicatorLayout()
  local db = NS.DB()
  local size = db.indicatorSize or 48
  local gap = 6

  -- Seuls les carrés activés dans les options prennent une place.
  local count = 0
  for _, square in ipairs(squares) do
    square:SetSize(size, size)
    local badge = math.max(10, math.floor(size * 0.35))
    square.badge:SetSize(badge, badge)
    square:ClearAllPoints()
    if NS.IndicatorEnabled(square.hand) then
      square:SetPoint("TOPLEFT", group, "TOPLEFT", count * (size + gap), 0)
      count = count + 1
    end
  end
  count = math.max(count, 1)
  group:SetSize(size * count + gap * (count - 1), size)

  group:ClearAllPoints()
  local anchor = db.indicatorsAnchor
  if type(anchor) == "table" and anchor.point then
    group:SetPoint(anchor.point, UIParent, anchor.point, anchor.x or 0, anchor.y or 0)
  else
    group:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
  end

  local unlocked = not db.indicatorsLocked
  -- Déverrouillé, le groupe passe au premier plan : en strate MEDIUM il se
  -- retrouve sous les cadres d'autres addons, qui captent le clic à sa place
  -- et le rendent impossible à attraper.
  group:SetFrameStrata(unlocked and "FULLSCREEN_DIALOG" or "MEDIUM")
  group:SetToplevel(unlocked)
  group:EnableMouse(unlocked)
  -- RegisterForDrag refuse nil : sans argument pour retirer le glisser.
  if unlocked then
    group:RegisterForDrag("LeftButton")
  else
    group:RegisterForDrag()
  end
  group.hint:SetShown(unlocked)
end

-- =========================================================
-- ÉTAT
-- =========================================================
-- Déverrouillé, tout est montré en permanence pour pouvoir placer le groupe.
function NS.UpdateIndicators()
  local db = NS.DB()
  local unlocked = not db.indicatorsLocked

  if not db.showIndicators or not NS.IsEnabled() then
    group:Hide()
    return
  end

  -- Règles d'affichage :
  --   option indicatorsAlways cochée -> tous les carrés activés, tout le
  --     temps, en combat comme hors combat (rouge, estompé ou avec minuteur) ;
  --   sinon -> ce qui va bientôt expirer (estompé), en combat comme hors
  --     combat ; et en combat, aussi ce qui manque complètement (rouge).
  --     Un poison ou une pierre qui a encore du temps n'est jamais montré.
  local always = db.indicatorsAlways and true or false
  local inCombat = (InCombatLockdown and InCombatLockdown())
    or (UnitAffectingCombat and UnitAffectingCombat("player"))

  local state = NS.enchantState or NS.WeaponEnchants()
  local threshold = (db.warnMinutes or 2) * 60
  local fade = db.indicatorFadeAlpha or 0.45
  local anyVisible = false

  for _, square in ipairs(squares) do
    local hand = square.hand
    local watched = (hand.key == "mh") and db.checkMainHand or db.checkOffHand
    local slotState = state[hand.key] or {}
    if hand.windfury then
      slotState = slotState.windfury or {}
    elseif hand.stone then
      slotState = slotState.stone or {}
    end
    local itemID = GetInventoryItemID and GetInventoryItemID("player", hand.slot)
    local soon = slotState.active and (slotState.remaining or 0) <= threshold

    local show, alpha = false, 1
    if not NS.IndicatorEnabled(hand) then
      show = false
    elseif unlocked then
      show = true
    elseif hand.windfury then
      -- Totem Furie-des-vents : buff de quelques secondes rafraîchi en
      -- boucle, toujours « bientôt expiré » : seulement avec l'option, et
      -- seulement si un shaman est dans le groupe.
      show = (always and itemID and ShamanInGroup()) and true or false
    elseif itemID and watched then
      if always then
        show, alpha = true, soon and fade or 1
      elseif soon then
        show, alpha = true, fade
      elseif inCombat and not slotState.active then
        show, alpha = true, 1
      end
    end

    if show then
      -- GetItemInfo n'existe pas comme global sur ce client : on demande la
      -- texture à l'emplacement d'équipement, et NS.ItemInfo sert de repli
      -- (il connaît déjà les bonnes fonctions selon le client).
      local texture
      if GetInventoryItemTexture then
        texture = GetInventoryItemTexture("player", hand.slot)
      end
      if not texture and itemID then
        local _, icon = NS.ItemInfo(itemID)
        texture = icon
      end
      square.icon:SetTexture(texture or NS.ICON)
      square.icon:SetDesaturated(not slotState.active)

      -- Rouge quand il n'y a plus rien, orangé quand le temps se réduit.
      if slotState.active then
        square.border:SetColorTexture(1, 0.7, 0.2, 0.9)
        square.time:SetText(NS.FormatTime(slotState.remaining))
      else
        square.border:SetColorTexture(1, 0.2, 0.2, 0.95)
        square.time:SetText("")
      end

      square:SetAlpha(alpha)
      square:Show()
      anyVisible = true
    else
      square:Hide()
    end
  end

  group:SetShown(anyVisible)
end

NS.UpdateIndicatorLayout()
