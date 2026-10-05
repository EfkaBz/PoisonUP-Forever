-- Core.lua - PoisonUp (Forever) - par Daeler
-- Modèle de données (ce qu'il y a dans les sacs, ce qu'il y a sur les armes)
-- et fabrication des macros sécurisées.

local ADDON_NAME, NS = ...
local L = NS.L

NS.inventory = {}       -- liste ordonnée des consommables disponibles
NS.dirty = true         -- le modèle doit-il être reconstruit ?

-- =========================================================
-- INFOS OBJET
-- =========================================================
local function ItemInfo(itemID)
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
  if not name then
    name = GetItemInfo and GetItemInfo(itemID) or nil
  end
  local icon
  if C_Item and C_Item.GetItemIconByID then
    icon = C_Item.GetItemIconByID(itemID)
  end
  if not icon and GetItemIcon then
    icon = GetItemIcon(itemID)
  end
  return name, icon or 134400
end
NS.ItemInfo = ItemInfo

-- =========================================================
-- CONSTRUCTION DU MODÈLE
-- =========================================================
-- Le principe de la version TBC est conservé : on n'affiche que ce que le
-- joueur porte, groupé par type de poison, du meilleur rang au moins bon.
function NS.RebuildInventory()
  local counts, where = NS.ScanBags()
  local perCategory = {}

  for itemID, count in pairs(counts) do
    local index = NS.ITEM_INDEX[itemID]
    if index and NS.CategoryVisible(index.category) then
      local name, icon = ItemInfo(itemID)
      local at = where[itemID] or {}
      perCategory[index.category] = perCategory[index.category] or {}
      table.insert(perCategory[index.category], {
        itemID = itemID,
        rank = index.rank,
        count = count,
        name = name or ("item:" .. itemID),
        icon = icon,
        category = index.category,
        bag = at.bag,
        slot = at.slot,
      })
    end
  end

  local list = {}
  -- L'ordre des types peut être réarrangé par le joueur (Button Sorting).
  for _, category in ipairs(NS.OrderedCategories()) do
    local entries = perCategory[category]
    if entries then
      -- rang décroissant : le plus haut rang possédé arrive en tête
      table.sort(entries, function(a, b) return a.rank > b.rank end)
      for position, entry in ipairs(entries) do
        entry.best = (position == 1)
        list[#list + 1] = entry
      end
    end
  end

  NS.inventory = list
  NS.dirty = false
  return list
end

function NS.Inventory()
  if NS.dirty then NS.RebuildInventory() end
  return NS.inventory
end

function NS.FindEntry(itemID)
  for _, entry in ipairs(NS.Inventory()) do
    if entry.itemID == itemID then return entry end
  end
end

-- =========================================================
-- APPLICATION DU POISON
-- =========================================================
-- Appliquer un poison est une action protégée : impossible depuis du Lua
-- (le client lève ADDON_ACTION_FORBIDDEN), il faut un clic du joueur sur un
-- bouton sécurisé. Comme la version TBC : "/use <objet>" met le poison
-- sur le curseur, "/use 16" le dépose sur l'arme. Voir NS.WireSlot plus bas
-- pour les différentes façons de câbler ça sur le bouton.
local function ConfirmLine()
  return NS.DB().autoConfirm and "\n/click StaticPopup1Button1" or ""
end

-- Comment désigner l'objet dans la macro. La version TBC écrivait le
-- NOM de l'objet ("/use Poison instantané VI") : certaines versions du parseur
-- de macros ne reconnaissent pas la forme "item:1234", donc on privilégie le
-- nom dès que le client nous l'a donné, avec repli sur l'identifiant.
function NS.ItemRef(itemID)
  if NS.DB().useItemName then
    local name = ItemInfo(itemID)
    if name and name ~= "" then return name end
  end
  return "item:" .. itemID
end

-- Sonde de debug : la macro appelle cette fonction en dernier. Si le message
-- apparaît, c'est que le bouton sécurisé a bien exécuté la macro et que le
-- problème est du côté de "/use 16" ; s'il n'apparaît pas, c'est le câblage du
-- bouton qui ne résout pas ses attributs.
-- On mémorise l'instant, en plus d'imprimer : une ligne de chat peut défiler
-- hors de l'écran, alors que /poisonup status répond toujours.
NS.lastMacroRun = nil
function PoisonUpForever_MacroRan(what)
  NS.lastMacroRun = { time = GetTime(), item = what }
  NS.Debug("macro exécutée jusqu'au bout (" .. tostring(what) .. ")")
end

local function DebugLine(itemID)
  if not NS.DB().debug then return "" end
  return "\n/run PoisonUpForever_MacroRan(" .. itemID .. ")"
end


-- La séquence appliquée à une main : "/use <objet>" met le poison sur le
-- curseur, "/use 16" (ou 17) le dépose sur l'arme.
function NS.MacroFor(itemID, slot)
  return string.format("/use %s\n/use %d%s", NS.ItemRef(itemID), slot, ConfirmLine())
end

-- =========================================================
-- CÂBLAGE DES BOUTONS SÉCURISÉS
-- =========================================================
-- Appliquer un poison ne peut se faire que depuis un bouton sécurisé, et la
-- séquence est celle de la version TBC : "/use <objet>" met le poison sur
-- le curseur, "/use 16" (ou 17) le dépose sur l'arme. Le texte vit sur
-- l'attribut du bouton ; rien n'est écrit dans la liste de macros du joueur.
--
-- ATTENTION, le piège de ce client : ses boutons sécurisés agissent à
-- l'ENFONCEMENT du bouton de souris. Un bouton enregistré avec
-- RegisterForClicks("AnyUp") reçoit bien le clic — PreClick, OnClick et
-- PostClick partent tous — mais le gestionnaire sécurisé ressort à sa première
-- ligne, sans même lire son attribut "type", et sans aucun message d'erreur.
-- D'où l'obligation d'enregistrer "AnyDown" en plus. Voir Menu.lua.
--
-- Les attributs sont posés à la fois suffixés par bouton (type1 = clic gauche,
-- type2 = clic droit) et non suffixés, la macro non suffixée distinguant
-- elle-même les mains avec [button:1] / [button:2] : selon le client, l'une ou
-- l'autre voie est empruntée, et les deux donnent le même résultat.
local function ClearWiring(button, suffix)
  for _, attribute in ipairs({ "type", "item", "target-slot", "macrotext" }) do
    button:SetAttribute(attribute .. suffix, nil)
  end
end

-- suffix : "1" (clic gauche), "2" (clic droit) ou "3" (clic milieu).
function NS.WireSlot(button, suffix, itemID, slot)
  if InCombatLockdown() then return false end
  ClearWiring(button, suffix)
  if not itemID then return false end
  button:SetAttribute("type" .. suffix, "macro")
  button:SetAttribute("macrotext" .. suffix,
    NS.MacroFor(itemID, slot) .. DebugLine(itemID))
  return true
end

-- Câble les deux mains sur un bouton du menu.
function NS.WireItemButton(button, itemID)
  if InCombatLockdown() then return false end

  NS.WireSlot(button, "1", itemID, NS.SLOT_MAINHAND)
  NS.WireSlot(button, "2", itemID, NS.SLOT_OFFHAND)

  local ref = NS.ItemRef(itemID)
  button:SetAttribute("type", "macro")
  button:SetAttribute("macrotext", table.concat({
    "/use [button:2] " .. ref,
    "/use [button:2] " .. NS.SLOT_OFFHAND,
    "/use [button:1] " .. ref,
    "/use [button:1] " .. NS.SLOT_MAINHAND,
  }, "\n") .. ConfirmLine() .. DebugLine(itemID))

  -- Maj + clic mémorise le favori au lieu d'appliquer : une valeur vide sur
  -- les attributs préfixés "shift-" neutralise l'action.
  button:SetAttribute("shift-type", "")
  button:SetAttribute("shift-type1", "")
  button:SetAttribute("shift-type2", "")
  return true
end

-- =========================================================
-- BOUTON RAPIDE : LES QUATRE JEUX DE POISONS
-- =========================================================
-- Reprise du « bouton rapide » de la version TBC : un seul bouton applique les
-- deux mains d'un coup, et le jeu appliqué dépend du modificateur tenu.
--
-- Les modificateurs, eux, sont bien transmis sur ce client (ils ne dépendent
-- pas du bouton de souris cliqué), donc [modifier:shift] et compagnie
-- fonctionnent. Clic gauche = main droite, clic droit = main gauche, comme
-- dans le menu.
local PRESET_CONDITION = {
  default = "nomodifier",
  shift = "modifier:shift",
  ctrl = "modifier:ctrl",
  alt = "modifier:alt",
}

function NS.QuickMacro()
  local lines, any = {}, false

  -- Main gauche d'abord (clic droit), puis main droite : l'ordre de la version
  -- TBC, pour que la dernière confirmation concerne la main droite.
  for _, hand in ipairs({
    { key = "oh", button = "button:2", slot = NS.SLOT_OFFHAND },
    { key = "mh", button = "button:1", slot = NS.SLOT_MAINHAND },
  }) do
    local used = false
    for _, preset in ipairs(NS.PRESET_KEYS) do
      local itemID = NS.Preset(preset)[hand.key]
      if itemID then
        lines[#lines + 1] = string.format("/use [%s,%s] %s",
          PRESET_CONDITION[preset], hand.button, NS.ItemRef(itemID))
        used, any = true, true
      end
    end
    if used then
      lines[#lines + 1] = string.format("/use [%s] %d", hand.button, hand.slot)
    end
  end

  if not any then return nil end
  if NS.DB().autoConfirm then
    lines[#lines + 1] = "/click StaticPopup1Button1"
  end
  return table.concat(lines, "\n")
end

-- Macro d'une seule main, sans condition [button:N] : elle est posée sur les
-- attributs suffixés (macrotext1 / macrotext2), comme pour les boutons du
-- menu. Sans elle, le client pouvait ignorer le [button:1] de la macro
-- commune et la main droite n'était jamais traitée.
function NS.QuickHandMacro(handKey)
  local slot = (handKey == "mh") and NS.SLOT_MAINHAND or NS.SLOT_OFFHAND
  local lines = {}
  for _, preset in ipairs(NS.PRESET_KEYS) do
    local itemID = NS.Preset(preset)[handKey]
    if itemID then
      lines[#lines + 1] = string.format("/use [%s] %s",
        PRESET_CONDITION[preset], NS.ItemRef(itemID))
    end
  end
  if #lines == 0 then return nil end
  lines[#lines + 1] = "/use " .. slot
  if NS.DB().autoConfirm then
    lines[#lines + 1] = "/click StaticPopup1Button1"
  end
  return table.concat(lines, "\n")
end

-- Résumé lisible d'un jeu, pour les infobulles.
function NS.PresetLabel(key)
  local preset = NS.Preset(key)
  local parts = {}
  if preset.mh then
    parts[#parts + 1] = L.MAINHAND .. " : " .. (ItemInfo(preset.mh) or preset.mh)
  end
  if preset.oh then
    parts[#parts + 1] = L.OFFHAND .. " : " .. (ItemInfo(preset.oh) or preset.oh)
  end
  if #parts == 0 then return nil end
  return table.concat(parts, "  |  ")
end

-- Annonce dans le chat, option « Afficher les poisons choisis sur le chat ».
function NS.Announce(itemID, slot)
  if not NS.DB().announceChat then return end
  local name = ItemInfo(itemID) or ("item:" .. itemID)
  local hand = (slot == NS.SLOT_OFFHAND) and L.OFFHAND or L.MAINHAND
  NS.Print(string.format(L.APPLIED, name, hand))
end

-- Décrit le câblage d'un bouton, pour /poisonup status et le mode debug.
function NS.DescribeWiring(button, suffix)
  local macrotext = button:GetAttribute("macrotext" .. suffix)
  return string.format("type%s=%s macro%s=%s",
    suffix, tostring(button:GetAttribute("type" .. suffix)),
    suffix, macrotext and (#macrotext .. " caractères") or "nil")
end


-- Enregistre un poison dans un jeu, pour une main donnée.
-- hand vaut "mh" (main droite) ou "oh" (main gauche) ; itemID nil efface.
function NS.SetPresetItem(presetKey, hand, itemID)
  local preset = NS.Presets()[presetKey]
  if not preset then return false end
  preset[hand] = itemID
  local label = NS.PresetLabel(presetKey)
  NS.Print(string.format(L.PRESET_SET, L["PRESET_" .. presetKey:upper()],
    label or (NONE or "Aucun")))
  if NS.UpdateQuickMacro then NS.UpdateQuickMacro() end
  if NS.RefreshOptions then NS.RefreshOptions() end
  return true
end

-- =========================================================
-- SURVEILLANCE DES ENCHANTEMENTS
-- =========================================================
-- Ajout par rapport à la version TBC : au lieu d'un simple minuteur
-- affiché, on prévient quand une arme tombe à sec ou approche de l'expiration.
local warned = { mh = false, oh = false }

local function SlotLabel(key)
  return (key == "mh") and L.MAINHAND or L.OFFHAND
end

local function SlotIndex(key)
  return (key == "mh") and NS.SLOT_MAINHAND or NS.SLOT_OFFHAND
end

-- Les trois canaux d'avertissement de l'onglet Timer sont indépendants :
-- chat, cadre d'erreur rouge en haut de l'écran, et cadre d'aura.
function NS.Alert(message)
  local db = NS.DB()
  if db.warnChat then NS.Print(message) end
  if db.warnError and UIErrorsFrame then
    UIErrorsFrame:AddMessage(message, 1, 0.3, 0.3, 1, 5)
  end
  if db.warnAura and NS.ShowAura then NS.ShowAura(message) end
  if NS.FlashButton then NS.FlashButton() end
end

-- « Ignorer les avertissements lors de la pêche » : inutile de rappeler qu'un
-- poison expire quand on ne frappe rien.
-- GetItemInfo n'existe pas comme global sur ce client, et son nom de
-- sous-type dépend de la langue : on passe par la classification numérique.
-- Classe 2 = arme, sous-classe 20 = canne à pêche.
local WEAPON_CLASS, FISHING_POLE_SUBCLASS = 2, 20

local function Fishing()
  local mainHand = GetInventoryItemID and GetInventoryItemID("player", NS.SLOT_MAINHAND)
  if not mainHand then return false end
  if not (C_Item and C_Item.GetItemInfoInstant) then return false end

  local ok, _, _, _, _, _, classID, subclassID =
    pcall(C_Item.GetItemInfoInstant, mainHand)
  return ok and classID == WEAPON_CLASS and subclassID == FISHING_POLE_SUBCLASS
end

local function WarningsAllowed()
  local db = NS.DB()
  if not db.warnEnabled or not NS.IsEnabled() then return false end
  if db.ignoreFishing and Fishing() then return false end
  if db.warnInstanceOnly then
    local inInstance = IsInInstance and IsInInstance()
    if not inInstance then return false end
  end
  return true
end

function NS.CheckEnchants()
  local state = NS.WeaponEnchants()
  NS.enchantState = state

  if not WarningsAllowed() then return state end
  local db = NS.DB()
  local threshold = (db.warnMinutes or 2) * 60

  for _, key in ipairs({ "mh", "oh" }) do
    local watched = (key == "mh") and db.checkMainHand or db.checkOffHand
    local slot = state[key] or {}
    if not watched or not NS.HasWeapon(SlotIndex(key)) then
      warned[key] = false
    elseif not slot.active then
      if not warned[key] then
        NS.Alert(string.format(L.WARN_EXPIRED, SlotLabel(key)))
        warned[key] = true
      end
    elseif (slot.remaining or 0) <= threshold then
      if not warned[key] then
        NS.Alert(string.format(L.WARN_SOON, SlotLabel(key), NS.FormatTime(slot.remaining)))
        warned[key] = true
      end
    else
      warned[key] = false
    end
  end

  return state
end

-- =========================================================
-- ÉVÉNEMENTS
-- =========================================================
local core = CreateFrame("Frame", "PoisonUpForever_Core")

NS.RegisterEvents(core, {
  "PLAYER_LOGIN",
  "BAG_UPDATE_DELAYED",
  "UNIT_INVENTORY_CHANGED",
  "PLAYER_EQUIPMENT_CHANGED",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",
  "GET_ITEM_INFO_RECEIVED",
})

core:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" then
    -- Option « Masquer automatiquement lors de l'entrée en combat ».
    if NS.DB().hideInCombat and NS.CloseMenu then NS.CloseMenu() end
    if NS.MenuEnterCombat then NS.MenuEnterCombat() end
    -- État relu tout de suite : le carré doit apparaître dès l'engagement,
    -- sans attendre le prochain tic du minuteur.
    pcall(NS.CheckEnchants)
    if NS.UpdateIndicators then pcall(NS.UpdateIndicators) end
    return
  end
  if event == "PLAYER_REGEN_ENABLED" and NS.MenuLeaveCombat then
    NS.MenuLeaveCombat()
  end
  if event == "PLAYER_REGEN_ENABLED" and NS.buttonsPending and NS.UpdateButtons then
    pcall(NS.UpdateButtons)
  end
  if event == "PLAYER_REGEN_ENABLED" and NS.UpdateIndicators then
    pcall(NS.UpdateIndicators)
  end
  NS.dirty = true
  if event == "PLAYER_LOGIN" then
    if NS.Boot then NS.Boot() end
    return
  end
  -- PLAYER_REGEN_ENABLED compris : les attributs sécurisés n'ont pas pu être
  -- écrits pendant le combat, on rattrape le retard dès la sortie.
  if NS.RefreshSecureState then NS.RefreshSecureState() end
end)

-- Le temps restant n'émet aucun événement : il faut l'interroger. Une seconde
-- de période suffit largement et reste négligeable côté performances.
-- Chaque étape est protégée : une erreur dans l'une ne doit pas arrêter les
-- autres (les carrés restaient figés). L'erreur est signalée une seule fois.
local tickErrors = {}
local function SafeStep(name, fn)
  if type(fn) ~= "function" then return end
  local ok, err = pcall(fn)
  if not ok and not tickErrors[name] then
    tickErrors[name] = true
    NS.Print("|cffff4040erreur (" .. name .. ")|r : " .. tostring(err))
  end
end

C_Timer.NewTicker(1, function()
  SafeStep("enchantements", NS.CheckEnchants)
  SafeStep("minuteurs", NS.UpdateTimers)
  SafeStep("carrés d'arme", NS.UpdateIndicators)
end)
