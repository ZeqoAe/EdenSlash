"""Construit les classes jouables à partir des données d'Eden Eternal.

    python -I tools/build_classes.py [--skip-models]

Sorties (game/) :
  data/classes.json        classes, compétences, passifs (adaptés au hack and slash)
  data/motion_keys.json    impacts / sons / traînées par animation (motion.ini)
  data/minimaps.json       mini-cartes officielles et leur calage monde -> image
  assets/player/<classe>/  modèle du héros (tenue de classe, animations utiles)
  assets/weapons/          armes de la classe (+ icônes)
  assets/ui/skills/        icônes des compétences
  assets/sound/            sons référencés par les animations
"""
import argparse
import io
import json
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import edenini  # noqa: E402
import edenpkg  # noqa: E402
import nif2gltf  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), '..')
GAME = os.path.join(ROOT, 'game')
PY = sys.executable

# Animation Eden (c_spell col. 3 = identifiant de séquence) -> nom de l'animation
MOTION_ID = {3001: 'shoot23', 3002: 'shoot24', 3003: 'shoot25', 3004: 'shoot54', 412: 'shoot12',
             401: 'shoot01', 402: 'shoot02', 3091: 'shoot50', 3092: 'shoot51', 3094: 'shoot63'}

# Calage des mini-cartes officielles (tools : ajustement eau / sol, voir journal)
MINIMAPS = {
    's002': {'image': 'res://assets/ui/maps/s002m.png', 'ppm': 1.0971, 'ox': 12, 'oy': 8},
    's100': {'image': 'res://assets/ui/maps/s100m.png', 'ppm': 3.2, 'ox': 36, 'oy': 54},
}

# --- Samouraï : compétences d'Eden adaptées au hack and slash -------------------------
# kind : dash (fond en avant), spin (autour de soi), cone (devant), fan (éventail long),
#        flurry (plusieurs coups), line (estoc), buff (renforcement)
SAMURAI_SKILLS = [
    {'id': 50181, 'kind': 'dash', 'mult': 1.8, 'radius': 2.6, 'arc': 120, 'dash': 6.0, 'cooldown': 6.0,
     'applies': {'bleed': 8.0},
     'desc': "Fond sur l'ennemi (6 m) : {dmg} % de dégâts et Saignement (8 s, 15 % de l'attaque par seconde)."},
    {'id': 50182, 'kind': 'spin', 'mult': 1.1, 'hits': 2, 'radius': 4.0, 'arc': 360, 'cooldown': 9.0,
     'buff': {'solar': 8.0},
     'desc': "Tourbillon solaire autour de toi : 2 coups de {dmg} %. Bénédiction solaire : -25 % de dégâts subis (8 s)."},
    {'id': 50183, 'kind': 'cone', 'mult': 2.0, 'radius': 4.0, 'arc': 120, 'cooldown': 5.0,
     'combo': {'requires': 'bleed', 'applies': {'scar': 8.0}},
     'desc': "Entaille en croix : {dmg} %. Sur une cible en Saignement : Cicatrice (ses dégâts -30 %, 8 s)."},
    {'id': 50184, 'kind': 'fan', 'mult': 1.7, 'radius': 10.0, 'arc': 90, 'cooldown': 8.0,
     'applies': {'purgatory': 8.0},
     'desc': "Purgatoire en éventail (10 m) : {dmg} % et Purgatoire (dégâts subis +20 %, 8 s)."},
    {'id': 50185, 'kind': 'flurry', 'mult': 0.9, 'hits': 3, 'radius': 3.5, 'arc': 160, 'cooldown': 7.0,
     'combo': {'requires': 'bleed', 'applies': {'cranes': 8.0}},
     'desc': "Danse des grues : 3 coups de {dmg} %. Sur Saignement : Mille grues (dégâts subis +15 %, 8 s)."},
    {'id': 50186, 'kind': 'cone', 'mult': 2.8, 'radius': 3.5, 'arc': 70, 'cooldown': 10.0,
     'combo': {'requires': 'scar', 'buff': {'marduk': 8.0}},
     'desc': "Frappe éclair : {dmg} %. Sur Cicatrice : Langue de Marduk (+30 % d'attaque et de vitesse, 8 s)."},
    {'id': 50187, 'kind': 'fan', 'mult': 2.2, 'radius': 10.0, 'arc': 90, 'cooldown': 10.0,
     'combo': {'requires': 'purgatory', 'double': True},
     'desc': "Lame d'Asura en éventail (10 m) : {dmg} %, doublé sur les cibles en Purgatoire."},
    {'id': 50188, 'kind': 'line', 'mult': 2.3, 'radius': 8.0, 'arc': 25, 'cooldown': 8.0,
     'combo': {'requires': 'cranes', 'applies': {'stun': 2.0}},
     'desc': "Estoc en ligne (8 m) : {dmg} %. Sur Mille grues : renverse la cible (2 s)."},
    {'id': 50189, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 25.0,
     'buff': {'shrine': 10.0},
     'desc': "Volonté du sanctuaire : +30 % de vitesse et -30 % de dégâts subis (10 s). Sous Bénédiction solaire : immunité au renversement."},
]

SAMURAI_PASSIVES = [
    {'id': 'battojutsu', 'eden': 50302, 'name': 'Battojutsu', 'stat': {'crit': 0.20}, 'max': 1,
     'desc': '+20 % de chances de coup critique.'},
    {'id': 'katana_expert', 'eden': 50305, 'name': 'Katana Expert', 'stat': {'atk_pct': 0.15}, 'max': 1,
     'desc': '+15 % d\'attaque avec un katana.'},
]

