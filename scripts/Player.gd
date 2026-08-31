extends CharacterBody3D

## Mouvement, rôle et tir. La caméra (rotation souris, capture) vit
## désormais dans scripts/PlayerCamera.gd, attaché au nœud CameraPivot —
## voir ce script pour tout ce qui concerne la vue.
##
## is_multiplayer_authority() garantit que seul le client propriétaire
## de ce joueur traite ses propres inputs — les autres le voient juste
## bouger via le MultiplayerSynchronizer.

const SPEED := 5.0
const JUMP_VELOCITY := 4.5

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var mesh_pivot: Node3D = $MeshPivot

var role: int = RoleTypes.Role.NONE
var is_spectating := false
var spectate_target: Node3D = null


func _ready() -> void:
	add_to_group("player")
	GameManager.role_assigned.connect(_on_role_assigned)
	GameManager.seeker_died.connect(_on_seeker_died)


func _on_role_assigned(id: int, assigned_role: int) -> void:
	if id != int(name):
		return
	role = assigned_role


func _on_seeker_died(id: int) -> void:
	if id != int(name) or not is_multiplayer_authority():
		return
	# Ce chercheur n'a plus de vies : il passe en spectateur des autres
	# chercheurs encore en vie. Son corps reste figé là où il est mort —
	# on ne déplace que la caméra, localement, pour ne rien perturber
	# côté réseau.
	is_spectating = true
	set_physics_process(false)
	_update_spectate_target()


func _update_spectate_target() -> void:
	spectate_target = null
	for other_id in GameManager.alive_seekers:
		var other_player := get_parent().get_node_or_null(str(other_id))
		if other_player:
			spectate_target = other_player
			return


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event.is_action_pressed("shoot") and role == RoleTypes.Role.SEEKER and not is_spectating:
		_shoot()


func _shoot() -> void:
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_transform.origin
	var to := from - camera.global_transform.basis.z * GameManager.SHOOT_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]  # Array[RID], pas Array[Node] — corrigé.
	var result := space_state.intersect_ray(query)

	var target_id := -1
	var hit_npc := false

	if result:
		var collider = result.collider
		print("[Shoot] Touché : %s (groupes : %s) — distance=%.1fm — pitch caméra=%.1f°" % [
			collider.name, collider.get_groups(), from.distance_to(result.position),
			rad_to_deg(camera.global_transform.basis.get_euler().x)
		])
		if collider.is_in_group("player"):
			target_id = int(collider.name)
		elif collider.is_in_group("npc"):
			hit_npc = true
	else:
		print("[Shoot] Rien touché (le rayon n'a rien croisé) — pitch caméra=%.1f°" % rad_to_deg(camera.global_transform.basis.get_euler().x))

	# Rien touché : pas la peine de déranger le serveur.
	if target_id == -1 and not hit_npc:
		return

	GameManager.request_shoot.rpc_id(1, target_id, hit_npc)


func _process(_delta: float) -> void:
	if not Network.is_active() or not is_multiplayer_authority():
		return
	if is_spectating:
		if not spectate_target:
			_update_spectate_target()
		if spectate_target:
			camera_pivot.global_position = spectate_target.global_position + Vector3(0, 1.6, 0)


func _physics_process(delta: float) -> void:
	if not Network.is_active() or not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# Le déplacement est relatif à l'orientation de la caméra, pas du corps.
	var direction := camera_pivot.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0
	direction = direction.normalized()

	if direction.length() > 0.01:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		mesh_pivot.rotation.y = atan2(direction.x, direction.z)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
