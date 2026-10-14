extends Node
## Idées en vrac du joueur (15/10) : options de lisibilité, roulette, puissance d'équipement…
## godot --headless --path game res://tests/test_ideas.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	_test_fx_options()
	_test_wheel()
	_test_gear_power()
	print("ÉCHECS : %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _test_fx_options() -> void:
	Settings.set_v("interface", "fx_spells", "all")
	check("effets : tout affiché par défaut", Settings.fx_factor("fx_spells", 1) == 1.0 and Settings.fx_factor("fx_spells", 0) == 1.0)
	Settings.set_v("interface", "fx_spells", "dim_others")
	check("effets : atténuer les autres, pas les miens", Settings.fx_factor("fx_spells", 1) == 1.0 and Settings.fx_factor("fx_spells", 0) < 1.0 and Settings.fx_factor("fx_spells", 0) > 0.0)
	Settings.set_v("interface", "fx_spells", "hide_others")
	check("effets : masquer ceux des autres", Settings.fx_factor("fx_spells", 1) == 1.0 and Settings.fx_factor("fx_spells", 0) == 0.0)
	Settings.set_v("interface", "fx_spells", "hide_mine")
	check("effets : masquer les miens", Settings.fx_factor("fx_spells", 1) == 0.0 and Settings.fx_factor("fx_spells", 0) == 1.0)
	Settings.set_v("interface", "fx_spells", "hide_all")
	check("effets : tout masquer", Settings.fx_factor("fx_spells", 1) == 0.0 and Settings.fx_factor("fx_spells", 0) == 0.0)
	check("aperçus (lobby, équipement) jamais masqués", Settings.fx_factor("fx_spells", -1) == 1.0)
	check("l'aperçu d'un nœud simple n'est pas un héros de combat", EdenFx._owner_scope(Node3D.new()) == -1)
	check("auras indépendantes des sorts", Settings.fx_factor("fx_auras", 0) == 1.0)
	Settings.set_v("interface", "fx_spells", "all")
	Settings.set_v("interface", "fx_particles", "off")
	check("particules : réglage lu", Settings.fx_particles() == "off")
	Settings.reset_all()


func _test_wheel() -> void:
	var total := 0
	for s in Wheel.SLICES:
		total += int(s[1])
	check("roulette : 12 cases, chances totales 100 %", Wheel.SLICES.size() == 12 and total == 100)
	check("roulette : cases contiguës jusqu'au tour complet", is_equal_approx(Wheel.span(0).x, 0.0) and is_equal_approx(Wheel.span(11).y, TAU))
	check("roulette : tirage 0 = 1re case, 0,999 = dernière", Wheel.slice_at(0.0) == 0 and Wheel.slice_at(0.999) == 11)
	Wheel.day_override = "2026-10-15"
	Profile.wheel = {}
	Profile.insignia = 0
	check("roulette : 3 lancers offerts", Wheel.free_left() == 3)
	var lost := Wheel.slice_of("lost")
	var r1 := Wheel.spin((float(Wheel.span(lost).x) + 0.01) / TAU)
	check("roulette : case Perdu, rien gagné", r1.ok and r1.kind == "lost" and r1.look.is_empty())
	check("roulette : un lancer de moins", Wheel.free_left() == 2)
	var r2 := Wheel.spin(0.03)
	var r3 := Wheel.spin(0.03)
	check("roulette : 3 lancers faits", not r2.is_empty() and not r3.is_empty() and Wheel.free_left() == 0)
	check("roulette : sans insignes, pas de lancer en plus", not Wheel.can_spin() and not Wheel.spin().ok)
	Profile.insignia = 500
	check("roulette : lancer en plus à 50 insignes", Wheel.extra_cost() == 50 and Wheel.can_spin())
	var r4 := Wheel.spin(0.03)
	check("roulette : insignes payés", r4.ok and Profile.insignia == 450 and Wheel.extra_cost() == 100)
	Wheel.spin(0.03)
	check("roulette : au plus 2 lancers en plus", Wheel.extra_cost() == -1 and not Wheel.can_spin())
	Wheel.day_override = "2026-10-16"
	check("roulette : nouveau jour, 3 lancers de nouveau", Wheel.free_left() == 3 and int(Wheel.state().extra) == 0)
	# pitié : 6 « Perdu » d'affilée
	Profile.wheel = {"day": "2026-10-16", "used": 0, "extra": 0, "misses": 6, "since_rare": 0, "total": 0}
	var r5 := Wheel.spin((float(Wheel.span(lost).x) + 0.01) / TAU)
	check("roulette : pitié du Perdu, au moins du commun", r5.kind != "lost" and String(r5.pity) != "")
	Profile.wheel = {"day": "2026-10-16", "used": 0, "extra": 0, "misses": 0, "since_rare": 24, "total": 0}
	var r6 := Wheel.spin((float(Wheel.span(lost).x) + 0.01) / TAU)
	check("roulette : pitié du rare après 25 lancers", r6.kind == "rare")
	Profile.wheel = {}
	Wheel.day_override = ""
	var pg := WheelPage.new()
	add_child(pg)
	pg.refresh()
	check("roulette : la page se construit", pg.get_child_count() > 0)
	pg.queue_free()


func _test_gear_power() -> void:
	Profile.reset_all()
	Settings.reset_all()
	Profile.equipped = {}
	check("PE : sans équipement, 0", GearPower.hero_power() == 0)
	check("PE attendue croissante avec le niveau", GearPower.expected(10) < GearPower.expected(50) and GearPower.expected(50) < GearPower.expected(90))
	var low := Items.generate(30, 1.0, "head", "warrior", 0, "", 0)
	var high := Items.generate(30, 1.0, "head", "warrior", Items.MYTHIC, "", Items.MYTHIC)
	check("PE d'une pièce : mythique > commune", GearPower.item_power(high) > GearPower.item_power(low) and GearPower.item_power(low) > 0)
	var up := high.duplicate(true)
	up["upgrade"] = 10
	check("PE d'une pièce : +10 > +0", GearPower.item_power(up) > GearPower.item_power(high))
	Profile.equipped = {"head": high}
	var one := GearPower.hero_power()
	check("PE du héros : une pièce portée = sa PE", one == GearPower.item_power(high))
	check("PE : variation si on remplace par une pièce meilleure", GearPower.delta_if_equipped(up) > 0 and GearPower.delta_if_equipped(low) < 0)
	Profile.equipped = {}
	for slot in Items.SLOTS:
		var it := Items.generate(40, 1.0, slot, "warrior", Items.MYTHIC, "", Items.MYTHIC)
		Profile.equipped[slot] = it
	var full := GearPower.hero_power()
	check("PE : 9 mythiques ≈ 80 % de l'attendue (note 8,7 sur 10)", GearPower.ratio(40, full) > 0.6 and GearPower.ratio(40, full) < 1.0)
	check("PE : texte lisible avec séparateur de milliers", GearPower.fmt(12345) == "12 345" and GearPower.fmt(7) == "7" and GearPower.fmt(-1500) == "-1 500")
	# verrous
	var zid := String(Dungeons.zone_ids()[0])
	check("donjon Normal : aucune PE requise", Dungeons.power_required(zid, 0) == 0 and Dungeons.power_ok(zid, 0))
	check("donjon Héroïque : PE requise > 0", Dungeons.power_required(zid, 1) > 0)
	check("donjon Mythique exige plus que l'Héroïque (niveau 90 vs ~30)", Dungeons.power_required(zid, 2) > Dungeons.power_required(zid, 1))
	Profile.equipped = {}
	check("sans équipement : Héroïque fermé", not Dungeons.power_ok(zid, 1))
	check("Ruée Héroïque fermée sans équipement, Normale ouverte", not Dungeons.power_ok(Dungeons.RUSH, 1) and Dungeons.power_ok(Dungeons.RUSH, 0))
	Settings.set_v("interface", "dev_mode", true)
	check("mode dev : tout ouvert", Dungeons.power_ok(zid, 2) and Dungeons.power_ok(Dungeons.RUSH, 2))
	Settings.set_v("interface", "dev_mode", false)
	# butin légendaire
	var chest := Rewards.make("gear", 60, true)
	var got_legend := false
	for i in 80:
		got_legend = got_legend or Rewards.top_rarity(chest) == Items.LEGENDARY
	check("sans PE : un coffre ne donne jamais de légendaire", not got_legend and not Rewards.legendary_open(chest))
	check("aperçu du coffre : dit la PE qu'il faut", Rewards.preview(chest).contains("PE"))
	Settings.set_v("interface", "dev_mode", true)
	for i in 80:
		got_legend = got_legend or Rewards.top_rarity(chest) == Items.LEGENDARY
	check("avec la PE (ici le mode dev) : des légendaires tombent", got_legend)
	Settings.reset_all()
	Profile.equipped = {}
