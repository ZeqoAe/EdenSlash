extends Node
## Tout texte que le joueur peut lire est en français (passe P10). Parcourt les objets (coffres, Armurerie, panoplies),
## leurs passifs, les sorts, certificats, cartes, boons, trophées, succès, titres, monstres, zones, et toutes les tables
## de constantes des scripts du jeu, puis signale les mots anglais courants (liste de contrôle).
## godot --headless --path game res://tests/test_texts_fr.tscn

var fails := 0
var flagged: Dictionary = {}  # source -> [textes]

## Liste de contrôle : mots anglais courants qui ne sont pas des mots français.
const ENGLISH := ["the", "of", "and", "you", "your", "with", "this", "that", "when", "after", "before", "each", "while",
	"damage", "target", "hits", "cooldown", "seconds", "from", "will", "are", "was", "has", "have", "deals", "increase",
	"increases", "reduces", "enemy", "enemies", "reward", "rewards", "health", "attack", "defense", "speed",
	"power", "magic", "sword", "axe", "bow", "boots", "gloves", "gauntlets", "bracers", "helmet", "crown", "cloak",
	"belt", "necklace", "armor", "shield", "staff", "wand", "blade", "hammer", "mace", "dagger", "pistol",
	"dark", "holy", "fire", "flame", "ice", "storm", "spirit", "soul", "blood", "heart", "eagle", "wolf", "king",
	"queen", "knight", "knights", "light", "shadow", "death", "moon", "sun", "ancient", "eternal", "sacred",
	"cursed", "accursed", "awaken", "ascended", "corrupted", "guardian", "battle", "steel", "iron", "gold",
	"golden", "silver", "leather", "feather", "wing", "wings", "thunder", "lightning", "wind", "sky", "demon", "devil",
	"angel", "mystic", "great", "hat", "tunic", "vestment", "greaves", "shoes", "mask", "serial",
	"number", "warrior", "hunter", "wizard", "witch", "priest", "soldier", "guard", "giant", "lily", "owl",
	"wanderer", "exile", "spider", "snake", "rock", "stone", "crystal", "wrath", "fury", "anger",
	"skill", "skills", "spell", "chest", "monster", "monsters", "player", "shop", "quest",
	"close", "open", "back", "next", "save", "load", "cancel", "confirm", "loading", "victory", "defeat", "empty",
	"locked", "unlocked", "none", "unknown", "error", "click", "press", "select", "choose",
	"heal", "heals", "shields", "restores", "restore", "critical", "stuns", "slows", "slow", "freeze", "freezes",
	"burn", "burns", "poison", "bleed", "bleeds", "summon", "summons", "nearby", "within", "every", "upon", "its",
	"their", "them", "than", "then", "only", "also", "all", "for", "to", "in", "by", "is", "be", "can", "it"]
## Jargon accepté (mots du jeu courants en français).
const ALLOWED := ["boss", "stun", "buff", "debuff", "item", "items", "ring", "level", "star", "magic", "poison", "slow", "burn", "light", "power",
	"hat", "mask", "stone", "rock", "wing", "wings", "guard", "number", "load", "save", "open", "close", "back", "next", "error", "empty", "none",
	"select", "great", "dark", "sun", "ice", "fire", "gold"]
## Clés dont la valeur n'est jamais affichée (identifiants, chemins, noms d'origine d'Eden).
const SKIP_KEYS := ["id", "icon", "eden", "eden_name", "eden_desc", "eden_stat", "name_en", "fx", "anim", "model", "outfit", "src",
	"code", "codes", "img", "path", "key", "kind", "stat", "stats", "trigger", "effect", "status", "color", "bus", "parts",
	"body", "body_model", "appearance", "weapons", "anims", "combo", "family", "parent", "class_id", "tier", "dmg_type",
	"weapon_type", "attributes", "base", "unlock_cond", "variants", "skin", "mount", "aura", "scene", "sfx", "shape"]


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


## Mots anglais de [param s] (vide si le texte est en français). Un texte dont le seul « mot anglais » est un mot
## de jargon courant (ALLOWED) n'est pas signalé.
func _english_in(s: String) -> Array:
	var clean := s.to_lower().replace("battle royale", "")
	for ch in ["'", "’", "(", ")", ":", ",", "-", ".", "!", "?", ";", "%", "+", "×", "·", "/", "[", "]", "
", "\"", "—", "–", "=", "<", ">", "*"]:
		clean = clean.replace(ch, " ")
	var hits: Array = []
	for w in clean.split(" ", false):
		if w in ENGLISH and not (w in ALLOWED) and not (w in hits):
			hits.append(w)
	return hits