# passifs communs à toutes les classes (statistiques et build « aérien »)
COMMON_PASSIVES = [
    {'id': 'vigor', 'name': 'Corps aguerri', 'stat': {'hp_pct': 0.15}, 'max': 3, 'desc': '+15 % de PV max.'},
    {'id': 'swift_blade', 'name': 'Lame du vent', 'stat': {'atk_speed': 0.12}, 'max': 3,
     'desc': "+12 % de vitesse d'attaque."},
    {'id': 'bloodthirst', 'name': 'Soif de sang', 'stat': {'lifesteal': 0.03}, 'max': 3,
     'desc': '3 % des dégâts infligés rendent des PV.'},
    {'id': 'light_step', 'name': 'Pas léger', 'stat': {'move_speed': 0.08}, 'max': 2,
     'desc': '+8 % de vitesse de déplacement.'},
    {'id': 'keen_edge', 'name': 'Fil tranchant', 'stat': {'crit_dmg': 0.30}, 'max': 3,
     'desc': '+30 % de dégâts critiques.'},
    {'id': 'focus', 'name': 'Concentration', 'stat': {'cdr': 0.08}, 'max': 3,
     'desc': '-8 % de temps de recharge des compétences.'},
    # build « aérien » : le saut devient une arme
    {'id': 'air_jump', 'name': 'Saut aérien', 'stat': {}, 'max': 2,
     'desc': "+1 saut en l'air (double, puis triple saut)."},
    {'id': 'high_jump', 'name': 'Bond puissant', 'stat': {}, 'max': 2,
     'desc': "+20 % de hauteur de saut : passe au-dessus de plus d'attaques."},
    {'id': 'dive_strike', 'name': 'Frappe plongeante', 'stat': {}, 'max': 3,
     'desc': "Attaquer en l'air plonge au sol : dégâts de zone et étourdissement."},
    {'id': 'featherfall', 'name': 'Apesanteur', 'stat': {}, 'max': 2,
     'desc': "Saut flottant : -25 % de gravité, plus de temps en l'air pour viser et esquiver."},
    {'id': 'air_dash', 'name': 'Pas aérien', 'stat': {}, 'max': 2,
     'desc': "+1 esquive en l'air avant de retoucher le sol."},
]
SAMURAI_PASSIVES = SAMURAI_PASSIVES + COMMON_PASSIVES

# --- Classes de base d'Eden : Guerrier, Voleur, Chasseur, Clerc, Magicien ---------------
# kinds supplémentaires : bolt (projectile, volley/spread/pierce), ground (zone au sol à
# l'endroit visé, range = distance de lancer), heal (soin en % des PV max), blink (téléportation)
WARRIOR_SKILLS = [
    {'id': 50011, 'kind': 'cone', 'mult': 2.0, 'radius': 3.6, 'arc': 120, 'cooldown': 5.0, 'applies': {'stun': 0.8},
     'desc': "Impact profond : {dmg} % en cône et renverse (0,8 s)."},
    {'id': 50012, 'kind': 'cone', 'mult': 2.8, 'radius': 3.4, 'arc': 80, 'cooldown': 8.0, 'applies': {'scar': 6.0},
     'desc': "Coup destructeur : {dmg} %. Cicatrice : dégâts de la cible -30 % (6 s)."},
    {'id': 50015, 'kind': 'spin', 'mult': 0.85, 'hits': 3, 'radius': 4.2, 'arc': 360, 'cooldown': 7.0,
     'desc': "Cyclone de combat : 3 coups de {dmg} % tout autour."},
    {'id': 50036, 'kind': 'cone', 'mult': 1.8, 'radius': 3.6, 'arc': 140, 'cooldown': 6.0, 'applies': {'bleed': 8.0},
     'desc': "Attaque sanglante : {dmg} % et Saignement (8 s)."},
    {'id': 50037, 'kind': 'dash', 'mult': 2.0, 'radius': 2.8, 'arc': 120, 'dash': 5.0, 'cooldown': 9.0, 'applies': {'stun': 1.2},
     'desc': "Poing de colère : fonce (5 m), {dmg} % et renverse (1,2 s)."},
    {'id': 50013, 'kind': 'spin', 'mult': 0.5, 'radius': 6.5, 'arc': 360, 'cooldown': 12.0, 'applies': {'purgatory': 8.0},
     'desc': "Provocation : {dmg} % autour, les ennemis subissent +20 % de dégâts (8 s)."},
    {'id': 50042, 'kind': 'spin', 'mult': 0.3, 'radius': 7.0, 'arc': 360, 'cooldown': 15.0, 'applies': {'chill': 5.0, 'scar': 5.0},
     'desc': "Intimidation : ralentit et affaiblit tous les ennemis proches (5 s)."},
    {'id': 50014, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 20.0, 'buff': {'fury': 8.0},
     'desc': "Déclaration de colère : Fureur, +25 % de dégâts (8 s)."},
    {'id': 50041, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 22.0, 'buff': {'barrier': 8.0},
     'desc': "Rugissement de fer : Barrière, -40 % de dégâts subis (8 s)."},
]

THIEF_SKILLS = [
    {'id': 50057, 'kind': 'dash', 'mult': 1.5, 'radius': 2.4, 'arc': 120, 'dash': 7.0, 'cooldown': 5.0,
     'desc': "Attaque éclair : bondit (7 m), {dmg} %."},
    {'id': 50016, 'kind': 'cone', 'mult': 1.6, 'radius': 3.0, 'arc': 120, 'cooldown': 5.0, 'applies': {'stun': 0.6},
     'desc': "Coup sec : {dmg} % et renverse (0,6 s)."},
    {'id': 50017, 'kind': 'flurry', 'mult': 0.7, 'hits': 3, 'radius': 3.0, 'arc': 150, 'cooldown': 6.0, 'applies': {'bleed': 6.0},
     'desc': "Coups résonnants : 3 × {dmg} % et Saignement (6 s)."},
    {'id': 50020, 'kind': 'flurry', 'mult': 0.5, 'hits': 5, 'radius': 3.0, 'arc': 150, 'cooldown': 9.0,
     'desc': "Frappe furieuse : 5 × {dmg} %."},
    {'id': 50058, 'kind': 'cone', 'mult': 3.0, 'radius': 3.0, 'arc': 70, 'cooldown': 10.0,
     'combo': {'requires': 'poison', 'double': True},
     'desc': "Embuscade : {dmg} %, doublé sur une cible empoisonnée."},
    {'id': 50059, 'kind': 'cone', 'mult': 1.4, 'radius': 3.2, 'arc': 120, 'cooldown': 12.0, 'applies': {'poison': 8.0, 'freeze': 1.5},
     'desc': "Confinement mortel : {dmg} %, Poison (8 s) et immobilise (1,5 s)."},
    {'id': 50061, 'kind': 'blink', 'mult': 1.2, 'radius': 3.0, 'arc': 360, 'range': 7.0, 'cooldown': 8.0, 'applies': {'poison': 5.0},
     'desc': "Pas de l'ombre : se téléporte (7 m) puis {dmg} % autour et Poison (5 s)."},
    {'id': 50019, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 15.0, 'buff': {'haste': 6.0},
     'desc': "Ombre rapide : Hâte, +30 % de vitesse (6 s)."},
    {'id': 50060, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 18.0, 'buff': {'keen': 8.0},
     'desc': "Force cachée : Œil acéré, +25 % de critique (8 s)."},
]

