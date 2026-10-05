-- Menu.lua - PoisonUp (Forever) - par Daeler
-- La barre de poisons qui sort du bouton.
--
-- Même présentation que la version TBC : une simple rangée d'icônes collée au
-- bouton, une icône par type de poison (le meilleur rang possédé), avec la
-- quantité en bas à droite.
--
-- OUVERTURE EN COMBAT
--
-- En combat, le code d'un addon ne peut ni afficher ni masquer la barre (elle
-- contient des boutons sécurisés), et ce client ne sait pas exécuter les
-- snippets SecureHandler. La barre est donc affichée, transparente, à l'entrée
-- en combat ; l'ouvrir ou la fermer ne fait alors que changer son opacité.
-- Voir NS.MenuEnterCombat.

local ADDON_NAME, NS = ...
local L = NS.L

local ICON_SIZE = 32
local MAX_BUTTONS = 32     -- doit correspondre au nombre déclaré dans le XML

local dressed = {}
local shown = {}           -- boutons actuellement affichés, dans l'ordre

local menu = _G["PoisonUpForever_MenuFrame"]
if not menu then
  menu = CreateFrame("Frame", "PoisonUpForever_MenuFrame", UIParent)
  menu:SetFrameStrata("DIALOG")
  menu:Hide()
  NS.xmlMissing = true
end
NS.menu = menu

-- =========================================================
-- HABILLAGE DES BOUTONS DÉCLARÉS EN XML
-- =========================================================
local function Dress(button)
  button:SetSize(ICON_SIZE, ICON_SIZE)
  -- Enfoncement ET relâchement : sur ce client le gestionnaire sécurisé ignore
  -- le relâchement seul. Voir Core.lua.
  button:RegisterForClicks("AnyDown", "AnyUp")

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
  button.border:SetColorTexture(0.35, 0.35, 0.35, 0.9)

  button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  button.count:SetPoint("BOTTOMRIGHT", -2, 2)

  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  local highlight = button:GetHighlightTexture()
  if highlight then highlight:SetBlendMode("ADD") end

  button:SetScript("OnEnter", function(self)
    if not self.itemID or not NS.MenuShown() then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if NS.DB().tooltipMode == "name" then
      GameTooltip:AddLine(self.itemName or "", 1, 1, 1)
    elseif not pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID) then
      GameTooltip:SetHyperlink("item:" .. self.itemID)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.TT_APPLY_MH, 1, 1, 1)
    GameTooltip:AddLine(L.TT_APPLY_OH, 1, 1, 1)
    GameTooltip:AddLine(L.TT_FAVOURITE, 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
    NS.ScheduleAutoClose()
  end)

  -- AUCUN PreClick : du code d'addon exécuté avant l'action souille le
  -- déroulement du clic. Tout ce qui n'est pas l'action passe en PostClick,
  -- lequel ne tourne d'ailleurs pas en combat sans risque : il ne fait que
  -- lire et imprimer.
  button:SetScript("PostClick", function(self, mouseButton, down)
    if not self.itemID or down then return end
    local offhand = (mouseButton == "RightButton")
    local slot = offhand and NS.SLOT_OFFHAND or NS.SLOT_MAINHAND

    if IsShiftKeyDown() then
      NS.SetPresetItem("default", offhand and "oh" or "mh", self.itemID)
      return
    end

    if not NS.HasWeapon(slot) then
      NS.Print(string.format(L.NO_WEAPON, offhand and L.OFFHAND or L.MAINHAND))
      return
    end

    if NS.DB().overwritePresets then
      NS.Presets().default[offhand and "oh" or "mh"] = self.itemID
      if NS.UpdateQuickMacro then NS.UpdateQuickMacro() end
    end

    NS.Announce(self.itemID, slot)
    -- La barre reste ouverte : on la referme soi-même avec le bouton.
  end)
end

local function GetButton(index)
  if index > MAX_BUTTONS then return nil end
  local button = _G["PoisonUpForever_Item" .. index]
  if not button then
    button = CreateFrame("Button", "PoisonUpForever_Item" .. index, menu,
      "SecureActionButtonTemplate")
    NS.xmlMissing = true
  end
  if not dressed[button] then
    Dress(button)
    dressed[button] = true
  end
  return button
end

