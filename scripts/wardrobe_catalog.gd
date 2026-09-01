class_name WardrobeCatalog

## Catalogue des apparences disponibles.
##
## POUR AJOUTER UN VÊTEMENT : ajoute son chemin dans la bonne liste
## ci-dessous. Rien d'autre à modifier dans le code.
##
## Les chemins sont des CHAÎNES, chargées à l'exécution, et non des
## preload(). C'est volontaire : un preload() vers un fichier absent
## empêcherait le script entier de se charger, alors qu'ici une pièce
## manquante est simplement signalée et ignorée. Pratique tant que la
## garde-robe est en cours de constitution.

enum Genre { HOMME, FEMME }

const MODELES := {
	Genre.HOMME: "res://scenes/character_male.tscn",
	Genre.FEMME: "res://scenes/character_female.tscn",
}

## Hauts, par genre.
## ⚠️ Pas d'entrée vide ici : le tirage étant uniforme, une option ""
## produirait des personnages torse nu, ce qui n'a aucun sens dans une
## foule où tout le monde doit pouvoir se fondre.
const HAUTS := {
	Genre.HOMME: [
		"res://Models & Animations/Clothes/Male/Tshirt_Male.glb",
	],
	Genre.FEMME: [
		"res://Models & Animations/Clothes/Female/Tshirt_Female.glb",
	],
}

## Bas, par genre. Même remarque que pour les hauts.
const BAS := {
	Genre.HOMME: [
		"res://Models & Animations/Clothes/Male/Pants_Male.glb",
	],
	Genre.FEMME: [
		"res://Models & Animations/Clothes/Female/Pants_Female.glb",
	],
}

## Chaussures, par genre. Vides pour l'instant : les modèles ont des
## pieds nus, à compléter quand tu auras modelé des chaussures.
const CHAUSSURES := {
	Genre.HOMME: [],
	Genre.FEMME: [],
}

## ---------------------------------------------------------------------
## ACCESSOIRES RIGIDES
##
## Cheveux, barbes, sourcils : ces meshes n'ont NI squelette NI vertex
## groups. Ils ne se déforment pas, ils suivent un os en bloc — d'où
## l'usage d'un BoneAttachment3D plutôt qu'un greffage sur le squelette.
## C'est aussi plus léger : aucun calcul de déformation par sommet.
## ---------------------------------------------------------------------

## Os sur lequel les accessoires de tête sont accrochés.
const OS_TETE := "Head"

## Coiffures, séparées par genre. Aucune pièce n'est partagée entre les
## deux : les modèles n'ayant pas la même taille (1,81 m contre 1,77 m),
## une coiffure modelée sur l'un tombe de travers sur l'autre.
const CHEVEUX := {
	Genre.HOMME: [
		"res://Models & Animations/Hairs/Male/Hair_Buzzed.gltf",
		"res://Models & Animations/Hairs/Male/Hair_SimpleParted.gltf",
	],
	Genre.FEMME: [
		"res://Models & Animations/Hairs/Female/Hair_BuzzedFemale.gltf",
		"res://Models & Animations/Hairs/Female/Hair_Long.gltf",
		"res://Models & Animations/Hairs/Female/Hair_Buns.gltf",
	],
}

## Pilosité faciale. L'entrée vide est ICI légitime, contrairement aux
## vêtements : ne pas porter de barbe est une apparence parfaitement
## normale, et elle doit rester majoritaire.
const BARBES := {
	Genre.HOMME: [
		"",
		"",
		"res://Models & Animations/Hairs/Male/Hair_Beard.gltf",
	],
	Genre.FEMME: [""],
}

const SOURCILS := {
	Genre.HOMME: [
		"res://Models & Animations/Hairs/Eyebrows/Eyebrows_Regular.gltf",
	],
	Genre.FEMME: [
		"res://Models & Animations/Hairs/Eyebrows/Eyebrows_Female.gltf",
	],
}

## Teintes appliquées aux vêtements. C'est le meilleur rapport
## variété/effort : 3 hauts x 3 bas x 8 teintes = des centaines
## d'apparences perçues à partir d'une poignée de meshes.
const TEINTES := [
	Color(0.20, 0.35, 0.65),  # bleu
	Color(0.65, 0.20, 0.20),  # rouge
	Color(0.20, 0.45, 0.25),  # vert
	Color(0.85, 0.80, 0.70),  # crème
	Color(0.25, 0.25, 0.30),  # gris foncé
	Color(0.75, 0.55, 0.20),  # ocre
	Color(0.45, 0.25, 0.55),  # violet
	Color(0.90, 0.90, 0.92),  # blanc
]

## Teinte réservée au chercheur, pour qu'il soit immédiatement
## identifiable. Elle ne fait PAS partie de TEINTES : un caché ne doit
## jamais pouvoir tirer cette couleur au hasard.
const TEINTE_CHERCHEUR := Color(0.95, 0.45, 0.05)  # orange vif

