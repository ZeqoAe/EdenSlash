class_name AutochessItems
extends RefCounted
## L'Échiquier, lot AC-H : effets des objets (AutochessData.COMPONENTS, ITEMS, SPECIAL_ITEMS ; annexe B). Appelé par
## AutochessEffects (couche pure, aucun nœud) ; rapport : conception/autochess/R_AC_H.md.
## Stats : un objet complet donne la somme de ses deux composants (AutochessData.item_stats) + les stats de son effet ; un
## composant seul ses stats ; un emblème les stats de son composant (son trait est compté par AC-B : unit_traits).
## Effets : clé « effect » + « params » ; deux exemplaires du même objet doublent l'ampleur (pas la fréquence) ; les effets
## « une fois » restent une fois. Ordre fixe : objets dans l'ordre de ITEMS (pas celui du porteur).

## Clés de « params » qui sont des stats de fiche pour les objets à effet « stats » (le reste : hors fiche, ex. taille).
const PASSIVE_STATS := ["hp", "hp_pct", "atk_pct", "as_pct", "spell_pct", "mana_start", "def", "mdef", "crit", "crit_dmg",
	"dodge", "range", "dmg_taken", "scale"]


static func n(u: Dictionary, id: String) -> int:
	return int(u.icount.get(id, 0))


static func prm(id: String) -> Dictionary:
	return AutochessData.ITEMS[id].params


## Rend la valeur d'un paramètre × nombre d'exemplaires.
static func amp(u: Dictionary, id: String, key: String) -> float:
	return float(prm(id).get(key, 0.0)) * n(u, id)


## Objets complets portés, dans l'ordre fixe de ITEMS.
static func carried(u: Dictionary) -> Array:
	return AutochessData.ITEMS.keys().filter(func(id): return n(u, String(id)) > 0)


# --- Fiche ---------------------------------------------------------------------------------------------------------
## Nom donné par la SPEC (§8) : fiche finale d'une unité d'un contexte (objets, traits et atouts compris).
static func apply(unit_entry: Dictionary, ctx: Dictionary) -> Dictionary:
	return AutochessEffects.apply_stats(unit_entry, ctx)


static func stat_mods(u: Dictionary, _ctx: Dictionary, acc: Dictionary) -> void:
	for s in u.items:
		var info: Dictionary = Autochess.parse_item(String(s))
		var id := String(info.id)
		var stats: Dictionary = {}
		if id == "embleme":
			stats = AutochessData.item_stats(String(info.component)) if AutochessData.COMPONENTS.has(String(info.component)) else {}
		elif AutochessData.COMPONENTS.has(id) or AutochessData.ITEMS.has(id):
			stats = AutochessData.item_stats(id)
		for k in stats:
			_add(acc, String(k), float(stats[k]))
		if not AutochessData.ITEMS.has(id):
			continue
		var it: Dictionary = AutochessData.ITEMS[id]
		var p: Dictionary = it.params
		match String(it.effect):
			"stats":
				for k in p:
					if String(k) in PASSIVE_STATS:
						_add(acc, String(k), float(p[k]))
			"mana_max":  # Incantation
				acc["mana_max_pct"] += float(p.mana_max_pct)
			"insensible_debut":  # Brute
				acc["hp"] += float(p.hp)
			"epines":  # Robustesse
				acc["def"] += float(p.def)
			"cadence_montante":  # Lame vive
				acc["as_pct"] += float(p.as_pct)
			"sort_critique", "or_elimination":  # Sort critique, Fortune
				acc["crit"] += float(p.crit)


static func _add(acc: Dictionary, k: String, v: float) -> void:
	if acc.has(k):
		acc[k] = float(acc[k]) + v


## Persistance : zones des sorts plus longues et plus larges ({dur: s de plus, radius_pct}).
static func zone_mods(u: Dictionary) -> Dictionary:
	return {"dur": amp(u, "persistance", "dur"), "radius_pct": amp(u, "persistance", "radius_pct")}