HUNTER_SKILLS = [
    {'id': 50021, 'kind': 'bolt', 'mult': 2.2, 'radius': 0.0, 'arc': 0, 'range': 16.0, 'pierce': 1, 'projectile': 'arrow', 'cooldown': 4.0,
     'desc': "Tir précis : flèche de {dmg} % qui traverse une cible (16 m)."},
    {'id': 50022, 'kind': 'bolt', 'mult': 1.8, 'radius': 0.0, 'arc': 0, 'range': 18.0, 'pierce': 99, 'projectile': 'arrow', 'cooldown': 7.0,
     'desc': "Perforation : flèche de {dmg} % qui traverse toute la ligne (18 m)."},
    {'id': 50078, 'kind': 'bolt', 'mult': 0.8, 'radius': 0.0, 'arc': 0, 'range': 14.0, 'volley': 5, 'spread': 50, 'projectile': 'arrow', 'cooldown': 7.0,
     'desc': "Tir en chaîne : 5 flèches de {dmg} % en éventail."},
    {'id': 50025, 'kind': 'bolt', 'mult': 1.4, 'radius': 0.0, 'arc': 0, 'range': 15.0, 'projectile': 'arrow', 'cooldown': 6.0, 'applies': {'chill': 5.0},
     'desc': "Tir aux genoux : {dmg} % et ralentit (5 s)."},
    {'id': 50079, 'kind': 'bolt', 'mult': 1.6, 'radius': 0.0, 'arc': 0, 'range': 15.0, 'projectile': 'arrow', 'cooldown': 9.0,
     'applies': {'bleed': 8.0, 'purgatory': 6.0},
     'desc': "Blessure perçante : {dmg} %, Saignement (8 s) et dégâts subis +20 % (6 s)."},
    {'id': 50081, 'kind': 'bolt', 'mult': 1.5, 'radius': 0.0, 'arc': 0, 'range': 15.0, 'projectile': 'arrow', 'cooldown': 10.0, 'applies': {'stun': 1.5},
     'desc': "Tir étourdissant : {dmg} % et renverse (1,5 s)."},
    {'id': 50082, 'kind': 'ground', 'mult': 1.2, 'radius': 4.0, 'arc': 360, 'range': 12.0, 'cooldown': 12.0, 'applies': {'stun': 1.0},
     'desc': "Bombe flash : {dmg} % dans une zone (4 m) à 12 m, renverse (1 s)."},
    {'id': 50083, 'kind': 'bolt', 'mult': 0.9, 'hits': 3, 'radius': 0.0, 'arc': 0, 'range': 14.0, 'projectile': 'fire', 'cooldown': 8.0, 'applies': {'burn': 6.0},
     'desc': "Flèches ardentes : 3 tirs de {dmg} % et Brûlure (6 s)."},
    {'id': 50023, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 20.0, 'buff': {'keen': 10.0},
     'desc': "Œil de faucon : Œil acéré, +25 % de critique (10 s)."},
]

CLERIC_SKILLS = [
    {'id': 50102, 'kind': 'bolt', 'mult': 2.0, 'radius': 0.0, 'arc': 0, 'range': 14.0, 'pierce': 1, 'projectile': 'holy', 'cooldown': 4.0,
     'applies': {'shock': 6.0}, 'desc': "Sanction de lumière : trait sacré de {dmg} %, dégâts subis +15 % (6 s)."},
    {'id': 50026, 'kind': 'ground', 'mult': 1.8, 'radius': 4.0, 'arc': 360, 'range': 10.0, 'cooldown': 6.0, 'applies': {'stun': 0.8},
     'desc': "Séisme : {dmg} % dans une zone (4 m) et renverse (0,8 s)."},
    {'id': 50027, 'kind': 'spin', 'mult': 0.8, 'hits': 3, 'radius': 4.5, 'arc': 360, 'cooldown': 8.0,
     'desc': "Tornade : 3 × {dmg} % autour de toi."},
    {'id': 50103, 'kind': 'ground', 'mult': 2.6, 'radius': 5.0, 'arc': 360, 'range': 12.0, 'cooldown': 12.0, 'applies': {'stun': 1.2},
     'desc': "Châtiment sacré : {dmg} % dans une large zone et renverse (1,2 s)."},
    {'id': 50028, 'kind': 'heal', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'heal': 0.25, 'cooldown': 10.0,
     'desc': "Soin : rend 25 % des PV max."},
    {'id': 50106, 'kind': 'heal', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'heal': 0.12, 'cooldown': 8.0, 'buff': {'regen': 8.0},
     'desc': "Cure de vie : rend 12 % des PV et Régénération (3 %/s, 8 s)."},
    {'id': 50109, 'kind': 'heal', 'mult': 1.0, 'radius': 5.0, 'arc': 360, 'heal': 0.3, 'cooldown': 25.0,
     'desc': "Rayonnement guérisseur : rend 30 % des PV et {dmg} % autour de toi."},
    {'id': 50029, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 18.0, 'buff': {'barrier': 8.0},
     'desc': "Prévention : Barrière, -40 % de dégâts subis (8 s)."},
    {'id': 50104, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 20.0, 'buff': {'fury': 10.0},
     'desc': "Bénédiction de lumière : Fureur, +25 % de dégâts (10 s)."},
]

