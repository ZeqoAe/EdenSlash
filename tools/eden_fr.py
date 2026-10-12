"""Noms français et réglages des classes d'Eden importées automatiquement
(tools/auto_classes.py). Les 6 premières classes (samouraï, guerrier, voleur, chasseur,
clerc, magicien) restent réglées à la main dans build_classes.py.

CLASS_META : id interne -> numéro de classe d'Eden (c_class), nom français, type d'arme,
             tenue (#L…), cheveux, couleurs, courte présentation.
Les classes « vertes » (classes de base d'Eden) ont un parent = elles-mêmes ; les classes
« orange » (ascensions) héritent des sorts de leur classe parente.
"""

# famille d'Eden (c_class col. 11) -> classe de base qui donne les 5 sorts de novice
FAMILY_BASE = {1: 'warrior', 2: 'thief', 3: 'hunter', 4: 'cleric', 5: 'magician'}
FAMILY_FR = {1: 'Guerrier', 2: 'Voleur', 3: 'Chasseur', 4: 'Clerc', 5: 'Magicien'}

# couleurs de tenue prêtes à l'emploi
_D = {
    'steel': [[150, 155, 165], [60, 70, 110], [40, 40, 50]],
    'royal': [[60, 80, 160], [220, 190, 90], [40, 40, 60]],
    'crimson': [[160, 30, 35], [210, 170, 80], [40, 30, 35]],
    'forest': [[60, 110, 60], [150, 120, 70], [50, 40, 30]],
    'night': [[45, 40, 60], [120, 40, 70], [25, 25, 30]],
    'holy': [[235, 230, 215], [210, 175, 80], [110, 140, 200]],
    'violet': [[110, 60, 150], [210, 180, 90], [40, 30, 60]],
    'frost': [[170, 210, 235], [80, 120, 180], [40, 50, 70]],
    'ember': [[200, 90, 30], [240, 200, 90], [50, 30, 20]],
    'jade': [[50, 150, 120], [220, 200, 120], [30, 50, 40]],
    'shadow': [[30, 30, 40], [90, 20, 30], [15, 15, 20]],
    'sun': [[240, 200, 80], [200, 80, 40], [60, 40, 30]],
    'rose': [[220, 120, 160], [240, 220, 180], [80, 40, 60]],
    'bronze': [[160, 110, 60], [90, 60, 40], [40, 30, 20]],
    'sky': [[90, 160, 220], [240, 240, 250], [40, 60, 90]],
}
_H = {
    'black': [[40, 32, 40], [30, 25, 30], [20, 20, 20]],
    'brown': [[120, 60, 30], [90, 45, 25], [50, 30, 20]],
    'blond': [[230, 200, 120], [190, 160, 90], [120, 100, 60]],
    'silver': [[200, 200, 210], [150, 150, 160], [90, 90, 100]],
    'red': [[170, 40, 35], [120, 30, 25], [60, 20, 20]],
    'blue': [[60, 90, 170], [45, 70, 130], [30, 40, 80]],
    'purple': [[110, 60, 150], [80, 45, 110], [40, 30, 70]],
    'green': [[60, 130, 80], [45, 100, 60], [25, 60, 35]],
    'white': [[240, 240, 245], [210, 210, 220], [160, 160, 175]],
}


def _c(eden, name, weapon, outfit, hair, dye, hcol, lore, key=None):
    return {'eden': eden, 'name_fr': name, 'weapon_type': weapon, 'outfit': outfit, 'hair': hair,
            'dye': {'outfit': _D[dye], 'hair': _H[hcol]}, 'lore_fr': lore}


