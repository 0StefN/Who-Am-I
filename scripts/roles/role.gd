class_name RoleTypes

## Enum partagé pour les rôles de partie.
## Fichier séparé pour que ce soit facile à étendre (ex : ajouter un
## rôle SPECTATOR plus tard) sans toucher au reste du système de rôles.

enum Role {
	NONE,
	SEEKER,
	HIDDEN,
}
