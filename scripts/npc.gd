extends CharacterBody3D

## PNJ basique, contrôlé exclusivement par le serveur — sa position est
## répliquée aux clients via MultiplayerSynchronizer, comme les joueurs.
##
## Le comportement (idle, patrouille, etc.) est entièrement délégué à un
## NPCState actif (voir scripts/npc/npc_state.gd pour l'API à étendre).
## Ce script ne fait que : exécuter l'état courant, appliquer la
## gravité, et exposer move_toward_point() comme utilitaire partagé.

## Vitesses et vitesse de rotation viennent de MovementConfig, partagé avec
## les joueurs : c'est ce qui garantit qu'un PNJ et un joueur caché bougent
## exactement pareil. Ne jamais redéfinir ces valeurs ici.

@onready var mesh_pivot: Node3D = $MeshPivot
@onready var modele: Node3D = $MeshPivot/Modele

var current_state: NPCState = null

## Vitesse de déplacement courante. Les états peuvent la changer pour faire
## marcher ou courir le PNJ (voir PatrolState). Les joueurs disposent du
## même choix via la touche sprint : un PNJ qui court ne doit pas être
## discernable d'un joueur qui sprinte.
var vitesse_actuelle := MovementConfig.WALK_SPEED

# Répliquée par le MultiplayerSynchronizer : le serveur calcule la vitesse,
# les clients s'en servent pour choisir l'animation localement.
var vitesse_reseau := 0.0


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


func _process(_delta: float) -> void:
	# Tourne sur tous les clients : chacun choisit l'animation localement
	# à partir de la vitesse répliquée par le serveur.
	if modele:
		modele.mettre_a_jour(vitesse_reseau, true)


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

	vitesse_reseau = Vector2(velocity.x, velocity.z).length()


## Utilitaire partagé par les états : avance vers un point (au sol, la
## hauteur du point est ignorée) et fait face à la direction de
## déplacement. Retourne true une fois arrivé à destination.
func move_toward_point(target: Vector3, delta: float) -> bool:
	var flat_target := Vector3(target.x, global_position.y, target.z)
	var to_target := flat_target - global_position
	var distance := to_target.length()

	if distance < 0.2:
		velocity.x = 0
		velocity.z = 0
		return true

	var direction := to_target.normalized()
	velocity.x = direction.x * vitesse_actuelle
	velocity.z = direction.z * vitesse_actuelle

	# Virage progressif plutôt qu'un demi-tour instantané.
	var angle_cible := atan2(direction.x, direction.z)
	mesh_pivot.rotation.y = lerp_angle(
		mesh_pivot.rotation.y, angle_cible, minf(1.0, MovementConfig.ROTATION_SPEED * delta))
	return false