# --- Coups ---------------------------------------------------------------------------------------------------------
## Avant un coup du porteur : Exécuteur, Tueur de géants, Écho ; Sort critique (les sorts peuvent critiquer).
static func pre_hit(ctx: Dictionary, hit: Dictionary) -> void:
	var a := AutochessEffects.unit(ctx, int(hit.src))
	var d := AutochessEffects.unit(ctx, int(hit.dst))
	if a.is_empty() or d.is_empty() or hit.proc:
		return
	if hit.attack:
		if n(a, "executeur") > 0 and AutochessEffects.hp_frac(d) < float(prm("executeur").below):
			hit["mult"] = float(hit.mult) + amp(a, "executeur", "dmg_pct")
		if n(a, "tueur_geants") > 0 and float(d.hp_max) > float(a.hp_max):
			hit["mult"] = float(hit.mult) + amp(a, "tueur_geants", "dmg_pct")
		if n(a, "echo") > 0 and a.st.get("echo_ready", false):
			a.st["echo_ready"] = false
			hit["mult"] = float(hit.mult) * (1.0 + (float(prm("echo").ratio) - 1.0) * n(a, "echo"))
			hit["tag"] = "echo"
	if hit.spell and n(a, "sort_critique") > 0:
		hit["can_crit"] = true


# --- Déclencheurs --------------------------------------------------------------------------------------------------
static func on_event(trigger: String, ev: Dictionary, ctx: Dictionary) -> void:
	match trigger:
		"debut_combat":
			for fid in AutochessTraits._sorted_units(ctx):
				var u: Dictionary = ctx.units[fid]
				if n(u, "brute") > 0:
					u["immune_until"] = float(prm("brute").dur)
					AutochessEffects.emit(ctx, {"type": "buff", "dst": fid, "stat": "cc_immune", "value": 1.0, "dur": float(prm("brute").dur),
						"tag": "brute"})
				if n(u, "nova_givre") > 0:
					u.st["nova_next"] = float(prm("nova_givre").every)
					_nova(ctx, fid)
				if n(u, "source") > 0:
					u.st["source_next"] = float(prm("source").every)
		"temps":
			_on_time(ctx)
		"attaque":
			_after_attack(ctx, ev)
		"coup_recu":
			_on_hit_taken(ctx, ev)
		"sort":
			_on_cast(ctx, int(ev.src))
		"sort_impact":
			var a := AutochessEffects.unit(ctx, int(ev.src))
			if n(a, "braise") > 0 and float(ev.dealt) > 0.0:
				var p := prm("braise")
				var d := AutochessEffects.unit(ctx, int(ev.dst))
				AutochessEffects.dot(ctx, int(ev.src), int(ev.dst), float(d.hp_max) * amp(a, "braise", "hp_pct") / float(p.dur),
					float(p.dur), "braise")
				AutochessEffects.cut_heal(ctx, int(ev.dst), float(p.heal_cut), float(p.dur))
		"critique":
			var a := AutochessEffects.unit(ctx, int(ev.src))
			if n(a, "flux_combo") > 0:
				AutochessEffects.gain_mana(ctx, int(ev.src), amp(a, "flux_combo", "mana"), "flux_combo")
		"seuil_pv":
			_on_threshold(ctx, int(ev.dst))
		"chute":
			var u := AutochessEffects.unit(ctx, int(ev.dst))
			if n(u, "volatile") > 0:
				var p := prm("volatile")
				for f in AutochessEffects.near(ctx, int(u.side), u.pos, float(p.radius) * AutochessData.CELL):
					AutochessEffects.proc_hit(ctx, int(ev.dst), f, float(u.hp_max) * amp(u, "volatile", "hp_pct"), "magic", "volatile")
		"elimination":
			var u := AutochessEffects.unit(ctx, int(ev.src))
			if n(u, "fortune") > 0:
				var p := prm("fortune")
				var got := int(u.st.get("fortune_gold", 0))
				var cap := int(p.per_round) * n(u, "fortune")
				var add := mini(int(p.gold) * n(u, "fortune"), cap - got)
				if add > 0:
					u.st["fortune_gold"] = got + add
					ctx.gold[int(u.side)] = int(ctx.gold[int(u.side)]) + add
					AutochessEffects.emit(ctx, {"type": "gold", "src": int(ev.src), "side": int(u.side), "amount": add})


