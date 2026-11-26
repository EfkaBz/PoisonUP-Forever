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

-- Seul le voleur pose des poisons. Les autres classes (guerrier, lanceurs de
-- sorts avec huiles de sorcier / de mana) n'ont que pierres et huiles.
function NS.UsesPoisons()
  local _, class = UnitClass("player")
  return class == "ROGUE"
end

-- Ce que l'addon surveille sur une main : le poison pour un voleur, la
-- pierre / l'huile pour les autres classes (minuteur du bouton, alertes).
function NS.TrackedEnchant(slotState)
  slotState = slotState or {}
  if NS.UsesPoisons() then return slotState end
  return slotState.stone or { active = false }
end

-- Icône des classes à huiles : celle de l'Huile de sorcier brillante.
NS.OIL_ITEM = 20749

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
  menuVertical = false,     -- icônes empilées verticalement
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
  indicatorShowCharges = true, -- nombre de charges dans le coin du carré
  indicatorWarnCharges = 10,   -- seuil de charges qui estompe le carré (0 = jamais)
  language = nil,             -- nil : langue du client
  indicatorsBounce = true,     -- les carrés rebondissent quand le poison va expirer
  indicatorsOutOfCombat = false, -- carrés « plus de poison / pierre » aussi hors combat
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
local poisonNames, poisonNamesAt

-- Appelée sur GET_ITEM_INFO_RECEIVED d'un de nos objets : un nom vient
-- d'arriver, la liste sera refaite au prochain besoin.
function NS.ResetPoisonNames() poisonNames = nil end

local function PoisonNames()
  -- Liste vide (noms pas encore en cache) : on ne la refait qu'une fois toutes
  -- les 30 s au plus. Avant, chaque ligne minutée de chaque infobulle relançait
  -- une demande de nom pour tout le catalogue, à chaque seconde.
  local now = GetTime and GetTime() or 0
  if poisonNames and (#poisonNames > 0 or now - (poisonNamesAt or 0) < 30) then
    return poisonNames
  end
  poisonNamesAt = now
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
  -- Tirets et espaces confondus : « Furie-des-vents », « Furie des vents »...
  local flat = lower:gsub("[%-%s]+", " ")
  return flat:find("windfury", 1, true) or flat:find("furie des vents", 1, true)
    or flat:find("windzorn", 1, true) or flat:find("viento furioso", 1, true)
    or flat:find("furia del vento", 1, true) or flat:find("fúria dos ventos", 1, true)
    or flat:find("неистовства ветра", 1, true)
    or false
end

-- Identifiants d'enchantement Furie-des-vents (totem 563/564/1783/2638/2639,
-- arme 283/284/525/1669/2636/3785-3787) : repli quand l'infobulle ne le
-- nomme pas.
local WINDFURY_ENCHANTS = {
  [563] = true, [564] = true, [1783] = true, [2638] = true, [2639] = true,
  [283] = true, [284] = true, [525] = true, [1669] = true, [2636] = true,
  [3785] = true, [3786] = true, [3787] = true,
}
NS.WINDFURY_ENCHANTS = WINDFURY_ENCHANTS

-- Sur Forever, le totem Furie-des-vents n'est plus un enchantement d'arme de
-- quelques secondes : c'est un buff de raid posé sur le joueur. Et les auras
-- y sont « secrètes » : impossible de parcourir les buffs et de lire leur nom
-- ou leur icône. Seule voie, celle de ForeverAuras : demander chaque ID de
-- sort connu avec C_UnitAuras.GetUnitAuraBySpellID.
-- Relevé en jeu : Forever pose « Totem Furie-des-vents » sous l'ID 10612.
local WINDFURY_AURAS = {
  8512, 8515, 8516, 10608, 10609, 10610, 10612, 10613, 10614, 27621, 78159,
}
-- Noms du buff dans la langue du client, tirés des sorts : repli quand
-- l'identifiant posé par Forever n'est dans aucune liste.
local WINDFURY_NAME_SPELLS = { 8512, 8232 }
NS.WINDFURY_AURAS = WINDFURY_AURAS

local function Secret(value)
  return issecretvalue and issecretvalue(value) or false
end

-- Dernière réponse lisible : quand les auras deviennent secrètes (en combat),
-- l'état connu juste avant est gardé, minuteur compris.
local lastWindfury, lastWindfuryAt

local function AurasSecret()
  if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
  local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
  return ok and not Secret(secret) and secret and true or false
end

