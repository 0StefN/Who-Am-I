extends Node3D

## Scène principale : gère 3 états d'UI (Menu -> Lobby -> HUD de manche),
## et spawn/despawn les joueurs pour tout le monde quand quelqu'un se
## connecte ou se déconnecte.

enum UIState { MENU, LOBBY, IN_GAME }

@export var player_scene: PackedScene

@onready var host_button: Button = $UI/MenuPanel/HostButton
@onready var join_button: Button = $UI/MenuPanel/JoinButton
@onready var ip_input: LineEdit = $UI/MenuPanel/IPInput
@onready var menu_panel: Control = $UI/MenuPanel

@onready var start_round_button: Button = $UI/LobbyPanel/StartRoundButton
@onready var players_label: Label = $UI/LobbyPanel/PlayersLabel
@onready var waiting_label: Label = $UI/LobbyPanel/WaitingLabel
@onready var lobby_panel: Control = $UI/LobbyPanel

@onready var hud_label: Label = $UI/HudLabel
@onready var crosshair: Label = $UI/Crosshair

@onready var players_container: Node3D = $Players

var ui_state: int = UIState.MENU
var _hud_debug_printed := false

# Compteur utilisé uniquement côté serveur pour répartir les spawns.
var _spawn_index := 0


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_round_button.pressed.connect(_on_start_round_pressed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_ended.connect(_on_round_ended)
	Network.disconnected_from_game.connect(_on_disconnected_from_game)
	_refresh_ui()


func _process(_delta: float) -> void:
	if not Network.is_active():
		return
	if ui_state == UIState.LOBBY:
		players_label.text = "Joueurs dans le lobby : %d" % (multiplayer.get_peers().size() + 1)
	elif ui_state == UIState.IN_GAME:
		_update_hud()


## Calcule une position de spawn distincte à chaque appel (cercle autour
## de l'origine). Appelé uniquement côté serveur, la position est ensuite
## envoyée telle quelle via RPC pour que tout le monde soit d'accord.
func _next_spawn_position() -> Vector3:
	var angle := _spawn_index * (TAU / 8.0)
	var radius := 3.0
	_spawn_index += 1
	return Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)


func _on_host_pressed() -> void:
	Network.host_game()
	# Le serveur (id 1) se spawn lui-même directement.
	spawn_player.rpc(1, _next_spawn_position())
	_setup_npcs()
	ui_state = UIState.LOBBY
	_refresh_ui()


## Assigne un comportement de patrouille à chaque PNJ de la scène.
## Fait ici (en code, côté serveur) plutôt qu'en dur dans la scène, pour
## rester facile à étendre : demain, on pourra piocher au hasard parmi
## plusieurs NPCState différents plutôt que toujours PatrolState.
func _setup_npcs() -> void:
	if not multiplayer.is_server():
		return
	for npc in $NPCs.get_children():
		var base: Vector3 = npc.position
		var patrol := PatrolState.new([
			base + Vector3(6, 0, 0),
			base + Vector3(-6, 0, 0),
		])
		npc.change_state(patrol)


func _on_join_pressed() -> void:
	var ip := ip_input.text if ip_input.text != "" else "127.0.0.1"
	Network.join_game(ip)
	ui_state = UIState.LOBBY
	_refresh_ui()


## Seul l'hôte peut réellement démarrer une manche — le bouton est
## masqué pour tout le monde sauf le serveur (voir _refresh_ui), donc
## un client normal ne devrait même pas pouvoir cliquer dessus.
func _on_start_round_pressed() -> void:
	if not multiplayer.is_server():
		return
	var player_ids := multiplayer.get_peers()
	player_ids.append(1)
	GameManager.start_round(player_ids)


func _on_round_started() -> void:
	_hud_debug_printed = false
	ui_state = UIState.IN_GAME
	_refresh_ui()


## Retour au lobby après une manche, pour pouvoir en relancer une
## rapidement pendant les tests sans redémarrer toute l'application.
func _on_round_ended(_winner: String) -> void:
	ui_state = UIState.LOBBY
	_refresh_ui()


## Connexion perdue (serveur fermé, échec réseau...) : on nettoie tout
## et on revient au menu, plutôt que de rester bloqué dans un état mort.
func _on_disconnected_from_game() -> void:
	for child in players_container.get_children():
		child.queue_free()
	GameManager.reset()
	ui_state = UIState.MENU
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_ui()


func _refresh_ui() -> void:
	menu_panel.visible = ui_state == UIState.MENU
	lobby_panel.visible = ui_state == UIState.LOBBY
	hud_label.visible = ui_state == UIState.IN_GAME
	if ui_state != UIState.IN_GAME:
		crosshair.visible = false

	if ui_state == UIState.LOBBY:
		start_round_button.visible = multiplayer.is_server()
		waiting_label.visible = not multiplayer.is_server()


func _update_hud() -> void:
	if GameManager.state == GameManager.GameState.ENDED:
		hud_label.text = "Manche terminée !"
		crosshair.visible = false
		return

	var my_id := multiplayer.get_unique_id()
	var my_role: int = GameManager.roles.get(my_id, RoleTypes.Role.NONE)
	if not _hud_debug_printed:
		print("[HUD] mon id=%d — rôle lu=%s — dict complet des rôles=%s" % [my_id, my_role, GameManager.roles])
		_hud_debug_printed = true
	var role_text := "Chercheur" if my_role == RoleTypes.Role.SEEKER else "Caché"

	var text := "Rôle : %s\nTemps restant : %.0fs" % [role_text, GameManager.time_left]
	if my_role == RoleTypes.Role.SEEKER:
		text += "\nVies : %d" % GameManager.seeker_lives.get(my_id, 0)

	hud_label.text = text
	crosshair.visible = (my_role == RoleTypes.Role.SEEKER)


## Appelé côté serveur uniquement quand un nouveau peer se connecte.
func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	# Dit à tout le monde (y compris le nouveau) de spawn ce joueur,
	# à une position libre calculée côté serveur.
	spawn_player.rpc(id, _next_spawn_position())
	# Dit spécifiquement au nouveau joueur de spawn tous ceux déjà présents,
	# à leur position ACTUELLE (pas une nouvelle position calculée).
	for existing_player in players_container.get_children():
		spawn_player.rpc_id(id, int(existing_player.name), existing_player.position)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	despawn_player.rpc(id)


@rpc("authority", "call_local", "reliable")
func spawn_player(id: int, spawn_position: Vector3) -> void:
	if players_container.has_node(str(id)):
		return  # Idempotent : évite les doublons si l'appel arrive deux fois.
	var player := player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	player.position = spawn_position
	players_container.add_child(player, true)


@rpc("authority", "call_local", "reliable")
func despawn_player(id: int) -> void:
	var player := players_container.get_node_or_null(str(id))
	if player:
		player.queue_free()
