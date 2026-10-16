extends Node
## Lot S3 du Survivant (conception/survivor, DECISIONS_JOUEUR §2, §4, §5) : cartes. Premier choix (armes de types
## différents et compétences, sans « Passer »), offres tirées sur des états aléatoires (garanties, au plus 2 nouvelles
## pièces, cibles distinctes, jamais de carte commune, sorts ≤ 6, niveaux 5 et 10 de sort), application de chaque type,
## passif de palier affiché = appliqué, relances (2 de base, nouveau tirage du passif), bannissement (sort, set, passif),
## garder, passer, cartes des coffres, choix du Bot, neutralisation de la progression du compte, hub intact :
## godot --headless --path game res://tests/test_sv3.tscn   (SV3_ROLLS=N : nombre de tirages, 10 000 par défaut)

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	Profile.save_profile()
	SurvivorCards.seed_with(31)
	_neutral_setup()
	_neutral_baseline()
	var hub := _hub()  # (après la Survie de référence, qui compte pour le compte)
	Survivor.start("warrior", "limestone")
	_first()
	_neutral_in_run()
	_rolls()
	_apply()
	_rerolls_and_bans()
	_keep_skip()
	_chests()
	_bot()
	await _picker()
	Run.finish("abandon")
	Profile.end_run_survival()
	check("hub intact après la run (équipement, préréglages, progression du compte)", _hub() == hub)
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	Profile.reset_all()
	get_tree().quit(1 if fails > 0 else 0)


func _hub() -> String:
	var eq := {}
	for s in Profile.equipped:
		eq[s] = String(Profile.equipped[s].get("uid", ""))
	var keys := {}
	for k in Survivor.HUB_KEYS:
		keys[k] = SurvivorRewards.hub_view(k, Profile.get(k))
	return JSON.stringify([Profile.vault.map(func(it): return String(it.get("uid", ""))), Profile.loadout, Profile.presets, eq, keys], "", true)


# --- neutralisation de la progression du compte -----------------------------------------------------------------------
var _talent := ""
var _talent_stat := ""
var _cert_stat := ""


## Compte avec un talent de statistique, un certificat posé et aucune maîtrise (sorts verrouillés hors Survivant).
func _neutral_setup() -> void:
	var tree: Dictionary = GameData.talents.get("warrior", {}).get("talents", {})
	for id in tree:
		var eff: Dictionary = tree[id].get("effect", {})
		if String(eff.get("type", "")) == "stat":
			_talent = String(id)
			_talent_stat = String(eff.stat)
			break
	Profile.talents["warrior"] = {_talent: 3} if _talent != "" else {}
	for p in GameData.class_data("warrior").get("passives", []):
		if not (p.get("stat", {}) as Dictionary).is_empty():
			Profile.certificates = ["warrior/" + String(p.id)]
			_cert_stat = String((p.stat as Dictionary).keys()[0])
			break
	Profile.save_profile()


func _neutral_baseline() -> void:
	Run.start_survival("warrior", 1)
	var ps := Run.passive_stats()
	check("hors Survivant : talents et certificats comptent (%s, %s)" % [_talent_stat, _cert_stat],
		_talent != "" and _cert_stat != "" and float(ps.get(_talent_stat, 0.0)) > 0.0 and float(ps.get(_cert_stat, 0.0)) > 0.0)
	var locked: Array = Run.class_data().get("skills", []).filter(func(s): return not Progression.skill_unlocked("warrior", int(s.id)))
	check("hors Survivant : des sorts restent fermés par la maîtrise (%d)" % locked.size(), not locked.is_empty())
	Run.finish("abandon")
	Profile.end_run_survival()


