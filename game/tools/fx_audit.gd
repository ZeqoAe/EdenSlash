extends Node
## Audit des effets de sorts : pour chaque sort de chaque classe, la taille réelle de ses effets d'Eden (sort
## lancé sur le héros « cast », impact « hit ») comparée à sa zone de dégâts, avant et après l'ajustement de
## l'échelle des effets à la zone (EdenFx.cast_scale / hit_scale). Écrit user://fx_audit.csv :
## ratio = rayon du cœur de l'effet à l'écran / rayon de la zone ; > 1,6 : l'effet déborde (on croit toucher plus
## loin), < 0,5 : l'effet est trop petit pour la zone (on ne voit pas ce qu'on touche). Les rayons viennent de
## data/fx_radius.json (tools/fx_measure.tscn).
## godot --headless --path game res://tools/fx_audit.tscn

const CAST_SCALE := 1.0  # × GameData.HERO_SCALE : l'effet d'incantation est posé sur le héros
const HIT_SCALE := 1.2


func _ready() -> void:
	var rows: PackedStringArray = ["classe;sort;id;type;rayon_zone;arc;fx_cast;ratio_cast_avant;ratio_cast_apres;fx_hit;ratio_hit_avant;ratio_hit_apres;verdict_avant;verdict_apres"]
	var seen := {}
	var bad := 0
	var bad_after := 0
	var total := 0
	for cid in GameData.classes:
		for s in GameData.class_data(cid).get("skills", []):
			var id := int(s.id)
			if seen.has(id):
				continue
			seen[id] = true
			var zone := float(s.get("radius", 0.0))
			if zone <= 0.0:
				continue
			total += 1
			var fx: Dictionary = s.get("fx", {})
			var cast := String(fx.get("cast", ""))
			var hit := String(fx.get("hit", ""))
			var nc := EdenFx.native_radius(cast)
			var nh := EdenFx.native_radius(hit)
			var qc := nc * GameData.HERO_SCALE * CAST_SCALE / zone
			var qh := nh * GameData.HERO_SCALE * HIT_SCALE / zone
			var qc2 := nc * EdenFx.cast_scale(cast, s, zone) / zone
			var qh2 := nh * EdenFx.hit_scale(hit, zone) / zone if String(s.get("kind", "")) == "ground" else qh
			var v1 := _verdict(qc, qh, cast, hit, zone, String(s.get("kind", "")))
			var v2 := _verdict(qc2, qh2, cast, hit, zone, String(s.get("kind", "")))
			if v1 != "ok":
				bad += 1
			if v2 != "ok":
				bad_after += 1
			rows.append("%s;%s;%d;%s;%.1f;%d;%s;%.2f;%.2f;%s;%.2f;%.2f;%s;%s" % [cid, String(s.get("name", "")).replace(";", ","), id, s.get("kind", ""), zone, int(s.get("arc", 0)), cast, qc, qc2, hit, qh, qh2, v1, v2])
	var f := FileAccess.open("user://fx_audit.csv", FileAccess.WRITE)
	f.store_string("\n".join(rows))
	f.close()
	print("sorts avec zone : %d · à revoir avant : %d · après : %d · fichier : %s" % [total, bad, bad_after, ProjectSettings.globalize_path("user://fx_audit.csv")])
	get_tree().quit()


static func _verdict(qc: float, qh: float, cast: String, hit: String, zone: float, kind: String) -> String:
	if kind in ["buff", "heal"]:
		return "ok"
	if (cast == "" and hit == ""):
		return "sans effet"
	if (qc > 1.6 or qh > 1.6) and zone <= 4.0:
		return "déborde"
	if (qc > 0.0 and qc < 0.5) or (qh > 0.0 and qh < 0.5 and kind == "ground"):
		return "trop petit"
	return "ok"
