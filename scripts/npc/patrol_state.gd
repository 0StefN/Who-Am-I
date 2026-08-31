class_name PatrolState
extends NPCState

## Fait patrouiller le PNJ entre une liste de points, en boucle.
## Déplacement en ligne droite (pas de pathfinding) — suffisant tant que
## la map est un simple blockout sans obstacle. À remplacer par un
## NavigationAgent3D quand la vraie map (avec navmesh bâké dans
## l'éditeur) sera en place.
##
## À chaque point atteint, le PNJ tire au sort s'il fait le trajet suivant
## en marchant ou en courant. C'est volontaire : les joueurs disposent d'un
## sprint, donc si les PNJ marchaient toujours, tout joueur qui court se
## trahirait immédiatement.

var waypoints: Array[Vector3] = []

## Probabilité (0 à 1) de faire le trajet suivant en courant.
var proba_course := 0.25

var _current_index := 0


func _init(points: Array[Vector3] = [], probabilite_course := 0.25) -> void:
	waypoints = points
	proba_course = probabilite_course


func enter(npc: CharacterBody3D) -> void:
	_current_index = 0
	_choisir_allure(npc)


## Marche ou course pour le trajet à venir.
func _choisir_allure(npc: CharacterBody3D) -> void:
	if randf() < proba_course:
		npc.vitesse_actuelle = MovementConfig.SPRINT_SPEED
	else:
		npc.vitesse_actuelle = MovementConfig.WALK_SPEED


func physics_update(npc: CharacterBody3D, delta: float) -> void:
	if waypoints.is_empty():
		return
	var arrived: bool = npc.move_toward_point(waypoints[_current_index], delta)
	if arrived:
		_current_index = (_current_index + 1) % waypoints.size()
		_choisir_allure(npc)
