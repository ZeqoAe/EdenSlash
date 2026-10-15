class_name SafeFile
extends RefCounted
## Écriture sûre des fichiers de sauvegarde de user:// (passe P2) : une coupure en pleine écriture ne perd plus la sauvegarde.
## write() : écrit « fichier.tmp », le relit et le valide, garde l'ancien fichier valide en « fichier.bak », puis remplace le fichier.
## read()  : le fichier, sinon « .tmp » (écriture terminée mais pas renommée), sinon « .bak » ; renvoie "" si rien n'est lisible.
## Un repli est noté dans `notices` (le lobby affiche un message sobre une fois).

## Chemins récupérés pendant cette session et pas encore annoncés au joueur.
static var notices: Array = []


## Texte JSON lisible : un dictionnaire ou un tableau (« null » ou un fichier tronqué ne le sont pas).
static func json_ok(text: String) -> bool:
	if text.strip_edges() == "":
		return false
	var d: Variant = JSON.parse_string(text)
	return d is Dictionary or d is Array


## Écrit [param text] dans [param path] sans jamais laisser un fichier à moitié écrit à la place du bon. [param valid] : Callable(texte) -> bool
## (par défaut json_ok). Renvoie faux si rien n'a pu être écrit.
static func write(path: String, text: String, valid := Callable()) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _direct(path, text)
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_string(tmp) != text or not _valid(text, valid):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return _direct(path, text)
	if FileAccess.file_exists(path):
		if _valid(FileAccess.get_file_as_string(path), valid):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) != OK:
		return _direct(path, text)  # le .tmp reste lisible par read() si cette écriture directe était coupée
	return true


static func _direct(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	return true


static func _valid(text: String, valid: Callable) -> bool:
	return bool(valid.call(text)) if valid.is_valid() else json_ok(text)


## Contenu lisible de [param path] (voir l'en-tête), "" s'il n'y en a pas. Un repli sur .tmp / .bak est noté dans `notices`
## quand le fichier principal existait mais était illisible.
static func read(path: String, valid := Callable()) -> String:
	var had_main := FileAccess.file_exists(path)
	if had_main:
		var t := FileAccess.get_file_as_string(path)
		if _valid(t, valid):
			return t
	for ext in [".tmp", ".bak"]:
		var p: String = path + ext
		if FileAccess.file_exists(p):
			var t2 := FileAccess.get_file_as_string(p)
			if _valid(t2, valid):
				if had_main or ext == ".bak":
					notices.append(path)
				return t2
	return ""


## Message sobre à montrer au joueur après un repli ("" : rien à dire). Vide la liste.
static func take_notice() -> String:
	if notices.is_empty():
		return ""
	notices = []
	return "Ta sauvegarde était abîmée (fermeture en pleine écriture ?). La dernière copie saine a été rechargée ; tu perds au plus la dernière partie."