static func _on_time(ctx: Dictionary) -> void:
	var t := float(ctx.t)
	for fid in AutochessTraits._sorted_units(ctx):
		var u: Dictionary = ctx.units[fid]
		if not u.alive:
			continue
		if n(u, "lame_vive") > 0 and t >= float(prm("lame_vive").after) and not u.st.get("lame_vive_done", false):
			u.st["lame_vive_done"] = true
			AutochessEffects.add_mod(ctx, fid, "as_pct", amp(u, "lame_vive", "as_late"), -1.0, "lame_vive")
		if n(u, "nova_givre") > 0 and u.st.has("nova_next") and t + 0.0001 >= float(u.st.nova_next):
			u.st["nova_next"] = float(u.st.nova_next) + float(prm("nova_givre").every)
			_nova(ctx, fid)
		if n(u, "source") > 0 and u.st.has("source_next"):
			var k := 0
			while t + 0.0001 >= float(u.st.source_next) and k < 4:
				u.st["source_next"] = float(u.st.source_next) + float(prm("source").every)
				AutochessEffects.gain_mana(ctx, fid, amp(u, "source", "mana"), "source")
				k += 1


## Rien à chaque impulsion pour l'instant (les brûlures / saignements des objets passent par AutochessEffects.dot).
static func pulse(_ctx: Dictionary) -> void:
	pass


static func _nova(ctx: Dictionary, fid: int) -> void:
	var u: Dictionary = ctx.units[fid]
	var p := prm("nova_givre")
	for f in AutochessEffects.near(ctx, int(u.side), u.pos, float(p.radius) * AutochessData.CELL):
		AutochessEffects.cc(ctx, fid, f, "freeze", float(p.dur), "nova_givre")


static func _after_attack(ctx: Dictionary, ev: Dictionary) -> void:
	var src := int(ev.src)
	var dst := int(ev.dst)
	var a := AutochessEffects.unit(ctx, src)
	if a.is_empty() or not a.alive:
		return
	var dealt := float(ev.dealt)
	var atk := AutochessEffects.stat(ctx, src, "atk")
	var d := AutochessEffects.unit(ctx, dst)
	for idv in carried(a):
		if not a.alive:
			return
		var id := String(idv)
		var p := prm(id)
		match id:
			"transe":
				var st := mini(int(a.st.get("transe", 0)) + 1, int(p.max))
				a.st["transe"] = st
				AutochessEffects.add_mod(ctx, src, "as_pct", float(p.as_pct) * st * n(a, id), -1.0, "transe")
			"lame_statique":
				if int(a.st.attacks) % maxi(1, int(p.every)) == 0:
					for f in AutochessEffects.near(ctx, int(a.side), d.pos, INF).slice(0, int(p.targets)):
						AutochessEffects.proc_hit(ctx, src, f, atk * amp(a, id, "ratio"), "magic", "eclair")
			"soif_de_sang":
				if dealt > 0.0:
					AutochessEffects.heal(ctx, src, src, dealt * amp(a, id, "lifesteal"), "vol_de_vie")
			"briseur_sorts":
				var before := AutochessEffects.mana(ctx, dst)
				AutochessEffects.gain_mana(ctx, dst, -amp(a, id, "mana"), "briseur_sorts")
				if before > AutochessEffects.mana(ctx, dst):
					a.st["drained"] = float(a.st.get("drained", 0.0)) + before - AutochessEffects.mana(ctx, dst)
			"tir_multiple":
				var others := AutochessEffects.near(ctx, int(a.side), a.pos, INF, [dst]).slice(0, int(p.targets))
				for f in others:
					AutochessEffects.proc_hit(ctx, src, f, atk * amp(a, id, "ratio"), "phys", "tir_multiple")
			"elan":
				AutochessEffects.gain_mana(ctx, src, amp(a, id, "mana"), "elan")
			"ricochet":
				var next := AutochessEffects.near(ctx, int(a.side), d.pos, INF, [dst]).slice(0, int(p.bounces))
				for f in next:
					AutochessEffects.proc_hit(ctx, src, f, atk * amp(a, id, "ratio"), "phys", "ricochet")
			"coup_final":
				if int(a.st.attacks) % maxi(1, int(p.every)) == 0:
					AutochessEffects.cc(ctx, src, dst, "stun", float(p.stun), "coup_final")
			"lame_givre":
				if AutochessEffects.alive(ctx, dst):
					AutochessEffects.add_mod(ctx, dst, "as_pct", amp(a, id, "as_pct"), float(p.dur), "lame_givre")
			"plaies":
				if AutochessEffects.alive(ctx, dst):
					AutochessEffects.dot(ctx, src, dst, float(d.hp_max) * amp(a, id, "hp_pct"), float(p.dur), "plaies")
					AutochessEffects.cut_heal(ctx, dst, float(p.heal_cut), float(p.dur))


