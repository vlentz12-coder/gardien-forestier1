class_name GameData
## Données du jeu : catégories, outils, chantiers, constantes.

const TOTAL := 1500
const AREA := 50.0             # demi-largeur de la zone jouable (carte de 100 x 100 m)
const CAMP_RADIUS := 14.0      # rayon de la clairière du camp
const HELPER_RANGE := 30.0     # rayon d'action des écureuils et hérissons autour du camp
const REACH := 4.5
const REACH_TONGS := 7.0       # portée des pinces
const TABLE_RADIUS := 3.2
const TOOLS_UNLOCK := 0.1      # restauration (0-1) à partir de laquelle les outils sont disponibles

const CATS := [
    {"name": "Feuilles", "icon": "🍃", "use": "Compost", "color": Color(0.85, 0.54, 0.17), "items": ["Feuille morte", "Aiguilles de pin", "Herbe sèche"]},
    {"name": "Bois", "icon": "🪵", "use": "Planches", "color": Color(0.48, 0.31, 0.16), "items": ["Branche", "Bûchette", "Écorce"]},
    {"name": "Graines", "icon": "🌰", "use": "Graines", "color": Color(0.61, 0.42, 0.25), "items": ["Pomme de pin", "Gland", "Graine"]},
    {"name": "Déchets", "icon": "🥫", "use": "Recyclage", "color": Color(0.29, 0.56, 0.78), "items": ["Canette", "Sac plastique", "Bouteille"]},
    {"name": "Champignons", "icon": "🍄", "use": "Nourriture", "color": Color(0.75, 0.22, 0.17), "items": ["Champignon", "Baie", "Noisette"]},
    {"name": "Pierres", "icon": "🪨", "use": "Chemins", "color": Color(0.55, 0.55, 0.55), "items": ["Caillou", "Gravier", "Terre sèche"]},
]

# Améliorations achetées avec les ressources (🌿). "max" > 1 : améliorable, coût × niveau.
const UPGRADES := [
    {"key": "rake", "name": "Râteau", "desc": "Feuilles : ramasse celles autour de la cible", "cost": 15},
    {"key": "pinces", "name": "Pinces", "desc": "Branches et déchets jusqu'à 7 m", "cost": 20},
    {"key": "bag", "name": "Grand sac", "desc": "Capacité 10 → 20", "cost": 25},
    {"key": "multi", "name": "Multi-ramassage", "desc": "+2 objets par ramassage", "cost": 40},
    {"key": "chariot", "name": "Chariot", "desc": "Capacité 50 (requiert Grand sac)", "cost": 60, "req": "bag"},
    {"key": "trieuse", "name": "Trieuse manuelle", "desc": "Trie 25 % du sac toute seule", "cost": 80},
    {"key": "squirrel", "name": "Écureuil collecteur", "desc": "Ramasse pommes de pin et noisettes, les apporte à la table (requiert Mangeoire)", "cost": 60, "max": 3, "req": "mangeoire"},
    {"key": "hedgehog", "name": "Hérisson balayeur", "desc": "Rassemble les feuilles en tas : le râteau adore", "cost": 70, "max": 2},
    {"key": "drone", "name": "Drone forestier", "desc": "Balise les derniers objets (≤ 120 restants)", "cost": 150},
]

# Chantiers : coûts en ressources TRIÉES (index de catégorie → quantité)
const PROJECTS := [
    {"key": "chemin", "name": "Chemin de pierres", "desc": "Vitesse +10 %", "cost": {5: 20}},
    {"key": "nichoir", "name": "Nichoir", "desc": "Les oiseaux reviennent plus tôt", "cost": {1: 10}},
    {"key": "pont", "name": "Pont réparable", "desc": "Traverse le ruisseau sans ralentir", "cost": {1: 25, 5: 10}},
    {"key": "composteur", "name": "Composteur rapide", "desc": "Feuilles triées : +1 ressource", "cost": {0: 25}},
    {"key": "scierie", "name": "Scierie mobile", "desc": "Branches triées : +1 ressource", "cost": {1: 20, 5: 8}},
    {"key": "recyclerie", "name": "Recyclerie", "desc": "Déchets triés : +2 ressources", "cost": {3: 20}},
    {"key": "mangeoire", "name": "Mangeoire", "desc": "Attire les animaux, débloque les écureuils", "cost": {4: 15}},
    {"key": "serre", "name": "Serre", "desc": "Replante de jeunes arbres autour du camp", "cost": {1: 15, 2: 10}},
    {"key": "arbre", "name": "Arbre ancien", "desc": "Un arbre majestueux revit", "cost": {2: 25, 0: 15}},
]

# Tas de feuilles des hérissons
const PILES := [Vector3(-7, 0, 6), Vector3(7, 0, 6), Vector3(-7, 0, -6), Vector3(7, 0, -6)]

# Barre d'outils : outils "actifs" (touches 1-4 / molette) et équipements passifs
const TOOLS := [
    {"name": "Mains", "icon": "✋", "up": "", "desc": "Ramasse un objet à la fois"},
    {"name": "Râteau", "icon": "🧹", "up": "rake", "desc": "Feuilles uniquement : ramasse celles autour de la cible"},
    {"name": "Pinces", "icon": "🥢", "up": "pinces", "desc": "Branches et déchets, jusqu'à 7 m"},
    {"name": "Multi", "icon": "🧺", "up": "multi", "desc": "Ramasse la cible + 2 objets proches"},
]
const PASSIVES := [
    {"name": "Grand sac", "icon": "🎒", "up": "bag"},
    {"name": "Chariot", "icon": "🛒", "up": "chariot"},
    {"name": "Trieuse", "icon": "⚙", "up": "trieuse"},
    {"name": "Écureuils", "icon": "🐿", "up": "squirrel"},
    {"name": "Hérissons", "icon": "🦔", "up": "hedgehog"},
    {"name": "Drone", "icon": "🚁", "up": "drone"},
]

# ---------- Phase 4 : zones de la grande carte ----------
# "weights" : poids de tirage des 6 catégories (Feuilles, Bois, Graines, Déchets, Champignons, Pierres)
const ZONES := [
    {"name": "Sentier des Écureuils", "center": Vector3(-30, 0, -28), "radius": 22.0, "weights": [2.0, 1.0, 4.0, 2.0, 2.5, 1.0]},
    {"name": "Marais aux Champignons", "center": Vector3(32, 0, -30), "radius": 20.0, "weights": [1.0, 2.5, 0.5, 1.0, 6.0, 1.0], "mud": true},
    {"name": "Vieille Scierie", "center": Vector3(-32, 0, 30), "radius": 20.0, "weights": [1.0, 6.0, 0.5, 3.0, 0.5, 1.5]},
    {"name": "Cœur de la Forêt", "center": Vector3(34, 0, 32), "radius": 22.0, "weights": [2.0, 2.0, 2.0, 2.0, 2.0, 2.0]},
]
