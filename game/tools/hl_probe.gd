extends "res://tools/progression_sim.gd"
## Lot H7 : sonde de puissance du niveau de héros (conception/progression/NIVEAU_HEROS.md §1.4, §2.2 ; rapport R_H7.md).
## Reconstruit la sonde de PR2 dans l'outil du dépôt (même indice que progression_sim : racine(PV effectifs × DPS)).
##
##   godot --headless --path game res://tools/hl_probe.tscn -- [--class=warrior] [--levels=15,25,35,45,60,75,90]
##         [--mep=…] [--mapmult=…]           puissance par carte, M′ suggéré, retard dans la bande, héros au-dessus
##   godot --headless --path game res://tools/hl_probe.tscn -- --talents   effet des talents et certificats (§2.2)
##   godot --headless --path game res://tools/hl_probe.tscn -- --sealed    même compte opti en Aventure et en Battle royale (lot H2)
##   godot --headless --path game res://tools/hl_probe.tscn -- --calage=p1,…,p12 [--late=q1,…,q12]   M′ de l'outil recalé sur le jeu
##         (lot H4b : chances de finir chaque carte mesurées dans le jeu avec l'équipement correct, et en retard de 10 niveaux)
##
## 1) indices bruts de kits types (époque.carte.+N.rang des gemmes) à plusieurs niveaux de héros ;
## 2) R par carte : jeu actuel (plafond 15 / 25 / 35, Epochs.MONSTER_MULT) | refonte H (décote, monstres 0,85 / 1,3 / 2,3 / 4,4)
##    | niveau de héros brut (héros et monstres au haut de la bande, sans M′) | niveau de héros avec le MAP_MULT de l'outil ;
## 3) M′ suggéré par carte : R brut du kit de la carte à +5 / R de la refonte H du même kit (aligne le niveau de héros sur la
##    colonne H de REFONTE_AVENTURE §3.1 ; c'est HERO_PROBE_MULT, avant le facteur d'époque) ;
## 4) dans une bande : même kit, héros et monstres N niveaux plus haut (le « retard d'équipement » qui remplace la décote) ;
## 5) au-dessus de la bande : kit de la carte, monstres au plafond, héros +N (sans synchronisation en Aventure).
## Rien n'est sauvegardé (Training.active).

const M_OLD := [0.85, 1.7, 3.4, 7.0]  # Epochs.MONSTER_MULT de 0.1.224 (jeu actuel)
const M_REFONTE_H := [0.85, 1.3, 2.3, 4.4]  # colonne H de REFONTE_AVENTURE §3.1
const SPECS := ["new", "1.1.0", "1.1.5.2", "1.2.5.2", "1.3.5.2", "1.3.10.3", "2.1.5.3", "2.2.5.3", "2.3.5.3", "2.3.10.3",
	"3.1.5.3", "3.2.5.3", "3.3.5.3", "3.3.10.4", "4.1.5.3", "4.2.5.3", "4.3.5.4", "4.3.10.4"]
## Kit de la carte à +5 (rang des gemmes de PR2) : référence du M′ suggéré.
const CARD_KITS := [["1.1.5.2", "1.2.5.2", "1.3.5.2"], ["2.1.5.3", "2.2.5.3", "2.3.5.3"], ["3.1.5.3", "3.2.5.3", "3.3.5.3"],
	["4.1.5.3", "4.2.5.3", "4.3.5.4"]]
const CLASSES := ["warrior", "magician", "hunter", "cleric", "thief", "knight", "sage", "ranger"]

var levels: Array = [15, 25, 35, 45, 60, 75, 90]


func _ready() -> void:
	parse_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levels="):
			levels = Array(a.trim_prefix("--levels=").split(",")).map(func(x): return int(x))
	heros = true
	setup()
	if "--talents" in OS.get_cmdline_user_args():
		talents_probe()
	elif "--sealed" in OS.get_cmdline_user_args():
		sealed_probe()
	elif Array(OS.get_cmdline_user_args()).any(func(a): return String(a).begins_with("--calage=")):
		calage_probe()
	else:
		ratio_probe()
	get_tree().quit()


static func kit_max_level(g: Dictionary) -> int:
	var mx := 0
	for s in g:
		mx = maxi(mx, int(g[s].get("level", 0)))
	return mx