static func _on_hit_taken(ctx: Dictionary, ev: Dictionary) -> void:
	var dst := int(ev.dst)
	var u := AutochessEffects.unit(ctx, dst)
	if u.is_empty() or not u.alive:
		return
	var t := float(ctx.t)
	if n(u, "pas_du_vent") > 0 and t >= float(u.st.get("pas_du_vent_cd", 0.0)):
		var p := prm("pas_du_vent")
		u.st["pas_du_vent_cd"] = t + float(p.cd)
		AutochessEffects.add_mod(ctx, dst, "dodge", amp(u, "pas_du_vent", "dodge"), float(p.dur), "pas_du_vent")
	# Robustesse : renvoie une part des dégâts physiques d'une vraie frappe (jamais d'un renvoi : pas de boucle)
	if n(u, "robustesse") > 0 and String(ev.kind) == "phys" and not ev.proc and AutochessEffects.alive(ctx, int(ev.src)):
		AutochessEffects.proc_hit(ctx, dst, int(ev.src), float(ev.dealt) * amp(u, "robustesse", "reflect"), "true", "epines")


static func _on_cast(ctx: Dictionary, src: int) -> void:
	var u := AutochessEffects.unit(ctx, src)
	if u.is_empty() or not u.alive:
		return
	if n(u, "echo") > 0:
		u.st["echo_ready"] = true
	if n(u, "barriere") > 0:
		var p := prm("barriere")
		AutochessEffects.shield(ctx, src, float(u.hp_max) * amp(u, "barriere", "shield_pct"), float(p.dur), "barriere")
	if n(u, "vigueur") > 0:
		AutochessEffects.heal(ctx, src, src, float(u.hp_max) * amp(u, "vigueur", "heal_pct"), "vigueur")
	if n(u, "onde_de_choc") > 0:
		var p := prm("onde_de_choc")
		for f in AutochessEffects.near(ctx, int(u.side), u.pos, float(p.radius) * AutochessData.CELL):
			AutochessEffects.cc(ctx, src, f, "knockup", float(p.dur), "onde_de_choc")


## Seuils de PV, une fois par combat : Second souffle, Ange gardien, bouclier de Soif de sang.
static func _on_threshold(ctx: Dictionary, fid: int) -> void:
	var u := AutochessEffects.unit(ctx, fid)
	if u.is_empty() or not u.alive:
		return
	var fr := AutochessEffects.hp_frac(u)
	if n(u, "second_souffle") > 0 and fr < float(prm("second_souffle").below) and not u.st.get("second_souffle", false):
		u.st["second_souffle"] = true
		AutochessEffects.heal(ctx, fid, fid, float(u.hp_max) * amp(u, "second_souffle", "heal_pct"), "second_souffle")
		AutochessEffects.add_mod(ctx, fid, "as_pct", amp(u, "second_souffle", "as_pct"), -1.0, "second_souffle")
	if n(u, "ange_gardien") > 0 and fr < float(prm("ange_gardien").below) and not u.st.get("ange_gardien", false):
		u.st["ange_gardien"] = true
		AutochessEffects.invuln(ctx, fid, float(prm("ange_gardien").dur))
	if n(u, "soif_de_sang") > 0 and fr < float(prm("soif_de_sang").below) and not u.st.get("soif_bouclier", false):
		u.st["soif_bouclier"] = true
		AutochessEffects.shield(ctx, fid, float(u.hp_max) * amp(u, "soif_de_sang", "shield_pct"), 99.0, "soif_de_sang")
