-- Locale.lua - PoisonUp (Forever) - par Daeler
-- Deux langues seulement : français (par défaut du client visé) et anglais en
-- repli. Les noms d'objets ne sont jamais traduits ici : ils viennent du client
-- via les itemID, ce qui évite toute la table de traduction de l'addon TBC.

local ADDON_NAME, NS = ...

local enUS = {
  TITLE                = "PoisonUp (Forever)",
  MAINHAND             = "Main hand",
  OFFHAND              = "Off hand",
  EMPTY                = "Nothing usable in your bags.",
  NO_WEAPON            = "Nothing equipped in %s: there is nothing to poison.",
  APPLIED              = "%s applied to %s.",

  CAT_DP               = "Deadly Poison",
  CAT_IP               = "Instant Poison",
  CAT_WP               = "Wound Poison",
  CAT_CP               = "Crippling Poison",
  CAT_MP               = "Mind-numbing Poison",
  CAT_AP               = "Anesthetic Poison",
  CAT_OP               = "Occult Poison",
  CAT_NP               = "Numbing Poison",
  CAT_TP               = "Atrophic Poison",
  CAT_SP               = "Sebacious Poison",
  CAT_SS               = "Sharpening Stones",
  CAT_WS               = "Weightstones",
  CAT_OIL              = "Oils",

  TT_LEFT              = "Left click: open the poison bar",
  TT_RIGHT             = "Right click: options",
  TT_DRAG              = "Drag: move the button",
  TT_LOCKED            = "Position locked (/poisonup unlock)",
  TT_APPLY_MH          = "Left click: apply to main hand",
  TT_APPLY_OH          = "Right click: apply to off hand",
  TT_FAVOURITE         = "Shift + click: save into the Default set",

  QUICK_TITLE          = "Poison sets",
  QUICK_EMPTY          = "No set defined yet.",

  WARN_EXPIRED         = "%s has no poison left!",
  WARN_SOON            = "%s poison expires in %s.",
  AURA_HINT            = "Drag to move - lock it again in the Timer tab",
  AURA_SAMPLE          = "Main hand poison expiring",

  COMBAT_LATER         = "Menu locked in combat, it will refresh afterwards.",
  WELCOME              = "loaded. /poisonup for the options.",
  ENABLED              = "enabled.",
  DISABLED             = "disabled.",
  RESET                = "frames reset.",
  SAVED                = "settings saved.",
  PRESET_SET           = "%s set: %s",
  PRESETS_CLEARED      = "all poison sets cleared.",

  SAVE                 = "Save",
  CLOSE                = "Close",
  TAB_OPTIONS          = "Options",
  TAB_MENU             = "Menu",
  TAB_TIMER            = "Timer",
  TAB_PRESETS          = "Poison sets",

  OPT_ENABLE           = "Enable PoisonUp",
  OPT_BUTTONS          = "Buttons:",
  OPT_MINIMAP          = "Show the PoisonUp button on the minimap",
  OPT_FREE             = "Show the free button",
  OPT_RESET_POS        = "Reset position",
  OPT_LOCK_FREE        = "Lock the free button",
  OPT_SCALE            = "Scale",
  OPT_ALPHA            = "Alpha",
  OPT_ANNOUNCE         = "Announce the chosen poison in chat",
  OPT_HOVER_SECTION    = "Menu on hover:",
  OPT_HOVER            = "Show the bar when the mouse passes over the button",
  OPT_AUTOHIDE_SECTION = "Auto hide:",
  OPT_AUTOHIDE         = "Hide the bar automatically when entering combat",

  MENU_PARENT          = "Parent frame of the poison bar:",
  MENU_PARENT_FREE     = "Free button",
  MENU_PARENT_MINIMAP  = "Minimap button",
  MENU_POSITION        = "Bar position:",
  POS_TOPLEFT          = "Top left",
  POS_TOP              = "Top",
  POS_TOPRIGHT         = "Top right",
  POS_LEFT             = "Left",
  POS_RIGHT            = "Right",
  POS_BOTTOMLEFT       = "Bottom left",
  POS_BOTTOM           = "Bottom",
  POS_BOTTOMRIGHT      = "Bottom right",
  MENU_SPACING         = "Spacing between buttons",
  MENU_TOOLTIP         = "Tooltip:",
  MENU_TOOLTIP_FULL    = "Full",
  MENU_TOOLTIP_NAME    = "Name only",
  MENU_QUICK_SECTION   = "Poison bar versus the quick button:",
  MENU_OVERWRITE       = "Overwrite the saved sets",
  MENU_OVERWRITE_NOTE  = "When ticked, applying a poison from the bar also replaces the matching entry of the Default set.",
  MENU_SORTING         = "Button Sorting",
  SORTING_HINT         = "Order of the poison types in the bar.",

  TIMER_SHOW           = "Show the remaining time of expiring poisons",
  TIMER_THRESHOLD      = "Warning threshold (minutes)",
  TIMER_FISHING        = "Ignore warnings while fishing",
  TIMER_INSTANCE       = "Warn only inside an instance, arena or battleground",
  TIMER_WEAPONS        = "Weapons to check:",
  TIMER_CHANNELS       = "Show poison time warnings through:",
  TIMER_ENABLED        = "Warnings enabled",
  TIMER_CHAT           = "Chat",
  TIMER_ERROR          = "Error frame",
  TIMER_AURA           = "Aura frame",
  TIMER_AURA_LOCK      = "Lock the aura frame",
  IND_SECTION          = "Weapon squares:",
  IND_SHOW             = "Show a square per weapon that needs poison",
  IND_STONES           = "Also show squares for stones / oils",
  IND_ALWAYS           = "Always show the squares (in and out of combat)",
  IND_WINDFURY         = "Show a Windfury Totem square (shaman in party)",
  IND_LOCK             = "Lock the squares",
  IND_SIZE             = "Square size",
  IND_FADE             = "Opacity when the poison is about to expire",
  IND_HINT             = "Drag to move - lock them again in the Options tab",

  PRESET_DEFAULT       = "Default",
  PRESET_SHIFT         = "SHIFT",
  PRESET_CTRL          = "CTRL",
  PRESET_ALT           = "ALT key",
  PRESET_SHOW_QUICK    = "Show the quick button",
  PRESET_LOCK_QUICK    = "Lock the quick button",
}