## Rapport brut (sans M′) du kit [param g] à la carte [param k] de l'époque [param ep] : héros et monstres au haut de la bande.
func raw_ratio(g: Dictionary, ep: int, k: int) -> float:
	var hi := band_hi(ep, k)
	return power_index(g, hi) / (float(base_index[k - 1]) * pow(1.1, hi - int(HERO_LEVELS[k - 1])))


## Rapport de la refonte H (décote, plafond de la carte) du kit [param g].
func refonte_ratio(g: Dictionary, ep: int, k: int) -> float:
	var cap: int = HERO_LEVELS[k - 1]
	return power_index(decoted(g, ep, k, cap), cap) / float(base_index[k - 1]) / float(M_REFONTE_H[ep - 1])


func ratio_probe() -> void:
	seed(7)
	var kits := {}
	for spec in SPECS:
		kits[spec] = StarterGear.items(cid) if spec == "new" else StarterGear.scenario(spec, cid)
	print("== indices bruts (racine(PV effectifs × DPS)), classe %s ==" % cid)
	for spec in SPECS:
		var line := "  %-9s niv. max %2d" % [spec, kit_max_level(kits[spec])]
		for lv in levels:
			line += "  N%d %.0f" % [int(lv), power_index(kits[spec], int(lv))]
		print(line)
	print("== R par carte : ACTUEL | REFONTE H | HÉROS brut (haut de bande, sans M′) | HÉROS avec MAP_MULT (- : kit non portable) ==")
	for spec in SPECS:
		var g: Dictionary = kits[spec]
		print("  %s" % spec)
		for ep in range(1, 5):
			var line := "    "
			for k in range(1, 4):
				var cap: int = HERO_LEVELS[k - 1]
				var r_old := power_index(g, cap) / float(base_index[k - 1]) / float(M_OLD[ep - 1])
				var r_h := refonte_ratio(g, ep, k)
				var ok: bool = spec == "new" or kit_max_level(g) <= band_hi(ep, k)
				var raw: float = raw_ratio(g, ep, k) if ok else -1.0
				line += "  %d.%d %.2f | %.2f | %s | %s" % [ep, k, r_old, r_h, ("%.3f" % raw) if ok else "  -  ",
					("%.2f" % (raw / map_mult(ep, k))) if ok else " - "]
			print(line)
	print("== M′ suggéré (kit de la carte à +5 : R brut / R refonte H) | HERO_PROBE_MULT | MAP_MULT de l'outil ==")
	for ep in range(1, 5):
		var line := "  époque %d" % ep
		for k in range(1, 4):
			var spec: String = CARD_KITS[ep - 1][k - 1]
			var g: Dictionary = kits[spec]
			line += "   %d.%d (%s) %.2f | %.2f | %.2f" % [ep, k, spec, raw_ratio(g, ep, k) / refonte_ratio(g, ep, k),
				float(HERO_PROBE_MULT[ep - 1][k - 1]), map_mult(ep, k)]
		print(line)
	print("== dans une bande : kit fixe, héros et monstres N niveaux au-dessus du kit (puissance relative) ==")
	for spec in ["1.1.5.2", "1.3.5.2", "2.3.5.3", "3.3.5.3", "4.1.5.3"]:
		var g: Dictionary = kits[spec]
		var lv0 := kit_max_level(g)
		var i0 := power_index(g, lv0)
		var line := "  %-9s (niv. %d)" % [spec, lv0]
		for d in [0, 3, 6, 10, 15]:
			line += "  +%d : ×%.2f" % [d, power_index(g, lv0 + d) / i0 / pow(1.1, d)]
		print(line)
	print("== au-dessus de la bande : kit de la carte, monstres au plafond, héros N niveaux plus haut ==")
	for spec in ["1.3.5.2", "2.3.5.3"]:
		var g: Dictionary = kits[spec]
		var lv0 := kit_max_level(g)
		var i0 := power_index(g, lv0)
		var line := "  %-9s" % spec
		for d in [0, 5, 10, 20]:
			line += "  +%d : ×%.2f" % [d, power_index(g, lv0 + d) / i0]
		print(line)


