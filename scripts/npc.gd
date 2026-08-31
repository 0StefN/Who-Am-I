extends CharacterBody3D

## PNJ basique, contrôlé exclusivement par le serveur — sa position est
## répliquée aux clients via MultiplayerSynchronizer, comme les joueurs.
##
## Le comportement (idle, patrouille, etc.) est entièrement délégué à un
## NPCState actif (voir scripts/npc/npc_state.gd pour l'API à étendre).
## Ce script ne fait que : exécuter l'état courant, appliquer la
## gravité, et exposer move_toward_point() comme utilitaire partagé.

const SPEED := 2.5

@onready var mesh_pivot: Node3D = $MeshPivot

var current_state: NPCState = null


func _ready() -> void:
	add_to_group("npc")
	set_multiplayer_authority(1)  # Toujours contrôlé par le serveur.
	change_state(IdleState.new())


## Point d'extension principal : change de comportement à tout moment,
## depuis n'importe quel état, sans rien connaître des autres états.
func change_state(new_state: NPCState) -> void:
	if current_state:
		current_state.exit(self)
	current_state = new_state
	if current_state:
		current_state.enter(self)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	if GameManager.state == GameManager.GameState.IN_PROGRESS and current_state:
		current_state.physics_update(self, delta)
	else:
		velocity.x = 0
		velocity.z = 0

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	move_and_slide()


## Utilitaire partagé par les états : avance vers un point (au sol, la
## hauteur du point est ignorée) et fait face à la direction de
## déplacement. Retourne true une fois arrivé à destination.
func move_toward_point(target: Vector3, _delta: float) -> bool:
	var flat_target := Vector3(target.x, global_position.y, target.z)
	var to_target := flat_target - global_position
	var distance := to_target.length()

	if distance < 0.2:
		velocity.x = 0
		velocity.z = 0
		return true

	var direction := to_target.normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	mesh_pivot.rotation.y = atan2(direction.x, direction.z)
	return false