local frFR = {
  TITLE                = "PoisonUp (Forever)",
  MAINHAND             = "Main droite",
  OFFHAND              = "Main gauche",
  EMPTY                = "Rien d'utilisable dans vos sacs.",
  NO_WEAPON            = "Aucune arme en %s : il n'y a rien à empoisonner.",
  APPLIED              = "%s appliqué en %s.",

  CAT_DP               = "Poison mortel",
  CAT_IP               = "Poison instantané",
  CAT_WP               = "Poison de blessure",
  CAT_CP               = "Poison paralysant",
  CAT_MP               = "Poison hébétant",
  CAT_AP               = "Poison anesthésiant",
  CAT_OP               = "Poison occulte",
  CAT_NP               = "Poison engourdissant",
  CAT_TP               = "Poison atrophiant",
  CAT_SP               = "Poison sébacé",
  CAT_SS               = "Pierres à aiguiser",
  CAT_WS               = "Pierres de gravier",
  CAT_OIL              = "Huiles",

  TT_LEFT              = "Clic gauche : ouvrir la barre de poisons",
  TT_RIGHT             = "Clic droit : options",
  TT_DRAG              = "Glisser : déplacer le bouton",
  TT_LOCKED            = "Position verrouillée (/poisonup unlock)",
  TT_APPLY_MH          = "Clic gauche : appliquer en main droite",
  TT_APPLY_OH          = "Clic droit : appliquer en main gauche",
  TT_FAVOURITE         = "Maj + clic : enregistrer dans le set Défaut",

  QUICK_TITLE          = "Sets de poison",
  QUICK_EMPTY          = "Aucun set défini.",

  WARN_EXPIRED         = "%s n'a plus de poison !",
  WARN_SOON            = "Le poison de %s expire dans %s.",
  AURA_HINT            = "Glissez pour déplacer - reverrouillez dans l'onglet Timer",
  AURA_SAMPLE          = "Poison de main droite bientôt expiré",

  COMBAT_LATER         = "Barre figée en combat, elle se mettra à jour ensuite.",
  WELCOME              = "chargé. /poisonup pour les options.",
  ENABLED              = "activé.",
  DISABLED             = "désactivé.",
  RESET                = "cadres réinitialisés.",
  SAVED                = "réglages enregistrés.",
  PRESET_SET           = "set %s : %s",
  PRESETS_CLEARED      = "tous les sets de poison ont été effacés.",

  SAVE                 = "Sauvegarder",
  CLOSE                = "Fermer",
  TAB_OPTIONS          = "Options",
  TAB_MENU             = "Menu",
  TAB_TIMER            = "Timer",
  TAB_PRESETS          = "Sets de poison",

  OPT_ENABLE           = "Activer PoisonUp",
  OPT_BUTTONS          = "Boutons :",
  OPT_MINIMAP          = "Afficher le bouton PoisonUp sur la mini-carte",
  OPT_FREE             = "Afficher le bouton libre",
  OPT_RESET_POS        = "Réinitialiser la position",
  OPT_LOCK_FREE        = "Bloquer le bouton libre",
  OPT_SCALE            = "Échelle",
  OPT_ALPHA            = "Alpha",
  OPT_ANNOUNCE         = "Afficher les poisons choisis sur le chat",
  OPT_HOVER_SECTION    = "Menu après survol (bouton libre) :",
  OPT_HOVER            = "Afficher le menu lorsque l'on passe la souris dessus",
  OPT_AUTOHIDE_SECTION = "Masquer automatiquement :",
  OPT_AUTOHIDE         = "Masquer le menu automatiquement lors de l'entrée en combat",

  MENU_PARENT          = "Cadre parent du menu des poisons :",
  MENU_PARENT_FREE     = "Bouton libre",
  MENU_PARENT_MINIMAP  = "Bouton sur la mini-carte",
  MENU_POSITION        = "Position du menu :",
  POS_TOPLEFT          = "En haut à gauche",
  POS_TOP              = "En haut",
  POS_TOPRIGHT         = "En haut à droite",
  POS_LEFT             = "Gauche",
  POS_RIGHT            = "Droite",
  POS_BOTTOMLEFT       = "En bas à gauche",
  POS_BOTTOM           = "En bas",
  POS_BOTTOMRIGHT      = "En bas à droite",
  MENU_SPACING         = "Espacement entre les boutons",
  MENU_TOOLTIP         = "Bulle d'aide :",
  MENU_TOOLTIP_FULL    = "Entière",
  MENU_TOOLTIP_NAME    = "Nom uniquement",
  MENU_QUICK_SECTION   = "Barre de poisons face au bouton rapide :",
  MENU_OVERWRITE       = "Écraser les sets préétablis",
  MENU_OVERWRITE_NOTE  = "Si coché, appliquer un poison depuis le menu remplace aussi l'entrée correspondante du set Défaut.",
  MENU_SORTING         = "Button Sorting",
  SORTING_HINT         = "Ordre des types de poison dans la barre.",

  TIMER_SHOW           = "Afficher le temps restant pour les poisons expirants",
  TIMER_THRESHOLD      = "Seuil d'avertissement (minutes)",
  TIMER_FISHING        = "Ignorer les avertissements lors de la pêche",
  TIMER_INSTANCE       = "Avertir seulement en instance, arène ou champ de bataille",
  TIMER_WEAPONS        = "Armes à vérifier :",
  TIMER_CHANNELS       = "Afficher un avertissement du temps des poisons via :",
  TIMER_ENABLED        = "Avertissements activés",
  TIMER_CHAT           = "Discussion",
  TIMER_ERROR          = "Frame d'erreur",
  TIMER_AURA           = "Aura",
  TIMER_AURA_LOCK      = "Bloquer la frame d'aura",
  IND_SECTION          = "Carrés d'arme :",
  IND_SHOW             = "Afficher un carré par arme à réempoisonner",
  IND_STONES           = "Afficher aussi les carrés pierres / huiles",
  IND_ALWAYS           = "Toujours afficher les carrés (en combat et hors combat)",
  IND_WINDFURY         = "Afficher un carré Totem Furie-des-vents (shaman groupé)",
  IND_LOCK             = "Bloquer les carrés",
  IND_SIZE             = "Taille des carrés",
  IND_FADE             = "Opacité quand le poison va bientôt expirer",
  IND_HINT             = "Glissez pour déplacer - reverrouillez dans l'onglet Options",

  PRESET_DEFAULT       = "Défaut",
  PRESET_SHIFT         = "MAJ",
  PRESET_CTRL          = "CTRL",
  PRESET_ALT           = "Touche ALT",
  PRESET_SHOW_QUICK    = "Afficher le bouton rapide",
  PRESET_LOCK_QUICK    = "Bloquer le bouton rapide",
}

local L = setmetatable({}, { __index = function(_, key) return key end })
for key, value in pairs(enUS) do L[key] = value end
if GetLocale() == "frFR" then
  for key, value in pairs(frFR) do L[key] = value end
end

-- Guerrier : pas de poison, les jeux deviennent des jeux de pierres.
local _, playerClass = UnitClass("player")
if playerClass == "WARRIOR" then
  if GetLocale() == "frFR" then
    L.TAB_PRESETS     = "Sets de pierre"
    L.QUICK_TITLE     = "Sets de pierre"
    L.PRESETS_CLEARED = "tous les sets de pierre ont été effacés."
  else
    L.TAB_PRESETS     = "Stone sets"
    L.QUICK_TITLE     = "Stone sets"
    L.PRESETS_CLEARED = "all stone sets cleared."
  end
end

NS.L = L