-- Renvoie { remaining (nil si sans durée), label } ou nil.
local function WindfuryAura()
  if not (C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID) then return nil end
  local now = GetTime and GetTime() or 0
  local unreadable = false
  for _, spellID in ipairs(WINDFURY_AURAS) do
    local ok, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, "player", spellID)
    if not ok then
      -- Appel refusé (auras verrouillées en combat) : illisible, pas absent.
      unreadable = true
    elseif aura ~= nil then
      if Secret(aura) then
        -- Secrète (en combat) mais renvoyée : le buff EST là, seuls son nom
        -- et sa durée sont cachés. Avant, c'était pris pour « illisible » et
        -- le carré restait rouge jusqu'à la fin du combat.
        lastWindfury, lastWindfuryAt = { label = "Windfury (buff " .. spellID .. ")" }, now
        return lastWindfury
      else
        local expiration = aura.expirationTime
        local remaining
        if not Secret(expiration) and type(expiration) == "number" and expiration > 0 then
          remaining = math.max(0, expiration - now)
        end
        local name = aura.name
        local label = ((not Secret(name) and type(name) == "string") and name or "Windfury")
          .. " (buff " .. spellID .. ")"
        lastWindfury, lastWindfuryAt = { remaining = remaining, label = label }, now
        return lastWindfury
      end
    end
  end
  -- Aucun identifiant connu : recherche par nom (« Totem Furie-des-vents »,
  -- « Arme Furie-des-vents »...), quel que soit l'identifiant réel.
  if C_UnitAuras.GetAuraDataBySpellName and C_Spell and C_Spell.GetSpellName then
    for _, nameSpell in ipairs(WINDFURY_NAME_SPELLS) do
      local okName, name = pcall(C_Spell.GetSpellName, nameSpell)
      if okName and type(name) == "string" and not Secret(name) then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if not ok then
          unreadable = true
        elseif aura ~= nil then
          if Secret(aura) then
            lastWindfury, lastWindfuryAt = { label = name }, now
            return lastWindfury
          else
            local expiration = aura.expirationTime
            local remaining
            if not Secret(expiration) and type(expiration) == "number" and expiration > 0 then
              remaining = math.max(0, expiration - now)
            end
            local id = aura.spellId
            lastWindfury, lastWindfuryAt = {
              remaining = remaining,
              label = name .. " (buff " .. ((not Secret(id) and tostring(id)) or "?") .. ")",
            }, now
            return lastWindfury
          end
        end
      end
    end
  end
  -- Rien de lisible alors que les auras sont secrètes : on garde l'état
  -- d'avant, tant que son minuteur (s'il en a un) n'est pas écoulé.
  if (unreadable or AurasSecret()) and lastWindfury then
    local copy = { label = lastWindfury.label .. " (mémorisé)" }
    if lastWindfury.remaining then
      copy.remaining = lastWindfury.remaining - (now - lastWindfuryAt)
      if copy.remaining <= 0 then return nil end
    end
    return copy
  end
  -- Auras secrètes (combat) et rien en mémoire : le jeu répond « absent »
  -- même quand le buff est là. L'état est inconnu, pas absent : second
  -- retour à true, le carré reste neutre au lieu de clignoter en rouge.
  if unreadable or AurasSecret() then return nil, true end
  lastWindfury = nil
  return nil
end
NS.WindfuryAura = WindfuryAura