## Talents (arbre légal de 80 points, priorité au build opti), certificats (2, 4, puis 7 et le plateau du build opti).
func talents_probe() -> void:
	print("== talents et certificats : indice en Aventure, kit 2.3.5.3 aux niveaux 60 et 20 ==")
	var keep_t: Dictionary = Profile.talents.duplicate(true)
	var keep_b: Array = Profile.cert_board.duplicate()
	var keep_x: Dictionary = Profile.expertise.duplicate(true)
	var keep_c := cid
	for c in CLASSES:
		cid = c
		Profile.selected_class = c
		var b := Duel.opti_build(c, 90)
		var gear := StarterGear.scenario("2.3.5.3", c)
		Profile.talents = {}
		Profile.cert_board = ["", "", "", "", "", "", ""]
		Profile._sync_certificates()
		var bare60 := power_index(gear, 60)
		var bare20 := power_index(gear, 20)
		Profile.set_expertise_level(c, 40)  # maîtrise 40 = 80 points, dépensés dans l'ordre de valeur du build opti
		var order: Array = (b.get("talents", {}) as Dictionary).keys()
		order.sort_custom(func(x, y): return int(b.talents[x]) > int(b.talents[y]))
		var guard := 400
		var progress := true
		while progress and guard > 0:
			progress = false
			for id in order:
				guard -= 1
				if Profile.talent_rank(c, id) < int(b.talents[id]) and Profile.add_talent(c, id):
					progress = true
		var spent := Profile.talent_spent(c)
		var t60 := power_index(gear, 60)
		var t20 := power_index(gear, 20)
		var part := ""
		for n in [2, 4]:
			var bb := ["", "", "", "", "", "", ""]
			for i in mini(n, (b.get("certs", []) as Array).size()):
				bb[CertBoard.OPEN_ORDER[i]] = String((b.get("certs", []) as Array)[i])
			Profile.cert_board = bb
			Profile._sync_certificates()
			part += "  %d certificats ×%.2f" % [n, power_index(gear, 60) / bare60]
		Profile.cert_board = RivalBuilds.cert_board(b)
		Profile._sync_certificates()
		var tc60 := power_index(gear, 60)
		var tc20 := power_index(gear, 20)
		print("  %-9s talents %d points ×%.2f / ×%.2f |%s | 7 certificats et plateau ×%.2f / ×%.2f" % [c, spent,
			t60 / bare60, t20 / bare20, part, tc60 / bare60, tc20 / bare20])
	Profile.talents = keep_t
	Profile.cert_board = keep_b
	Profile.expertise = keep_x
	Profile._sync_certificates()
	cid = keep_c
	Profile.selected_class = keep_c


## Lot H2 : compte « opti » (talents et plateau du build opti, archive de 100 entrées) contre compte neuf, même kit 2.3.5.3 au
## niveau 60, en Aventure puis en Battle royale (Royale.active : mode scellé, plafonds JcJ compris des deux côtés).
func sealed_probe() -> void:
	print("== mode scellé : compte opti / compte neuf, kit 2.3.5.3, niveau 60 ==")
	var keep_t: Dictionary = Profile.talents.duplicate(true)
	var keep_b: Array = Profile.cert_board.duplicate()
	var keep_a: Dictionary = Profile.archive.duplicate(true)
	var arc := {}
	for e: Dictionary in GameData.eden_items:
		if e.has("arch") and arc.size() < 100:
			arc["e%d" % int(e.id)] = {}  # (100 entrées : paliers 10, 25, 50 et 100 de l'archive)
	for c in CLASSES:
		cid = c
		Profile.selected_class = c
		var b := Duel.opti_build(c, 90)
		var gear := StarterGear.scenario("2.3.5.3", c)
		var line := "  %-9s" % c
		for mode in ["Aventure", "Battle royale"]:
			Royale.active = mode == "Battle royale"
			Profile.talents = {}
			Profile.cert_board = ["", "", "", "", "", "", ""]
			Profile.archive = {}
			Profile._sync_certificates()
			var bare := power_index(gear, 60)
			Profile.talents = {c: (b.get("talents", {}) as Dictionary).duplicate()}
			Profile.cert_board = RivalBuilds.cert_board(b)
			Profile.archive = arc.duplicate(true)
			Profile._sync_certificates()
			var full := power_index(gear, 60)
			line += "  %s ×%.2f" % [mode, full / bare]
		Royale.active = false
		print(line + "  (%d certificats, archive %d)" % [Profile.certificates.size(), arc.size()])
	Profile.talents = keep_t
	Profile.cert_board = keep_b
	Profile.archive = keep_a
	Profile._sync_certificates()


## Équipement « retard 10 » de chaque carte (comme tools/boss_ttk.py, BAND_LATE ; "new" : départ).
const LATE_KITS := ["new", "1.1.5", "1.2.5", "1.3.0", "1.3.5", "2.2.5", "2.3.0", "2.3.5", "3.1.5", "3.2.5", "3.3.5", "3.3.5"]


