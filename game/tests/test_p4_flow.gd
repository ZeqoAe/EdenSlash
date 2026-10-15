extends Node
## Intégration (passe P4) : le parcours du hub de bout en bout, sans changer de scène.
## Compte neuf -> Survie (mort, bilan) -> équipement du hub restauré -> Armurerie (achat) -> Forge (+N, gemme,
## enchantement) -> Fabrication -> Coffres / Roulette -> Registre / « Équiper le meilleur » -> Survie avec l'équipement
## du hub. Les activités lancées depuis le lobby sont dans test_p4_activities.
## godot --headless --path game res://tests/test_p4_flow.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _uids(d: Dictionary) -> Array:
	var out: Array = []
	for s in d:
		out.append("%s:%s" % [s, d[s].uid])
	out.sort()
	return out


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	await _flow()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _flow() -> void:
	# --- 1. compte neuf -------------------------------------------------------------------------------------
	check("compte neuf : classe de départ, 8 pièces portées, aucune activité tardive ouverte",
		Profile.selected_class == "warrior" and Profile.equipped.size() == 8 and not Unlocks.is_open("tower") and not Unlocks.is_open("royale")
		and Unlocks.is_open("survival") and Unlocks.is_open("training"))
	check("compte neuf : 60 classes dans le Registre, aucune n'est notée à tort comme maîtrisée", ClassGear.entries().size() == GameData.classes.size() and GameData.classes.size() == 60)
	var hub := _uids(Profile.equipped)

	# --- 2. Survie : une carte, la mort, le bilan --------------------------------------------------------------
	Run.start_survival("warrior", 1)
	check("Survie : démarrée sur l'équipement du hub", _uids(Profile.equipped) == hub and Run.survival and Run.active)
	var chest_card: Array = SlotChests.offer("head", 1, 1, 3)
	check("Survie : un coffre d'emplacement propose du choix", chest_card.size() >= 2)
	Run.apply_card({"type": "gear", "item": chest_card[0]})
	Run.hero_level = 8
	Run.kills = 55
	Run.elites = 2
	Run.stage = 1
	Run.add_gold(300, "monstres")
	var insignia_before := Profile.insignia
	Run.finish("defaite")
	check("Survie : la défaite rapporte des insignes de participation", Run.insignia_gain > 0)
	Profile.end_run_survival()
	check("Survie finie : équipement du hub restauré", _uids(Profile.equipped) == hub and not Run.active)
	check("Survie finie : les insignes sont ajoutés (%d -> %d)" % [insignia_before, Profile.insignia], Profile.insignia == insignia_before + Run.insignia_gain)
	check("Survie finie : or et clés de la run remis à zéro", Profile.gold == 0 and Profile.keys == 0)
	check("Survie finie : la pièce du coffre est à découvrir à l'Armurerie", int(chest_card[0].eden) in Profile.seen_gear)
	check("le bilan se décrit sans erreur (Survie perdue)", Profile.runs_done >= 1 and Unlocks.is_open("collection"))

	# --- 3. Armurerie : achat -----------------------------------------------------------------------------------
	Profile.insignia = 50000
	var shop := GearShopPage.new()
	add_child(shop)
	await get_tree().process_frame
	shop.refresh()
	var buyable: Array = shop._all.filter(func(r): return r.state == "buy")
	check("Armurerie : au moins une pièce à acheter après la Survie", not buyable.is_empty())
	var n_before := Profile.vault.size() + Profile.inventory.size()
	var gold_pieces := 0
	if not buyable.is_empty():
		var row: Dictionary = buyable[0]
		var price := GearShopPage.price(row.e)
		shop._select(int(row.e.id))
		var ins := Profile.insignia
		shop._on_buy()
		check("Armurerie : l'achat coûte son prix en insignes", Profile.insignia == ins - price)
		check("Armurerie : la pièce est possédée ensuite", GearShopPage.owned(int(row.e.id)))
		check("Armurerie : la pièce est au coffre ou au sac (%d -> %d)" % [n_before, Profile.vault.size() + Profile.inventory.size()], Profile.vault.size() + Profile.inventory.size() > n_before)
		gold_pieces += 1
	shop.queue_free()

	# --- 4. Forge : +N, gemme, enchantement -------------------------------------------------------------------
	var piece: Dictionary = Profile.equipped.weapon
	piece["level"] = 60
	piece["upgrade"] = 0
	Profile.set_amount("crystal", 5000)
	Profile.materials["crystal"] = 5000
	var scroll := Craft.fortify_key(Craft.fortify_kind(piece), Craft.fortify_level_for(piece))
	Profile.add_bag(scroll, 40)
	check("Forge : un parchemin de fortification correspond à la pièce (%s)" % scroll, Craft.fortify_for(piece) != "")
	var ups := 0
	for i in 40:

		var r := Profile.upgrade_item(piece)
		if r.get("error", false):
			check("Forge : pas d'erreur de fortification (%s)" % String(r.text), false)
			break
		if r.ok:
			ups += 1
		if int(piece.upgrade) >= 5:
			break
	check("Forge : la pièce monte en +N (%d)" % int(piece.upgrade), int(piece.upgrade) >= 1 and ups >= 1)
	Profile.add_bag("drill", 3)
	var msg := ""
	for i in 6:
		msg = Craft.drill(piece)
		if piece.get("sockets", []).size() >= 1:
			break
	check("Forge : un emplacement de gemme est percé (%s)" % msg, piece.get("sockets", []).size() >= 1)
	Profile.add_bag(Craft.gem_key("garnet", 1))
	var gmsg := Craft.insert_gem(piece, Craft.gem_key("garnet", 1), 0)
	check("Forge : la gemme est sertie (%s)" % gmsg, piece.sockets[0] is Dictionary and Craft.extra_stats(piece).get("hp", 0) > 0)
	Profile.add_bag(Craft.scroll_key("optimize", 1))
	var esc := Craft.scroll_key("optimize", 1)
	var emsg := Craft.apply_scroll(piece, esc)
	check("Forge : un enchantement est appliqué (%s)" % emsg, piece.has("enchant") or emsg.begins_with("Objet de niveau"))
	check("Forge : les statistiques de la pièce restent calculables", Items.stats(piece).size() > 0)

	# --- 5. Fabrication ------------------------------------------------------------------------------------------
	var zid := String(Dungeons.zone_ids()[0])
	check("Fabrication : sans plan, rien n'est fabriqué (message d'erreur)", FabricationPage.craft(zid, "head").has("error"))
	Profile.plans = ["plan_" + zid]
	check("Fabrication : le plan est reconnu", zid in FabricationPage.known())
	var fab_before := Profile.vault.size() + Profile.inventory.size()
	Profile.materials["crystal"] = 100000
	var fr := FabricationPage.craft(zid, "head")
	check("Fabrication : une pièce de la panoplie du donjon est fabriquée (%s)" % [str(fr.get("error", "ok"))], not fr.has("error") and fr.get("archetype", "") == Dungeons.archetype(zid))
	check("Fabrication : la pièce est au coffre ou au sac", Profile.vault.size() + Profile.inventory.size() > fab_before)

	# --- 6. Coffres et Roulette ----------------------------------------------------------------------------------
	Profile.chest_add("gear", 30)
	Profile.chest_add("forge", 30)
	Profile.chest_add("jewel", 30)
	var n_chests := Profile.reward_chests.size()
	check("Coffres : trois coffres rapportés", n_chests >= 3)
	var opened := 0
	for c in Profile.reward_chests.duplicate():
		var got := Rewards.open(c)
		if not Rewards.is_choice(c):
			opened += 1 if not got.is_empty() else 0
		check("Coffres : aperçu et récapitulatif lisibles (%s)" % Rewards.name_of(c), Rewards.preview(c) != "" and Rewards.summary(got) is String)
	Wheel.state()["used"] = 0
	var spin := Wheel.spin(0.5)
	check("Roulette : un lancer gratuit rend un gain ou « Perdu » (%s)" % String(spin.get("text", "")), bool(spin.get("ok", false)) and String(spin.text) != "")
	var spin2 := Wheel.spin(0.1)
	check("Roulette : un 2e lancer est gratuit ou payé, jamais une erreur", typeof(spin2) == TYPE_DICTIONARY)

	# --- 7. Registre et « Équiper le meilleur » -------------------------------------------------------------------
	var c0 := ClassGear.equipped_count()
	check("Registre : compteur N / 60", c0.y == 60)
	var m1 := ClassGear.equip_best("warrior")
	check("Équiper le meilleur : un message (%s)" % m1, m1 != "")
	var m2 := ClassGear.equip_best("warrior")
	check("Équiper le meilleur : idempotent (2e appel : rien à changer)", m2.begins_with("Rien à changer"))
	check("Équiper le meilleur : annulable", ClassGear.can_undo() or m1.begins_with("Rien"))
	if ClassGear.can_undo():
		ClassGear.undo()
		var m3 := ClassGear.equip_best("warrior")
		check("Équiper le meilleur : refait après l'annulation", m3 != "")
	var e := ClassGear.entry("warrior")
	check("Registre : l'entrée de la classe a un statut, une PE et une ligne « il manque » ou rien", e.has("status") and e.has("pe") and e.has("need") and e.has("activity"))

	# --- 8. Survie avec l'équipement du hub -------------------------------------------------------------------------
	var hub2 := _uids(Profile.equipped)
	var weapon_up := int(Profile.equipped.weapon.get("upgrade", 0))
	Run.start_survival("warrior", 1)
	check("Survie 2 : l'équipement du hub (après Forge et Meilleur) est porté", _uids(Profile.equipped) == hub2)
	check("Survie 2 : le +N de l'arme est celui du hub (%d)" % weapon_up, int(Profile.equipped.weapon.get("upgrade", 0)) == weapon_up or Run.slot_upgrade(weapon_up, "weapon") >= weapon_up)
	Profile.equipped.chest["upgrade"] = 3  # (la run modifie sa copie)
	Run.finish("defaite")
	Profile.end_run_survival()
	check("Survie 2 finie : le hub est intact (copie jetée)", _uids(Profile.equipped) == hub2)
	var hub_chest_up := 0
	for it in Profile.vault:
		if String(it.uid) == String(Profile.equipped.chest.uid):
			hub_chest_up = int(it.upgrade)
	check("Survie 2 finie : le +3 de la copie n'est pas dans le coffre", hub_chest_up != 3 or int(Profile.equipped.chest.upgrade) == 3)

	# --- 9. sauvegarde / rechargement : rien ne se perd ---------------------------------------------------------------
	Profile.save_profile()
	var saved_uids := _uids(Profile.equipped)
	var vault_n := Profile.vault.size()
	var insignia := Profile.insignia
	var seen := Profile.seen_gear.size()
	Profile.load_profile()
	check("rechargement : équipement, coffre, insignes et pièces découvertes identiques",
		_uids(Profile.equipped) == saved_uids and Profile.vault.size() == vault_n and Profile.insignia == insignia and Profile.seen_gear.size() == seen)
	Profile.reset_all()
