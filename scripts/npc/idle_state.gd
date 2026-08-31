class_name IdleState
extends NPCState

## Le PNJ reste immobile. Comportement par défaut le plus simple,
## et brique de base pour des états plus élaborés plus tard (ex : idle
## qui regarde autour de lui de temps en temps).

func physics_update(npc: CharacterBody3D, _delta: float) -> void:
	npc.velocity.x = 0
	npc.velocity.z = 0