## Ordre des valeurs dans une tenue. Une tenue est un PackedInt32Array :
## compact à répliquer sur le réseau, et reconstruit à l'identique par
## chaque client.
enum Champ {
	GENRE, HAUT, BAS, CHAUSSURES, TEINTE, CHERCHEUR,
	CHEVEUX, BARBE, SOURCILS,
}
const TAILLE_TENUE := 9


static func _liste(dictionnaire: Dictionary, genre: int) -> Array:
	return dictionnaire.get(genre, [])


## Tire un indice dans une liste. Retourne -1 si la liste est vide :
## cette catégorie n'a alors simplement aucun vêtement à proposer.
static func _tirer_index(liste: Array, rng: RandomNumberGenerator) -> int:
	if liste.is_empty():
		return -1
	return rng.randi_range(0, liste.size() - 1)


## Tire une tenue au hasard. `rng` est fourni par l'appelant (le serveur),
## pour que le tirage reste maîtrisé et reproductible si besoin.
static func tirer_tenue(rng: RandomNumberGenerator) -> PackedInt32Array:
	var genre := rng.randi_range(0, 1)
	var tenue := PackedInt32Array()
	tenue.resize(TAILLE_TENUE)
	tenue[Champ.GENRE] = genre
	tenue[Champ.HAUT] = _tirer_index(_liste(HAUTS, genre), rng)
	tenue[Champ.BAS] = _tirer_index(_liste(BAS, genre), rng)
	tenue[Champ.CHAUSSURES] = _tirer_index(_liste(CHAUSSURES, genre), rng)
	tenue[Champ.TEINTE] = rng.randi_range(0, TEINTES.size() - 1)
	tenue[Champ.CHERCHEUR] = 0
	tenue[Champ.CHEVEUX] = _tirer_index(_liste(CHEVEUX, genre), rng)
	tenue[Champ.BARBE] = _tirer_index(_liste(BARBES, genre), rng)
	tenue[Champ.SOURCILS] = _tirer_index(_liste(SOURCILS, genre), rng)
	return tenue


## Transforme une tenue en tenue de chercheur : même corps, même
## vêtements, mais teinte réservée. On garde le modèle et les vêtements
## d'origine pour que la silhouette reste cohérente ; seule la couleur
## le distingue.
static func en_chercheur(tenue: PackedInt32Array) -> PackedInt32Array:
	var copie := tenue.duplicate()
	if copie.size() < TAILLE_TENUE:
		return copie
	copie[Champ.CHERCHEUR] = 1
	return copie


static func chemin_modele(tenue: PackedInt32Array) -> String:
	if tenue.size() < TAILLE_TENUE:
		return MODELES[Genre.HOMME]
	return MODELES.get(tenue[Champ.GENRE], MODELES[Genre.HOMME])


## Chemins des vêtements d'une tenue, en ignorant les emplacements vides.
static func chemins_vetements(tenue: PackedInt32Array) -> Array[String]:
	var resultat: Array[String] = []
	if tenue.size() < TAILLE_TENUE:
		return resultat
	var genre: int = tenue[Champ.GENRE]
	for paire in [[HAUTS, Champ.HAUT], [BAS, Champ.BAS],
			[CHAUSSURES, Champ.CHAUSSURES]]:
		var liste: Array = _liste(paire[0], genre)
		var index: int = tenue[paire[1]]
		if index >= 0 and index < liste.size() and liste[index] != "":
			resultat.append(liste[index])
	return resultat


## Chemins des accessoires rigides (cheveux, barbe, sourcils), à monter
## sur un BoneAttachment3D plutôt qu'à greffer sur le squelette.
static func chemins_accessoires_tete(tenue: PackedInt32Array) -> Array[String]:
	var resultat: Array[String] = []
	if tenue.size() < TAILLE_TENUE:
		return resultat
	var genre: int = tenue[Champ.GENRE]
	for paire in [[CHEVEUX, Champ.CHEVEUX], [BARBES, Champ.BARBE],
			[SOURCILS, Champ.SOURCILS]]:
		var liste: Array = _liste(paire[0], genre)
		var index: int = tenue[paire[1]]
		if index >= 0 and index < liste.size() and liste[index] != "":
			resultat.append(liste[index])
	return resultat


static func couleur(tenue: PackedInt32Array) -> Color:
	if tenue.size() < TAILLE_TENUE:
		return TEINTES[0]
	if tenue[Champ.CHERCHEUR] == 1:
		return TEINTE_CHERCHEUR
	var index: int = tenue[Champ.TEINTE]
	if index < 0 or index >= TEINTES.size():
		return TEINTES[0]
	return TEINTES[index]
