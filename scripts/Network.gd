extends Node

## Autoload : gère uniquement la connexion réseau (host / join).
## Le spawn des joueurs est géré par Main.gd, pas ici.

signal disconnected_from_game

const PORT := 7777
const MAX_PLAYERS := 8

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## À vérifier avant tout appel à multiplayer.* dans un _process/_physics_process
## qui tourne en continu — évite le spam d'erreurs "multiplayer instance isn't
## currently active" quand le peer a été perdu (fenêtre fermée, coupure réseau).
func is_active() -> bool:
	return multiplayer.multiplayer_peer != null \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		push_error("Impossible de créer le serveur : %s" % error)
		return
	multiplayer.multiplayer_peer = peer
	print("[Network] Serveur créé sur le port %d" % PORT)


func join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, PORT)
	if error != OK:
		push_error("Impossible de rejoindre %s : %s" % [ip, error])
		return
	multiplayer.multiplayer_peer = peer
	print("[Network] Tentative de connexion à %s..." % ip)


func _on_peer_connected(id: int) -> void:
	print("[Network] Peer connecté : %d" % id)


func _on_peer_disconnected(id: int) -> void:
	print("[Network] Peer déconnecté : %d" % id)


func _on_connected_ok() -> void:
	print("[Network] Connecté au serveur avec succès")


func _on_connected_fail() -> void:
	push_error("[Network] Échec de connexion au serveur")
	multiplayer.multiplayer_peer = null
	disconnected_from_game.emit()


func _on_server_disconnected() -> void:
	print("[Network] Déconnecté du serveur")
	multiplayer.multiplayer_peer = null
	disconnected_from_game.emit()