CLASS_META = {
    # --- classes vertes (classes de base d'Eden) ----------------------------------------
    'bard': _c(6, 'Barde', 'guitar', 251, 108, 'rose', 'blond',
               "Le barde enflamme le combat à la guitare : notes explosives, chants de guerre et mélodies de soin."),
    'knight': _c(7, 'Chevalier', 'rapier', 205, 103, 'royal', 'brown',
                 "Élégant et vif, le chevalier esquive plutôt qu'il ne pare et enchaîne des estocades mortelles."),
    'engineer': _c(8, 'Ingénieur', 'cannon', 215, 104, 'bronze', 'brown',
                   "L'ingénieur pilonne à distance : obus, bombes d'huile et armure mécanique de combat."),
    'martial_artist': _c(9, 'Artiste martial', 'cestus', 206, 102, 'ember', 'black',
                         "Poings gantés et souffle maîtrisé : l'artiste martial brise les gardes et charge sans peur."),
    'illusionist': _c(10, 'Illusionniste', 'grimoire', 253, 105, 'violet', 'purple',
                      "L'illusionniste trompe l'esprit : stalactites, hypnose et pluie de météores."),
    'blade_dancer': _c(11, 'Danseuse de lames', 'sword', 211, 102, 'rose', 'red',
                       "Chaque pas est une lame : la danseuse tourbillonne au milieu des ennemis."),
    'shaman': _c(12, 'Chaman', 'staff', 264, 108, 'jade', 'green',
                 "Le chaman parle à la nature : orages, ronces et pluies de vie."),
    'templar': _c(13, 'Templier', 'sword', 250, 103, 'holy', 'blond',
                  "Bouclier levé, le templier frappe de lumière sacrée et protège les siens."),
    'ranger': _c(14, 'Rôdeur', 'bow', 226, 104, 'forest', 'brown',
                 "Le rôdeur pilonne de très loin : pluies de flèches, tirs chargés et bonds d'esquive."),
    'warlock': _c(15, 'Démoniste', 'rod', 273, 105, 'shadow', 'silver',
                  "Le démoniste ronge ses proies : parasites des ténèbres, pactes et peste."),
    'sage': _c(17, 'Sage', 'hammer', 257, 108, 'sun', 'white',
               "Le sage frappe au marteau et soigne par ses auras."),
    'dragon_knight': _c(18, 'Chevalier dragon', 'spear', 259, 103, 'crimson', 'red',
                        "Lance au poing, le chevalier dragon change de forme : flamme, ténèbres ou furtivité."),
    'luminary': _c(19, 'Luminaire', 'greatsword', 230, 107, 'sky', 'white',
                   "Épéiste de lumière et d'ombre : le luminaire tranche avec l'aurore puis avec le néant."),
    'inquisitor': _c(59, 'Inquisiteur', 'gunscythe', 226, 102, 'night', 'black',
                     "Faux-fusil en main, l'inquisiteur enchaîne ses proies et les juge."),
    # --- classes orange (ascensions) --------------------------------------------------------
    'berserker': _c(21, 'Berserker', 'axe', 210, 103, 'crimson', 'red',
                    "Le berserker renonce à se défendre : la fureur du titan écrase tout."),
    'shielder': _c(22, 'Protecteur', 'sword', 210, 103, 'steel', 'brown',
                   "Le protecteur encaisse, provoque et inspire ses alliés."),
    'arch_elementalist': _c(23, 'Archi-élémentaliste', 'staff', 298, 105, 'ember', 'purple',
                            "Maître des trois éléments : tonnerre, flammes en spirale et vent polaire."),
    'stormcaster': _c(24, 'Maître de la gravité', 'staff', 298, 105, 'sky', 'blue',
                      "Il plie l'espace : trous noirs, gravité inversée et tempêtes d'apesanteur."),
    'trainer': _c(25, 'Dompteur', 'bow', 213, 104, 'forest', 'brown',
                  "Le dompteur appelle ses bêtes et marque les proies pour la meute."),
    'devil_hunter': _c(26, 'Chasseur de démons', 'bow', 213, 104, 'shadow', 'silver',
                       "Tireur des ténèbres, il traque et abat les démons d'un seul trait."),
    'adjudicator': _c(27, 'Juge sacré', 'scepter', 262, 108, 'holy', 'blond',
                      "Le juge sacré foudroie et bénit : feu divin et eaux purificatrices."),
    'equilibrian': _c(28, "Prêtre de l'ombre", 'scepter', 262, 108, 'night', 'silver',
                      "Entre lumière et nuit : ses sceaux sacrés soignent autant qu'ils punissent."),
    'assassin': _c(29, 'Assassin', 'dagger', 237, 102, 'shadow', 'black',
                   "Silence, une lame, une victime : l'assassin frappe depuis l'ombre."),
    'kage': _c(30, 'Kage', 'dagger', 237, 102, 'night', 'black',
               "Ninja de l'ombre : techniques d'évasion, clones et insectes."),
    'battlefield_poet': _c(31, 'Chantre de guerre', 'guitar', 251, 108, 'ember', 'red',
                           "Son métal brûle et électrise le champ de bataille."),
    'life_worshipper': _c(32, 'Chantre de vie', 'guitar', 251, 108, 'holy', 'blond',
                          "Ses chants de lumière soignent et accélèrent les siens."),
    'executioner': _c(33, 'Exécuteur', 'rapier', 205, 103, 'crimson', 'black',
                      "Lame assoiffée de sang : chaque coup reçu est rendu au centuple."),
    'glacier_knight': _c(34, 'Gardien du serment', 'rapier', 205, 103, 'frost', 'silver',
                         "Chevalier de glace : estocades gelées et monture protectrice."),
    'mecha_ares': _c(35, 'Arès mécanique', 'cannon', 215, 104, 'steel', 'brown',
                     "Pilote d'armure : poings d'acier, missiles et forteresse invincible."),
    'annihilator': _c(36, 'Annihilateur', 'cannon', 215, 104, 'bronze', 'black',
                      "Artilleur absolu : rayons, balles multicolores et canon satellite."),
    'asura': _c(37, 'Asura', 'cestus', 206, 102, 'ember', 'red',
                "Le poing de l'enfer : rythme de frappes et corps d'or."),
    'rakshasa': _c(38, 'Rakshasa', 'cestus', 206, 102, 'jade', 'black',
                   "Ondes de choc et poings du dragon : le rakshasa frappe à distance."),
    'demon_tamer': _c(39, 'Maître des chimères', 'grimoire', 253, 105, 'violet', 'purple',
                      "Il invoque et sacrifie des chimères démoniaques."),
    'chronologist': _c(40, 'Maître du temps', 'grimoire', 253, 105, 'sky', 'white',
                       "Il gèle, ralentit et accélère le temps lui-même."),
    'blade_acrobat': _c(41, "Danseuse d'épées", 'sword', 211, 102, 'sun', 'blond',
                        "Postures de star et danse d'épées tourbillonnante."),
    'elegant_dancer': _c(42, 'Danseuse envoûtante', 'sword', 211, 102, 'rose', 'purple',
                         "Ses pas de danse charment, protègent et désorientent."),
    'druid': _c(43, 'Druide', 'staff', 264, 108, 'forest', 'green',
                "Le druide prend la forme de l'ours, du singe ou du loup."),
    'archimage': _c(44, 'Chaman des totems', 'staff', 264, 108, 'jade', 'white',
                    "Totems de bénédiction, de temps et de méditation."),
    'dawnbreaker': _c(45, 'Chevalier de sang', 'sword', 250, 103, 'crimson', 'silver',
                      "Il vole le sang et la force de ses ennemis pour renaître."),
    'paladin': _c(46, 'Paladin', 'hammer', 250, 103, 'holy', 'blond',
                  "Marteau sacré et bouclier divin : la justice frappe en tonnerre."),
    'absolute_arrow': _c(47, 'Flèche absolue', 'bow', 226, 104, 'frost', 'silver',
                         "Tirs absolus : âme brisée, glace et rafales en chaîne."),
    'holy_arrow': _c(48, 'Flèche sacrée', 'bow', 226, 104, 'holy', 'blond',
                     "Flèches de lumière et pacte avec le dragon sacré."),
    'dark_envoy': _c(49, 'Émissaire des ténèbres', 'rod', 273, 105, 'shadow', 'red',
                     "Pactes infernaux et marque de mort : la prison des ténèbres s'ouvre."),
    'conjurer': _c(50, 'Envoûteur', 'rod', 273, 105, 'frost', 'blue',
                   "Malédictions de glace et de foudre, vers de givre et exil."),
    'blade_master': _c(51, 'Maître-sabre', 'katana', 272, 107, 'night', 'black',
                       "L'ancêtre du sabre : retour de l'hirondelle et sabre du rêve."),
    'master_fencer': _c(52, 'Héritier du sabre', 'katana', 272, 107, 'sky', 'silver',
                        "École ancienne de la lune : nouvelle lune, croissant et éclipse."),
    'psalmist': _c(53, 'Psalmiste', 'hammer', 257, 108, 'holy', 'white',
                   "Marteaux des archanges et auras de bénédiction."),
    'orator': _c(54, 'Orateur sacré', 'hammer', 257, 108, 'violet', 'white',
                 "Marteaux sacrés et paroles maudites qui brisent la volonté."),
    'dragon_soul': _c(55, 'Âme de dragon', 'spear', 259, 103, 'ember', 'red',
                      "L'âme du dragon le possède : souffle destructeur et écailles."),
    'dragon_rider': _c(56, 'Dompteur de dragons', 'spear', 259, 103, 'royal', 'blue',
                       "Il combat aux côtés du dragon divin, sous forme céleste ou impériale."),
    'black_blade': _c(57, 'Lame noire', 'greatsword', 230, 107, 'shadow', 'black',
                      "Lame démoniaque : tranches infernales et royaume corrompu."),
    'light_blade': _c(58, 'Lame de lumière', 'greatsword', 230, 107, 'holy', 'white',
                      "Lame sacrée : sanctuaire, frappes célestes et danse de la nuit sainte."),
    'reaver': _c(60, 'Faucheur', 'gunscythe', 226, 102, 'shadow', 'silver',
                 "La faux de la mort : chaînes de fureur et moisson des âmes."),
    'rifleteer': _c(61, 'Fusilier', 'gunscythe', 226, 102, 'night', 'black',
                    "Le fusil-faux en rafales : entraves d'ombre et champ du jugement."),
}

