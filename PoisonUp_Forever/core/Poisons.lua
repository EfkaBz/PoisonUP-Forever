-- Poisons.lua - PoisonUp (Forever) - par Daeler
-- Catalogue des consommables applicables sur une arme.
--
-- La version TBC choisissait sa table selon GetBuildInfo (Vanilla / TBC
-- / Cata). Ici on garde une seule liste volontairement large : le menu est
-- construit à partir du contenu réel des sacs, donc un identifiant absent du
-- client ou du contenu de Forever ne s'affiche tout simplement jamais. Cela
-- évite d'avoir à deviner le palier de contenu du serveur.
--
-- L'ordre des rangs va du plus faible au plus fort : le menu n'affiche par
-- défaut que le rang le plus élevé possédé, les autres sont repliés dessous.

-- Listes d'objets reprises de l'addon TBC de Karrion@Terenas, Silentdave
-- et humfras.

local ADDON_NAME, NS = ...

NS.CATEGORY_ORDER = {
  "IP", "DP", "WP", "CP", "MP", "AP", "OP", "NP", "TP", "SP", "SS", "WS", "OIL",
}

NS.CATEGORIES = {
  -- Poisons de dégâts
  IP = { kind = "poison", items = { 6947, 6949, 6950, 8926, 8927, 8928, 21927 } },
  DP = { kind = "poison", items = { 2892, 2893, 8984, 8985, 20844, 22053, 22054 } },
  WP = { kind = "poison", items = { 10918, 10920, 10921, 10922, 22055 } },

  -- Poisons utilitaires
  CP = { kind = "poison", items = { 3775, 3776 } },
  MP = { kind = "poison", items = { 5237, 6951, 9186 } },
  AP = { kind = "poison", items = { 21835 } },

  -- Poisons ajoutés par les saisons de contenu Classic récentes
  OP = { kind = "poison", items = { 226374, 234444 } },
  NP = { kind = "poison", items = { 217346 } },
  TP = { kind = "poison", items = { 217347 } },
  SP = { kind = "poison", items = { 217345 } },

  -- Pierres (option showStones)
  SS = { kind = "stone", items = { 2862, 2863, 2871, 7964, 12404, 23122, 23528, 23529, 237810, 238241 } },
  WS = { kind = "stone", items = { 3239, 3240, 3241, 7965, 12643, 18262, 28420, 28421 } },

  -- Huiles : absentes de la version TBC, ajoutées ici parce qu'elles
  -- s'appliquent exactement de la même manière et servent aux hybrides.
  OIL = { kind = "oil", items = { 3824, 3829, 20745, 20747, 20748, 20744, 20746, 20750, 20749 } },
}

-- Index inverse itemID -> { category, rank } construit une seule fois.
NS.ITEM_INDEX = {}
for category, data in pairs(NS.CATEGORIES) do
  for rank, itemID in ipairs(data.items) do
    NS.ITEM_INDEX[itemID] = { category = category, rank = rank, kind = data.kind }
  end
end

-- Une catégorie est-elle affichable compte tenu des options ?
function NS.CategoryVisible(category)
  local db = NS.DB()
  local kind = NS.CATEGORIES[category] and NS.CATEGORIES[category].kind
  if kind == "stone" then return db.showStones and true or false end
  if kind == "oil" then return db.showOils and true or false end
  return true
end

function NS.CategoryLabel(category)
  return NS.L["CAT_" .. category]
end

-- Ordre d'affichage des types dans le menu. Le joueur peut le réarranger avec
-- « Button Sorting » (onglet Menu) ; on complète toujours avec les types
-- absents de sa liste, pour qu'un ajout futur ne disparaisse pas.
function NS.OrderedCategories()
  local saved = NS.DB().categoryOrder
  if type(saved) ~= "table" then return NS.CATEGORY_ORDER end

  local ordered, seen = {}, {}
  for _, category in ipairs(saved) do
    if NS.CATEGORIES[category] and not seen[category] then
      ordered[#ordered + 1] = category
      seen[category] = true
    end
  end
  for _, category in ipairs(NS.CATEGORY_ORDER) do
    if not seen[category] then ordered[#ordered + 1] = category end
  end
  return ordered
end

-- Déplace un type d'un cran dans l'ordre d'affichage.
function NS.MoveCategory(category, delta)
  local ordered = NS.OrderedCategories()
  for index, name in ipairs(ordered) do
    if name == category then
      local target = index + delta
      if target < 1 or target > #ordered then return false end
      ordered[index], ordered[target] = ordered[target], ordered[index]
      NS.DB().categoryOrder = ordered
      return true
    end
  end
  return false
end
