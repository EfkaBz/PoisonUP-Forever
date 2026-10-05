# PoisonUp (Forever)

Applique poisons, pierres et huiles sur vos armes en un clic, et vous prévient
quand il faut remettre ça.

Écrit par **Daeler** pour **World of Warcraft: Forever** (interface 16001).

## Utilisation

### La barre de poisons

**Clic gauche** sur le bouton flottant : la barre sort du bouton, une icône par
type de poison possédé — le meilleur rang, avec la quantité dans le coin.

- **Clic gauche** sur une icône : applique en **main droite**
- **Clic droit** sur une icône : applique en **main gauche**
- **Maj + clic** : enregistre le poison dans le set **Défaut** au lieu de
  l'appliquer

Seul ce que vous avez réellement dans vos sacs apparaît.

### Le bouton flottant

- **Clic gauche** : ouvre la barre
- **Clic droit** : ouvre les options
- **Glisser** : le déplace où vous voulez (verrouillable)

Un second bouton peut être accroché à la mini-carte ; l'onglet Menu décide
duquel la barre sort.

### Le bouton rapide

Applique **les deux mains d'un coup**, selon le modificateur tenu : Défaut,
MAJ, CTRL ou ALT. Les quatre jeux se règlent dans l'onglet « Sets de poison ».
Il n'apparaît qu'une fois au moins un set défini.

### Les carrés d'arme

Un carré par main, qui n'apparaît que lorsqu'il y a quelque chose à faire :

| État de l'arme | Carré |
| --- | --- |
| plus de poison | opaque, bordure rouge |
| poison sous le seuil d'alerte | estompé, bordure orangée, temps restant affiché |
| poison au large | masqué |

L'addon est actif d'office pour les voleurs et masqué pour les autres classes ;
`/poisonup on` force l'affichage.

## Options

Quatre onglets, comme l'original.

**Options** — activer l'addon · bouton mini-carte · bouton libre et sa
réinitialisation · verrouillage · échelle · transparence · carrés d'arme
(affichage, verrouillage, taille, opacité de l'estompage) · annonce du poison
dans le chat · ouverture de la barre au survol · masquage automatique en
combat.

**Menu** — cadre parent de la barre · échelle · les huit positions autour du
bouton · espacement entre les icônes · bulle d'aide entière ou nom seul ·
écrasement des sets préétablis · **Button Sorting** pour réordonner les types
de poison.

**Timer** — temps restant · seuil d'avertissement en minutes · ignorer pendant
la pêche · avertir seulement en instance · armes à vérifier · et trois canaux
d'alerte indépendants : chat, cadre d'erreur, cadre d'aura (déplaçable, avec
échelle et transparence).

**Sets de poison** — les quatre jeux Défaut / MAJ / CTRL / ALT, une liste
déroulante par main, et les réglages du bouton rapide.

## Commandes

```
/poisonup              ouvre les options   (alias : /pup)
/poisonup on | off     active ou désactive l'addon
/poisonup lock|unlock  verrouille le bouton libre
/poisonup reset        replace tous les cadres au centre de l'écran
/poisonup sets         affiche les jeux de poisons
/poisonup clearsets    efface tous les jeux
/poisonup status       état du câblage et de la détection (diagnostic)
/poisonup debug        trace les clics dans le chat
```

## Ce qui change par rapport à la version TBC

Le principe est identique — bouton libre, barre de poisons, clic gauche = main
droite, clic droit = main gauche, sets par modificateur — l'implémentation est
entièrement neuve :

| TBC | Forever |
| --- | --- |
| LibStub + LibDBIcon + LibUIDropDownMenu + SimpleSticky | aucune bibliothèque, tout est natif |
| templates de fenêtre de Blizzard | fenêtre dessinée à la main, insensible aux renommages du moteur |
| minuteurs dans une fenêtre séparée | temps restant sur le bouton, et carrés d'arme |
| confirmation d'écrasement à valider à la main | `/click StaticPopup1Button1` intégré à la macro (option) |
| — | huiles de sorcier / de mana en plus des poisons et des pierres |
| 7 traductions partielles | français et anglais, noms d'objets fournis par le client |

## Notes techniques

Trois particularités de ce client ont coûté cher à trouver. Elles sont notées
ici pour qui porterait un autre addon.

### Les boutons sécurisés agissent à l'enfoncement

Un bouton enregistré avec `RegisterForClicks("AnyUp")` reçoit bien le clic —
`PreClick`, `OnClick` et `PostClick` partent tous — mais le gestionnaire
sécurisé ressort à sa première ligne, sans même lire son attribut `type`, **et
sans aucun message d'erreur**.