func _neutral_in_run() -> void:
	var ps := Run.passive_stats()
	check("Survivant : ni talents ni certificats ni plateau dans les stats (%s)" % ps, ps.is_empty())
	var sk: Array = Run.class_data().get("skills", [])
	var all_zero := true
	for s in sk:
		var t := Run.skill_talent(int(s.id))
		all_zero = all_zero and is_zero_approx(float(t.dmg)) and is_zero_approx(float(t.cd)) and is_zero_approx(float(t.power))
	check("Survivant : aucun talent de sort", all_zero)
	check("Survivant : tout le kit de la classe, sans la maîtrise du compte (%d / %d sorts)" % [SurvivorCards.spells_open().size(), sk.size()],
		SurvivorCards.spells_open().size() == sk.size() and sk.size() > Progression.BASE_SKILLS)
	check("Survivant : aucune carte commune ni certificat proposable (passifs = pièces)", SurvivorCards.candidates().all(func(c): return c.kind != "passive"))


# --- premier choix -----------------------------------------------------------------------------------------------------------
func _first() -> void:
	var ok := true
	var both := true
	var distinct := true
	for i in 200:
		var cards := Run.roll_cards(3)
		ok = ok and cards.size() == 3 and cards.all(func(c): return String(c.type) in ["sv_weapon", "skill"] and c.get("sv_first", false))
		both = both and cards.any(func(c): return c.type == "sv_weapon") and cards.any(func(c): return c.type == "skill")
		var types: Array = cards.filter(func(c): return c.type == "sv_weapon").map(func(c): return String(c.wtype))
		var seen := {}
		for t in types:
			distinct = distinct and not seen.has(t)
			seen[t] = true
	check("premier choix : seulement des armes et des compétences (200 tirages)", ok)
	check("premier choix : au moins une arme et une compétence", both)
	check("premier choix : armes de types tous différents", distinct)
	check("premier choix : pas de « Passer »", not SurvivorCards.can_skip(SurvivorCards.first_offer()))
	check("premier choix : 2 relances de base", SurvivorCards.rerolls_left() == 2 and Run.rerolls_left() == 2)


# --- tirages sur des états aléatoires ------------------------------------------------------------------------------------
func _random_state(rng: RandomNumberGenerator) -> void:
	Profile.equipped = {}
	Run.skills.clear()
	Run.chains.clear()
	Run.passives.clear()
	Run.passive_power.clear()
	Run.weapon_ups = {}
	Run.kept.clear()
	Run.banned.clear()
	Run.hero_level = rng.randi_range(1, 40)
	var nothing := rng.randf() < 0.05
	if not nothing and rng.randf() < 0.85:
		var w := SurvivorGear.make_weapon(String(SurvivorPool.weapon_types()[rng.randi() % SurvivorPool.weapon_types().size()]), {"rng": rng})
		SurvivorGear.equip(w)
		w.upgrade = 2 * rng.randi_range(0, 5)
	var fill := rng.randf()
	for slot in SurvivorPool.slots():
		if not nothing and rng.randf() < fill:
			var it := SurvivorGear.make_piece(slot, {"rng": rng})
			if SurvivorGear.equip(it):
				it.upgrade = 2 * rng.randi_range(0, 5)
	var ids: Array = Run.class_data().get("skills", []).map(func(s): return int(s.id))
	var nsp := 0 if nothing else rng.randi_range(0, Survivor.SPELL_MAX)
	for i in nsp:
		var e := {"id": int(ids[i]), "rank": rng.randi_range(1, 10)}
		if i < Run.MAX_SKILLS:
			Run.skills.append(e)
		else:
			var slot := (i - Run.MAX_SKILLS) % Run.MAX_SKILLS
			var ch: Array = Run.chain_of(slot).duplicate()
			ch.append(e)
			Run.chains[slot] = ch
	if rng.randf() < 0.3:  # prérequis d'une évolution parfois portés
		Run.passives["static_blade"] = 1
		Run.passive_power["static_blade"] = 1.0


