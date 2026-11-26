-- Aura.lua - PoisonUp (Forever) - par Daeler
-- Le cadre d'avertissement déplaçable.
--
-- Troisième canal d'alerte de l'onglet Timer, à côté du chat et du cadre
-- d'erreur : une pastille bien visible au milieu de l'écran quand un poison
-- arrive à expiration. Verrouillable, avec échelle et transparence propres,
-- comme la « frame d'aura » de la version TBC.

local ADDON_NAME, NS = ...
local L = NS.L

local aura = CreateFrame("Frame", "PoisonUpForever_Aura", UIParent)
aura:SetSize(240, 56)
aura:SetFrameStrata("HIGH")
aura:SetMovable(true)
aura:SetClampedToScreen(true)
aura:Hide()
NS.aura = aura

aura.bg = aura:CreateTexture(nil, "BACKGROUND")
aura.bg:SetAllPoints(aura)
aura.bg:SetColorTexture(0, 0, 0, 0.6)

aura.icon = aura:CreateTexture(nil, "ARTWORK")
aura.icon:SetSize(40, 40)
aura.icon:SetPoint("LEFT", 8, 0)
aura.icon:SetTexture(NS.ICON)
aura.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

aura.text = aura:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
aura.text:SetPoint("LEFT", aura.icon, "RIGHT", 10, 0)
aura.text:SetPoint("RIGHT", -8, 0)
aura.text:SetJustifyH("LEFT")
aura.text:SetTextColor(1, 0.4, 0.4)

-- Bandeau visible uniquement quand le cadre est déverrouillé, pour qu'on
-- sache où le prendre alors qu'il est vide la plupart du temps.
aura.hint = aura:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
aura.hint:SetPoint("BOTTOM", aura, "TOP", 0, 2)
aura.hint:SetText(L.AURA_HINT)
NS.localeRefreshers = NS.localeRefreshers or {}
table.insert(NS.localeRefreshers, function() aura.hint:SetText(L.AURA_HINT) end)

aura:SetScript("OnDragStart", function(self)
  if NS.DB().auraLocked then return end
  self:StartMoving()
  self.isMoving = true
end)

-- Position gérée par l'addon : le cache de disposition du client ne doit pas
-- la rétablir de son côté au chargement.
if aura.SetDontSavePosition then aura:SetDontSavePosition(true) end

-- Le cadre a sa propre échelle (0.7 par défaut). Les décalages de SetPoint et
-- GetCenter sont exprimés dans cette échelle : on enregistre le centre en
-- unités d'UIParent (drapeau ui), pour que la position ne dépende pas de
-- l'échelle choisie ensuite. L'ancien calcul multipliait par l'échelle une
-- seconde fois, et le cadre sautait vers le coin bas-gauche à chaque lâcher.
aura:SetScript("OnDragStop", function(self)
  if not self.isMoving then return end
  self:StopMovingOrSizing()
  self.isMoving = false
  local cx, cy = self:GetCenter()
  local px, py = UIParent:GetCenter()
  if cx and cy and px and py then
    local scale = self:GetScale()
    NS.DB().auraAnchor = {
      point = "CENTER", x = cx * scale - px, y = cy * scale - py, ui = true,
    }
  end
  NS.UpdateAura()
end)

local hideTimer

-- Affiche un avertissement quelques secondes. Si le cadre est déverrouillé il
-- reste visible en permanence, le temps de le placer.
function NS.ShowAura(message)
  aura.text:SetText(message)
  aura:Show()
  if hideTimer then hideTimer:Cancel() end
  if NS.DB().auraLocked then
    hideTimer = C_Timer.NewTimer(5, function()
      hideTimer = nil
      aura:Hide()
    end)
  end
end

function NS.UpdateAura()
  local db = NS.DB()
  local scale = db.auraScale or 0.7
  if scale <= 0 then scale = 0.7 end
  aura:SetScale(scale)
  aura:SetAlpha(db.auraAlpha or 1)

  aura:ClearAllPoints()
  local anchor = db.auraAnchor
  if type(anchor) == "table" and anchor.point then
    -- Les ancres « ui » sont en unités d'UIParent ; les anciennes étaient
    -- directement dans l'échelle du cadre.
    local factor = anchor.ui and (1 / scale) or 1
    aura:SetPoint(anchor.point, UIParent, anchor.point,
      (anchor.x or 0) * factor, (anchor.y or 0) * factor)
  else
    aura:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
  end

  local unlocked = not db.auraLocked
  -- Déverrouillé, le cadre passe au premier plan comme les carrés d'arme :
  -- sinon les cadres d'autres addons captent le clic à sa place.
  aura:SetFrameStrata(unlocked and "FULLSCREEN_DIALOG" or "HIGH")
  aura:SetToplevel(unlocked)
  aura:EnableMouse(unlocked)
  -- RegisterForDrag refuse nil : pour retirer le glisser, il faut l'appeler
  -- sans aucun argument.
  if unlocked then
    aura:RegisterForDrag("LeftButton")
  else
    aura:RegisterForDrag()
  end
  aura.hint:SetShown(unlocked)
  aura.bg:SetColorTexture(0, 0, 0, unlocked and 0.85 or 0.6)

  if unlocked then
    -- Déverrouillé : on montre le cadre avec un texte d'exemple pour pouvoir
    -- le positionner.
    aura.text:SetText(L.AURA_SAMPLE)
    aura:Show()
  elseif not hideTimer then
    aura:Hide()
  end
end
