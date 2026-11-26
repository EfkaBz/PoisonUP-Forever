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
-- défaut, ou le seuil de charges de l'onglet Options (dix par défaut) : le
-- premier des deux atteint estompe le carré. Le groupe se déplace d'un bloc et se redimensionne dans les options.
--
-- Sur Forever, pierre à aiguiser / huile se cumulent au poison : deux carrés de
-- plus suivent la pierre de chaque main avec les mêmes règles.

local ADDON_NAME, NS = ...
local L = NS.L

-- Halo vert (actif) : plus large et plus lumineux que les autres états.
local GREEN_GLOW = { 0.5, 1, 0.2, 1 }
local GREEN_SPREAD = 22

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
NS.localeRefreshers = NS.localeRefreshers or {}
table.insert(NS.localeRefreshers, function() group.hint:SetText(L.IND_HINT) end)
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

  -- Cadre grimoire (Widgets.lua) : la bordure et le halo disent l'état.
  NS.W.SkinSquare(square, 14)

  -- Temps restant, pour savoir s'il reste dix secondes ou deux minutes.
  square.time = square:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  square.time:SetPoint("BOTTOM", square, "BOTTOM", 0, 2)

  -- Charges restantes, en haut à droite : vert pâle, ambre quand il en reste
  -- peu.
  square.charges = square:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  square.charges:SetPoint("TOPRIGHT", square, "TOPRIGHT", -3, -3)
  square.charges:SetJustifyH("RIGHT")

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
  square.badgeBorder:SetColorTexture(0.69, 0.54, 0.31, 1)

  -- Rebond quand le poison va expirer : un petit saut, une retombée qui
  -- rebondit, puis une pause, en boucle. Une animation ne touche qu'au rendu :
  -- l'ancrage du carré ne bouge pas.
  local hop = square:CreateAnimationGroup()
  hop:SetLooping("REPEAT")
  local function Step(order, y, duration, smoothing)
    local move = hop:CreateAnimation("Translation")
    move:SetOrder(order)
    move:SetOffset(0, y)
    move:SetDuration(duration)
    move:SetSmoothing(smoothing)
    return move
  end
  square.hopSteps = {
    Step(1, 1, 0.16, "OUT"),        -- saut
    Step(2, -1, 0.14, "IN"),        -- retombée
    Step(3, 0.35, 0.09, "OUT"),     -- petit rebond
    Step(4, -0.35, 0.09, "IN"),
  }
  Step(5, 0, 0.9, "NONE")           -- pause
  square.hop = hop

  -- Hauteur du saut proportionnelle à la taille du carré.
  function square:SetBounce(on)
    if on then
      local height = math.max(4, (self:GetHeight() or 36) * 0.22)
      local ratios = { 1, -1, 0.35, -0.35 }
      for index, move in ipairs(self.hopSteps) do
        move:SetOffset(0, height * ratios[index])
      end
      if not self.hop:IsPlaying() then self.hop:Play() end
    elseif self.hop:IsPlaying() then
      self.hop:Stop()
    end
  end

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
  -- Furie-des-vents : seulement pour les classes de mêlée.
  if hand.windfury then
    return db.showWindfuryIndicator and (NS.UsesPoisons() or NS.IsWarrior()) and true or false
  end
  if hand.stone then return db.showStoneIndicators and true or false end
  -- Guerrier, lanceurs de sorts : pas de poison, donc pas de carrés poison.
  if not NS.UsesPoisons() then return false end
  return true
end

-- Un shaman dans le groupe ou le raid ? Sans lui, pas de totem à attendre.
-- Résultat gardé 5 s : en raid, c'était 40 unités interrogées chaque seconde.
local shamanCache, shamanCacheAt
local ScanForShaman
local function ShamanInGroup()
  local now = GetTime and GetTime() or 0
  if shamanCacheAt and now - shamanCacheAt < 5 then return shamanCache end
  shamanCache, shamanCacheAt = ScanForShaman(), now
  return shamanCache
end

function ScanForShaman()
  if not UnitClass then return false end
  local _, own = UnitClass("player")
  if own == "SHAMAN" then return true end
  -- Sur Forever le totem couvre tout le raid, pas seulement le groupe.
  local raid = IsInRaid and IsInRaid()
  for i = 1, raid and 40 or 4 do
    local unit = (raid and "raid" or "party") .. i
    if UnitExists and UnitExists(unit) then
      local ok, _, class = pcall(UnitClass, unit)
      if ok and not (issecretvalue and issecretvalue(class)) and class == "SHAMAN" then
        return true
      end
    end
  end
  return false