func _rolls() -> void:
	var n := int(OS.get_environment("SV3_ROLLS")) if OS.get_environment("SV3_ROLLS") != "" else 10000
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var bad := {"size": 0, "pieces": 0, "equip": 0, "spell": 0, "keys": 0, "boon": 0, "spells6": 0, "filled": 0, "tier5": 0,
		"tier10": 0, "noweapon": 0, "net": 0, "dead": 0}
	var seen_types := {}
	var dead_offers := 0
	for i in n:
		_random_state(rng)
		var cands := SurvivorCards.candidates()
		var had_equip := cands.any(func(c): return c.fam == "equip")
		var had_spell := cands.any(func(c): return c.fam == "spell")
		var had_new := cands.any(func(c): return c.kind == "spell_new")
		var cards := Run.roll_cards(3)
		var types: Array = cards.map(func(c): return String(c.type))
		for t in types:
			seen_types[t] = int(seen_types.get(t, 0)) + 1
		if cards.size() != 3:
			bad.size += 1
		if types.count("sv_piece") > SurvivorCards.NEW_PIECES_MAX:
			bad.pieces += 1
		var fams: Array = types.map(func(t): return SurvivorCards.FAMILY.get(t, "?"))
		if had_equip and not "equip" in fams and not _first_case():
			bad.equip += 1
		if had_spell and not "spell" in fams and not _first_case():
			bad.spell += 1
		var keys: Array = cards.map(func(c): return String(c.get("sv_key", "")))
		var uniq := {}
		for k in keys:
			uniq[k] = true
		if uniq.size() != keys.size() or keys.has(""):
			bad.keys += 1
		if types.has("passive") or types.has("trophy") or types.has("gear"):
			bad.boon += 1
		if Run.all_skills().size() >= Survivor.SPELL_MAX and (types.has("skill") or types.has("chain")):
			bad.spells6 += 1
		for c in cards:
			if c.type == "sv_piece" and not Profile.equipped.get(String(c.slot), {}).is_empty():
				bad.filled += 1
			if c.type == "upgrade":
				var to := int(c.rank_to)
				if to == 5 and Cards.TIER_ORDER.find(String(c.tier)) < 2:
					bad.tier5 += 1
				if to == 10 and String(c.tier) != "legendary":
					bad.tier10 += 1
		if Profile.equipped.get("weapon", {}).is_empty() and not _first_case() and not types.has("sv_weapon"):
			bad.noweapon += 1
		if Run.all_skills().size() < 2 and had_new and not _first_case() and not (types.has("skill") or types.has("chain")):
			bad.net += 1
		if fams.all(func(f): return f == "fallback"):
			dead_offers += 1
			if not cands.is_empty():
				bad.dead += 1
	print("   %d tirages · types vus : %s · offres toutes en repli : %d" % [n, seen_types, dead_offers])
	check("toujours 3 cartes (%d)" % bad.size, bad.size == 0)
	check("jamais plus de 2 nouvelles pièces (%d)" % bad.pieces, bad.pieces == 0)
	check("une carte d'équipement quand c'est possible (%d)" % bad.equip, bad.equip == 0)
	check("une carte de sort quand c'est possible (%d)" % bad.spell, bad.spell == 0)
	check("cibles toutes différentes (%d)" % bad.keys, bad.keys == 0)
	check("jamais de carte commune, de trophée ni d'équipement de la Survie (%d)" % bad.boon, bad.boon == 0)
	check("%d sorts : plus de nouveau sort (%d)" % [Survivor.SPELL_MAX, bad.spells6], bad.spells6 == 0)
	check("emplacement pris jamais reproposé (%d)" % bad.filled, bad.filled == 0)
	check("sort mené au niveau 5 : au moins épique (%d) ; au niveau 10 : légendaire (%d)" % [bad.tier5, bad.tier10], bad.tier5 == 0 and bad.tier10 == 0)
	check("sans arme : une arme proposée (%d)" % bad.noweapon, bad.noweapon == 0)
	check("moins de 2 sorts : un nouveau sort proposé (%d)" % bad.net, bad.net == 0)
	check("jamais 3 cartes de repli quand une vraie carte existe (%d)" % bad.dead, bad.dead == 0)
	for t in ["sv_weapon", "sv_piece", "sv_piece_up", "sv_weapon_up", "skill", "chain", "upgrade", "sv_evolution"]:
		check("type « %s » proposé (%d)" % [t, int(seen_types.get(t, 0))], int(seen_types.get(t, 0)) > 0)