-- =========================================================
-- CONSTRUCTION
-- =========================================================
-- Une icône par type de poison : le meilleur rang possédé, et la quantité
-- totale de ce rang. C'est ce que montrait la version TBC.
-- Pierres et huiles : chaque objet possédé a son icône, car le rang du
-- catalogue ne dit pas lequel convient à l'arme (niveau, type de dégâts).
local function BestPerCategory()
  local order = {}
  for _, entry in ipairs(NS.Inventory()) do
    local kind = NS.CATEGORIES[entry.category].kind
    if entry.best or kind == "stone" or kind == "oil" then order[#order + 1] = entry end
  end
  return order
end

-- Quel bouton la barre suit-elle ? L'onglet Menu décide.
local function ParentButton()
  if NS.DB().menuParent == "minimap" and NS.minimapButton
     and NS.minimapButton:IsShown() then
    return NS.minimapButton
  end
  if NS.button and NS.button:IsShown() then return NS.button end
  return NS.minimapButton or NS.button
end

-- Prépare tout ce qui ne pourra plus être touché une fois le combat engagé :
-- câblage des macros, placement des icônes, ancrage de la barre, snippets.
function NS.BuildMenu()
  if InCombatLockdown() then return false end

  local entries = BestPerCategory()
  local spacing = NS.DB().menuSpacing or 0
  local previous

  for index = 1, MAX_BUTTONS do
    local button = _G["PoisonUpForever_Item" .. index]
    local entry = entries[index]

    if entry then
      button = GetButton(index)
      button.itemID = entry.itemID
      button.itemName = entry.name
      button.icon:SetTexture(entry.icon)
      button.count:SetText(entry.count > 1 and entry.count or "")
      NS.WireItemButton(button, entry.itemID)

      button:ClearAllPoints()
      if previous then
        button:SetPoint("LEFT", previous, "RIGHT", 4 + spacing, 0)
      else
        button:SetPoint("LEFT", menu, "LEFT", 0, 0)
      end
      button:Show()
      previous = button
    elseif button then
      button.itemID = nil
      button:Hide()
    end
  end

  shown = entries
  local step = ICON_SIZE + 4 + spacing
  menu:SetSize(math.max(1, #entries * step - spacing - 4), ICON_SIZE)
  menu:SetScale(NS.DB().menuScale or 1.0)

  -- L'ancrage se fige ici : en combat, plus question de déplacer la barre.
  local parent = ParentButton()
  local position = NS.MENU_POSITIONS[NS.DB().menuPosition] or NS.MENU_POSITIONS.RIGHT
  menu:ClearAllPoints()
  if parent then
    menu:SetPoint(position[1], parent, position[2], position[3], position[4])
  else
    menu:SetPoint("CENTER")
  end

  return #entries > 0
end

-- =========================================================
-- OUVERTURE / FERMETURE
-- =========================================================
-- En combat, Show/Hide sont interdits sur la barre (elle contient des boutons
-- sécurisés), mais SetAlpha reste permis. À l'entrée en combat la barre est
-- donc affichée, transparente si elle était fermée, et c'est son opacité qui
-- fait office d'ouverture tant que dure le combat. À la sortie, on revient à
-- un vrai Show/Hide.
local combatOpen = false

function NS.MenuShown()
  if InCombatLockdown() then return menu:IsShown() and combatOpen end
  return menu:IsShown()
end

function NS.OpenMenu()
  if not NS.IsEnabled() then return end
  if InCombatLockdown() then
    if not menu:IsShown() or #shown == 0 then return end
    combatOpen = true
    menu:SetAlpha(1)
    return
  end
  if not NS.BuildMenu() then
    NS.Print(L.EMPTY)
    return
  end
  menu:SetAlpha(1)
  menu:Show()
end

function NS.CloseMenu()
  if InCombatLockdown() then
    combatOpen = false
    menu:SetAlpha(0)
    return
  end
  menu:Hide()
end

function NS.ToggleMenu()
  if NS.MenuShown() then NS.CloseMenu() else NS.OpenMenu() end
end

-- Appelé sur PLAYER_REGEN_DISABLED, dernier instant où Show est permis.
function NS.MenuEnterCombat()
  combatOpen = menu:IsShown()
  if not NS.IsEnabled() or #shown == 0 then return end
  if not combatOpen then menu:SetAlpha(0) end
  menu:Show()
end

-- Appelé sur PLAYER_REGEN_ENABLED : la barre retrouve un état normal.
function NS.MenuLeaveCombat()
  if combatOpen then menu:SetAlpha(1) else menu:Hide(); menu:SetAlpha(1) end
end

-- Fermeture au survol sortant, avec un court délai pour laisser au curseur le
-- temps de passer du bouton à la rangée, et d'une icône à l'autre.
local closeTimer
function NS.ScheduleAutoClose()
  if closeTimer then closeTimer:Cancel() end
  closeTimer = C_Timer.NewTimer(0.35, function()
    closeTimer = nil
    if not NS.DB().menuOnHover or InCombatLockdown() then return end
    for index = 1, #shown do
      local button = _G["PoisonUpForever_Item" .. index]
      if button and button:IsMouseOver() then return end
    end
    if NS.button and NS.button:IsMouseOver() then return end
    if NS.minimapButton and NS.minimapButton:IsMouseOver() then return end
    NS.CloseMenu()
  end)
end

-- Reconstruit la barre dès que les sacs ou les réglages changent, qu'elle soit
-- ouverte ou non : c'est ce qui la rend utilisable en combat, où plus rien ne
-- peut être préparé.
function NS.RefreshSecureState()
  if InCombatLockdown() then return end
  NS.BuildMenu()
  if NS.UpdateQuickMacro then NS.UpdateQuickMacro() end
end