func _note(source: String, text: String) -> void:
	var w := _english_in(text)
	if w.is_empty():
		return
	if not flagged.has(source):
		flagged[source] = {}
	flagged[source][text] = w


func _strip(bb: String) -> String:
	var re := RegEx.create_from_string("\\[[^\\]]*\\]")
	return re.sub(bb, "", true)


## Parcourt récursivement un dictionnaire / tableau / texte et note les textes anglais.
func _walk(source: String, v: Variant, key := "", depth := 0) -> void:
	if depth > 8:
		return
	if v is String:
		if key in SKIP_KEYS:
			return
		var s: String = v
		if s.begins_with("res://") or s.begins_with("user://") or s.length() < 3:
			return
		# un identifiant (un mot en minuscules, avec ou sans « _ ») n'est pas un texte lisible
		if not s.contains(" ") and (s == s.to_lower() or s.contains("_")):
			return
		_note(source + "." + key, s)
	elif v is Dictionary:
		for k in v:
			_walk(source, v[k], str(k), depth + 1)
	elif v is Array:
		for x in v:
			_walk(source, x, key, depth + 1)


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	# 0. le détecteur lui-même
	check("détecteur : un texte d'Eden en anglais est signalé", _english_in("When attacking, 5% chance to apply a DoT to the target").size() > 0 and _english_in("Bone Shattered Harvest Axe").size() > 0)
	check("détecteur : un texte français passe", _english_in("à l'impact, 10 % de chances : Puissance (6 s)").is_empty() and _english_in("Hache de bataille de la Rage").is_empty())

	# 1. tables de constantes de tous les scripts du jeu (cartes, boons, trophées, succès, titres, épreuves, textes d'aide…)
	var n_scripts := 0
	for gc in ProjectSettings.get_global_class_list():
		var path := String(gc.path)
		if path.contains("/ml/") or path.contains("/tools/") or path.contains("/tests/") or path.contains("dev_") or path.contains("test_tools"):
			continue
		var sc: Script = load(path)
		if sc == null:
			continue
		n_scripts += 1
		var cm := sc.get_script_constant_map()
		for cname in cm:
			if cname in SKIP_KEYS:
				continue
			_walk("%s.%s" % [str(gc["class"]), str(cname)], cm[cname], str(cname))
	check("%d scripts de classe parcourus (constantes de texte)" % n_scripts, n_scripts > 100)

	# 2. données chargées : classes (sorts, certificats, passifs), monstres, zones
	for cid in GameData.classes:  # « name » = nom anglais d'origine, jamais affiché (name_fr l'est)
		var cd: Dictionary = (GameData.classes[cid] as Dictionary).duplicate()
		cd.erase("name")
		_walk("classe " + str(cid), cd)
	for mid in GameData.monsters:  # « title » : titre d'origine, jamais affiché
		var md: Dictionary = (GameData.monsters[mid] as Dictionary).duplicate()
		md.erase("title")
		_walk("monstre", md)
	_walk("zones", GameData.zones)
	_walk("talents", GameData.talents)
	_walk("passifs communs", GameData.common_passives)
	_walk("types d'arme", GameData.weapon_types)

	# 3. équipement : cartes complètes (nom, passif, panoplie) de toutes les pièces d'Eden
	var n_items := 0
	for e in GameData.eden_items:
		n_items += 1
		var it := Items.from_eden(e, int(e.get("level", 1)))
		it["rarity"] = maxi(int(it.get("rarity", 0)), Items.MYTHIC) if e.has("passive") else int(it.get("rarity", 0))
		if e.has("passive"):
			it["passive"] = e.passive
		_note("carte d'objet", _strip(Items.describe(it, true)))
	check("%d cartes d'objets d'Eden lues (nom, passif, panoplie)" % n_items, n_items > 5000)
	for sid in GameData.eden_sets:
		_note("panoplie d'Eden (nom)", String(GameData.eden_sets[sid].get("name", "")))
	for sid in Items.SETS:
		_walk("panoplie du jeu " + String(sid), Items.SETS[sid])
		for n in Items.set_tiers(String(sid)):
			_note("palier de panoplie du jeu", " ; ".join(Items.bonus_lines(Items.set_bonus(String(sid), int(n)))))

	# 4. trophées (effets), boons, cartes de classe, succès
	for kind in Trophies.KINDS:
		for r in range(0, 6):
			var p := Trophies.passive_for({"trophy": kind, "level": 40}, r)
			_note("trophée " + String(kind), String(p.name) + " : " + String(p.desc))
	for b in Boons.all():
		_walk("boon " + String(b.get("id", "")), b)
	for cid in GameData.classes:
		for c in Cards.class_cards(String(cid)):
			_walk("carte de classe " + String(cid), c)
	_walk("succès", Achievements.LIST)
	for t in Achievements.titles():
		_note("titre", String(t))

	# 4b. lot GX-3 : objectifs (ce qui manque, conseil), pastilles du sac, verdicts, pastilles de plan
	var gx3_wt := Items.default_weapon_type("warrior")
	var gpool := GearShopPage.tier_pool(1, 1, "head", gx3_wt)
	if not gpool.is_empty():
		var gid := Goals.piece_id(int(gpool[0].id))
		Goals.follow(gid)
		for st in [[false, 0], [true, 0], [true, 100000]]:
			Profile.seen_gear = [int(gpool[0].id)] if bool(st[0]) else []
			Profile.insignia = int(st[1])
			var s := Goals.status(gid)
			_note("objectif", String(s.line))
			for step in s.steps:
				_note("objectif (étape)", String(step.text))
			_note("objectif (boussole)", String(Goals.advice().get("text", "")))
		Goals.unfollow(gid)
		Profile.seen_gear = []
		Profile.insignia = 0
	for c in InventoryPage.CHIPS:
		_note("sac (pastille)", String(c[1]) + " : " + String(c[2]))
	var vw := Items.generate(30, 0.5, "chest", "warrior", 3, "", 5)
	_note("verdict", _strip(Items.verdict_line(vw, Items.generate(10, 0.5, "chest", "warrior", 1, "", 5), true)))
	_note("verdict", _strip(Items.verdict_line(vw, {}, false)))

	# 5. apparences et collection (noms) : comptés, signalés seulement pour le bilan
	var cos_bad := 0
	for c in GameData.cosmetics:
		if not _english_in(String(c.name)).is_empty():
			cos_bad += 1
			if "--all" in OS.get_cmdline_user_args():
				print("  APPARENCE : ", c.name, " <= ", c.get("name_en", ""))
	var col_bad := 0
	for c in GameData.collection:
		if not _english_in(String(c.name)).is_empty():
			col_bad += 1
			if "--all" in OS.get_cmdline_user_args():
				print("  COLLECTION : ", c.name, " <= ", c.get("name_en", ""))
	print("INFO  apparences avec mot anglais : %d / %d ; collection : %d / %d" % [cos_bad, GameData.cosmetics.size(), col_bad, GameData.collection.size()])

	# 5b. points précis : talents traduits (nom d'origine gardé), passif d'Eden sans nom anglais, ids intacts
	var kat: Dictionary = GameData.talents.get("samurai", {}).get("talents", {}).get("52463", {})
	check("talent « Katana Specialization » -> « %s » (nom d'origine gardé, id inchangé)" % kat.get("name", ""),
		String(kat.get("name", "")) == "Spécialisation katana" and String(kat.get("name_en", "")) == "Katana Specialization")
	var with_passive: Dictionary = GameData.eden_items.filter(func(e): return e.has("passive") and (e.passive as Dictionary).has("eden"))[0]
	var card := _strip(Items.describe(Items.from_eden(with_passive, 50), true))
	check("carte d'une pièce à passif d'Eden : « ✶ Passif : effet » sans nom anglais (%s)" % String(with_passive.passive.name), card.contains("✶ Passif : ") and not card.contains(String(with_passive.passive.name)))
	var trophy_card := _strip(Items.describe({"name": "Test", "slot": "trophy", "rarity": 3, "level": 10, "passive": Trophies.passive_for({"trophy": "agi", "level": 10}, 3)}, true))
	check("passif d'un trophée de la run : garde son nom français", trophy_card.contains("✶ Passif — "))

	# 5c. Survivant (lot SVX-2) : les mots du joueur (BIBLE § 12) : ni « run », ni « build », ni « set », ni « lobby »
	var sv_texts: Array = [SurvivorGear.LOCK_TEXT]
	for t in ["sv_piece", "sv_weapon", "sv_piece_up", "skill", "sv_evolution"]:
		var fake := {"type": t, "item": {"set": "x"}, "offer": {"passives": [{"id": "ember"}]}}
		sv_texts.append(SurvivorCards.ban_tip(fake))
		sv_texts.append(SurvivorCards.ban_label(fake))
	for t in SurvivorCards.FALLBACK:
		var fc := SurvivorCards.fallback_card(String(t))
		sv_texts.append(String(fc.title) + " " + String(fc.desc))
	for p in Survivor.PALIERS:
		sv_texts.append(String(p.name) + " " + String(p.rule) + " " + String(p.tip))
	for id in ["sv_first", "sv_locked", "sv_tier"]:
		sv_texts.append(String(Tutorial.card_spec(id).get("short", "")))
	for k in ["weapon", "dot", "other", "set:x"]:
		sv_texts.append(String(SurvivorLog.source(k).name))
	var bp := SurvivorBuildPage.new()
	sv_texts.append(bp.subtitle())
	bp.free()
	var sv_bad: Array = []
	for t in sv_texts:
		var low := String(t).to_lower()
		for ch in ["'", "’", "(", ")", ":", ",", ".", "!", "?", ";", "«", "»", "·", "/", "\n", "-"]:
			low = low.replace(ch, " ")
		for w in low.split(" ", false):
			if w in ["run", "runs", "build", "builds", "set", "sets", "lobby", "jce"]:
				sv_bad.append("%s (« %s »)" % [w, String(t).left(60)])
	check("Survivant : aucun « run / build / set / lobby » côté joueur %s" % str(sv_bad.slice(0, 4)), sv_bad.is_empty())

	# 5e. Battle royale, lot BR-I3 : annonces, onomatopées, fiches, intentions, sons, aide du largage
	var br_src := FileAccess.get_file_as_string("res://scripts/core/royale_director.gd") + FileAccess.get_file_as_string("res://scripts/ui/royale_hud.gd")
	var br_rx := RegEx.create_from_string("(?:message\\.emit|push|feed|word)\\(\"([^\"]+)\"")
	var br_texts: Array = []
	for m in br_rx.search_all(br_src):
		br_texts.append(m.get_string(1).replace("\\n", " "))
	for id in RoyaleHud.TIPS:
		br_texts.append(String(RoyaleHud.TIPS[id].title) + " : " + String(RoyaleHud.TIPS[id].body))
	for k in RoyaleDirector.INTENT:
		br_texts.append(String(RoyaleDirector.INTENT[k]))
	for k in RoyaleCues.KINDS:
		br_texts.append(String(RoyaleCues.KINDS[k][0]))
	var br_bad: Array = []
	for t in br_texts:
		_note("Battle royale (annonces, fiches)", String(t))
		var low := String(t).to_lower()
		for ch in ["'", "’", "(", ")", ":", ",", ".", "!", "?", ";", "«", "»", "·", "/", "-"]:
			low = low.replace(ch, " ")
		for brw in low.split(" ", false):
			if brw in ["run", "runs", "build", "builds", "lobby", "spawn", "loot", "ping"]:
				br_bad.append("%s (« %s »)" % [brw, String(t).left(60)])
	check("Battle royale : %d annonces et fiches, ni « run / build / lobby / spawn / loot / ping » %s" % [br_texts.size(), str(br_bad.slice(0, 4))],
		br_texts.size() > 20 and br_bad.is_empty())

	# 5c. HUD de boss v2, page Donjons v2, journal des rencontres (lot DNG-2) : noms, consignes, annonces, lignes de butin
	for t in BossBricks.DEFS.keys() + BossBrain.KIT:
		_note("barre de boss", BossBar.mech_name(String(t)) + " · " + String(BossBar.CAST_HINT.get(t, "")))
		_note("page Donjons", BossBricks.hint_of(String(t)))
	for k in BossBar.SHORT:
		_note("annonce courte", String(BossBar.SHORT[k]))
	for id in BossLibrary.ids():
		_note("journal des rencontres", DungeonPage.missing_line(String(id), Encounters.missing_slots(String(id)), BossLibrary.loot(String(id)).slots))
	_note("frise", BossTimeline.when_text({"in": 6.0}) + " " + BossTimeline.when_text({"now": true}) + " " + BossTimeline.when_text({"in": -1.0, "at": 0.35}))
	check("HUD de boss v2 : chaque mécanique a un nom français", (BossBricks.DEFS.keys() + BossBrain.KIT).all(func(t): return BossBar.mech_name(String(t)) != ""))

	# 6. bilan : tout texte signalé
	var total := 0
	for src in flagged:
		var d: Dictionary = flagged[src]
		total += d.size()
		var shown := 0
		for t in d:
			if shown < (500 if "--all" in OS.get_cmdline_user_args() else 6):
				print("  ANGLAIS [%s] (%s) : %s" % [src, ",".join(PackedStringArray(d[t])), String(t).left(140)])
			shown += 1
		if d.size() > 6:
			print("  ANGLAIS [%s] … et %d autres" % [src, d.size() - 6])
	check("aucun texte anglais lisible par le joueur (%d signalés dans %d sources)" % [total, flagged.size()], total == 0)
	check("apparences : aucun mot anglais dans leur nom", cos_bad == 0)
	print("TOUT OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