func _first_case() -> bool:
	return Profile.equipped.get("weapon", {}).is_empty() and Run.all_skills().is_empty()


# --- application -------------------------------------------------------------------------------------------------------------
func _clear() -> void:
	Profile.equipped = {}
	Run.skills.clear()
	Run.chains.clear()
	Run.passives.clear()
	Run.passive_power.clear()
	Run.weapon_ups = {}
	Run.kept.clear()
	Run.banned.clear()
	Run.bans_used = 0
	Run.locks_used = 0
	Run.rerolls_used = 0
	Run.hero_level = 12


func _apply() -> void:
	_clear()
	var w := SurvivorCards.weapon_card()
	Run.apply_card(w)
	check("arme : portée, verrouillée, type de la carte", Profile.equipped.get("weapon", {}).get("uid", "") == w.item.uid
		and SurvivorGear.locked("weapon") and Run.weapon_type() == String(w.wtype))
	var p := SurvivorCards.new_piece_card("chest")
	Run.apply_card(p)
	check("nouvelle pièce : portée et verrouillée (passif fixe ajouté)", is_same(Profile.equipped.get("chest"), p.item) and SurvivorGear.locked("chest")
		and Run.passives.has(String(p.item.sv_passives[0].id)))
	check("emplacement pris : plus de carte de nouvelle pièce", SurvivorCards.new_piece_card("chest").is_empty())
	# amélioration jusqu'à +10 : le passif écrit sur la carte est celui appliqué
	var shown_ok := true
	var applied_ok := true
	for i in 5:
		var u := SurvivorCards.up_card("chest", "common")
		for pv in u.offer.passives:
			shown_ok = shown_ok and String(u.desc).contains(String(Boons.get_def(String(pv.id)).name))
		Run.apply_card(u)
		for pv in u.offer.passives:
			applied_ok = applied_ok and String(pv.id) in SurvivorGear.passives_of(Profile.equipped.chest)
	var chest: Dictionary = Profile.equipped.chest
	check("amélioration de pièce : +2 par carte jusqu'à +10 (%d)" % int(chest.upgrade), int(chest.upgrade) == 10)
	check("passif de palier affiché sur la carte (+6, +8, +10)", shown_ok)
	check("passif affiché = passif appliqué ; 4 passifs distincts à +10 (%s)" % [SurvivorGear.passives_of(chest)], applied_ok
		and SurvivorGear.passives_of(chest).size() == 4)
	check("pièce à +10 : plus de carte d'amélioration", SurvivorCards.up_card("chest", "common").is_empty())
	# légendaire : +4, et le jet monte
	var b := SurvivorCards.new_piece_card("boots")
	Run.apply_card(b)
	b.item.quality = 1.0
	var lg := SurvivorCards.up_card("boots", "legendary")
	Run.apply_card(lg)
	check("amélioration légendaire : +4 (deux paliers) et jet relevé (%d, %.2f)" % [int(b.item.upgrade), float(b.item.quality)],
		int(b.item.upgrade) == 4 and float(b.item.quality) > 1.0)
	# arme : +2 et amélioration d'auto-attaque
	var wu := SurvivorCards.up_card("weapon", "rare")
	Run.apply_card(wu)
	check("amélioration d'arme : +2 et auto-attaque (rang %d)" % int(Run.weapon_ups.get("weapon", {}).get("rank", 0)),
		int(Profile.equipped.weapon.upgrade) == 2 and int(Run.weapon_ups.weapon.rank) == 2 and wu.type == "sv_weapon_up")
	# sorts : nouveau, enchaînement, amélioration jusqu'à 10
	var ids: Array = Run.class_data().get("skills", []).map(func(s): return int(s.id))
	for i in 4:
		Run.apply_card(SurvivorCards.spell_card(int(ids[i])))
	check("4 nouveaux sorts : les 4 cases", Run.skills.size() == 4)
	var ch := SurvivorCards.spell_card(int(ids[4]))
	Run.apply_card(ch)
	var chained: bool = String(ch.type) == "chain"
	for i in range(5, Survivor.SPELL_MAX):
		var c := SurvivorCards.spell_card(int(ids[i]))
		chained = chained and String(c.get("type", "")) == "chain"
		Run.apply_card(c)
	check("la grille entière : 12 sorts, les 4 cases et 2 enchaînements par case (%s)" % ch.type,
		Survivor.SPELL_MAX == Run.MAX_SKILLS * (1 + Run.MAX_CHAIN) and chained and Run.all_skills().size() == Survivor.SPELL_MAX
		and range(Run.MAX_SKILLS).all(func(k): return Run.chain_of(k).size() == Run.MAX_CHAIN))
	check("%d sorts : plus de nouveau sort" % Survivor.SPELL_MAX, SurvivorCards.spell_card(int(ids[Survivor.SPELL_MAX])).is_empty() if ids.size() > Survivor.SPELL_MAX else true)
	var sid := int(ids[0])
	var tiers: Array = []
	for i in 9:
		var c := SurvivorCards.spell_up_card(sid, "common")
		tiers.append(String(c.tier))
		Run.apply_card(c)
	var e := Run.skill_entry(sid)
	check("sort de 1 à 10 : effet cumulé (niv. %d, dégâts +%d %%, recharge -%d %%)" % [int(e.rank), roundi(float(e.get("dmg", 0)) * 100), roundi(float(e.get("cd", 0)) * 100)],
		int(e.rank) == 10 and float(e.get("dmg", e.get("heal", e.get("dur", 0.0)))) > 0.5 and float(e.cd) > 0.3)
	check("niveau 5 épique, niveau 10 légendaire (%s)" % [tiers], String(tiers[3]) == "epic" and String(tiers[8]) == "legendary")
	check("sort au niveau 10 : plus d'amélioration", SurvivorCards.spell_up_card(sid, "common").is_empty())
	# évolution
	Run.passives["static_blade"] = 1
	Run.passive_power["static_blade"] = 1.0
	check("évolution possible quand ses passifs sont portés", "storm_lord" in SurvivorCards.evolutions_open())
	Run.apply_card(SurvivorCards.evolution_card("storm_lord"))
	check("évolution prise : passif de la run, plus proposée", Run.passives.has("storm_lord") and not "storm_lord" in SurvivorCards.evolutions_open())
	# repli
	var g0 := Profile.gold
	Run.apply_card(SurvivorCards.fallback_card("sv_gold"))
	var r0 := Run.rerolls_left()
	Run.apply_card(SurvivorCards.fallback_card("sv_reroll"))
	check("repli : or et relance", Profile.gold > g0 and Run.rerolls_left() == r0 + 1)


