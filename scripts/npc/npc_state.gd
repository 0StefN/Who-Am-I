class_name NPCState
extends Resource

## Classe de base pour un comportement de PNJ.
##
## Pour ajouter un nouveau comportement (PNJ qui sursaute, qui suit un
## joueur suspect, qui imite un mouvement vu récemment, etc.) : crée une
## classe qui hérite de celle-ci et implémente les méthodes voulues, puis
## assigne une instance via npc.change_state(MonNouvelEtat.new(...)).
## Aucun changement nécessaire ailleurs dans le code.

## Appelé une fois à l'entrée dans cet état.
func enter(_npc: CharacterBody3D) -> void:
	pass

## Appelé à chaque physics frame tant que cet état est actif.
func physics_update(_npc: CharacterBody3D, _delta: float) -> void:
	pass

## Appelé une fois en sortant de cet état.
func exit(_npc: CharacterBody3D) -> void:
	pass