MAGICIAN_SKILLS = [
    {'id': 50031, 'kind': 'ground', 'mult': 2.0, 'radius': 3.5, 'arc': 360, 'range': 12.0, 'cooldown': 4.0, 'applies': {'burn': 6.0},
     'desc': "Bombe de feu : {dmg} % dans une zone (3,5 m) et Brûlure (6 s)."},
    {'id': 50126, 'kind': 'bolt', 'mult': 2.4, 'radius': 0.0, 'arc': 0, 'range': 16.0, 'pierce': 2, 'projectile': 'magic', 'cooldown': 5.0,
     'applies': {'shock': 5.0}, 'desc': "Éclair : {dmg} %, traverse 2 cibles, dégâts subis +15 % (5 s)."},
    {'id': 50033, 'kind': 'cone', 'mult': 1.5, 'radius': 7.0, 'arc': 70, 'cooldown': 6.0, 'applies': {'chill': 5.0},
     'desc': "Frisson de l'hiver : cône de givre (7 m), {dmg} % et ralentit (5 s)."},
    {'id': 50032, 'kind': 'ground', 'mult': 1.2, 'radius': 5.0, 'arc': 360, 'range': 12.0, 'cooldown': 8.0, 'applies': {'shock': 6.0, 'chill': 3.0},
     'desc': "Toile d'éclairs : {dmg} % dans une zone (5 m), électrocute et ralentit."},
    {'id': 50127, 'kind': 'ground', 'mult': 1.0, 'hits': 3, 'radius': 5.0, 'arc': 360, 'range': 12.0, 'cooldown': 12.0, 'applies': {'burn': 6.0},
     'desc': "Feu de l'enfer : 3 × {dmg} % dans une zone et Brûlure (6 s)."},
    {'id': 50128, 'kind': 'ground', 'mult': 0.7, 'hits': 4, 'radius': 6.0, 'arc': 360, 'range': 12.0, 'cooldown': 14.0,
     'applies': {'chill': 4.0, 'freeze': 1.0}, 'desc': "Tempête de neige : 4 × {dmg} % dans une large zone, gèle (1 s)."},
    {'id': 50035, 'kind': 'blink', 'mult': 0.6, 'radius': 3.0, 'arc': 360, 'range': 9.0, 'cooldown': 8.0, 'applies': {'chill': 3.0},
     'desc': "Saut dimensionnel : se téléporte (9 m), {dmg} % et ralentit autour."},
    {'id': 50034, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 22.0, 'buff': {'fury': 10.0},
     'desc': "Amplification magique : Fureur, +25 % de dégâts (10 s)."},
    {'id': 50133, 'kind': 'buff', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'cooldown': 22.0, 'buff': {'barrier': 10.0},
     'desc': "Bouclier de glace : Barrière, -40 % de dégâts subis (10 s)."},
]


def _class_passives(a, b):
    return [a, b] + COMMON_PASSIVES


WARRIOR_PASSIVES = _class_passives(
    {'id': 'unshakable', 'eden': 50201, 'name': 'Inébranlable', 'stat': {'hp_pct': 0.2}, 'max': 1, 'desc': '+20 % de PV max.'},
    {'id': 'double_cut', 'eden': 50202, 'name': 'Double entaille', 'stat': {'atk_pct': 0.12}, 'max': 2, 'desc': "+12 % d'attaque."})
THIEF_PASSIVES = _class_passives(
    {'id': 'quick_means', 'eden': 50207, 'name': 'Moyens rapides', 'stat': {'atk_speed': 0.15}, 'max': 2, 'desc': "+15 % de vitesse d'attaque."},
    {'id': 'dagger_expert', 'eden': 50208, 'name': 'Expert de la dague', 'stat': {'crit': 0.15}, 'max': 1, 'desc': '+15 % de chances de critique.'})
HUNTER_PASSIVES = _class_passives(
    {'id': 'hawkeye', 'eden': 50213, 'name': 'Œil de lynx', 'stat': {'reach': 0.2}, 'max': 2, 'desc': '+20 % de portée.'},
    {'id': 'bow_expert', 'eden': 50214, 'name': "Expert de l'arc", 'stat': {'atk_pct': 0.15}, 'max': 1, 'desc': "+15 % d'attaque avec un arc."})
CLERIC_PASSIVES = _class_passives(
    {'id': 'iron_will', 'eden': 50205, 'name': 'Volonté de fer', 'stat': {'hp_pct': 0.15}, 'max': 2, 'desc': '+15 % de PV max.'},
    {'id': 'shield_expert', 'eden': 50206, 'name': 'Foi protectrice', 'stat': {'lifesteal': 0.03}, 'max': 2, 'desc': '3 % des dégâts infligés rendent des PV.'})
MAGICIAN_PASSIVES = _class_passives(
    {'id': 'elemental_essence', 'eden': 50225, 'name': 'Essence élémentaire', 'stat': {'area': 0.15}, 'max': 2, 'desc': '+15 % de zone d\'effet.'},
    {'id': 'staff_expert', 'eden': 50226, 'name': 'Expert du bâton', 'stat': {'atk_pct': 0.15}, 'max': 1, 'desc': "+15 % d'attaque avec un bâton."})


def _base_class(class_id, outfit, hair, dye, weapons, battle, attacks, combo, skills, passives, lore, **extra):
    c = {
        'class_id': class_id, 'body': 'm',
        'appearance': {'outfit': '#L%d' % outfit, 'skin': 'SL%d' % outfit, 'hair': '#L%d' % hair, 'face': '#LFACE',
                       'dye': dye},
        'weapons': weapons,
        'anims': {'idle': 'stand01', 'battle': battle, 'run': 'move02', 'attacks': attacks,
                  'hurt': 'hurt13', 'death': 'death01', 'jump': 'jump01', 'dodge': 'jump02'},
        'combo': combo, 'skills': skills, 'passives': passives, 'start_skills': 3, 'lore_fr': lore,
    }
    c.update(extra)
    return c


