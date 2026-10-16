extends Node
## Lot H2 : modes scellés (NIVEAU_HEROS §2.3). En Survivant et en Battle royale, rien de la progression du compte en combat :
## ni talents, ni certificats, ni plateau, ni archive, ni aura, ni sort fermé par la maîtrise, ni carte à débloquer.
## En Aventure (et au Duel, aux Arènes) tout reste. Compte « opti » : maîtrise 40, talents et plateau du build opti,
## archive de 100 entrées, aura portée.
## godot --headless --path game res://tests/test_h2.tscn

const CID := "warrior"

var fails := 0
var hero: Player


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = false
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = CID
	hero = Player.new()
	add_child(hero)
	hero.set_physics_process(false)
	hero.set_process(false)
	_test_switch()
	_test_stats()
	_test_cards()
	_test_knock()
	_test_survivor()
	_mode("")
	Run.active = false
	Run.survival = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Mode de combat : "" Aventure (Survie), "royale", "survivor", "duel".
func _mode(m: String) -> void:
	Royale.active = m == "royale"
	Survivor.active = m == "survivor"
	Duel.active = m == "duel"
	Run.active = true
	Run.survival = true
	Run.class_id = CID
	Run.passives = {}
	Run.passive_power = {}
	Run.skills = []
	Run.chains = {}
	Run.banned = []
	Run.kept = []


func _fresh() -> void:
	Profile.talents = {}
	Profile.cert_board = ["", "", "", "", "", "", ""]
	Profile.archive = {}
	Profile.expertise = {}
	Profile.worn = {}
	Profile._sync_certificates()


func _opti() -> void:
	var b := Duel.opti_build(CID, 90)
	Profile.set_expertise_level(CID, 40)
	Profile.talents = {CID: (b.get("talents", {}) as Dictionary).duplicate()}
	Profile.cert_board = RivalBuilds.cert_board(b)
	Profile._sync_certificates()
	for e: Dictionary in GameData.eden_items:
		if e.has("arch") and Profile.archive.size() < 100:
			Profile.archive["e%d" % int(e.id)] = {}
	for x: Dictionary in GameData.auras:
		if not (x.aura.get("stat", {}) as Dictionary).is_empty():
			Profile.collect(x)
			Profile.set_aura(CID, String(x.aura.kind), int(x.id))
			break


func _sheet() -> Dictionary:
	hero.level = 30
	hero.recalc_stats()
	return {"hp": hero.max_hp, "atk": hero.atk, "matk": hero.matk, "def": hero.defense, "crit": hero.crit,
		"spd": hero.atk_speed, "dmg": hero.dmg_mult, "cdr": hero.cdr}


func _test_switch() -> void:
	_mode("")
	Run.active = false
	check("menu : pas scellé", not Modes.sealed())
	_mode("")
	check("Aventure : pas scellé", not Modes.sealed())
	_mode("royale")
	check("Battle royale : scellé", Modes.sealed())
	_mode("survivor")
	check("Survivant : scellé", Modes.sealed())
	_mode("duel")
	check("Duel : pas scellé (règle JcJ : lot H5)", not Modes.sealed())
	_mode("")
	Modes.forced = "royale"
	check("mode imposé « royale » : scellé", Modes.sealed())
	Modes.forced = "tower"
	check("mode imposé « tower » : pas scellé", not Modes.sealed())
	Modes.forced = ""