# nouvelles armes : nom, codes d'Eden (4 modèles), posture de combat, type de dégâts
NEW_WEAPON_TYPES = {
    'sword': {'name': 'Épée', 'codes': ['W10101', 'W10201', 'W10301', 'W10401'], 'battle': 'battle01', 'dmg_type': 'phys'},
    'rapier': {'name': 'Rapière', 'codes': ['W11401', 'W11501', 'W11601', 'W11701'], 'battle': 'battle11', 'dmg_type': 'phys'},
    'greatsword': {'name': 'Espadon', 'codes': ['W20801', 'W20901', 'W21001', 'W21101'], 'battle': 'battle03', 'dmg_type': 'phys'},
    'hammer': {'name': 'Marteau', 'codes': ['W40101', 'W40201', 'W40301', 'W40401'], 'battle': 'battle03', 'dmg_type': 'phys'},
    'rod': {'name': 'Bâton de métal', 'codes': ['W30801', 'W30901', 'W31001', 'W31101'], 'battle': 'battle04', 'dmg_type': 'mag',
            'attack_range': 9.0},
    'cestus': {'name': 'Gantelets', 'codes': ['W31301', 'W31401', 'W31501', 'W31601'], 'battle': 'battle10', 'dmg_type': 'phys'},
    'cannon': {'name': 'Canon', 'codes': ['W50801', 'W50901', 'W51001', 'W51101'], 'battle': 'battle06', 'dmg_type': 'phys',
               'attack_range': 12.0},
    'spear': {'name': 'Lance', 'codes': ['W52101', 'W52201', 'W52301', 'W52401'], 'battle': 'battle12', 'dmg_type': 'phys'},
    'guitar': {'name': 'Guitare', 'codes': ['W60801', 'W60901', 'W61001', 'W61101'], 'battle': 'battle08', 'dmg_type': 'mag',
               'attack_range': 10.0},
    'grimoire': {'name': 'Grimoire', 'codes': ['W61401', 'W61601', 'W61701', 'W61801'], 'battle': 'battle09', 'dmg_type': 'mag',
                 'attack_range': 11.0},
    'gunscythe': {'name': 'Faux-fusil', 'codes': ['W55401', 'W55402', 'W55501', 'W55502'], 'battle': 'battle03', 'dmg_type': 'phys'},
}