NEW_CLASSES = {
    'warrior': _base_class(
        1, 210, 103, {'outfit': [[120, 125, 135], [170, 40, 35], [60, 55, 50]], 'hair': [[120, 60, 30], [90, 45, 25], [50, 30, 20]]},
        ['W20101', 'W20201', 'W20301', 'W20401'], 'battle03', ['attack08', 'attack09'],
        [{'anim': 'attack08', 'mult': 1.1, 'arc': 160, 'radius': 3.0, 'hit_fx': 's00241'},
         {'anim': 'attack09', 'mult': 1.3, 'arc': 160, 'radius': 3.0, 'hit_fx': 's00241'},
         {'anim': 'shoot25', 'mult': 2.6, 'arc': 360, 'radius': 3.8, 'leap': 6.0, 'finisher': True,
          'applies': {'stun': 0.6}, 'hit_fx': 's00541'}],
        WARRIOR_SKILLS, WARRIOR_PASSIVES,
        "Le guerrier encaisse en première ligne : sa hache lourde renverse et brise les rangs ennemis.",
        weapon_name='Hache', base={'hp': 1.25, 'def': 6.0, 'atk': 1.0}),
    'thief': _base_class(
        5, 237, 102, {'outfit': [[45, 40, 55], [110, 30, 60], [25, 25, 30]], 'hair': [[200, 200, 210], [150, 150, 160], [90, 90, 100]]},
        ['W10801', 'W10901', 'W11001', 'W11101'], 'battle02', ['attack05', 'attack06'],
        [{'anim': 'attack05', 'mult': 0.8, 'arc': 140, 'speed': 1.25, 'hit_fx': 's00141'},
         {'anim': 'attack06', 'mult': 0.9, 'arc': 140, 'speed': 1.25, 'hit_fx': 's00141'},
         {'anim': 'attack05', 'mult': 1.0, 'arc': 140, 'speed': 1.3, 'hit_fx': 's00241'},
         {'anim': 'shoot23', 'mult': 1.8, 'arc': 360, 'radius': 3.2, 'leap': 7.5, 'finisher': True,
          'applies': {'poison': 5.0}, 'hit_fx': 's00541'}],
        THIEF_SKILLS, THIEF_PASSIVES,
        "Le voleur frappe vite et disparaît : dagues empoisonnées, pas de l'ombre et embuscades.",
        weapon_name='Dague', base={'hp': 0.9, 'crit': 0.1, 'atk_speed': 0.15, 'move_speed': 0.08}),
    'hunter': _base_class(
        3, 213, 104, {'outfit': [[70, 110, 60], [150, 110, 60], [60, 45, 35]], 'hair': [[150, 90, 40], [110, 65, 30], [60, 40, 20]]},
        ['W50101', 'W50201', 'W50301', 'W50401'], 'battle05', ['attack12'],
        [{'anim': 'attack12', 'mult': 0.9, 'bolt': True, 'projectile': 'arrow', 'hit_fx': 's00141'},
         {'anim': 'attack12', 'mult': 1.0, 'bolt': True, 'projectile': 'arrow', 'hit_fx': 's00141'},
         {'anim': 'shoot50', 'mult': 1.4, 'bolt': True, 'volley': 3, 'pierce': 1, 'projectile': 'arrow',
          'finisher': True, 'hit_fx': 's00241'}],
        HUNTER_SKILLS, HUNTER_PASSIVES,
        "Le chasseur tient l'ennemi à distance : flèches perçantes, volées et pièges aveuglants.",
        weapon_name='Arc', weapon_bone='Bip01 L Hand', attack_range=13.0, base={'hp': 0.85, 'atk': 0.95}),
    'cleric': _base_class(
        4, 262, 108, {'outfit': [[235, 230, 220], [200, 165, 70], [120, 140, 190]], 'hair': [[230, 200, 120], [190, 160, 90], [120, 100, 60]]},
        ['W30101', 'W30201', 'W30301', 'W30401'], 'battle04', ['attack10', 'attack11'],
        [{'anim': 'attack10', 'mult': 1.0, 'arc': 150, 'hit_fx': 's00141'},
         {'anim': 'attack11', 'mult': 1.1, 'arc': 150, 'hit_fx': 's00241'},
         {'anim': 'shoot01', 'mult': 2.0, 'arc': 360, 'radius': 4.0, 'finisher': True,
          'applies': {'shock': 5.0}, 'hit_fx': 's00541'}],
        CLERIC_SKILLS, CLERIC_PASSIVES,
        "Le clerc soigne ses blessures et foudroie le mal : zones sacrées, soins et barrières.",
        weapon_name='Sceptre', base={'hp': 1.1, 'def': 3.0, 'atk': 0.9}),
    'magician': _base_class(
        2, 298, 105, {'outfit': [[60, 70, 140], [200, 170, 80], [40, 35, 60]], 'hair': [[90, 60, 140], [70, 45, 110], [40, 30, 70]]},
        ['W60101', 'W60201', 'W60301', 'W60401'], 'battle07', ['attack14'],
        [{'anim': 'attack14', 'mult': 0.9, 'bolt': True, 'projectile': 'magic', 'hit_fx': 's00341'},
         {'anim': 'attack14', 'mult': 1.0, 'bolt': True, 'projectile': 'magic', 'hit_fx': 's00341'},
         {'anim': 'shoot01', 'mult': 1.3, 'bolt': True, 'volley': 3, 'pierce': 1, 'projectile': 'fire',
          'finisher': True, 'hit_fx': 's00541'}],
        MAGICIAN_SKILLS, MAGICIAN_PASSIVES,
        "Le magicien plie les éléments : feu, glace et foudre ravagent des zones entières.",
        weapon_name='Bâton', attack_range=12.0, base={'hp': 0.8, 'atk': 1.15}),
}


