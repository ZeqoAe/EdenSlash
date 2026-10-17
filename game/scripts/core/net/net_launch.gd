class_name NetLaunch
extends RefCounted
## Lancement du Mode amis (lot NET-A, conception/benchmark/NETWORK.md, R_NET_A.md).
## Les arguments se donnent AVANT tout « -- » : un argument placé après « -- » met Profile et Settings en mode test
## (profile_test.json), ce qui ferait jouer un ami sur un profil vide. Ils sont aussi lus après « -- » (outils de test).
##   EdenSlash.exe --host [--net-port=24680]            héberge une partie (arène d'essai)
##   EdenSlash.exe --join=100.64.0.7[:24680]            rejoint l'hôte à cette adresse
##   EdenSlash.exe --profil=ami ...                     emplacement de sauvegarde à part (deux instances sur un même PC)
## Options d'essai : --net-class=<classe> --net-name=<nom> --net-pilot (pilote automatique) --net-secs=N (mesure N s puis
## quitte, ligne « [net] {json} ») --net-report=<fichier.json> --net-lag=<ms> --net-loss=<%> (côté client) --net-version=<x>
## (essai du refus d'une autre version) --net-snap=<instantanés par seconde>.

const SCENE := "res://scenes/net_arena.tscn"
const INSTANCE_DIR := "user://instances/"

## Le lancement direct (--host / --join) ne sert qu'une fois : « Retour » ramène ensuite à l'écran titre.
static var used := false
static var _instance := "?"  # (cache) nom de l'instance, "" sans --profil


## Tous les arguments, d'abord ceux d'avant « -- ».
static func args() -> PackedStringArray:
	return OS.get_cmdline_args() + OS.get_cmdline_user_args()


## Valeur de « --clé=valeur » ([param def] si absent).
static func value(key: String, def := "") -> String:
	for a in args():
		if a.begins_with(key + "="):
			return a.trim_prefix(key + "=")
	return def


static func flag(key: String) -> bool:
	return key in args()


## Une partie entre amis est demandée par la ligne de commande (et pas encore lancée).
static func requested() -> bool:
	return not used and (flag("--host") or value("--join") != "")


## Rôle demandé : « host », « join » ou "".
static func role() -> String:
	if flag("--host"):
		return "host"
	return "join" if value("--join") != "" else ""


## Adresse et port de « --join=adresse[:port] » : [adresse, port].
static func join_target() -> Array:
	return parse_address(value("--join"), int(value("--net-port", str(NetProtocol.PORT))))


## « 100.64.0.7:24680 », « 192.168.1.20 », « [::1]:24680 » -> [adresse, port] (port par défaut sinon).
static func parse_address(text: String, def_port := NetProtocol.PORT) -> Array:
	var t := text.strip_edges()
	var port := def_port
	if t.begins_with("["):  # IPv6 entre crochets
		var close := t.find("]")
		if close > 0:
			if t.substr(close + 1).begins_with(":") and t.substr(close + 2).is_valid_int():
				port = int(t.substr(close + 2))
			t = t.substr(1, close - 1)
	elif t.count(":") == 1:
		var parts := t.split(":")
		if parts[1].is_valid_int():
			port = int(parts[1])
		t = parts[0]
	return [t, clampi(port, 1, 65535)]


## Nom de l'instance (--profil=… ou --profile=…), lettres, chiffres, « _ » et « - » seulement ; "" sans.
static func instance() -> String:
	if _instance == "?":
		var raw := value("--profil", value("--profile"))
		var out := ""
		for ch in raw.to_lower():
			if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
				out += ch
		_instance = out.substr(0, 24)
	return _instance


## Chemin de sauvegarde de cette instance : « user://x » devient « user://instances/<nom>/x » avec --profil=<nom> ;
## inchangé sans --profil (comportement habituel). Sert au profil, aux réglages, aux préréglages de sorts et au journal.
static func user_path(path: String) -> String:
	var inst := instance()
	if inst == "" or not path.begins_with("user://") or path.begins_with(INSTANCE_DIR):
		return path
	var dir := INSTANCE_DIR + inst + "/"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	return dir + path.trim_prefix("user://")