## Lot H4b (--calage=p1,…,p12) : pour chaque carte, le M′ de l'outil qui donne à l'équipement « correct » (pièces de la carte à
## +5, trouvailles de la run, héros au haut de la bande ; carte I-1 : le compte neuf, niveau 1 et équipement de départ) la chance
## de finir la carte mesurée dans le jeu (joueur moyen appris :
## sigmoïde(C_MAP + BETA ln R) × sigmoïde(C_BOSS + BETA ln R)). Avec --late=q1,…,q12 (chances mesurées en retard de 10 niveaux) :
## M′ ajusté sur les deux points (moindres carrés des logits, chances bornées à 5-95 % ; un retard sans victoire ne compte que si
## la prévision dépasse 5 %), chance prévue en retard face à la mesure.
func calage_probe() -> void:
	var target: Array = []
	var late: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--calage="):
			target = Array(a.trim_prefix("--calage=").split(",")).map(func(x): return float(x))
		elif a.begins_with("--late="):
			late = Array(a.trim_prefix("--late=").split(",")).map(func(x): return float(x))
	seed(7)
	print("== calage (lot H4b), classe %s : carte | chance mesurée | R brut (kit +5, trouvailles) | R visé | M′ de l'outil | retard : R brut, prévu, mesuré ==" % cid)
	var mm: Array = []
	for ep in range(1, 5):
		for k in range(1, 4):
			var i := (ep - 1) * 3 + k - 1
			_cur = {"hl": band_hi(ep, k)}
			var g := run_gear(StarterGear.scenario("%d.%d.5" % [ep, k], cid), ep, k)
			var raw := raw_ratio(g, ep, k)
			if i == 0:
				# compte neuf : héros niveau 1, équipement de départ, monstres au bas de la bande
				_cur = {"hl": 1}
				g = run_gear(StarterGear.items(cid), ep, k)
				raw = power_index(g, 1) / (float(base_index[0]) * pow(1.1, band_level(ep, k, 1) - int(HERO_LEVELS[0])))
			var p := clampf(float(target[i]), 0.02, 0.98)
			var lo := -6.0
			var hi := 6.0
			for it in 60:
				var mid := (lo + hi) * 0.5
				if clear_chance(exp(mid), k - 1, 0.0) < p:
					lo = mid
				else:
					hi = mid
			var r := exp((lo + hi) * 0.5)
			var m := raw / r
			var spec: String = LATE_KITS[i]
			var lg := run_gear(StarterGear.items(cid) if spec == "new" else StarterGear.scenario(spec, cid), ep, k)
			var lraw := raw_ratio(lg, ep, k)
			if late.size() > i and i > 0:
				# deux points (équipement correct et retard) : M′ qui minimise la somme des écarts de logit
				var q := clampf(float(late[i]), 0.05, 0.95)
				var pc := clampf(p, 0.05, 0.95)
				var best := INF
				var m0 := m
				for step in range(-600, 601):
					var mt := m0 * exp(float(step) * 0.005)
					var e1 := _logit(clampf(clear_chance(raw / mt, k - 1, 0.0), 0.001, 0.999)) - _logit(pc)
					var pl := clear_chance(lraw / mt, k - 1, 0.0)
					var e2 := _logit(clampf(pl, 0.001, 0.999)) - _logit(q)
					if q <= 0.05 and pl <= 0.05:
						e2 = 0.0  # mesure censurée (aucune victoire sur 20) : toute prévision sous 5 % lui va
					if e1 * e1 + e2 * e2 < best:
						best = e1 * e1 + e2 * e2
						m = mt
			mm.append(m)
			var line := "  %d-%d  %.2f  %.3f  %.3f  %.3f  prévu %.2f" % [ep, k, p, raw, r, m, clear_chance(raw / m, k - 1, 0.0)]
			line += "  | retard %.3f prévu %.2f" % [lraw, clear_chance(lraw / m, k - 1, 0.0)]
			if late.size() > i:
				line += " mesuré %.2f" % float(late[i])
			print(line)
	_cur = {}
	print("  HERO_GAME_MULT := [%s]" % ", ".join(range(4).map(func(e): return "[%s]" % ", ".join(mm.slice(e * 3, e * 3 + 3).map(func(x): return "%.3f" % x)))))


static func _logit(p: float) -> float:
	return log(p / (1.0 - p))