CLASSES = {
    'samurai': {
        'class_id': 16, 'body': 'm',
        'appearance': {'outfit': '#L272', 'skin': 'SL272', 'hair': '#L107', 'face': '#LFACE',
                       'dye': {'outfit': [[150, 25, 30], [225, 180, 90], [35, 30, 40]],
                               'hair': [[40, 32, 40], [30, 25, 30], [20, 20, 20]]}},
        'weapons': ['W21301', 'W21401', 'W21501', 'W21601'],
        'anims': {'idle': 'stand01', 'battle': 'battle13', 'run': 'move02', 'attacks': ['attack25', 'attack26'],
                  'hurt': 'hurt13', 'death': 'death01', 'jump': 'jump01', 'dodge': 'jump02'},
        # combo d'auto-attaque : sabre dans un sens, dans l'autre, puis coup final en saut
        # (zone, renversement) ; voir Player.combo_chain()
        'combo': [
            {'anim': 'attack25', 'mult': 1.0, 'arc': 150, 'hit_fx': 's00141'},
            {'anim': 'attack26', 'mult': 1.15, 'arc': 150, 'hit_fx': 's00241'},
            {'anim': 'shoot24', 'mult': 2.2, 'arc': 360, 'radius': 3.4, 'leap': 7.5, 'dash': 2.0, 'speed': 1.15,
             'finisher': True, 'applies': {'stun': 0.4}, 'hit_fx': 's00541'},
        ],
        'skills': SAMURAI_SKILLS,
        'passives': SAMURAI_PASSIVES,
        'start_skills': 3,  # cartes de compétence proposées au départ de la run
        'lore_fr': ("Un samouraï ne se fie qu'à son katana. Après des années d'entraînement, "
                    "même la lame la plus lourde lui paraît légère comme une plume."),
        'weapon_name': 'Katana',
    },
}
CLASSES.update(NEW_CLASSES)

# --- combos d'auto-attaque (3 coups ; le 3e est le coup final, renforcé par les cartes) ----
# champs : mult (% de l'attaque), radius/arc (zone), max_targets, pull (attraction en m),
# kind ground (zone au sol visée, range) / heal, drop (rain, hammer), leap + leap_forward +
# land_hit (salto, impact à la retombée), dash (élan avant l'impact), move (+ move_dir evade),
# self_status (statuts sur soi : invisible, evasion, regen), bolt (+ volley, spread, projectile)
COMBOS = {
    'samurai': [
        {'name': 'Taille ascendante', 'anim': 'attack25', 'mult': 1.0, 'arc': 150, 'hit_fx': 's00141'},
        {'name': 'Taille descendante', 'anim': 'attack26', 'mult': 1.15, 'arc': 150, 'hit_fx': 's00241'},
        {'name': 'Salto du faucon', 'anim': 'shoot24', 'mult': 2.2, 'arc': 360, 'radius': 3.4, 'leap': 8.0,
         'leap_forward': 6.0, 'land_hit': True, 'finisher': True, 'applies': {'stun': 1.0}, 'hit_fx': 's00541',
         'desc': "Salto avant ; l'impact à la retombée frappe tout autour."},
    ],
    'warrior': [
        {'name': 'Coup de hache', 'anim': 'attack08', 'mult': 1.3, 'arc': 140, 'radius': 3.2, 'max_targets': 3,
         'hit_fx': 's00241', 'desc': 'Large coup de hache qui touche les 3 ennemis les plus proches.'},
        {'name': 'Crochet', 'anim': 'attack09', 'mult': 1.0, 'arc': 120, 'radius': 4.5, 'pull': 3.0,
         'applies': {'stun': 1.0}, 'hit_fx': 's00241', 'desc': 'La lame accroche les ennemis et les attire vers toi.'},
        {'name': 'Tournoi de la hache', 'anim': 'shoot25', 'mult': 1.8, 'arc': 360, 'radius': 4.2, 'finisher': True,
         'hit_fx': 's00541', 'desc': 'Tour complet sur toi-même, hache tendue.'},
    ],
    'thief': [
        {'name': 'Tourbillon de lames', 'anim': 'attack05', 'mult': 0.8, 'arc': 360, 'radius': 2.8, 'speed': 1.2,
         'hit_fx': 's00141', 'desc': 'Les dagues tournoient tout autour de toi.'},
        {'name': 'Ruée tournoyante', 'anim': 'attack06', 'mult': 1.0, 'arc': 360, 'radius': 3.0, 'dash': 4.0, 'speed': 1.2,
         'hit_fx': 's00241', 'desc': 'Fonce de 4 m puis tourbillonne.'},
        {'name': 'Fumigène', 'anim': 'shoot23', 'mult': 1.4, 'arc': 360, 'radius': 3.5, 'move': 5.0, 'finisher': True,
         'applies': {'chill': 3.0}, 'self_status': {'invisible': 2.0, 'evasion': 4.0}, 'hit_fx': 's00541',
         'desc': "Bond de 5 m ; une bombe fumigène explose à l'arrivée : tu deviens invisible et insaisissable."},
    ],
    'hunter': [
        {'name': 'Flèche', 'anim': 'attack12', 'mult': 1.0, 'bolt': True, 'projectile': 'arrow', 'hit_fx': 's00141',
         'desc': 'Une flèche rapide.'},
        {'name': 'Triple flèche', 'anim': 'attack12', 'mult': 0.7, 'bolt': True, 'volley': 3, 'spread': 24,
         'projectile': 'arrow', 'hit_fx': 's00141', 'desc': '3 flèches en éventail.'},
        {'name': 'Pluie de flèches', 'anim': 'shoot50', 'kind': 'ground', 'range': 12.0, 'mult': 1.5, 'radius': 4.0,
         'arc': 360, 'drop': 'rain', 'finisher': True, 'hit_fx': 's00241',
         'desc': 'Une volée retombe sur la zone visée (12 m).'},
    ],
    'cleric': [
        {'name': 'Éclat sacré', 'anim': 'attack10', 'kind': 'ground', 'range': 9.0, 'mult': 0.9, 'radius': 2.5, 'arc': 360,
         'hit_fx': 's19141', 'desc': 'Petite explosion de lumière sur la zone visée.'},
        {'name': 'Marteau céleste', 'anim': 'attack11', 'kind': 'ground', 'range': 9.0, 'mult': 1.3, 'radius': 3.5,
         'arc': 360, 'drop': 'hammer', 'applies': {'stun': 1.0}, 'hit_fx': 's11641',
         'desc': 'Un marteau de lumière tombe du ciel.'},
        {'name': 'Prière de groupe', 'anim': 'shoot12', 'kind': 'heal', 'heal': 0.06, 'mult': 0.0, 'radius': 0.0,
         'finisher': True, 'self_status': {'regen': 3.0}, 'desc': 'Soigne le clerc (et ses alliés à venir).'},
    ],
    'magician': [
        {'name': 'Explosion arcanique', 'anim': 'attack14', 'kind': 'ground', 'range': 10.0, 'mult': 1.0, 'radius': 2.5,
         'arc': 360, 'hit_fx': 's12141', 'desc': 'Explosion magique sur la zone visée.'},
        {'name': 'Puits gravitationnel', 'anim': 'shoot01', 'kind': 'ground', 'range': 10.0, 'mult': 0.8, 'radius': 4.0,
         'arc': 360, 'pull': 3.0, 'applies': {'chill': 2.0}, 'hit_fx': 's12241',
         'desc': 'Une zone qui aspire les ennemis vers son centre.'},
        {'name': 'Pas éthéré', 'anim': 'jump02', 'mult': 0.0, 'radius': 0.0, 'arc': 0, 'move': 6.0, 'move_dir': 'evade',
         'finisher': True, 'self_status': {'invisible': 2.5},
         'desc': "Glisse de 6 m (direction de déplacement, sinon loin du danger) et devient invisible pour se replacer."},
    ],
}
for _cid, _combo in COMBOS.items():
    CLASSES[_cid]['combo'] = _combo
