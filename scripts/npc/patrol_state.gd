class_name PatrolState
extends NPCState

## Fait patrouiller le PNJ entre une liste de points, en boucle.
## Déplacement en ligne droite (pas de pathfinding) — suffisant tant que
## la map est un simple blockout sans obstacle. À remplacer par un
## NavigationAgent3D quand la vraie map (avec navmesh bâké dans
## l'éditeur) sera en place.

var waypoints: Array[Vector3] = []
var _current_index := 0


func _init(points: Array[Vector3] = []) -> void:
	waypoints = points


func enter(_npc: CharacterBody3D) -> void:
	_current_index = 0


func physics_update(npc: CharacterBody3D, delta: float) -> void:
	if waypoints.is_empty():
		return
	var arrived: bool = npc.move_toward_point(waypoints[_current_index], delta)
	if arrived:
		_current_index = (_current_index + 1) % waypoints.size()