# --- relances et bannissements ---------------------------------------------------------------------------------------------
func _rerolls_and_bans() -> void:
	_clear()
	Run.apply_card(SurvivorCards.weapon_card())
	var p := SurvivorCards.new_piece_card("head")
	Run.apply_card(p)
	p.item.upgrade = 4
	# relance d'une amélioration qui éveille : un nouveau tirage du passif
	var seen := {}
	for i in 30:
		var u := SurvivorCards.up_card("head", "common")
		seen[String(u.offer.passives[0].id)] = true
	check("relancer une amélioration à palier : autre passif tiré (%d différents sur 30)" % seen.size(), seen.size() >= 5)
	# bannir le passif d'une amélioration
	var u2 := SurvivorCards.up_card("head", "common")
	var banned_id := String(u2.offer.passives[0].id)
	check("amélioration à passif : bannissable (« %s »)" % SurvivorCards.ban_label(u2), SurvivorCards.can_ban(u2) and SurvivorCards.ban_label(u2) == "Bannir ce passif")
	var rep := Run.ban_card(u2, [u2])
	var never := true
	for i in 200:
		var u := SurvivorCards.up_card("head", "common")
		never = never and String(u.offer.passives[0].id) != banned_id
	check("passif banni : plus jamais tiré cette run ; remplaçant = même pièce, autre passif", never and rep.type == "sv_piece_up"
		and String(rep.offer.passives[0].id) != banned_id and String(rep.slot) == "head")
	# bannir un set
	var set_card: Dictionary = {}
	for i in 200:
		var c := SurvivorCards.new_piece_card("chest")
		if String(c.item.get("set", "")) != "":
			set_card = c
			break
	var sid := String(set_card.item.set)
	check("pièce de set : « Bannir le set »", SurvivorCards.ban_label(set_card) == "Bannir le set")
	Run.ban_card(set_card, [set_card])
	var no_set := true
	for i in 300:
		var c := SurvivorCards.new_piece_card(["chest", "legs", "gloves", "boots"][i % 4])
		no_set = no_set and String(c.item.get("set", "")) != sid
	check("set banni : plus aucune de ses pièces (%s)" % SurvivorPool.panoply_name(sid), no_set)
	# bannir un sort
	var spell := SurvivorCards.spell_card(int(Run.class_data().skills[2].id))
	Run.ban_card(spell, [spell])
	check("sort banni : plus proposé", not SurvivorCards.spells_open().any(func(s): return int(s.id) == int(spell.id)))
	check("3 bannissements par run : le 4e est refusé", SurvivorCards.bans_left() == 0 and Run.ban_card(SurvivorCards.spell_card(int(Run.class_data().skills[3].id)), []).is_empty()
		and not SurvivorCards.can_ban(SurvivorCards.spell_card(int(Run.class_data().skills[3].id))))
	check("l'amélioration de sort ne se bannit pas", not SurvivorCards.can_ban({"type": "upgrade"}))