-- Diagnostic : réponse brute de chaque ID, et si les auras sont secrètes.
function NS.WindfuryProbe()
  local probe = { time = date and date("%H:%M:%S") or "", ids = {} }
  local ok, secret = pcall(function() return C_Secrets and C_Secrets.ShouldAurasBeSecret() end)
  probe.aurasSecret = ok and (Secret(secret) and "secret" or tostring(secret)) or "erreur"
  probe.cache = lastWindfury and tostring(lastWindfury.label) or "aucun"
  for _, spellID in ipairs(WINDFURY_AURAS) do
    local okCall, aura = pcall(C_UnitAuras.GetUnitAuraBySpellID, "player", spellID)
    local text
    if not okCall then text = "erreur: " .. tostring(aura)
    elseif aura == nil then text = nil
    elseif Secret(aura) then text = "secret"
    else
      text = "présent | nom=" .. (Secret(aura.name) and "secret" or tostring(aura.name))
        .. " | exp=" .. (Secret(aura.expirationTime) and "secret" or tostring(aura.expirationTime))
    end
    if text then probe.ids[#probe.ids + 1] = spellID .. " : " .. text end
  end
  return probe
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

-- Lit une ligne d'enchantement : sa durée et, quand le jeu l'affiche, ses
-- charges. « Poison instantané (29 min) (115 charges) » : chaque parenthèse
-- est examinée, la première durée trouvée est gardée (avant, seule la
-- dernière parenthèse comptait, et une ligne finissant par ses charges
-- n'était plus reconnue du tout). Toute parenthèse « nombre + mot » qui n'est
-- pas une durée est prise pour des charges, quelle que soit la langue
-- (« charges », « Aufladungen », « cargas », « заряда »...).
-- Le texte brut de l'infobulle garde les codes d'affichage : couleurs, et
-- surtout la grammaire « |4Charge:Charges; » que le chat résout à l'écran.
-- Le « 4 » de ce code se faisait lire comme un nombre de charges, et cassait
-- la parenthèse « (85 |4Charge:Charges;) ». On ne garde que le texte affiché.
local function PlainText(text)
  return (text:gsub("|4[^:;]*:([^;]*);", "%1")
    :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function LineDuration(text)
  text = PlainText(text)
  local duration, charges
  for n, u in text:gmatch("%((%d+)%s*([^%d%(%)]-)%)") do
    local number = tonumber(n)
    local unit = u:lower():gsub("^%s+", "")
    local seconds
    if unit ~= "" then
      -- Les minutes d'abord : « мин » commence par « м », pas par « с ».
      if StartsWithAny(unit, MINUTE_UNITS) then seconds = number * 60
      elseif StartsWithAny(unit, HOUR_UNITS) then seconds = number * 3600
      elseif StartsWithAny(unit, SECOND_UNITS) then seconds = number
      end
    end
    if seconds then
      duration = duration or seconds
    elseif unit ~= "" and not charges then
      charges = number
    end
  end
  return duration, charges
end

-- Le mot « charge » dans la langue du client, tiré de ITEM_SPELL_CHARGES
-- (« %d |4Charge:Charges; », « %d |4заряд:заряда:зарядов; »...) : la
-- première forme sert de racine, contenue dans toutes les autres.
local chargeWord
local function ChargeWord()
  if chargeWord then return chargeWord end
  local text = type(ITEM_SPELL_CHARGES) == "string" and ITEM_SPELL_CHARGES or ""
  text = text:gsub("|4([^:;]+)[^;]*;", "%1"):gsub("%%d", ""):gsub("[%(%)]", "")
  text = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
  chargeWord = (text ~= "") and text or "charge"
  return chargeWord
end

-- Ligne de charges à part (« 85 Charges ») : le nombre, ou nil.
local function ChargesLine(text)
  local lower = PlainText(text):lower()
  local word = ChargeWord()
  if not (lower:find(word, 1, true) or lower:find("charge", 1, true)) then return nil end
  return tonumber(lower:match("(%d+)"))
end

-- Renvoie { poison = {remaining, charges, label} ou nil, stone = {...} ou nil }.
-- apiRemaining : durée (s) que GetWeaponEnchantInfo donne pour cette main, ou
-- nil. Elle sert à départager plusieurs lignes prises pour du poison.
local function EnchantsFromTooltip(slot, apiRemaining)
  local found = {}
  if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return found end

  local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
  if not ok or type(data) ~= "table" then return found end
  if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, data) end

  -- Toutes les lignes minutées d'abord, le tri ensuite. Avant, la première
  -- ligne prise pour du poison l'emportait : avec deux enchantements minutés
  -- sur la même arme, le carré et le bouton affichaient celui de l'autre
  -- enchantement (3 min / 10 charges au lieu de 27 min).
  local timed, last = {}, nil
  for _, line in ipairs(data.lines or {}) do
    if TooltipUtil and TooltipUtil.SurfaceArgs then pcall(TooltipUtil.SurfaceArgs, line) end
    local text = line.leftText
    if type(text) == "string" then
      local remaining, charges = LineDuration(text)
      if remaining then
        local entry = {
          remaining = remaining, charges = charges, label = text,
          kind = (IsWindfuryLine(text) and "windfury")
            or (IsPoisonLine(text) and "poison") or "stone",
        }
        timed[#timed + 1] = entry
        last = entry
      else
        -- Les charges peuvent suivre sur leur propre ligne, juste sous
        -- l'enchantement : elles lui reviennent. Plus bas, ce n'est plus lui.
        if last and not last.charges then last.charges = ChargesLine(text) end
        last = nil
      end
    end
  end

  local poisons = {}
  for _, entry in ipairs(timed) do
    if entry.kind == "windfury" and not found.windfury then
      found.windfury = entry
    elseif entry.kind == "poison" then
      poisons[#poisons + 1] = entry
    end
  end

  -- Plusieurs lignes « poison » : celle dont la durée colle le mieux à celle
  -- de l'API est le vrai poison de cette main.
  local chosen = poisons[1]
  if #poisons > 1 and apiRemaining and apiRemaining > 0 then
    local best
    for _, entry in ipairs(poisons) do
      local gap = math.abs(entry.remaining - apiRemaining)
      if not best or gap < best then best, chosen = gap, entry end
    end
  end
  found.poison = chosen

  -- La pierre / l'huile : une ligne reconnue comme telle. Les autres lignes
  -- « poison » écartées sont ignorées : ce sont des enchantements temporaires
  -- étrangers à l'addon (ex. le bonus d'arme du donjon de la Terrasse du
  -- Façonneur, 3 min / 10 charges), ni poison ni pierre.
  for _, entry in ipairs(timed) do
    if entry.kind == "stone" then found.stone = entry; break end
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
    }
    local tooltip = EnchantsFromTooltip(inventorySlot,
      slot.active and slot.remaining > 0 and slot.remaining or nil)
    -- Repli sur l'infobulle quand la fonction ne rapporte rien, ce qui est le
    -- cas permanent sur ce client.
    -- L'API ne dit pas QUEL enchantement est posé : une pierre seule la fait
    -- répondre « actif ». Dès que l'infobulle trie quelque chose, elle a
    -- donc le dernier mot sur le poison.
    if tooltip.poison or tooltip.stone or tooltip.windfury then
      slot.fromTooltip = true
      if tooltip.poison then
        slot.active, slot.remaining, slot.label = true, tooltip.poison.remaining, tooltip.poison.label
        -- Charges : l'infobulle seulement. Celles de l'API sont fausses sur
        -- ce client (4 annoncées pour 85 réelles), comme le reste de ses
        -- réponses.
        slot.charges = tooltip.poison.charges
      else
        slot.active, slot.remaining, slot.label, slot.charges = false, 0, nil, nil
      end
    end
    -- La pierre / l'huile, suivie à part puisqu'elle se cumule au poison.
    slot.stone = tooltip.stone and {
      active = true, remaining = tooltip.stone.remaining,
      charges = tooltip.stone.charges, label = tooltip.stone.label,
    } or { active = false }
    -- Furie-des-vents (main droite) : le buff de raid de Forever d'abord,
    -- puis l'ancien enchantement d'arme (infobulle, identifiant de l'API).
    local wf, wfUnknown
    -- Les auras ne sont interrogées que si le carré Furie-des-vents est
    -- activé : onze requêtes par seconde sinon, pour un carré invisible.
    if inventorySlot == NS.SLOT_MAINHAND then
      if NS.DB().showWindfuryIndicator then wf, wfUnknown = WindfuryAura() end
      wf = wf or tooltip.windfury
      if not wf then
        local enchantID = (offset == 5) and tonumber(results[4]) or nil
        if enchantID and WINDFURY_ENCHANTS[enchantID] and results[1] then
          wf = { remaining = (tonumber(results[2]) or 0) / 1000, label = "enchant " .. enchantID }
        end
      end
    end
    slot.windfury = wf and {
      active = true, remaining = wf.remaining, label = wf.label,
    } or { active = false, unknown = wfUnknown or nil }
    return slot
  end

  return { mh = Slot(1, NS.SLOT_MAINHAND), oh = Slot(offset, NS.SLOT_OFFHAND) }
end

-- Une ARME, pas seulement un objet : un bouclier ou un objet tenu en main
-- gauche (classe « armure ») ne prend ni poison ni pierre, il ne doit donc
-- déclencher ni avertissement ni carré. Classe 2 = arme.
local WEAPON_CLASS = 2
function NS.HasWeapon(slot)
  local id = GetInventoryItemID and GetInventoryItemID("player", slot)
  if not id then return false end
  if not (C_Item and C_Item.GetItemInfoInstant) then return true end
  local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, id)
  if not ok or classID == nil then return true end
  return classID == WEAPON_CLASS
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
  if class == "ROGUE" or class == "WARRIOR" then return true end
  -- Autres classes : actif dès qu'une huile ou une pierre est dans les sacs.
  return NS.Inventory and #NS.Inventory() > 0 or false
end
