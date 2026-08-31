class_name MovementConfig

## Constantes de mouvement PARTAGÉES entre les joueurs et les PNJ.
##
## ⚠️ POURQUOI CE FICHIER EXISTE
## Dans un jeu de déguisement, la moindre différence de mouvement entre un
## joueur caché et un PNJ le trahit instantanément : vitesse, vitesse de
## virage, seuil de passage marche/course. Si ces valeurs vivaient en double
## dans Player.gd et npc.gd, une modification d'un seul côté créerait un
## écart invisible dans le code mais évident à l'écran.
##
## Tout ce qui influe sur l'apparence du mouvement va ICI, jamais ailleurs.

## Vitesse de déplacement normale, identique pour tous.
const WALK_SPEED := 3.0

## Vitesse en sprint, identique pour tous. Les PNJ courent aussi par
## moments (voir PatrolState) : sans ça, un joueur qui sprinte serait
## immédiatement repérable.
const SPRINT_SPEED := 6.0

## Vitesse d'alignement du corps vers la direction de déplacement.
## Plus la valeur est basse, plus les virages sont larges.
const ROTATION_SPEED := 8.0

## En dessous : animation d'attente. Au-dessus : marche.
const SEUIL_MARCHE := 0.2

## Seuil de passage marche -> course, à mi-chemin entre les deux vitesses.
## Calculé plutôt qu'écrit en dur : impossible de le désaccorder en
## changeant WALK_SPEED ou SPRINT_SPEED.
const SEUIL_COURSE := (WALK_SPEED + SPRINT_SPEED) / 2.0
