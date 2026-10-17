class_name Version
extends RefCounted
## Numéro de version du jeu, affiché en bas à droite de tous les écrans et dans
## les rapports F9. À augmenter de 1 (dernier chiffre) à CHAQUE envoi sur GitHub,
## avec une ligne dans CHANGELOG.md (voir CLAUDE.md).

const NUMBER := "0.1.320"


static func label() -> String:
	return "Eden Slash v" + NUMBER