Le symptôme est un clic parfaitement silencieux, identique quel que soit le
mécanisme : macro ou action native, bouton créé par `CreateFrame` ou déclaré en
XML, attributs suffixés par bouton ou non, avec ou sans `PreClick`. Tout échoue
de la même façon tant que `"AnyDown"` n'est pas enregistré :

```lua
button:RegisterForClicks("AnyDown", "AnyUp")
```

Les deux phases sont transmises ; le gestionnaire de Blizzard n'exécute
l'action que pour celle qu'il attend, donc pas de double application. Les
`PostClick` de l'addon ignorent l'enfoncement pour ne pas partir deux fois.

### GetWeaponEnchantInfo ne rapporte rien

Elle existe, mais répond toujours « aucun enchantement », même avec un poison
de trente minutes sur l'arme. L'addon lit donc l'**infobulle de l'emplacement
d'arme** (`C_TooltipInfo.GetInventoryItem`), dont la ligne d'enchantement donne
le nom du poison et son temps restant : `Instant Poison (30 min) (60 Charges)`.
La précision tombe à la minute, ce qui suffit pour les minuteurs, les
avertissements et les carrés d'arme.

`GetWeaponEnchantInfo` reste essayée en premier : si une mise à jour la répare,
elle reprend la main automatiquement, sans changement de code.

### Fonctions absentes ou déplacées

- `RunMacroText` et `UseItemByName` **n'existent pas** ; les macros passent par
  `C_Macro.RunMacroText`.
- `GetItemInfo` n'existe pas comme global : `C_Item.GetItemNameByID`,
  `C_Item.GetItemIconByID` et `C_Item.GetItemInfoInstant` le remplacent.
- `SetBackdrop` n'existe que sur les cadres héritant de `BackdropTemplate` ;
  un `CreateFrame("Frame")` ordinaire se retrouve transparent en silence.
- `RegisterForDrag(nil)` lève une erreur : pour retirer le glisser, il faut
  appeler la fonction **sans argument**.
- Appliquer un poison depuis du Lua lève `ADDON_ACTION_FORBIDDEN`, et `pcall`
  ne l'intercepte pas — le blocage est côté C.

### Rien ne fonctionne en combat

Blizzard interdit à un addon de modifier un attribut sécurisé ou d'afficher un
cadre protégé pendant un combat. La version TBC contournait la règle avec des
*snippets* `SecureHandler`, un petit code exécuté dans l'environnement
restreint du jeu, qui en a le droit.

**Cette voie est fermée sur ce client** : il ne sait pas compiler les snippets.
`loadstring_untainted` vaut `nil` dans `RestrictedExecution`, et le premier
clic lève une erreur sans jamais exécuter le code. Il n'existe donc aucun
mécanisme autorisé, et la barre reste inutilisable une fois le combat engagé.

La barre est malgré tout construite d'avance et reconstruite à chaque
changement de sacs. C'est sans effet aujourd'hui, mais elle sera prête le jour
où le client saura exécuter un snippet : il n'y aura qu'à reposer l'attribut
`_onclick` sur le bouton.

Pour la même raison, l'option « masquer automatiquement lors de l'entrée en
combat » ne peut pas s'appliquer : à l'instant où l'événement arrive, le
verrou est déjà posé.

## Structure

```
PoisonUp_Forever.toc
data/     README.md         cette documentation
          poisonup_icon.tga icône de la liste des addons
locale/   Locale.lua        textes français / anglais
core/     Compat.lua        compatibilité du client : sacs, événements,
                            enchantements d'arme, réglages sauvegardés
          Poisons.lua       catalogue des poisons, pierres et huiles
          Core.lua          modèle d'inventaire, câblage des boutons,
                            surveillance des poisons posés
ui/       Widgets.lua       cases, curseurs, listes et onglets dessinés à la main
          Frames.xml        déclaration des boutons sécurisés
          Menu.lua          la barre de poisons
          Button.lua        bouton libre et bouton de mini-carte
          Quick.lua         bouton rapide et jeux par modificateur
          Aura.lua          cadre d'avertissement déplaçable
          Indicators.lua    carrés d'arme
          Options.lua       fenêtre à onglets et commandes /poisonup
```

Deux contraintes d'ordre de chargement, notées dans le `.toc` : `Locale.lua`
passe en premier car plusieurs fichiers capturent `NS.L` dès leur chargement,
et `Frames.xml` avant le Lua qui habille ses boutons.

## Origine

PoisonUp reprend le principe de **Poisoner**, l'addon de Burning Crusade de
Karrion@Terenas, Silentdave et humfras, dont le code a servi de point de
depart. Tout a ete reecrit pour le client Forever.