end
NS.ShamanInGroup = ShamanInGroup

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
    -- Badge pierre : l'huile pour les lanceurs de sorts (NS.ICON est déjà
    -- l'huile de sorcier pour eux, voir NS.Boot).
    if square.hand.stone then
      local caster = not NS.UsesPoisons() and not NS.IsWarrior()
      square.badge:SetTexture(caster and NS.ICON or NS.STONE_ICON)
    end
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

  -- Options « instance seulement » et « pêche » de l'onglet Timer : les
  -- carrés sont des avertissements comme les autres. Déverrouillé, on les
  -- montre quand même pour pouvoir placer le groupe.
  if not unlocked and NS.WarningContextAllowed and not NS.WarningContextAllowed() then
    for _, square in ipairs(squares) do
      square:SetBounce(false)
      square:Hide()
    end
    group:Hide()
    return
  end

  -- Règles d'affichage :
  --   option indicatorsAlways cochée -> tous les carrés activés, tout le
  --     temps, en combat comme hors combat (rouge, estompé ou avec minuteur) ;
  --   sinon -> ce qui va bientôt expirer (estompé), en combat comme hors
  --     combat ; et en combat, aussi ce qui manque complètement (rouge).
  --     Option indicatorsOutOfCombat : ce qui manque est aussi montré hors
  --     combat (arme sans poison, sans pierre).
  --     Un poison ou une pierre qui a encore du temps n'est jamais montré.
  local always = db.indicatorsAlways and true or false
  local inCombat = (InCombatLockdown and InCombatLockdown())
    or (UnitAffectingCombat and UnitAffectingCombat("player"))

  local state = NS.enchantState or NS.WeaponEnchants()
  local threshold = (db.warnMinutes or 2) * 60
  local fade = db.indicatorFadeAlpha or 0.45
  local chargeThreshold = db.indicatorWarnCharges or 0
  local showCharges = db.indicatorShowCharges ~= false
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
    -- Bouclier ou objet tenu en main gauche : traité comme une main vide.
    local itemID = NS.HasWeapon(hand.slot)
      and GetInventoryItemID and GetInventoryItemID("player", hand.slot) or nil
    -- Bientôt expiré : par le temps (inchangé) ou par les charges, quand le
    -- jeu les donne et que le seuil n'est pas à 0.
    local charges = slotState.active and slotState.charges or nil
    local lowCharges = charges and chargeThreshold > 0 and charges <= chargeThreshold
    local soon = slotState.active
      and (((slotState.remaining or 0) <= threshold) or lowCharges) and true or false
    -- Furie-des-vents : buff de raid entretenu par le totem, jamais « bientôt
    -- expiré » ; il est là (vert) ou il manque (rouge).
    if hand.windfury then soon = false end

    local show, alpha = false, 1
    if not NS.IndicatorEnabled(hand) then
      show = false
    elseif unlocked then
      show = true
    elseif hand.windfury then
      -- Totem Furie-des-vents : buff de quelques secondes rafraîchi en
      -- boucle. Son option suffit (avant, il fallait aussi « toujours
      -- afficher », et le carré n'apparaissait jamais) : montré dès que le
      -- totem est actif, ou qu'un shaman est groupé (rouge s'il manque).
      show = (itemID and (slotState.active or ShamanInGroup())) and true or false
    elseif itemID and watched then
      if always then
        show, alpha = true, soon and fade or 1
      elseif soon then
        show, alpha = true, fade
      elseif (inCombat or db.indicatorsOutOfCombat) and not slotState.active then
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
        -- Ambre qui bat quand il reste peu de temps, bronze sinon.
        if soon then
          square:SetTrim({ 1, 0.7, 0.25 })
          square:SetGlow({ 1, 0.65, 0.15, 0.7 }, true)
        else
          square:SetTrim({ 0.69, 0.54, 0.31 })
          square:SetGlow(GREEN_GLOW, false, GREEN_SPREAD)
        end
        -- Buff sans durée (totem posé) : pas de minuteur à afficher.
        square.time:SetText(slotState.remaining and NS.FormatTime(slotState.remaining) or "")
      elseif slotState.unknown then
        -- Furie-des-vents en combat : auras secrètes, présence invérifiable.
        -- On suppose le buff présent (shaman groupé) : vert, comme actif.
        square.icon:SetDesaturated(false)
        square:SetTrim({ 0.69, 0.54, 0.31 })
        square:SetGlow(GREEN_GLOW, false, GREEN_SPREAD)
        square.time:SetText("")
      else
        square:SetTrim({ 1, 0.25, 0.2 })
        square:SetGlow({ 1, 0.2, 0.15, 0.8 }, true)
        square.time:SetText("")
        -- Diagnostic : carré Furie-des-vents rouge, on note dans quel
        -- contexte (combat, auras secrètes, réponse de chaque ID).
        if hand.windfury and db.debug and NS.WindfuryProbe then
          db.wfRed = NS.WindfuryProbe()
          db.wfRed.inCombat = tostring(inCombat)
        end
      end

      if showCharges and charges then
        square.charges:SetText(charges)
        if lowCharges then
          square.charges:SetTextColor(1, 0.7, 0.25)
        else
          square.charges:SetTextColor(0.75, 1, 0.55)
        end
        square.charges:Show()
      else
        square.charges:Hide()
      end

      square:SetAlpha(alpha)
      -- Rebond : poison / pierre bientôt expiré, ou Furie-des-vents absent
      -- (shaman groupé mais buff manquant, carré rouge).
      local bounce
      if hand.windfury then
        bounce = not slotState.active and not slotState.unknown
      else
        bounce = slotState.active and soon
      end
      square:SetBounce(bounce and not unlocked and db.indicatorsBounce ~= false)
      square:Show()
      anyVisible = true
    else
      square:SetBounce(false)
      square:Hide()
    end
  end

  group:SetShown(anyVisible)
end

NS.UpdateIndicatorLayout()
