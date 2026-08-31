extends Node3D

## Attaché à CameraPivot (enfant de Player). Gère TOUT ce qui concerne
## la caméra : rotation à la souris, capture/relâche du curseur,
## re-capture au retour du focus fenêtre.
##
## Isolé de Player.gd exprès : si un bug apparaît côté tir/rôles/réseau,
## il ne doit pas pouvoir interférer avec ce script.

const MOUSE_SENSITIVITY := 0.003
const PITCH_MIN := -1.3  # Limite pour regarder vers le haut.
const PITCH_MAX := 0.8   # Limite pour regarder vers le bas.

const THIRD_PERSON_DISTANCE := 4.0
const FPS_DISTANCE := 0.0  # Chercheur : caméra directement à hauteur des yeux.

const THIRD_PERSON_HEIGHT := 1.6  # Surélevée : vue de recul sur le personnage.
const FPS_EYE_HEIGHT := 1.5    # Proche du sommet de la capsule (haut ≈ 0.9).

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var is_owner := false  # Vrai uniquement pour le joueur contrôlé localement.


func _ready() -> void:
	is_owner = get_parent().is_multiplayer_authority()
	camera.current = is_owner
	print("[PlayerCamera] _ready pour le joueur %s — is_owner=%s" % [get_parent().name, is_owner])

	if not is_owner:
		return

	GameManager.round_started.connect(_on_round_started)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.role_assigned.connect(_on_role_assigned)


## Chercheur = FPS (visée précise, caméra à hauteur des yeux).
## Caché = 3e personne (pas besoin de viser, vue surélevée classique).
func _on_role_assigned(id: int, role: int) -> void:
	if id != int(get_parent().name):
		return
	if role == RoleTypes.Role.SEEKER:
		spring_arm.spring_length = FPS_DISTANCE
		position.y = FPS_EYE_HEIGHT
	else:
		spring_arm.spring_length = THIRD_PERSON_DISTANCE
		position.y = THIRD_PERSON_HEIGHT
	print("[PlayerCamera] rôle reçu=%s — hauteur=%.2f distance=%.1f" % [role, position.y, spring_arm.spring_length])


func _on_round_started() -> void:
	print("[PlayerCamera] round_started reçu — capture de la souris")
	spring_arm.rotation.x = 0.0  # Repart toujours à l'horizontale, sans inclinaison résiduelle.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_round_ended(_winner: String) -> void:
	print("[PlayerCamera] round_ended reçu — relâche de la souris")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Re-capture forcée quand la fenêtre regagne le focus OS (voir
## explication détaillée dans l'historique du projet : Godot ne
## re-capture pas tout seul après un alt-tab).
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_IN:
		return
	if is_owner and GameManager.state == GameManager.GameState.IN_PROGRESS:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not is_owner:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x - event.relative.y * MOUSE_SENSITIVITY,
			PITCH_MIN,
			PITCH_MAX
		)

	# Échap relâche la souris, un clic la recapture — mais seulement
	# pendant une manche (pas pendant le lobby, pour ne pas gêner les
	# clics sur les boutons d'UI).
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if GameManager.state == GameManager.GameState.IN_PROGRESS:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
