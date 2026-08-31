class_name RoleAssigner
extends Resource

## Classe de base pour l'attribution des rôles en début de manche.
##
## Pour ajouter une nouvelle façon de choisir qui est chercheur/caché
## (vote des joueurs, choix manuel par l'hôte, etc.) : crée une nouvelle
## classe qui hérite de celle-ci, surcharge assign_roles(), puis assigne
## une instance à GameManager.role_assigner. Rien d'autre à changer.

## Doit retourner un Dictionary { peer_id: int -> RoleTypes.Role }
## couvrant TOUS les ids de player_ids.
func assign_roles(_player_ids: Array, _seeker_count: int) -> Dictionary:
	push_error("RoleAssigner.assign_roles() doit être surchargé par une sous-classe")
	return {}