# --- garder et passer --------------------------------------------------------------------------------------------------------
func _keep_skip() -> void:
	_clear()
	Run.apply_card(SurvivorCards.weapon_card())
	var p := SurvivorCards.new_piece_card("legs")
	Run.apply_card(p)
	p.item.upgrade = 4
	var u := SurvivorCards.up_card("legs", "rare")
	check("garder une amélioration à passif", SurvivorCards.keep(u) and Run.locks_used == 1)
	var next := Run.roll_cards(3)
	var back: Array = next.filter(func(c): return c.type == "sv_piece_up" and String(c.slot) == "legs")
	check("la carte gardée revient telle quelle (même passif « %s », même rareté)" % String(u.offer.passives[0].id), back.size() == 1
		and String(back[0].offer.passives[0].id) == String(u.offer.passives[0].id) and String(back[0].tier) == "rare" and Run.kept.is_empty())
	var g0 := Profile.gold
	var g := SurvivorCards.skip()
	check("passer : de l'or (%d)" % g, g > 0 and Profile.gold == g0 + g and SurvivorCards.can_skip(next))


# --- coffres -----------------------------------------------------------------------------------------------------------------
func _chests() -> void:
	_clear()
	var wbox := SurvivorCards.chest_cards("sv_weapon")
	check("coffre d'arme sans arme : 3 armes de types différents", wbox.size() == 3 and wbox.all(func(c): return c.type == "sv_weapon"))
	Run.apply_card(wbox[0])
	var wb2 := SurvivorCards.chest_cards("sv_weapon")
	check("coffre d'arme : 3 améliorations de raretés différentes", wb2.size() == 3 and wb2.all(func(c): return c.type == "sv_weapon_up")
		and wb2.map(func(c): return c.tier).size() == 3 and wb2[0].tier != wb2[1].tier and wb2[1].tier != wb2[2].tier)
	var head := SurvivorCards.chest_cards("sv_head")
	check("coffre de tête (libre) : 3 pièces de tête, jamais deux du même set", head.size() == 3 and head.all(func(c): return c.type == "sv_piece" and c.slot == "head"))
	Run.apply_card(head[0])
	var head2 := SurvivorCards.chest_cards("sv_head")
	check("coffre de tête (pris) : l'amélioration de la tête d'abord", head2.size() == 3 and head2[0].type == "sv_piece_up" and head2[0].slot == "head")
	check("coffre de sort : des cartes de sort", SurvivorCards.chest_cards("sv_spell").all(func(c): return SurvivorCards.FAMILY.get(String(c.type), "") in ["spell", "fallback"]))
	check("coffre doré : 3 cartes", SurvivorCards.chest_cards("sv_gold").size() == 3)
	var gd := SurvivorCards.chest_cards("sv_guardian")
	check("coffre du gardien : des pièces d'emplacements libres différents", gd.size() == 3 and gd.filter(func(c): return c.type == "sv_piece").size() >= 2)
	var anvil := SurvivorCards.chest_cards("sv_anvil")
	check("enclume : améliorations des pièces portées (%d)" % anvil.size(), not anvil.is_empty() and anvil.all(func(c): return c.type in ["sv_piece_up", "sv_weapon_up"]))
	check("coffres : « Passer » possible", SurvivorCards.can_skip(head2))