CLASSES['cleric']['attack_range'] = 9.0
CLASSES['magician']['attack_range'] = 10.0
# type de dégâts (infobulles) et bonus de critique propres à certaines compétences
for _cid in ('cleric', 'magician'):
    CLASSES[_cid]['dmg_type'] = 'mag'
SAMURAI_FR = {50181: 'Hirondelle déchue', 50182: 'Vent solaire', 50183: 'Entaille en croix', 50184: 'Purgatoire',
              50185: 'Danse des grues', 50186: 'Langue de Marduk', 50187: "Lame d'Asura", 50188: 'Estoc',
              50189: 'Volonté du sanctuaire'}
CRIT_BONUS = {50058: 0.30, 50021: 0.20, 50186: 0.15, 50188: 0.10, 50012: 0.10, 50126: 0.10, 50103: 0.10, 50057: 0.15}

ANIM_FILTER = (r'stand0[1-3]|battle0[2-7]|battle13|move0[1-4]|move3[7-9]|move4[0-3]|attack0[5-9]|attack1[0-4]'
               r'|attack2[5-6]|shoot0[12]|shoot12|shoot2[3-5]|shoot5[014]|shoot63'
               r'|hurt13|hurt01|death01|jump0[1-3]')


def clean_eden_text(s):
    s = re.sub(r'\$\d+\$', '', s or '')
    return re.sub(r'#[^#]*#', '', s).replace('\r\n', ' ').strip()


