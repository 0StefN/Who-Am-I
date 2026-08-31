class_name RandomRoleAssigner
extends RoleAssigner

## Implémentation par défaut : tire au hasard `seeker_count` chercheurs
## parmi les joueurs, le reste devient caché.
func assign_roles(player_ids: Array, seeker_count: int) -> Dictionary:
	var roles := {}
	var shuffled := player_ids.duplicate()
	shuffled.shuffle()

	var actual_seeker_count := mini(seeker_count, shuffled.size())

	for i in range(shuffled.size()):
		if i < actual_seeker_count:
			roles[shuffled[i]] = RoleTypes.Role.SEEKER
		else:
			roles[shuffled[i]] = RoleTypes.Role.HIDDEN

	return roles
