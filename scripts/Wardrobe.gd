class_name Wardrobe

## Construit l'apparence d'un personnage à partir d'une tenue.
##
## PRINCIPE DU GREFFAGE
## Un vêtement exporté depuis Blender arrive avec sa PROPRE copie du
## squelette. On n'en garde que le MeshInstance3D, qu'on rattache au
## Skeleton3D du personnage. Godot fait ensuite correspondre les os par
## leur NOM : comme vêtements et personnages partagent la même convention
## (65 os, mêmes noms), le vêtement suit les animations sans rien de plus.
##
## Le squelette en double du vêtement est jeté : le garder ferait tourner
## deux squelettes pour rien.


## Cherche le premier nœud d'un type donné, en profondeur.
static func _trouver(racine: Node, type_recherche) -> Node:
	if is_instance_of(racine, type_recherche):
		return racine
	for enfant in racine.get_children():
		var trouve := _trouver(enfant, type_recherche)
		if trouve:
			return trouve
	return null


## Charge une ressource en signalant proprement son absence, plutôt que
## de laisser Godot échouer en silence.
static func _charger(chemin: String) -> PackedScene:
	if chemin == "":
		return null
	if not ResourceLoader.exists(chemin):
		push_warning("Wardrobe : ressource introuvable, ignorée : %s" % chemin)
		return null
	return load(chemin) as PackedScene


## Construit un personnage complet (modèle + vêtements + teinte) et
## l'ajoute sous `parent`. Retourne la racine du modèle, qui porte le
## script CharacterAnimator.
static func construire(parent: Node3D, tenue: PackedInt32Array) -> Node3D:
	# On repart de zéro : construire par-dessus un modèle existant
	# empilerait les vêtements à chaque changement de tenue.
	for ancien in parent.get_children():
		parent.remove_child(ancien)
		ancien.queue_free()

	var scene_modele := _charger(WardrobeCatalog.chemin_modele(tenue))
	if scene_modele == null:
		push_error("Wardrobe : modèle introuvable pour la tenue %s" % str(tenue))
		return null

	var modele := scene_modele.instantiate() as Node3D
	parent.add_child(modele)

	var couleur := WardrobeCatalog.couleur(tenue)
	for chemin in WardrobeCatalog.chemins_vetements(tenue):
		var maillage := attacher(modele, _charger(chemin))
		if maillage:
			_teinter(maillage, couleur)

	# Accessoires rigides : cheveux, barbe, sourcils. Ils ne sont PAS
	# teintés — ils ont leurs propres textures, qu'une surcharge de
	# matériau écraserait au profit d'un aplat de couleur.
	for chemin in WardrobeCatalog.chemins_accessoires_tete(tenue):
		attacher_rigide(modele, _charger(chemin), WardrobeCatalog.OS_TETE)

	return modele


## Monte un accessoire rigide (cheveux, chapeau, lunettes...) sur un os.
##
## Contrairement à un vêtement, un accessoire rigide n'a ni squelette ni
## vertex groups : il ne se déforme pas, il suit un os en bloc. Un
## BoneAttachment3D suffit, et évite tout calcul de déformation.
static func attacher_rigide(personnage: Node3D, scene_accessoire: PackedScene,
		nom_os: String) -> Node3D:
	if scene_accessoire == null:
		return null

	var squelette := _trouver(personnage, Skeleton3D) as Skeleton3D
	if squelette == null:
		push_error("Wardrobe : aucun Skeleton3D trouvé sur %s" % personnage.name)
		return null

	if squelette.find_bone(nom_os) == -1:
		push_error("Wardrobe : os '%s' introuvable dans le squelette" % nom_os)
		return null

	var attache := BoneAttachment3D.new()
	attache.name = "Attache_%s" % nom_os
	squelette.add_child(attache)
	attache.bone_name = nom_os

	var instance := scene_accessoire.instantiate() as Node3D
	attache.add_child(instance)
	# L'accessoire a été modelé dans l'espace du personnage, pas dans
	# celui de l'os : on annule la transformation de l'os pour le
	# replacer là où il a été conçu.
	instance.transform = squelette.get_bone_global_pose(
		squelette.find_bone(nom_os)).affine_inverse()

	return instance


## Attache un vêtement au squelette d'un personnage.
## Retourne le MeshInstance3D greffé, ou null.
static func attacher(personnage: Node3D, scene_vetement: PackedScene) -> MeshInstance3D:
	if scene_vetement == null:
		return null

	var squelette := _trouver(personnage, Skeleton3D) as Skeleton3D
	if squelette == null:
		push_error("Wardrobe : aucun Skeleton3D trouvé sur %s" % personnage.name)
		return null

	var instance := scene_vetement.instantiate()
	var maillage := _trouver(instance, MeshInstance3D) as MeshInstance3D
	if maillage == null:
		push_error("Wardrobe : aucun MeshInstance3D dans %s"
			% scene_vetement.resource_path)
		instance.queue_free()
		return null

	# Le mesh appartient encore à la scène du vêtement, qu'on s'apprête à
	# libérer. Sans couper ce lien de propriété, Godot signale une
	# hiérarchie incohérente à chaque greffe.
	maillage.owner = null
	maillage.get_parent().remove_child(maillage)
	instance.queue_free()

	squelette.add_child(maillage)
	# Le mesh est désormais exprimé dans l'espace du squelette du
	# personnage, plus dans celui de son fichier d'origine.
	maillage.transform = Transform3D.IDENTITY
	# C'est cette ligne qui fait le lien : le mesh va chercher ses os ici.
	maillage.skeleton = maillage.get_path_to(squelette)

	return maillage


## Dilatation du vêtement au rendu, en mètres, le long des normales.
##
## POURQUOI : un vêtement n'est décollé de la peau que de quelques
## millimètres (le Displace appliqué dans Blender). Au repos ça suffit,
## mais dès qu'un membre se plie fortement — une jambe en pleine course —
## le muscle gonfle et traverse le tissu. Comme les personnages ne sont
## pas tous dans la même pose au même instant, le défaut n'apparaît que
## sur certains d'entre eux, ce qui le rend trompeur à diagnostiquer.
##
## `grow` dilate le maillage à l'affichage, sans toucher à la géométrie ni
## au skinning. Augmente cette valeur si la peau transperce encore ;
## diminue-la si le vêtement paraît bouffant.
const DILATATION := 0.006


## Applique une teinte au vêtement via une surcharge de matériau.
## On passe par material_override plutôt que par le matériau de la
## ressource : celui-ci est PARTAGÉ entre toutes les instances du même
## vêtement, donc le modifier recolorerait tous les personnages d'un coup.
static func _teinter(maillage: MeshInstance3D, couleur: Color) -> void:
	var materiau := StandardMaterial3D.new()
	materiau.albedo_color = couleur
	materiau.roughness = 0.85
	materiau.grow = true
	materiau.grow_amount = DILATATION
	maillage.material_override = materiau
