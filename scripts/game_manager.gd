extends Node

## Autoload : gère l'état de la partie (rôles, timer, vies, victoire).
## Autoritaire côté serveur — les clients ne font que recevoir des mises
## à jour via RPC, jamais de décision prise localement.

signal role_assigned(id: int, role: RoleTypes.Role)
signal round_started
signal round_ended(winner: String)  # "seekers" ou "hidden"
signal timer_updated(seconds_left: float)
signal seeker_died(id: int)
signal hidden_captured(id: int)

enum GameState { WAITING, IN_PROGRESS, ENDED }

# --- Réglages à ajuster librement pour les tests ---
const ROUND_DURATION_SECONDS := 30.0
const SEEKER_LIVES := 3
const SEEKER_COUNT := 1
const SHOOT_RANGE := 50.0
# -----------------------------------------------------

var role_assigner: RoleAssigner = RandomRoleAssigner.new()

var state: int = GameState.WAITING
var roles: Dictionary = {}          # id -> RoleTypes.Role
var seeker_lives: Dictionary = {}   # id -> int
var alive_seekers: Array = []
var alive_hidden: Array = []
var time_left: float = 0.0


func _process(delta: float) -> void:
	if not Network.is_active():
		return
	if not multiplayer.is_server():
		return
	if state != GameState.IN_PROGRESS:
		return

	time_left -= delta
	sync_timer.rpc(time_left)

	if time_left <= 0.0:
		_end_round("hidden")


## Remet l'état à zéro (appelé après une déconnexion, pour repartir propre).
func reset() -> void:
	state = GameState.WAITING
	roles.clear()
	seeker_lives.clear()
	alive_seekers.clear()
	alive_hidden.clear()
	time_left = 0.0


## Appelé côté serveur pour démarrer une manche avec la liste des ids connectés.
func start_round(player_ids: Array) -> void:
	if not multiplayer.is_server():
		return

	roles = role_assigner.assign_roles(player_ids, SEEKER_COUNT)
	seeker_lives.clear()
	alive_seekers.clear()
	alive_hidden.clear()

	for id in roles:
		var role: int = roles[id]
		if role == RoleTypes.Role.SEEKER:
			seeker_lives[id] = SEEKER_LIVES
			alive_seekers.append(id)
		else:
			alive_hidden.append(id)

	time_left = ROUND_DURATION_SECONDS

	for id in roles:
		sync_role.rpc(id, roles[id])
	sync_round_started.rpc()


## Appelé UNIQUEMENT par request_shoot (jamais directement par un input client).
func resolve_shot(shooter_id: int, target_id: int, hit_npc: bool) -> void:
	if state != GameState.IN_PROGRESS:
		return
	if roles.get(shooter_id) != RoleTypes.Role.SEEKER:
		return  # Un caché qui "tire" n'a aucun effet — sécurité côté serveur.

	if hit_npc:
		_seeker_loses_life(shooter_id)
	elif target_id != -1 and roles.get(target_id) == RoleTypes.Role.HIDDEN:
		_capture_hidden(target_id)


func _seeker_loses_life(id: int) -> void:
	if not seeker_lives.has(id):
		return
	seeker_lives[id] -= 1
	sync_seeker_lives.rpc(id, seeker_lives[id])

	if seeker_lives[id] <= 0:
		alive_seekers.erase(id)
		sync_seeker_died.rpc(id)

		if alive_seekers.is_empty():
			_end_round("hidden")
		# Sinon : ce chercheur passe en spectateur (géré côté client via
		# le signal seeker_died), la manche continue avec les autres.


func _capture_hidden(id: int) -> void:
	if not alive_hidden.has(id):
		return
	alive_hidden.erase(id)
	sync_hidden_captured.rpc(id)

	if alive_hidden.is_empty():
		_end_round("seekers")


func _end_round(winner: String) -> void:
	sync_round_ended.rpc(winner)


# --- RPCs de synchronisation (serveur -> clients) ---

@rpc("authority", "call_local", "reliable")
func sync_role(id: int, role: RoleTypes.Role) -> void:
	roles[id] = role
	role_assigned.emit(id, role)


@rpc("authority", "call_local", "reliable")
func sync_round_started() -> void:
	state = GameState.IN_PROGRESS
	round_started.emit()


@rpc("authority", "call_local", "unreliable")
func sync_timer(seconds_left: float) -> void:
	time_left = seconds_left
	timer_updated.emit(seconds_left)


@rpc("authority", "call_local", "reliable")
func sync_seeker_lives(id: int, lives: int) -> void:
	seeker_lives[id] = lives


@rpc("authority", "call_local", "reliable")
func sync_seeker_died(id: int) -> void:
	alive_seekers.erase(id)
	seeker_died.emit(id)


@rpc("authority", "call_local", "reliable")
func sync_hidden_captured(id: int) -> void:
	alive_hidden.erase(id)
	hidden_captured.emit(id)


@rpc("authority", "call_local", "reliable")
func sync_round_ended(winner: String) -> void:
	state = GameState.ENDED
	round_ended.emit(winner)


## Appelé par le client chercheur qui tire (rpc_id(1, ...) vers le serveur).
## target_id == -1 signifie "n'a touché aucun joueur".
## L'identité du tireur est déduite du peer réseau authentifié, jamais
## d'une valeur envoyée par le client, pour éviter la triche.
@rpc("any_peer", "call_local", "reliable")
func request_shoot(target_id: int, hit_npc: bool) -> void:
	if not multiplayer.is_server():
		return
	var shooter_id := multiplayer.get_remote_sender_id()
	if shooter_id == 0:
		shooter_id = multiplayer.get_unique_id()  # Le serveur tire lui-même.
	resolve_shot(shooter_id, target_id, hit_npc)
