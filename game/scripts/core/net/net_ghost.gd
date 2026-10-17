class_name NetGhost
extends Player
## Fantôme d'un héros chez un client (lot NET-A) : le modèle, la tenue, l'arme et les animations d'un vrai [Player] de sa
## classe, mais AUCUNE logique : ni physique, ni collisions, ni groupes (aucun monstre, sort ou projectile ne le voit), ni
## entrées. L'hôte décide de tout ; [method show_state] le place entre deux instantanés et rejoue son animation.
## Anneau au sol doré pour le héros du joueur, lagon pour ses amis ; nom et PV au-dessus de la tête.

var slot := -1
var mine := false
var hero_label := ""  # nom du joueur (à poser avant add_child)
var _plate: Label3D
var _shown_name := ""


func _ready() -> void:
	foe = true  # héros « à sa fiche » : ne lit jamais Run, Profile ni le clavier
	super._ready()
	if hero_label != "":
		display_name = hero_label
	remove_from_group("foe_heroes")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	for c in get_children():
		if c is Decal:
			(c as Decal).modulate = Color(1.0, 0.82, 0.35, 0.6) if mine else Color(0.35, 0.8, 1.0, 0.6)
	_plate = Label3D.new()
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.no_depth_test = true
	_plate.fixed_size = true
	_plate.pixel_size = 0.0009
	_plate.font_size = 26
	_plate.outline_size = 10
	_plate.outline_modulate = UiTheme.INK
	_plate.modulate = UiTheme.GOLD if mine else UiTheme.TEXT
	_plate.position = Vector3.UP * 2.75
	add_child(_plate)
	position = Vector3(0, -50, 0)  # caché sous le sol jusqu'au premier instantané


## Pose l'état interpolé entre [param a] et [param c] (k de 0 à 1) ; [param anim_names] : table des noms de l'hôte.
func show_state(a: Dictionary, c: Dictionary, k: float, anim_names: Dictionary) -> void:
	global_position = (a.pos as Vector3).lerp(c.pos, k)
	rotation.y = lerp_angle(float(a.yaw), float(c.yaw), k)
	max_hp = maxf(1.0, float(c.max_hp))
	hp = lerpf(float(a.hp), float(c.hp), k)
	is_dead = int(c.flags) & 1 != 0
	var e: Dictionary = c if k > 0.5 else a
	var an := String(anim_names.get(int(e.anim), ""))
	if an != "" and anim and anim.has_animation(an):
		var restarted := an == _current_anim and float(e.apos) + 0.08 < anim.current_animation_position - 0.25
		if an != _current_anim or restarted or not anim.is_playing():
			play(an, 0.08, float(e.aspeed), true)
			anim.seek(float(e.apos), true)
		elif absf(anim.current_animation_position - float(e.apos)) > 0.2:
			anim.seek(float(e.apos), true)
	var txt := "%s\n%d / %d" % [display_name, roundi(hp), roundi(max_hp)]
	if txt != _shown_name and _plate:
		_shown_name = txt
		_plate.text = txt