# noms français des sorts et certificats (traduits de l'anglais d'Eden et, quand
# l'anglais est approximatif, du chinois d'origine)
SPELL_FR = {
    # Barde
    50221: 'Rythme entraînant', 50222: 'Musicien populaire', 50110: 'Bombe vocale', 50111: 'Métal brûlant',
    50112: 'Musique de vie', 50113: 'Symphonie démoniaque', 50114: 'Mélodie exaltée', 50115: 'Hymne guerrier',
    50116: "Chant d'illusion", 50117: 'Poème du vent', 50172: 'Concerto sacré', 50171: 'Pulsation musicale',
    # Chevalier
    50203: 'Esprit clair', 50204: 'Expert de la rapière', 50043: 'Attaque continue', 50044: 'Tempête du jugement',
    50045: 'Sceau des lames', 50046: 'Intrépide', 50047: 'Brise du chevalier', 50048: 'Concentration',
    50049: 'Tactique élégante', 50153: 'Asile', 50154: 'Lancer de bouclier',
    # Ingénieur
    50215: 'Asile de métal', 50216: "Expert de l'artillerie", 50086: 'Artillerie lourde', 50087: 'Débogage',
    50088: 'Rayon rétrécissant', 50089: 'Réglages mécaniques', 50090: "Bombe d'huile", 50091: 'Poudre noire',
    50092: 'Bombe gluante', 50093: "Armure d'acier", 50165: 'Destruction par missiles', 50166: "Super homme d'acier",
    # Artiste martial
    50209: 'Impact commotionnant', 50210: 'Expert des gantelets', 50064: 'Coup dévastateur', 50065: 'Répression',
    50066: 'Assaut chargé', 50067: 'Rugissement de vajra', 50068: 'Force défensive', 50069: 'Accumulation',
    50070: 'Cicatrice spirituelle', 50160: 'Maîtrise du souffle', 50159: 'Volonté tenace',
    # Illusionniste
    50227: 'Métamorphose', 50228: 'Érudit', 50134: 'Stalactite mortelle', 50135: 'Œil hypnotique',
    50136: 'Stimulation', 50137: 'Domaine psychédélique', 50138: "Vague d'esprit", 50139: 'Frénésie du bouffon',
    50140: 'Retour du temps', 50141: 'Appel ancien', 50177: 'Magie inefficace', 50178: 'Aérolithe',
    # Danseuse de lames
    50211: "Expert de l'épée", 50212: 'Gymnaste', 50071: 'Superstar', 50072: 'Lame dansante', 50073: 'Charme éclatant',
    50074: 'Samba magique', 50075: 'Chant de patience', 50076: 'Danse de guerre', 50077: 'Saut de ballet',
    50162: 'Danse lente', 50161: "Danse de l'oiseau de feu", 60058: 'Danse hypnotique',
    # Chaman
    50223: 'Bouclier de la nature', 50224: 'Bâton druidique', 50118: 'Châtiment naturel', 50119: 'Rage des tempêtes',
    50120: 'Bouclier de ronces', 50121: 'Marques du vent', 50122: 'Énergie de la terre', 50123: 'Gouttes du ciel',
    50124: 'Cyclone verdoyant', 50125: 'Bénédiction de la nature', 50174: 'Arbre de vie', 50173: 'Rappel',
    # Templier
    50205: 'Volonté de fer', 50206: 'Expert du bouclier', 50050: 'Lumière sacrée', 50051: 'Impact du jugement',
    50052: 'Coup de bouclier', 50053: 'Avènement céleste', 50054: 'Bouclier décisif', 50055: 'Lumière de soin',
    50056: 'Lumière protectrice', 50156: 'Marteau du tonnerre', 50155: 'Bouclier de lumière', 60059: 'Pénitence',
    # Rôdeur
    50217: 'Résistance élémentaire', 50218: 'Expert du pilonnage', 50094: 'Tir commotionnant', 50095: "Pluie d'étoiles filantes",
    50096: 'Pilonnage', 50097: "Bond d'esquive", 50098: 'Charge', 50099: 'Cœur du tireur', 50100: 'Flèche de terreur',
    50101: 'Sérénité', 50168: "Poursuite de l'aigle", 50167: 'Regard perçant',
    # Démoniste
    50229: 'Cape de crânes', 50230: 'Esprit mort', 50142: "Flèche d'ombre", 50143: 'Parasite des ténèbres',
    50144: 'Attaque cauchemardesque', 50145: 'Menaces de mort', 50146: 'Conversion du sang', 50147: 'Tribut',
    50148: 'Sentence de mort', 50149: 'Pacte maléfique', 50179: 'Porteur de peste', 50180: 'Cri sauvage',
    # Sage
    50433: 'Descendant du sage', 50434: 'Expert du marteau', 50424: 'Marteau guérisseur', 50425: "Marteau d'inspiration",
    50426: 'Aura : protection du marteau', 50427: 'Aura : esprit du marteau', 50428: 'Aura : bouclier protecteur',
    50429: 'Aura : souffle éthéré', 50430: 'Aura : singularité', 50431: 'Courage inébranlable', 50432: 'Fracas terrestre',
    60057: 'Arrivée bénie',
    # Chevalier dragon
    50457: 'Maître dragon', 50456: 'Expert de la lance', 50444: 'Écaille inversée', 50445: 'Coup de queue du drake',
    50446: 'Dévoreur infernal', 50447: 'Puissance du drake', 50448: 'Embuscade du croc', 50449: "Taille de l'aile",
    50450: 'Forme du drake de feu', 50451: 'Forme du drake noir', 50452: 'Forme du drake furtif', 50453: 'Flamme noire cachée',
    # Luminaire
    50483: 'Esprit chaotique', 50482: 'Assaut du chaos', 50462: 'Fente de lumière', 50463: "Destruction de l'aurore",
    50464: 'Lumière éclatante', 50465: 'Gloire aveuglante', 50466: 'Prière sacrée', 50467: 'Taille noire',
    50468: 'Formation du silence', 50469: "Croix d'ombre", 50470: 'Porte des ténèbres', 50471: "Sacrifice de l'ombre",
    # Berserker
    50798: "Esprit sans peur", 50202: 'Double entaille', 50687: 'Frappe frénétique', 50688: 'Coup en pleine face',
    50689: 'Bousculade', 50690: 'Fièvre du titan', 50691: 'Survie désespérée', 50692: 'Rugissement meurtrier',
    50693: 'Colère', 50694: 'Cœur ébranlé',
    # Protecteur
    50799: 'Inébranlable', 50695: 'Frappe tenace', 50696: 'Coup provocant', 50697: 'Interception',
    50698: 'Corps du titan', 50699: 'Inspiration vitale', 50700: 'Rugissement inspirant', 50701: 'Effroi',
    50702: 'Volonté sans fin',
    # Archi-élémentaliste
    50225: 'Essence élémentaire', 50800: 'Expert du bâton', 50765: 'Explosion de tonnerre', 50766: 'Tornade de flammes',
    50767: 'Vent polaire du nord', 50768: 'Silence élémentaire', 50769: 'Chaos élémentaire', 50770: 'Barrière élémentaire',
    50771: 'Incarnation du tonnerre', 50772: 'Cercueil de glace', 50773: 'Libération magique', 50774: 'Dragon à neuf têtes',
    50775: 'Conversion du sang démoniaque',
    # Maître de la gravité
    50801: 'Expert du bâton', 50776: 'Plume céleste', 50777: 'Tourbillon des ailes', 50778: 'Trou noir',
    50779: 'Attraction vers le bas', 50780: 'Gravité déséquilibrée', 50781: 'Espace parallèle', 50783: 'Saut de quadrant',
    50784: 'Danse aérienne', 50785: 'Tempête antigravité', 50786: 'Équilibre gravitationnel',
    # Dompteur
    50213: 'Œil de lynx', 50893: "Expert de l'arc", 50850: 'Tir enchaîné', 50851: 'Tir rapide', 50852: 'Appel du roi des bêtes',
    50853: 'Appel de la bête dragon', 50854: 'Bête de substitution', 50855: 'Furie sauvage', 50856: 'Bandage de bête',
    50857: 'Marque de chasse', 50858: 'Tir en saut',
    # Chasseur de démons
    50894: "Expert de l'arc", 50867: 'Marque de tir', 50868: 'Salve ininterrompue', 50869: 'Tir visé', 50870: 'Tir de blocage',
    50871: 'Flèche vipérine', 50872: 'Chasseur caché', 50873: 'Forme de chasseur de démons', 50874: 'Posture de sniper',
    50875: 'Embuscade',
    # Juge sacré
    50219: 'Dissipation magique', 50895: 'Maître de cérémonie', 50876: "Frappe d'examen", 50877: 'Pluie de météores sacrés',
    50878: 'Feu divin', 50879: "Infusion d'énergie", 50880: 'Révélation de vie', 50881: 'Grâce sacrée',
    50882: 'Lumière de vérité', 50883: 'Reliques de vie', 50884: 'Eau purificatrice',
    # Prêtre de l'ombre
    50896: 'Maître de cérémonie', 50885: 'Venue de la lumière', 50886: 'Faux silencieuse', 50887: "Cercle de l'esprit saint",
    50888: 'Écriture du désespoir', 50889: 'Terre sacrée', 50890: 'Écran de flamme sacrée', 50891: 'Lumière de félicité',
    50892: 'Lumière de la nuit noire',
    # Assassin
    56047: 'Mains sans ombre', 50208: 'Expert de la dague', 56001: "Coup d'ombre", 56002: 'Égorgement',
    56003: 'Entailles mortelles', 56004: 'Assassinat silencieux', 56005: 'Forme meurtrière', 56006: 'Évanescence',
    56007: 'Marche nocturne', 56008: 'Dissimulation',
    # Kage
    56048: 'Mains sans ombre', 56011: 'Élément : évasion', 56016: 'Ombre : lien mortel', 56017: 'Corps : cyclone',
    56018: 'Sceau : flèche sombre', 56019: 'Interdit : armure cachée', 56020: 'Insecte : nid', 56021: 'Ninjutsu : clone',
    56022: 'Médecine : renaissance',
    # Chantre de guerre
    50802: 'Musicien populaire', 50703: 'Trille de flammes', 50704: 'Métal sombre', 50705: 'Mélodie de vie',
    50706: 'Chant démoniaque', 50707: 'Mélodie grave', 50708: 'Vent de paix', 50709: 'Requiem',
    50710: 'Tonnerre entrelacé',
    # Chantre de vie
    50803: 'Musicien populaire', 50711: 'Notes explosives', 50712: 'Chant de lumière', 50713: 'Suite de vie',
    50714: "Mouvement d'assaut", 50715: 'Mélodie légère', 50716: "Vent d'impatience", 50717: 'Chant du chasseur d\'âmes',
    50718: 'Voix du tonnerre',
    # Exécuteur
    50846: 'Esprit clair', 50809: 'Estoc sanguinaire', 50810: 'Riposte de sang', 50811: 'Lame de sang',
    50812: 'Retour héroïque', 50813: 'Garde de la lame', 50814: 'Souffle de feu', 50815: 'Ordre de charge',
    50816: 'Verdict du procès', 50817: 'Estoc à la main',
    # Gardien du serment
    50847: 'Esprit clair', 50818: 'Estoc de glace', 50819: 'Estoc tournoyant', 50820: "Limite de l'épée de glace",
    50821: 'Honneur', 50822: 'Destrier gardien', 50823: 'Protection glacée', 50824: 'Commandement',
    50825: 'Garde du serment', 50826: 'Estoc à la cheville',
    # Arès mécanique
    50804: "Expert de l'artillerie", 50737: "Poing d'acier", 50738: 'Programme de protection PCC0', 50739: 'Rayon gamma',
    50740: 'Missiles automatiques', 50741: 'Mine lancée', 50742: 'Armure mécanique', 50743: "Rempart d'acier invincible",
    50744: 'Anéantissement total',
    # Annihilateur
    50805: "Expert de l'artillerie", 50746: 'Tir concentré', 50747: 'Programme de soutien', 50748: 'Rugissement sonique',
    50749: 'Mode tir', 50750: 'Balles multicolores', 50751: 'Camouflage optique', 50752: 'Rechargement',
    50753: 'Canon satellite',
    # Asura
    50848: 'Expert des gantelets', 50827: 'Poing plongeant', 50829: 'Puissance du poing', 50831: 'Poing du tyran',
    50833: "Domaine d'Asura", 50834: 'Rythme des coups', 50835: 'Concentration du souffle', 50836: "Corps d'or",
    50837: 'Brise-roi',
    # Rakshasa
    50849: 'Expert des gantelets', 50838: "Ruée d'impact", 50839: 'Vague du dragon de feu', 50840: "Poing de l'ombre du dragon",
    50841: 'Regard furieux', 50842: 'Posture de la brise', 50843: 'Frappe explosive', 50844: "Canon de l'âme du dragon",
    50845: 'Concentration',
    # Maître des chimères
    56077: 'Expert du grimoire', 56053: 'Appel des chimères', 56057: 'Invocation du roi démon', 56058: 'Asservissement',
    56059: 'Sacrifice', 56060: 'Vitalité des chimères', 56061: 'Invasion des chimères', 56062: 'Chute des chimères',
    56063: 'Tempête des chimères',
    # Maître du temps
    56078: 'Érudit', 56068: 'Temps gelé', 56070: 'Ralentissement temporel', 56071: 'Hypnose temporelle',
    56072: 'Illusion du temps', 56073: 'Avance rapide', 56074: 'Temps suspendu', 56075: 'Retour en arrière',
    56076: 'Rétroaction temporelle',
    # Danseuse d'épées
    50806: 'Maître gymnaste', 50719: 'Posture de star', 50720: "Danse d'épées", 50721: 'Rythme charmeur',
    50722: 'Rythme magique', 50723: 'Envoûtement', 50724: 'Danse de victoire', 50725: 'Danse perturbante',
    50726: 'Danse de la nuit noire',
    # Danseuse envoûtante
    50807: 'Maître gymnaste', 50729: 'Danse absolue', 50730: 'Posture rapide', 50731: 'Pas étincelants',
    50732: 'Pas de samba', 50733: 'Danse de la colombe', 50734: 'Danse exaltante', 50735: 'Danse protectrice',
    50736: 'Danse navette',
    # Druide
    56106: 'Bâton druidique', 56079: 'Art vaudou', 56081: 'Frappe des ancêtres', 56082: 'Peine des âmes',
    56083: 'Source de vie', 56085: 'Armure du hérisson', 56086: 'Protection de la nature', 56087: 'Pouvoir de métamorphose',
    56088: 'Forme animale (ours)', 56089: 'Forme animale (singe)', 56090: 'Forme animale (loup)',
    # Chaman des totems
    56107: 'Bâton amplifié', 56095: 'Baiser du marais', 56096: "Contre-attaque de l'élu", 56097: 'Pluie bienfaitrice',
    56098: 'Totem de bénédiction', 56099: 'Totem du temps', 56100: 'Totem de révolte', 56101: 'Totem de grâce',
    56102: 'Totem de méditation',
    # Chevalier de sang
    56049: 'Volonté de fer', 56023: 'Vol de sang', 56024: "Vol d'âme", 56025: 'Vol de force', 56026: 'Taille de sang',
    56027: 'Taille démoniaque', 56028: 'Taille puissante', 56029: 'Domaine du sang', 56030: 'Renaissance du sang',
    # Paladin
    56050: 'Volonté de fer', 56031: 'Sceau du pouvoir', 56035: 'Protection de lumière', 56036: 'Bouclier sacré',
    56037: 'Marteau du châtiment', 56038: 'Marteau de justice', 56039: 'Marteau de tonnerre', 56040: 'Coup de bouclier furieux',
    56041: 'Forme de bénédiction',
    # Flèche absolue
    56129: 'Expert du pilonnage', 56111: 'Absolu : âme brisée', 56112: 'Absolu : âme de glace', 56113: 'Absolu : onde du vent',
    56114: 'Absolu : éclipse', 56115: 'Absolu : rafale', 56116: 'Absolu : esprit combatif', 56117: 'Absolu : majesté',
    56118: 'Absolu : ombre rapide',
    # Flèche sacrée
    56130: 'Expert du pilonnage', 56119: 'Flèche pure', 56120: "Frappe d'Amaterasu", 56121: 'Désarmement céleste',
    56122: 'Assaut de lumière céleste', 56123: 'Retraite sacrée', 56124: "Souffle de l'esprit saint", 56125: 'Foi sacrée',
    56126: 'Pacte du dragon sacré',
    # Émissaire des ténèbres
    50930: 'Esprit mort', 50897: 'Marque de mort', 50898: 'Pacte infernal', 50899: 'Pacte de la prison noire',
    50900: "Raffinage de l'enfer", 50901: 'Souffle raffiné', 50902: 'Sacrifice suprême', 50903: 'Impact de la nuit',
    50904: 'Bombardement de flammes', 50905: 'Venue de la mort',
    # Envoûteur
    50931: 'Esprit mort', 50912: "Malédiction de l'hiver", 50913: 'Malédiction du tonnerre', 50914: 'Essaim de givre',
    50915: 'Explosion de foudre', 50916: 'Venin du ver de glace', 50917: 'Dragon de foudre', 50918: 'Tonnerre hanté',
    50919: 'Nécrose du ver de glace', 50920: 'Exil',
    # Maître-sabre
    50302: 'Battojutsu', 50940: 'Expert du katana', 50921: 'Pas de jade', 50922: 'Esprit vide', 50923: "Retour de l'hirondelle",
    50924: 'Miroir limpide', 50925: 'Sabre du rêve', 50926: 'Garde', 50927: 'Barque de Ganryu', 50928: 'Résilience',
    # Héritier du sabre
    50941: 'Expert du katana', 50932: 'Souffle suspendu', 50933: 'Nouvelle lune', 50934: 'Croissant de lune',
    50935: 'Pleine lune', 50936: 'Éclipse', 50937: "Lune et ombre", 50938: 'Brume', 50939: "Éclair de l'aube",
    # Psalmiste
    56147: 'Spécialiste du marteau', 56131: "Marteau de l'archange", 56132: 'Marteau aux six ailes',
    56133: "Aura : bénédiction de l'ange", 56134: 'Aura : étreinte sacrée', 56135: 'Aura : protection de la prière',
    56136: 'Psaume du béni', 56137: 'Aura : protection spirituelle', 56138: 'Bénédiction du roi sage',
    # Orateur sacré
    56148: 'Spécialiste du marteau', 56139: 'Marteau céleste', 56140: 'Marteau démoniaque', 56141: 'Marteau du premier roi',
    56142: 'Aura : perte de combativité', 56143: 'Aura : mort sans souffle', 56144: "Aura : esprit brise-mur",
    56145: 'Aura : malédiction des mots', 56146: 'Mythe chanté',
    # Âme de dragon
    56200: 'Expert de la lance', 56153: 'Fureur du dragon divin', 56154: 'Terreur du dragon de feu', 56155: 'Souffle destructeur',
    56156: 'Retour du dragon caché', 56157: "Armure d'écailles", 56158: 'Retour de l\'âme du dragon',
    56159: 'Possession draconique', 56160: 'Rage du dévoreur',
    # Dompteur de dragons
    56201: 'Expert de la lance', 56162: 'Lance écarlate', 56163: "Lance dans l'âme", 56164: 'Taille du roi dragon',
    56165: 'Hurlement terrifiant', 56166: "Retour de l'aile", 56167: 'Colère du dragon', 56168: 'Forme céleste',
    56169: 'Forme impériale', 56170: 'Fin de forme', 56171: 'Combat aux côtés du dragon divin',
    # Lame noire
    56202: 'Impact chaotique', 56179: "Taille de l'enfer", 56180: 'Taille du démon', 56181: 'Taille sombre',
    56182: 'Brise-démon', 56183: 'Royaume corrompu', 56184: "Démon de l'ombre", 56185: 'Renversement sombre',
    56186: 'Souffle de la lame magique',
    # Lame de lumière
    56203: 'Impact chaotique', 56187: 'Sanctuaire', 56189: 'Jour saint', 56191: 'Taille du démon sacré',
    56193: 'Frappe céleste', 56195: 'Désillusion', 56196: 'Sacrifice du démon sacré', 56197: 'Danse de la nuit sainte',
    56199: 'Le dieu démon ébranle le ciel',
    # Inquisiteur
    50971: 'Voile de la mort', 50976: 'Maîtrise du faux-fusil', 50943: "Chaîne d'âme", 50944: 'Garrot', 50945: 'Impact infernal',
    50946: 'Spirale perçante', 50947: 'Flammes jumelles', 50948: 'Dévastation', 50949: 'Verdict final',
    50950: 'Posture de chasse', 53001: 'Carnage', 53002: 'Chaînes de souffrance',
    # Faucheur
    50977: 'Maîtrise du faux-fusil', 50951: 'Destination finale', 50953: 'Chaîne de fureur', 50955: 'Faux de la mort',
    50957: 'Moisson des âmes', 50958: 'Faux du jugement', 50959: 'Marche funèbre',
    # Fusilier
    50978: 'Maîtrise du faux-fusil', 50960: 'Taille sans peur', 50961: 'Croc de tempête', 50963: "Entrave d'ombre",
    50965: 'Champ du jugement', 50966: 'Balle-faux', 50969: "Sanction d'anéantissement", 50970: "Illusion de l'ombre",
}
