class_name GameData
## Données du jeu : catégories, outils, chantiers, constantes.

const TOTAL := 3000
const AREA := 50.0             # demi-largeur de la zone jouable (carte de 100 x 100 m)
const CAMP_RADIUS := 14.0      # rayon de la clairière du camp
const HELPER_RANGE := 30.0     # rayon d'action des écureuils et hérissons autour du camp
const REACH := 4.5
const REACH_TONGS := 7.0       # portée des pinces
const TABLE_RADIUS := 3.2
const TOOLS_UNLOCK_COUNT := 100   # objets ramassés à partir desquels les outils sont disponibles

# ---------- Seaux et machine de restauration ----------
# Chaque bac de tri verse son produit dans un seau ; le joueur porte le seau jusqu'à la machine.
const MACHINE_NAME := "LaMachineQuiRestoreLaForêtator"
const MACHINE_POS := Vector3(0, 0, -7)   # place de la machine dans les anciennes sauvegardes
const BUCKET_CAP := 30          # produits par seau
const BUCKET_CAP_XXL := 75      # avec l'amélioration « Seau XXL »
const REACH_MACHINE := 4.0

const CATS := [
    {"name": "Feuilles", "icon": "🍃", "use": "Compost", "product": "Compost", "color": Color(0.85, 0.54, 0.17), "items": ["Feuille morte", "Aiguilles de pin", "Herbe sèche"]},
    {"name": "Bois", "icon": "🪵", "use": "Bûches", "product": "Sciure", "color": Color(0.48, 0.31, 0.16), "items": ["Branche", "Bûchette", "Écorce"]},
    {"name": "Graines", "icon": "🌰", "use": "Graines", "product": "Semences", "color": Color(0.61, 0.42, 0.25), "items": ["Pomme de pin", "Gland", "Graine"]},
    {"name": "Déchets", "icon": "🥫", "use": "Recyclage", "product": "Recyclé", "color": Color(0.29, 0.56, 0.78), "items": ["Canette", "Sac plastique", "Bouteille"]},
    {"name": "Champignons", "icon": "🍄", "use": "Nourriture", "product": "Spores", "color": Color(0.75, 0.22, 0.17), "items": ["Champignon", "Baie", "Noisette"]},
    {"name": "Pierres", "icon": "🪨", "use": "Pierres", "product": "Gravier", "color": Color(0.55, 0.55, 0.55), "items": ["Caillou", "Gravier", "Terre sèche"]},
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
    {"key": "seau", "name": "Seau XXL", "desc": "Seaux de produits : capacité 30 → 75", "cost": 45},
    {"key": "drone", "name": "Drone forestier", "desc": "Balise les derniers objets (≤ 120 restants)", "cost": 150},
]

# ---------- Constructions (menu Tab) ----------
# Coûts : index de catégorie → quantité de ressources TRIÉES (stock), "planches" → planches de la scierie.
# "foot" : rayon d'encombrement au sol (pour vérifier qu'on peut la poser).
const PLANKS_PER_LOG := 2       # la scierie transforme 1 bûche en 2 planches

const BUILDINGS := [
    {"key": "table", "name": "Table de tri", "desc": "Trie tes objets ; un seau par produit se remplit devant elle", "cost": {}, "foot": 2.3},
    {"key": "machine", "name": MACHINE_NAME, "desc": "Verse-y les seaux de produits : c'est elle qui restaure la forêt", "cost": {}, "foot": 3.6},
    {"key": "scierie", "name": "Scierie", "desc": "Charge-y tes bûches (E) : 1 bûche → 2 planches. Bois trié : +1 ressource", "cost": {1: 12, 5: 5}, "foot": 1.9},
]

# Chantiers : posés où l'on veut (le pont, lui, se pose forcément sur le ruisseau)
const PROJECTS := [
    {"key": "chemin", "name": "Chemin de pierres", "desc": "Vitesse +10 %", "cost": {5: 20}, "foot": 3.0},
    {"key": "nichoir", "name": "Nichoir", "desc": "Les oiseaux reviennent plus tôt", "cost": {1: 10}, "foot": 0.8},
    {"key": "pont", "name": "Pont réparable", "desc": "Traverse le ruisseau sans ralentir (se pose sur le ruisseau)", "cost": {1: 25, 5: 10}, "foot": 1.8},
    {"key": "composteur", "name": "Composteur rapide", "desc": "Feuilles triées : +1 ressource", "cost": {0: 25}, "foot": 1.0},
    {"key": "recyclerie", "name": "Recyclerie", "desc": "Déchets triés : +2 ressources", "cost": {3: 20}, "foot": 1.6},
    {"key": "mangeoire", "name": "Mangeoire", "desc": "Attire les animaux, débloque les écureuils", "cost": {4: 15}, "foot": 0.8},
    {"key": "serre", "name": "Serre", "desc": "Replante de jeunes arbres autour d'elle", "cost": {1: 15, 2: 10}, "foot": 1.8},
    {"key": "arbre", "name": "Arbre ancien", "desc": "Un arbre majestueux revit", "cost": {2: 25, 0: 15}, "foot": 1.6},
]

# Position des constructions dans les sauvegardes d'avant le menu Tab (elles étaient fixes)
const LEGACY_POS := {
    "table": Vector3(0, 0, 0), "machine": MACHINE_POS, "scierie": Vector3(-5.5, 0, -2.5),
    "chemin": Vector3(0, 0, 7.0), "nichoir": Vector3(-3.5, 0, -3.5), "pont": Vector3(10.3, 0, 0),
    "composteur": Vector3(5.0, 0, -2.0), "recyclerie": Vector3(4.85, 0, 3.5), "mangeoire": Vector3(-4.0, 0, 3.5),
    "serre": Vector3(7.0, 0, -4.0), "arbre": Vector3(-9.0, 0, -9.0),
}

# Le chalet et ses meubles : purement décoratifs, c'est la récompense de fin.
const CHALET := {"key": "chalet", "name": "Petit chalet", "desc": "Un chalet vide où t'installer : construis ensuite ses meubles", "cost": {"planches": 40, 5: 20}, "foot": 5.0}
const FURNITURE := [
    {"key": "tapis", "name": "Tapis", "cost": {"planches": 2, 3: 8}},
    {"key": "table_repas", "name": "Table", "cost": {"planches": 10}},
    {"key": "chaise", "name": "Chaise", "cost": {"planches": 6}},
    {"key": "lit", "name": "Lit", "cost": {"planches": 16, 0: 10}},
    {"key": "coffre", "name": "Coffre", "cost": {"planches": 8}},
    {"key": "armoire", "name": "Armoire", "cost": {"planches": 14}},
    {"key": "etagere", "name": "Étagère à livres", "cost": {"planches": 8, 3: 4}},
    {"key": "cheminee", "name": "Cheminée", "cost": {"planches": 4, 5: 15}},
    {"key": "lampe", "name": "Lampe", "cost": {"planches": 4, 3: 3}},
    {"key": "plante", "name": "Plante en pot", "cost": {2: 3, 0: 2}},
]

## Nom d'une ressource de coût : index de catégorie ou "planches".
static func res_name(k) -> String:
    return "Planches" if k is String else String(CATS[k]["use"])

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
    {"name": "Seau XXL", "icon": "🪣", "up": "seau"},
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