func _test_stats() -> void:
	_fresh()
	_mode("")
	var fresh_adv := _sheet()
	_mode("royale")
	var fresh_br := _sheet()
	_opti()
	check("compte opti : talents, 7 certificats, archive, aura", not Profile.talents.get(CID, {}).is_empty()
		and Profile.certificates.size() >= 7 and not Archive.bonus().is_empty() and not Profile.aura_stats(CID).is_empty())
	_mode("")
	var ps_adv := Run.passive_stats()
	check("Aventure : talents et certificats dans les passifs (%d stats)" % ps_adv.size(), ps_adv.size() > 0)
	var opti_adv := _sheet()
	check("Aventure : le compte opti est plus fort (PV %.0f > %.0f, attaque %.0f > %.0f)" % [opti_adv.hp, fresh_adv.hp, opti_adv.atk, fresh_adv.atk],
		opti_adv.hp > fresh_adv.hp * 1.05 and opti_adv.atk > fresh_adv.atk * 1.05)
	var talented := -1
	for id in Profile.talents[CID]:
		var eff: Dictionary = GameData.talents.get(CID, {}).get("talents", {}).get(id, {}).get("effect", {})
		if String(eff.get("type", "")).begins_with("skill_"):
			talented = int(eff.skill)
			break
	var st_adv := Run.skill_talent(talented)
	check("Aventure : talent de sort actif (sort %d)" % talented, talented > 0 and (st_adv.dmg != 0.0 or st_adv.cd != 0.0 or st_adv.duration != 0.0 or st_adv.power != 0.0))
	check("Aventure : certificats proposés en carte", not Run.certificate_pool().is_empty())
	for m in ["royale", "survivor"]:
		_mode(m)
		check("%s : aucun talent ni certificat dans les passifs" % m, Run.passive_stats().is_empty())
		var st := Run.skill_talent(talented)
		check("%s : aucun talent de sort" % m, st.dmg == 0.0 and st.cd == 0.0 and st.duration == 0.0 and st.power == 0.0)
		check("%s : aucun certificat proposé en carte" % m, Run.certificate_pool().is_empty())
	_mode("royale")
	var opti_br := _sheet()
	var same := true
	for k in fresh_br:
		if not is_equal_approx(float(opti_br[k]), float(fresh_br[k])):
			same = false
			print("      %s : opti %.4f, neuf %.4f" % [k, float(opti_br[k]), float(fresh_br[k])])
	check("Battle royale : compte opti = compte neuf (PV %.0f, attaque %.0f)" % [opti_br.hp, opti_br.atk], same)


func _test_cards() -> void:
	_fresh()  # maîtrise 0 : la plupart des sorts fermés, cartes à débloquer fermées
	var all_ids: Array = Run.class_data().get("skills", []).map(func(s): return int(s.id))
	_mode("")
	var adv: Array = Run.roll_cards(99, true).map(func(c): return int(c.id))
	_mode("royale")
	var br: Array = Run.roll_cards(99, true).map(func(c): return int(c.id))
	check("Aventure, maîtrise 0 : sorts fermés (%d / %d proposés)" % [adv.size(), all_ids.size()], adv.size() < all_ids.size())
	br.sort()
	all_ids.sort()
	check("Battle royale : le kit entier proposé (%d sorts)" % br.size(), br == all_ids)
	var locked: Array = Boons.all().filter(func(d): return not Cards.unlock_rule(String(d.id)).is_empty() and not Cards.card_unlocked(String(d.id)) \
		and not d.has("requires") and not d.get("instant", false)).map(func(d): return String(d.id))
	check("compte neuf : des cartes à débloquer (%d)" % locked.size(), not locked.is_empty())
	_mode("")
	Run.skills = [{"id": int(all_ids[0]), "rank": 1}]
	var adv_p: Array = []
	for i in 30:
		adv_p += Run.roll_cards(99).filter(func(c): return String(c.type) == "passive").map(func(c): return String(c.id))
	_mode("royale")
	Run.skills = [{"id": int(all_ids[0]), "rank": 1}]
	var br_p: Array = []
	for i in 30:
		br_p += Run.roll_cards(99).filter(func(c): return String(c.type) == "passive").map(func(c): return String(c.id))
	check("Aventure : aucune carte fermée proposée", not adv_p.any(func(id): return id in locked))
	check("Battle royale : cartes fermées du compte proposées", br_p.any(func(id): return id in locked))
	check("Battle royale : aucun certificat en carte", not br_p.any(func(id): return String(id).begins_with("cert:")))


func _test_knock() -> void:
	var key := ""
	for c in GameData.talents:
		for p in GameData.talents[c].get("certificates", []):
			var k := "%s/%s" % [c, p]
			if String(TalentsPage.cert_passive(k).get("desc", "")).contains("insensible aux renversements"):
				key = k
				break
		if key != "":
			break
	check("certificat « insensible aux renversements » trouvé (%s)" % key, key != "")
	Profile.certificates = [key]
	_mode("")
	check("Aventure : certificat porté = insensible aux renversements", hero.knock_immune())
	_mode("royale")
	check("Battle royale : certificat du compte sans effet", not hero.knock_immune())
	Run.passives = {"cert:" + key: 1}
	check("Battle royale : carte de certificat de la run garde son effet", hero.knock_immune())
	Profile.certificates = []
	Run.passives = {}


func _test_survivor() -> void:
	_opti()
	_mode("survivor")
	check("Survivant : passifs du compte coupés (comme avant)", Run.passive_stats().is_empty())
	_mode("duel")
	Duel.bare = false
	check("Duel équipé : talents et certificats gardés", not Run.passive_stats().is_empty())
	Duel.active = false
