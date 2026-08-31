extends CharacterBody3D

## Mouvement, rôle et tir. La caméra (rotation souris, capture) vit
## désormais dans scripts/PlayerCamera.gd, attaché au nœud CameraPivot —
## voir ce script pour tout ce qui concerne la vue.
##
## is_multiplayer_authority() garantit que seul le client propriétaire
## de ce joueur traite ses propres inputs — les autres le voient juste
## bouger via le MultiplayerSynchronizer.

const JUMP_VELOCITY := 4.5

## Vitesses et vitesse de rotation viennent de MovementConfig, partagé avec
## les PNJ : c'est ce qui garantit qu'un joueur caché bouge exactement comme
## un PNJ. Ne jamais redéfinir ces valeurs ici.

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var mesh_pivot: Node3D = $MeshPivot
@onready var modele: Node3D = $MeshPivot/Modele

var role: int = RoleTypes.Role.NONE
var is_spectating := false
var spectate_target: Node3D = null

# Répliquées par le MultiplayerSynchronizer : on synchronise la VITESSE,
# pas le nom de l'animation. Chaque client en déduit localement quoi jouer,
# ce qui est plus léger et plus robuste qu'envoyer des chaînes sur le réseau.
var vitesse_reseau := 0.0
var au_sol_reseau := true


func _ready() -> void:
	add_to_group("player")
	GameManager.role_assigned.connect(_on_role_assigned)
	GameManager.seeker_died.connect(_on_seeker_died)


func _on_role_assigned(id: int, assigned_role: int) -> void:
	if id != int(name):
		return
	role = assigned_role

	# En vue FPS, la caméra est dans la tête du modèle : on verrait
	# l'intérieur du maillage. On le masque donc pour son seul porteur.
	# Les autres joueurs continuent de le voir normalement, puisque cette
	# visibilité n'est modifiée que localement.
	if is_multiplayer_authority() and modele:
		modele.definir_visibilite_locale(role != RoleTypes.Role.SEEKER)


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
		if collider.is_in_group("player"):
			target_id = int(collider.name)
		elif collider.is_in_group("npc"):
			hit_npc = true

	# Rien touché : pas la peine de déranger le serveur.
	if target_id == -1 and not hit_npc:
		return

	GameManager.request_shoot.rpc_id(1, target_id, hit_npc)


func _process(_delta: float) -> void:
	if not Network.is_active():
		return

	# L'animation est mise à jour pour TOUS les joueurs, y compris ceux
	# contrôlés à distance : c'est ce qui les fait bouger correctement à
	# l'écran des autres. Le joueur local calcule sa vitesse réelle, les
	# autres utilisent celle reçue par le MultiplayerSynchronizer.
	if modele:
		if is_multiplayer_authority():
			vitesse_reseau = Vector2(velocity.x, velocity.z).length()
			au_sol_reseau = is_on_floor()
		modele.mettre_a_jour(vitesse_reseau, au_sol_reseau)

	if not is_multiplayer_authority():
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

	var vitesse := MovementConfig.SPRINT_SPEED if Input.is_action_pressed("sprint") \
		else MovementConfig.WALK_SPEED

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	# Le déplacement est relatif à l'orientation de la caméra, pas du corps.
	var direction := camera_pivot.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0
	direction = direction.normalized()

	if role == RoleTypes.Role.SEEKER:
		# Chercheur en vue FPS : son corps doit regarder là où il VISE, pas
		# là où il se déplace. Sans ça, les autres le voient orienté
		# différemment de sa ligne de tir (il peut viser de côté tout en
		# ayant le corps de face). On calcule l'angle depuis la caméra, avec
		# la même convention que pour le déplacement.
		var avant_camera := -camera_pivot.global_transform.basis.z
		mesh_pivot.rotation.y = atan2(avant_camera.x, avant_camera.z)
		if direction.length() > 0.01:
			velocity.x = direction.x * vitesse
			velocity.z = direction.z * vitesse
		else:
			velocity.x = move_toward(velocity.x, 0, vitesse)
			velocity.z = move_toward(velocity.z, 0, vitesse)
	elif direction.length() > 0.01:
		velocity.x = direction.x * vitesse
		velocity.z = direction.z * vitesse
		var angle_cible := atan2(direction.x, direction.z)
		mesh_pivot.rotation.y = lerp_angle(
			mesh_pivot.rotation.y, angle_cible,
			minf(1.0, MovementConfig.ROTATION_SPEED * delta))
	else:
		velocity.x = move_toward(velocity.x, 0, vitesse)
		velocity.z = move_toward(velocity.z, 0, vitesse)

	move_and_slide()
