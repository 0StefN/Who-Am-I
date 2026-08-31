extends Node3D

## Pilote les animations d'un personnage (joueur ou PNJ) à partir de sa
## vitesse au sol. À placer sur l'instance du modèle (la scène
## superhero_*_full_body.tscn), qui contient déjà son AnimationPlayer et
## sa bibliothèque UAL1_Standard.
##
## Volontairement basé sur AnimationPlayer + temps de fondu plutôt que sur
## un AnimationTree : un AnimationTree donne de meilleurs blends, mais sa
## ressource s'écrit très mal à la main dans un .tscn. On pourra migrer
## depuis l'éditeur plus tard, une fois le reste validé.

## Si le personnage marche à reculons, mets 180.0 ici.
## Godot considère -Z comme l'avant ; selon l'export du modèle, il peut
## regarder vers +Z. Pour les modèles Quaternius : 0.0.
const ROTATION_MODELE := 0.0

const FONDU := 0.2  # Durée des transitions, en secondes.

# Les seuils viennent de MovementConfig : ils doivent être identiques pour
# les joueurs et les PNJ, sinon un joueur caché change d'animation à une
# vitesse différente d'un PNJ et se trahit.

# Noms tels que Godot les expose après import. Attention : l'importateur
# RETIRE le suffixe '_Loop' des noms du .glb et le convertit en propriété
# de bouclage. D'où 'Idle' et non 'Idle_Loop'.
const ANIM_IDLE := "UAL1_Standard/Idle"
const ANIM_MARCHE := "UAL1_Standard/Walk"
const ANIM_COURSE := "UAL1_Standard/Jog_Fwd"
const ANIM_SAUT := "UAL1_Standard/Jump"

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _animation_courante := ""


func _ready() -> void:
	rotation_degrees.y = ROTATION_MODELE

	if animation_player == null:
		push_error("CharacterAnimator : aucun AnimationPlayer trouvé sur %s"
			% name)
		return

	# Vérifie que les animations attendues existent vraiment : plus lisible
	# qu'un échec silencieux au premier appel de jouer().
	for anim in [ANIM_IDLE, ANIM_MARCHE, ANIM_COURSE, ANIM_SAUT]:
		if not animation_player.has_animation(anim):
			push_error("CharacterAnimator : animation introuvable '%s'. "
				% anim + "Animations disponibles : %s"
				% str(animation_player.get_animation_list()))
			return

	# Le mixer doit être actif pour écrire dans le Skeleton3D.
	animation_player.active = true
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE

	_boucler(ANIM_IDLE)
	_boucler(ANIM_MARCHE)
	_boucler(ANIM_COURSE)

	jouer(ANIM_IDLE)


## Les animations de boucle doivent boucler, sinon elles s'arrêtent
## à la dernière frame.
func _boucler(nom: String) -> void:
	var anim := animation_player.get_animation(nom)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR


func jouer(nom: String) -> void:
	if nom == _animation_courante:
		return
	_animation_courante = nom
	animation_player.play(nom, FONDU)


## Point d'entrée principal, appelé à chaque frame par le joueur ou le PNJ.
## vitesse_sol : norme de la vélocité horizontale (m/s).
func mettre_a_jour(vitesse_sol: float, au_sol: bool) -> void:
	if animation_player == null:
		return

	if not au_sol:
		jouer(ANIM_SAUT)
	elif vitesse_sol >= MovementConfig.SEUIL_COURSE:
		jouer(ANIM_COURSE)
	elif vitesse_sol >= MovementConfig.SEUIL_MARCHE:
		jouer(ANIM_MARCHE)
	else:
		jouer(ANIM_IDLE)


## Masque le modèle pour son propre porteur (vue FPS du chercheur), sans
## le cacher aux autres joueurs : on n'agit que sur l'affichage local.
func definir_visibilite_locale(visible_localement: bool) -> void:
	visible = visible_localement