# --- choix automatique (Bot, pilote) ----------------------------------------------------------------------------------------
func _bot() -> void:
	_clear()
	var first := SurvivorCards.first_offer()
	check("Bot : le premier choix prend l'arme", String(CardPicker.auto_pick(first).type) == "sv_weapon")
	var ok := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 300:
		_random_state(rng)
		var cards := Run.roll_cards(3)
		var pick := CardPicker.auto_pick(cards)
		ok = ok and not pick.is_empty() and pick in cards
		Run.apply_card(pick)
	check("Bot : une carte choisie et appliquée à chaque fois (300)", ok)


# --- interface : choix, Passer, Bannir --------------------------------------------------------------------------------------
func _picker() -> void:
	_clear()
	var picker := CardPicker.new()
	add_child(picker)
	var reroll := func(): return Run.roll_cards(3)
	picker.offer("Choisis ton arme ou ta première compétence", SurvivorCards.first_offer(), func(): return SurvivorCards.first_offer())
	await get_tree().process_frame
	check("interface : premier choix sans « Passer », relance présente", picker.is_open() and not picker._skip.visible and picker._reroll.visible)
	var before := Run.rerolls_used
	picker._do_reroll()
	check("interface : relancer consomme une relance et garde un premier choix", Run.rerolls_used == before + 1
		and picker._cards.all(func(c): return c.get("sv_first", false)) and not picker._skip.visible)
	picker._opened_at -= CardPicker.CONFIRM_DELAY_MS
	picker._choose(0)
	await get_tree().process_frame
	check("interface : choix fermé, jeu repris", not picker.is_open() and not get_tree().paused)
	Run.hero_level = 5
	picker.offer("Niveau 5 ! Choisis une carte", Run.roll_cards(3), reroll)
	await get_tree().process_frame
	await get_tree().process_frame
	check("interface : « Passer (+%d or) » sur une montée de niveau" % SurvivorCards.skip_gold(), picker._skip.visible
		and picker._skip.text == "Passer (+%d or)" % SurvivorCards.skip_gold())
	var g0 := Profile.gold
	picker._opened_at -= CardPicker.CONFIRM_DELAY_MS
	picker._do_skip()
	check("interface : Passer ferme le choix et donne l'or", not picker.is_open() and Profile.gold > g0)
	picker.queue_free()
