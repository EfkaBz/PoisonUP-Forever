-- Compat.lua - PoisonUp (Forever) - par Daeler
-- Couche de compatibilité pour World of Warcraft: Forever (interface 16001).
--
-- L'addon TBC d'origine visait Vanilla, TBC et Cataclysm : il s'appuyait
-- sur LibDBIcon, LibUIDropDownMenu et des templates XML SecureHandler. Forever tourne sur le moteur Retail (jeu d'API 12.x), où :
--
--   1. UIDropDownMenu et les anciens templates de menu n'existent plus (ils ont
--      été remplacés par l'API Menu). -> on dessine notre propre flyout.
--   2. Les fonctions de sacs sont passées dans C_Container ; GetContainerItemInfo
--      renvoie une table et non plus une liste de valeurs. -> NS.ScanBags()
--   3. UseContainerItem est protégée : appliquer un poison depuis du Lua lève
--      ADDON_ACTION_FORBIDDEN. Seul un bouton sécurisé le permet, et sur ce
--      client il doit être enregistré pour l'ENFONCEMENT du bouton de souris,
--      pas seulement pour le relâchement. -> voir NS.WireSlot dans Core.lua.
--   4. RegisterEvent sur un événement inconnu LÈVE UNE ERREUR (silencieux sur
--      BCC). -> NS.RegisterEvents()
--   5. Les SavedVariables peuvent arriver vides ou après l'exécution du Lua
--      (bug connu de la bêta). -> accesseur auto-réparant NS.DB()
--   6. GetAddOnMetadata global a disparu au profit de C_AddOns.

local ADDON_NAME, NS = ...

NS.ADDON_NAME = ADDON_NAME
NS.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata
  and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "1.0"

NS.ICON = "Interface\\Icons\\Ability_Poisons"
NS.STONE_ICON = "Interface\\Icons\\INV_Stone_SharpeningStone_01"

-- Guerrier : pas de poison, seulement pierres à aiguiser (et totem
-- Furie-des-vents). L'icône principale devient la pierre.
function NS.IsWarrior()
  local _, class = UnitClass("player")
  return class == "WARRIOR"
end
if NS.IsWarrior() then NS.ICON = NS.STONE_ICON end

-- Emplacements d'inventaire visés par les macros.
NS.SLOT_MAINHAND = 16
NS.SLOT_OFFHAND = 17

-- =========================================================
-- 1. BASE DE DONNÉES (SavedVariables)
-- =========================================================
PoisonUpDB_Forever = PoisonUpDB_Forever or {}

-- Les réglages reprennent ceux de la version TBC, onglet par onglet.
local DB_DEFAULTS = {
  -- --- Onglet Options ---------------------------------------------------
  enabled = nil,            -- nil = auto (activé pour les voleurs uniquement)
  showMinimapButton = false,
  showFreeButton = true,
  lockFreeButton = false,
  -- Position libre sur l'interface, comme le bouton libre de la version
  -- TBC, ancré à UIParent.
  anchor = nil,             -- { point, x, y } ; nil = centre de l'écran
  minimapAngle = 150,
  freeScale = 1.0,
  freeAlpha = 1.0,
  announceChat = true,      -- annoncer le poison choisi dans le chat
  menuOnHover = false,
  hideInCombat = false,

  -- --- Onglet Menu ------------------------------------------------------
  menuParent = "free",      -- "free" ou "minimap"
  menuScale = 1.0,
  menuPosition = "RIGHT",   -- une des huit positions autour du bouton
  menuSpacing = 0,          -- -20 à 20
  tooltipMode = "full",     -- "full" ou "name"
  overwritePresets = false,
  categoryOrder = nil,      -- ordre personnalisé des types (Button Sorting)

  -- --- Onglet Timer -----------------------------------------------------
  showTimer = true,
  warnMinutes = 2,          -- seuil d'avertissement, en minutes
  ignoreFishing = false,
  warnInstanceOnly = false,
  checkMainHand = true,
  checkOffHand = true,
  warnEnabled = true,
  warnChat = true,
  warnError = true,
  warnAura = true,
  auraLocked = true,
  auraAnchor = nil,
  auraScale = 0.7,
  auraAlpha = 1.0,
  -- Carrés d'arme : repère visuel quand une main manque de poison.
  showIndicators = true,
  indicatorsLocked = true,
  indicatorsAnchor = nil,
  indicatorSize = 48,
  indicatorFadeAlpha = 0.45,   -- opacité quand le poison va bientôt expirer
  indicatorsAlways = false,    -- carré « plus de poison » aussi hors combat
  showStoneIndicators = true,  -- deux carrés de plus pour pierre / huile
  showWindfuryIndicator = true, -- carré du totem Furie-des-vents (main droite)

  -- --- Onglet Sets de poison -------------------------------------------
  -- { mh = itemID, oh = itemID } pour chaque modificateur.
  presets = nil,
  showQuickButton = true,
  quickLocked = true,
  quickAnchor = nil,
  quickScale = 1.0,
  quickAlpha = 1.0,

  -- --- Divers -----------------------------------------------------------
  autoConfirm = true,       -- valider la popup d'écrasement automatiquement
  useItemName = true,       -- désigner l'objet par son nom plutôt que item:<id>
  showStones = true,        -- afficher pierres à aiguiser / gravier
  showOils = true,          -- afficher les huiles (ajout Forever)
  debug = false,
  welcomeShown = false,
}

-- Les huit positions du menu autour du bouton, comme la grille 3x3 de
-- l'onglet Menu. Pour chacune : le point du menu, le point du bouton, et le
-- décalage appliqué.
NS.MENU_POSITIONS = {
  TOPLEFT     = { "BOTTOMRIGHT", "TOPLEFT",     -2,  2 },
  TOP         = { "BOTTOM",      "TOP",          0,  2 },
  TOPRIGHT    = { "BOTTOMLEFT",  "TOPRIGHT",     2,  2 },
  LEFT        = { "RIGHT",       "LEFT",        -2,  0 },
  RIGHT       = { "LEFT",        "RIGHT",        2,  0 },
  BOTTOMLEFT  = { "TOPRIGHT",    "BOTTOMLEFT",  -2, -2 },
  BOTTOM      = { "TOP",         "BOTTOM",       0, -2 },
  BOTTOMRIGHT = { "TOPLEFT",     "BOTTOMRIGHT",  2, -2 },
}

-- Les quatre jeux de poisons du bouton rapide, dans l'ordre d'affichage.
NS.PRESET_KEYS = { "default", "shift", "ctrl", "alt" }

local function FillDefaults(target, defaults)
  for key, default in pairs(defaults) do
    if target[key] == nil then
      target[key] = default
    end
  end
  return target
end

-- Accesseur auto-réparant : garantit une table valide À CHAQUE appel plutôt
-- qu'une seule fois au chargement.
function NS.DB()
  if type(PoisonUpDB_Forever) ~= "table" then
    PoisonUpDB_Forever = {}
  end
  local db = FillDefaults(PoisonUpDB_Forever, DB_DEFAULTS)
  -- Réglages des versions de mise au point, devenus sans objet.
  db.applyMode, db.modeMigrated = nil, nil
  if type(db.presets) ~= "table" then db.presets = {} end
  for _, key in ipairs(NS.PRESET_KEYS) do
    if type(db.presets[key]) ~= "table" then db.presets[key] = {} end
  end
  return db
end

-- Le jeu de poisons d'un modificateur, toujours une table exploitable.
function NS.Preset(key)
  return NS.Presets()[key] or {}
end

-- Les jeux sont propres au personnage. Un voleur reprend au premier passage
-- les jeux de compte des versions précédentes ; un guerrier part de zéro.
function NS.Presets()
  if type(PoisonUpCharDB_Forever) ~= "table" then
    PoisonUpCharDB_Forever = {}
  end
  local char = PoisonUpCharDB_Forever
  if type(char.presets) ~= "table" then
    char.presets = {}
    local legacy = NS.DB().presets
    local _, class = UnitClass("player")
    if class == "ROGUE" and type(legacy) == "table" then
      for key, set in pairs(legacy) do
        if type(set) == "table" then
          char.presets[key] = { mh = set.mh, oh = set.oh }
        end
      end
    end
  end
  for _, key in ipairs(NS.PRESET_KEYS) do
    if type(char.presets[key]) ~= "table" then char.presets[key] = {} end
  end
  return char.presets
end

-- =========================================================
-- 2. ENREGISTREMENT D'ÉVÉNEMENTS TOLÉRANT
-- =========================================================
function NS.RegisterEvents(frame, events)
  local rejected
  for _, event in ipairs(events) do
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then
      rejected = rejected or {}
      rejected[#rejected + 1] = event
    end
  end
  return rejected
end

-- =========================================================
-- 3. SACS (C_Container)
-- =========================================================
local Container = C_Container

local function NumBagSlots()
  return NUM_BAG_SLOTS or 4
end

-- Renvoie une table { [itemID] = quantité } de tout ce que le joueur porte.
-- On passe par les sacs et non par GetItemCount pour n'afficher que ce que le
-- joueur a réellement sur lui (et non en banque), comme la version TBC.
-- Renvoie aussi l'emplacement (sac, case) de la première pile trouvée.
function NS.ScanBags()
  local counts, where = {}, {}
  if not Container then return counts, where end
  for bag = 0, NumBagSlots() do
    local slots = Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local info = Container.GetContainerItemInfo(bag, slot)
      local itemID = info and info.itemID
      if itemID then
        counts[itemID] = (counts[itemID] or 0) + (info.stackCount or 1)
        if not where[itemID] then
          where[itemID] = { bag = bag, slot = slot }
        end
      end
    end
  end
  return counts, where
end

-- =========================================================
-- 4. ENCHANTEMENTS D'ARME
-- =========================================================
-- GetWeaponEnchantInfo renvoie des durées en millisecondes. On normalise en
-- secondes et on protège l'appel : sur Forever la signature a gagné des valeurs
-- de retour supplémentaires selon les builds.
-- Deux signatures existent selon le client, et il faut deviner laquelle :
--
--   Classic (6 valeurs) : hasMH, mhExp, mhCharges, hasOH, ohExp, ohCharges
--   Retail  (8 valeurs) : hasMH, mhExp, mhCharges, mhID, hasOH, ohExp,
--                         ohCharges, ohID
--
-- La différence est l'identifiant d'enchantement glissé en 4e position. Se
-- tromper décale tout ce qui concerne la main gauche : on lisait l'expiration
-- à la place du drapeau de présence, d'où une main gauche annoncée sans poison
-- alors qu'elle en avait. On repère donc la signature au type des valeurs :
-- le drapeau est un booléen, l'identifiant un nombre.
-- Sur ce client, GetWeaponEnchantInfo répond systématiquement « aucun
-- enchantement » même lorsqu'un poison de vingt minutes est actif. L'infobulle
-- de l'emplacement d'arme, elle, affiche bien la ligne d'enchantement avec son
-- temps restant : c'est notre seule source fiable.
--
-- Le format est « Poison instantané (19 min) », quelle que soit la langue pour
-- la partie entre parenthèses. On ne cherche donc que la durée.
-- Sur Forever, poison et pierre (ou huile) se cumulent : l'infobulle peut
-- porter deux lignes minutées. On les trie : une ligne qui reprend le nom d'un
-- poison connu est le poison, toute autre ligne minutée est la pierre/huile.
local poisonNames

local function PoisonNames()
  if poisonNames and #poisonNames > 0 then return poisonNames end
  poisonNames = {}
  local getName = C_Item and C_Item.GetItemNameByID
  if not getName then return poisonNames end
  local seen = {}
  for _, data in pairs(NS.CATEGORIES) do
    if data.kind == "poison" then
      for _, itemID in ipairs(data.items) do
        local ok, name = pcall(getName, itemID)
        if ok and type(name) == "string" then
          -- On retire le rang en chiffres romains : l'enchantement n'en a pas
          -- toujours.
          local base = name:gsub("%s+[IVX]+$", ""):lower()
          if base ~= "" and not seen[base] then
            seen[base] = true
            poisonNames[#poisonNames + 1] = base
          end
        end
      end
    end
  end
  return poisonNames
end

local function IsPoisonLine(text)
  local lower = text:lower()
  for _, base in ipairs(PoisonNames()) do
    if lower:find(base, 1, true) then return true end
  end
  -- Repli tant que les noms d'objets ne sont pas en cache.
  return lower:find("poison", 1, true) or lower:find("gift", 1, true)
    or lower:find("veneno", 1, true) or false
end

-- Le totem Furie-des-vents pose lui aussi un enchantement minuté sur l'arme.
local function IsWindfuryLine(text)
  local lower = text:lower()
  return lower:find("windfury", 1, true) or lower:find("furie-des-vents", 1, true)
    or lower:find("windzorn", 1, true) or lower:find("viento furioso", 1, true)
    or false
end

-- La durée est lue quelle que soit la langue : « (30 min) », « (30 Min.) »
-- en allemand, « (30 мин.) », « (30분) », « (30分钟) »... Seule l'unité
-- compte : minutes, heures ou secondes ; le reste est ignoré. Avant, seul « min » en
-- minuscules était reconnu : sur les autres langues aucune ligne n'était
-- trouvée, poison comme pierre, et les carrés restaient rouges.
local SECOND_UNITS = { "s", "с", "초", "秒" }
local HOUR_UNITS = { "h", "std", "ч", "시간", "小时", "小時" }
local MINUTE_UNITS = { "m", "м", "분", "分" }

local function StartsWithAny(unit, list)
  for _, prefix in ipairs(list) do
    if unit:sub(1, #prefix) == prefix then return true end
  end
  return false
end

local function LineDuration(text)
  local number, unit
  for n, u in text:gmatch("%((%d+)%s*([^%d%(%)]-)%)") do
    number, unit = n, u
  end
  if not number or not unit or unit == "" then return nil end
  unit = unit:lower():gsub("^%s+", "")
  number = tonumber(number)
  -- Les minutes d'abord : « мин » commence par « м », pas par « с ».
  if StartsWithAny(unit, MINUTE_UNITS) then return number * 60 end
  if StartsWithAny(unit, HOUR_UNITS) then return number * 3600 end
  if StartsWithAny(unit, SECOND_UNITS) then return number end
  -- Tout autre texte entre parenthèses (« (3 charges) »...) n'est pas une durée.
  return nil
end

-- Renvoie { poison = {remaining, label} ou nil, stone = {remaining, label} ou nil }.
local function EnchantsFromTooltip(slot)
  local found = {}
  if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return found end

  local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
  if not ok or type(data) ~= "table" then return found end
  if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, data) end

  for _, line in ipairs(data.lines or {}) do
    if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
    local text = line.leftText
    if type(text) == "string" then
      local remaining = LineDuration(text)
      if remaining then
        local key = (IsWindfuryLine(text) and "windfury")
          or (IsPoisonLine(text) and "poison") or "stone"
        if not found[key] then
          found[key] = { remaining = remaining, label = text }
        end
      end
    end
  end
  return found
end

function NS.WeaponEnchants()
  local results = { pcall(GetWeaponEnchantInfo) }
  if not results[1] then
    results = {}
  else
    table.remove(results, 1)   -- le drapeau de pcall
  end

  local offset = 4           -- position du drapeau de main gauche
  if type(results[5]) == "boolean" then
    offset = 5               -- signature Retail
  elseif type(results[4]) == "boolean" then
    offset = 4               -- signature Classic
  elseif type(results[4]) == "number" then
    offset = 5               -- 4e valeur numérique : c'est un identifiant
  end

  local function Slot(flagIndex, inventorySlot)
    local slot = {
      active = results[flagIndex] and true or false,
      remaining = (tonumber(results[flagIndex + 1]) or 0) / 1000,
      charges = results[flagIndex + 2],
    }
    local tooltip = EnchantsFromTooltip(inventorySlot)
    -- Repli sur l'infobulle quand la fonction ne rapporte rien, ce qui est le
    -- cas permanent sur ce client.
    -- L'API ne dit pas QUEL enchantement est posé : une pierre seule la fait
    -- répondre « actif ». Dès que l'infobulle trie quelque chose, elle a
    -- donc le dernier mot sur le poison.
    if tooltip.poison or tooltip.stone or tooltip.windfury then
      slot.fromTooltip = true
      if tooltip.poison then
        slot.active, slot.remaining, slot.label = true, tooltip.poison.remaining, tooltip.poison.label
      else
        slot.active, slot.remaining, slot.label = false, 0, nil
      end
    end
    -- La pierre / l'huile, suivie à part puisqu'elle se cumule au poison.
    slot.stone = tooltip.stone and {
      active = true, remaining = tooltip.stone.remaining, label = tooltip.stone.label,
    } or { active = false }
    slot.windfury = tooltip.windfury and {
      active = true, remaining = tooltip.windfury.remaining, label = tooltip.windfury.label,
    } or { active = false }
    return slot
  end

  return { mh = Slot(1, NS.SLOT_MAINHAND), oh = Slot(offset, NS.SLOT_OFFHAND) }
end

function NS.HasWeapon(slot)
  local id = GetInventoryItemID and GetInventoryItemID("player", slot)
  return id ~= nil
end

-- Nom de l'objet équipé dans un emplacement, ou nil. Un poison appliqué sur un
-- emplacement vide ne produit aucune action ET aucun message d'erreur : c'est
-- la première chose à vérifier quand « il ne se passe rien ».
function NS.EquippedName(slot)
  local id = GetInventoryItemID and GetInventoryItemID("player", slot)
  if not id then return nil end
  local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
  if link then return link end
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  return name or ("item:" .. id)
end

-- =========================================================
-- 5. DIVERS
-- =========================================================
function NS.Atan2(y, x)
  if atan2 then return atan2(y, x) end
  return math.atan(y, x)
end

function NS.Print(msg)
  print("|cff1eff00PoisonUp|r: " .. tostring(msg))
end

-- Trace activable par /poisonup debug : sert à voir si le clic arrive bien sur
-- le bouton sécurisé et quelle macro il exécute.
function NS.Debug(msg)
  if not NS.DB().debug then return end
  print("|cff888888PoisonUp|r |cffffd100debug|r: " .. tostring(msg))
end

function NS.FormatTime(seconds)
  seconds = math.floor(seconds or 0)
  if seconds <= 0 then return "--" end
  if seconds >= 3600 then
    return math.floor(seconds / 3600) .. "h"
  elseif seconds >= 60 then
    return math.floor(seconds / 60) .. "m"
  end
  return seconds .. "s"
end

local lastFired = {}
function NS.Throttle(key, cooldown)
  local now = GetTime()
  if lastFired[key] and (now - lastFired[key]) < (cooldown or 1) then
    return true
  end
  lastFired[key] = now
  return false
end

-- Le joueur est-il censé voir l'addon ? Activé d'office pour les voleurs,
-- désactivé sinon, exactement comme la version TBC — mais l'option
-- explicite de la base prime sur ce défaut.
function NS.IsEnabled()
  local db = NS.DB()
  if db.enabled ~= nil then return db.enabled end
  local _, class = UnitClass("player")
  return class == "ROGUE" or class == "WARRIOR"
end