def parse_motion(path):
    """motion.ini -> {kfm: {anim: {'hit': [t], 'sounds': [[t, wav]], 'trail': [t0, t1], 'len': t}}}"""
    out = {}
    for line in open(path, encoding='cp1252', errors='replace'):
        if not line.startswith('DB') or '=' not in line:
            continue
        f = line.strip().split('=', 1)[1].split(',')
        if len(f) < 7:
            continue
        kfm, _kf, t, key, _link, sound, anim = f[:7]
        try:
            t = float(t)
        except ValueError:
            continue
        a = out.setdefault(kfm.lower(), {}).setdefault(anim, {'hit': [], 'sounds': [], 'trail': []})
        k = key.lower()
        if k in ('hit', '_hit1', '_hit2', '_hit3', '_hit4'):
            a['hit'].append(round(t, 4))
        elif k == 'end':
            a['len'] = round(t, 4)
        elif k in ('y1', 'y2'):
            a['trail'].append(round(t, 4))
        if sound and sound.lower().endswith('.wav'):
            a['sounds'].append([round(t, 4), sound.lower()])
    for kfm in out.values():
        for a in kfm.values():
            a['hit'].sort()
            a['trail'].sort()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--skip-models', action='store_true')
    a = ap.parse_args()
    idx = {e['path']: e for e in edenpkg.read_index(nif2gltf.PKG)}
    read = lambda p: edenpkg.read_file(nif2gltf.PKG, idx[p])  # noqa: E731
    from PIL import Image

    tspell = edenini.read_text('t_spell')
    cspell = {int(r[0]): r for r in edenini.read_table('c_spell') if r[0].isdigit()}
    tclass = edenini.read_text('t_class')
    motion = parse_motion(os.path.join(edenini.DB, 'motion.ini'))

    def export_icon(code, folder='skillicon', res_dir='assets/ui/skills'):
        p = 'ui/%s/%s.dds' % (folder, code.lower())
        if p not in idx:
            return ''
        out_dir = os.path.join(GAME, res_dir)
        os.makedirs(out_dir, exist_ok=True)
        dst = os.path.join(out_dir, code.lower() + '.png')
        if not os.path.exists(dst):
            Image.open(io.BytesIO(read(p))).convert('RGBA').save(dst)
        return 'res://%s/%s.png' % (res_dir, code.lower())

    out_classes = {}
    used_anims = set()
    fx_names = {'s00141', 's00241', 's00341', 's00441', 's00541'}  # impacts des attaques de base
    for cid, c in CLASSES.items():
        crow = next(r for r in edenini.read_table('c_class') if r[0] == str(c['class_id']))
        entry = {k: v for k, v in c.items() if k not in ('skills', 'passives')}
        entry['name'] = tclass[c['class_id']][0]
        entry['name_fr'] = {'samurai': 'Samouraï', 'warrior': 'Guerrier', 'thief': 'Voleur', 'hunter': 'Chasseur',
                            'cleric': 'Clerc', 'magician': 'Magicien'}.get(cid, entry['name'])
        entry['lore'] = c.get('lore_fr') or clean_eden_text(tclass[c['class_id']][1])
        entry['icon'] = export_icon(crow[3], 'uiicon', 'assets/ui/classes')
        entry['model'] = 'res://assets/player/%s/%s.glb' % (cid, cid)
        skills = []
        for s in c['skills']:
            r = cspell[s['id']]
            anim = MOTION_ID.get(int(r[3]), 'shoot23')
            used_anims.add(anim)
            sk = dict(s)
            # nom français (début de la description « Nom : ... »), nom d'Eden gardé en référence
            sk['name'] = SAMURAI_FR.get(s['id']) or (s['desc'].split(' :')[0] if ' :' in s['desc'][:40] else tspell[s['id']][0])
            sk['icon'] = export_icon(r[1])
            sk['anim'] = anim
            sk['desc'] = s['desc'].format(dmg=int(round(s['mult'] * 100)))
            sk['dmg_type'] = s.get('dmg_type', c.get('dmg_type', 'phys'))
            sk['eden_name'] = tspell[s['id']][0]
            if s['id'] in CRIT_BONUS:
                sk['crit_bonus'] = CRIT_BONUS[s['id']]
            # effets d'Eden : incantation (code E -> s), impact (colonne 10)
            cast = ('s' + r[5][1:]).lower() if r[5].upper().startswith('E') else ''
            hit = r[10].lower()
            sk['fx'] = {'cast': cast if 'effect/model/%s.nif' % cast in idx else '',
                        'hit': hit if 'effect/model/%s.nif' % hit in idx else ''}
            fx_names.update(v for v in sk['fx'].values() if v)
            skills.append(sk)
        entry['skills'] = skills
        passives = []
        for p in c['passives']:
            pp = dict(p)
            if 'eden' in p:
                pp['icon'] = export_icon(cspell[p['eden']][1])
            passives.append(pp)
        entry['passives'] = passives
        # armes : icônes + modèles
        weapons = []
        wdir = os.path.join(GAME, 'assets', 'weapons')
        for w in c['weapons']:
            model = w[:4].lower()
            weapons.append({'code': w, 'model': 'res://assets/weapons/%s.glb' % model,
                            'texture': 'res://assets/weapons/textures/%s.png' % w.lower(),
                            'icon': export_icon(w, 'itemicon', 'assets/weapons/icons')})
            if c.get('weapon_bone'):
                weapons[-1]['bone'] = c['weapon_bone']
        entry['weapons'] = weapons
        out_classes[cid] = entry

        if not a.skip_models:
            ap_ = c['appearance']
            dye = dict(nif2gltf.DEFAULT_DYE)
            dye.update(ap_['dye'])
            subprocess.run([PY, '-I', os.path.join(os.path.dirname(__file__), 'nif2gltf.py'),
                            'char/%s.kfm' % c['body'], os.path.join(GAME, 'assets', 'player', cid),
                            '--name', cid, '--only', ','.join([ap_['outfit'], ap_['skin'], ap_['hair'], ap_['face']]),
                            '--anims', ANIM_FILTER, '--dye', json.dumps(dye),
                            '--tex-dir', os.path.join(GAME, 'assets', 'player', 'textures')], check=True)
            conv = nif2gltf.Converter(idx, os.path.join(wdir, 'textures'), 'textures/')
            for w in sorted({x[:4].lower() for x in c['weapons']}):
                conv.convert('item/model/%s.nif' % w, [], os.path.join(wdir, w + '.glb'))
            for w in c['weapons']:
                p = conv.find_texture(w.lower() + '.dds', 'item/')
                if p:
                    conv.export_texture(p)

    import fx2godot
    fx2godot.convert(sorted(n for n in fx_names
                            if not os.path.exists(os.path.join(fx2godot.OUT, n + '.fx.json'))), idx)
    # sons des animations du héros et des monstres utilisés
    snd_dir = os.path.join(GAME, 'assets', 'sound')
    os.makedirs(snd_dir, exist_ok=True)
    monsters = json.load(open(os.path.join(GAME, 'data', 'monsters.json'), encoding='utf-8'))
    kfms = {'m'} | {m['model'] for m in monsters.values()}
    keys = {k: v for k, v in motion.items() if k in kfms}
    wavs = {snd for kf in keys.values() for an in kf.values() for _, snd in an['sounds']}
    # les sons sont des fichiers libres du client (EdenReforged/sound), pas dans les pkg
    src_dir = os.path.join(os.path.dirname(nif2gltf.PKG), 'sound')
    available = {f.lower(): f for f in os.listdir(src_dir)} if os.path.isdir(src_dir) else {}
    copied = 0
    for w in sorted(wavs):
        dst = os.path.join(snd_dir, w)
        if w in available and not os.path.exists(dst):
            shutil.copyfile(os.path.join(src_dir, available[w]), dst)
            copied += 1
    # icônes d'équipement : a1 tête, a2 torse, a3 jambes, a4 gants, a5 bottes, a6 cape
    slots = {'head': 'a1', 'chest': 'a2', 'legs': 'a3', 'gloves': 'a4', 'boots': 'a5', 'back': 'a6'}
    item_icons = {}
    for slot, pre in slots.items():
        codes = sorted(p.split('/')[-1][:-4] for p in idx
                       if re.match(r'ui/itemicon/%s\d{4}\.dds$' % pre, p))[:40]
        item_icons[slot] = [export_icon(c, 'itemicon', 'assets/ui/items') for c in codes]
    # matériaux d'amélioration et or
    item_icons['materials'] = {k: export_icon(c, 'itemicon', 'assets/ui/items')
                               for k, c in {'fragment': 'i00206', 'essence': 'i00222', 'crystal': 'i00232', 'gold': 'i00228'}.items()}
    with open(os.path.join(GAME, 'data', 'item_icons.json'), 'w', encoding='utf-8') as f:
        json.dump(item_icons, f, indent=1)
    with open(os.path.join(GAME, 'data', 'classes.json'), 'w', encoding='utf-8') as f:
        json.dump(out_classes, f, indent=1, ensure_ascii=False)
    with open(os.path.join(GAME, 'data', 'motion_keys.json'), 'w', encoding='utf-8') as f:
        json.dump(keys, f, ensure_ascii=False)
    with open(os.path.join(GAME, 'data', 'minimaps.json'), 'w', encoding='utf-8') as f:
        json.dump(MINIMAPS, f, indent=1)
    print('%d classe(s), %d animations clés, %d sons copiés' % (len(out_classes), sum(len(v) for v in keys.values()), copied))


if __name__ == '__main__':
    main()
