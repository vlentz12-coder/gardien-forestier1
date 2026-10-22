class_name GameData
## Données du jeu : catégories, outils, chantiers, constantes.

const TOTAL := 3000
const AREA := 75.0             # demi-largeur de la zone jouable (carte de 150 x 150 m)
const CAMP_RADIUS := 14.0      # rayon de la clairière du camp
const HELPER_RANGE := 40.0     # rayon d'action des écureuils et hérissons autour du camp
const REACH := 4.5
const REACH_TONGS := 7.0       # portée des pinces
const TABLE_RADIUS := 3.2
const TOOLS_UNLOCK_COUNT := 100   # objets ramassés à partir desquels les outils sont disponibles
# Rivière : large et lente à traverser à pied (impossible d'y sauter) ; le pont la franchit.
const STREAM_X := 14.0
const STREAM_W := 7.0

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
# "foot" : rayon d'encombrement au sol ; "size" : empreinte rectangulaire (largeur x profondeur) quand
# la construction n'est pas ronde. On peut ainsi coller les constructions les unes aux autres.
const PLANKS_PER_LOG := 2       # la scierie transforme 1 bûche en 2 planches

const BUILDINGS := [
    {"key": "table", "name": "Table de tri", "desc": "Trie tes objets ; un seau par produit se remplit devant elle", "cost": {}, "foot": 2.3, "size": Vector2(4.0, 3.4)},
    {"key": "machine", "name": MACHINE_NAME, "desc": "Verse-y les seaux de produits : c'est elle qui restaure la forêt", "cost": {}, "foot": 3.6, "size": Vector2(6.8, 3.2)},
    {"key": "scierie", "name": "Scierie", "desc": "Charge-y tes bûches (E) : 1 bûche → 2 planches. Bois trié : +1 ressource", "cost": {1: 12, 5: 5}, "foot": 1.9, "size": Vector2(4.4, 1.4)},
]

# Chantiers : posés où l'on veut (le pont, lui, se pose forcément sur le ruisseau).
# "tier" : palier de déblocage (voir TIER_UNLOCK), 1 par défaut. "res" dans un coût : ressources 🌿.
const TIER_UNLOCK := {1: 0, 2: 900, 3: 1800}   # objets ramassés nécessaires pour chaque palier
const PROJECTS := [
    {"key": "chemin", "name": "Chemin de pierres", "desc": "Vitesse +10 %", "cost": {5: 20}, "foot": 3.0, "size": Vector2(1.0, 7.2)},
    {"key": "nichoir", "name": "Nichoir", "desc": "Les oiseaux reviennent plus tôt", "cost": {1: 10}, "foot": 0.5},
    {"key": "pont", "name": "Pont réparable", "desc": "Traverse le ruisseau sans ralentir (se pose sur le ruisseau)", "cost": {1: 25, 5: 10}, "foot": 1.8},
    {"key": "composteur", "name": "Composteur rapide", "desc": "Feuilles triées : +1 ressource", "cost": {0: 25}, "foot": 1.0, "size": Vector2(1.3, 1.3)},
    {"key": "recyclerie", "name": "Recyclerie", "desc": "Déchets triés : +2 ressources", "cost": {3: 20}, "foot": 1.6, "size": Vector2(2.6, 0.9)},
    {"key": "mangeoire", "name": "Mangeoire", "desc": "Attire les animaux, débloque les écureuils", "cost": {4: 15}, "foot": 0.6},
    {"key": "serre", "name": "Serre", "desc": "Replante de jeunes arbres autour d'elle", "cost": {1: 15, 2: 10}, "foot": 2.6},
    {"key": "arbre", "name": "Arbre ancien", "desc": "Un arbre majestueux revit", "cost": {2: 25, 0: 15}, "foot": 1.0},
    # Palier 2
    {"key": "puits", "name": "Puits", "desc": "L'endurance se recharge 50 % plus vite", "cost": {5: 40, 1: 30}, "foot": 1.0, "tier": 2},
    {"key": "potager", "name": "Potager", "desc": "Graines triées : +1 🌿", "cost": {2: 70, 0: 50, "planches": 16}, "foot": 2.2, "size": Vector2(3.3, 2.5), "tier": 2},
    {"key": "ruches", "name": "Ruches", "desc": "Les abeilles reviennent : les fleurs repoussent bien plus tôt", "cost": {4: 70, "planches": 20}, "foot": 1.5, "size": Vector2(2.8, 0.8), "tier": 2},
    {"key": "etang", "name": "Étang et ponton", "desc": "Champignons triés : +1 🌿", "cost": {5: 40, 4: 80, "planches": 24}, "foot": 3.1, "tier": 2},
    # Palier 3
    {"key": "cabane", "name": "Cabane perchée", "desc": "Endurance maximale +50 %", "cost": {1: 60, 3: 60, "planches": 70, "res": 150}, "foot": 2.4, "size": Vector2(3.4, 3.4), "tier": 3},
    {"key": "kiosque", "name": "Kiosque", "desc": "Écureuils et hérissons travaillent 40 % plus vite", "cost": {5: 50, 3: 80, "planches": 60, "res": 150}, "foot": 2.5, "tier": 3},
    {"key": "observatoire", "name": "Observatoire", "desc": "Balise les objets restants dès qu'il en reste 600", "cost": {5: 60, 3: 120, 0: 60, "planches": 40, "res": 200}, "foot": 1.3, "tier": 3},
    {"key": "monument", "name": "Monument du gardien", "desc": "Le chef-d'œuvre final : la forêt te remercie", "cost": {0: 120, 2: 150, 3: 100, 4: 250, 5: 50, "planches": 60, "res": 500}, "foot": 2.0, "size": Vector2(2.4, 2.4), "tier": 3},
]

# Améliorations des constructions essentielles (menu Tab, onglet Essentiel).
# "min" : objets ramassés nécessaires. Les deux dernières automatisent le travail en fin de partie.
const BUILD_UPGRADES := [
    {"key": "scierie", "level": 2, "name": "Scierie niveau 2", "desc": "3 planches par bûche, découpe 2× plus rapide", "cost": {1: 40, 5: 15}, "min": 0},
    {"key": "scierie", "level": 3, "name": "Scierie niveau 3", "desc": "4 planches par bûche", "cost": {1: 80, 3: 40, "res": 150}, "min": 1200},
    {"key": "machine", "level": 2, "name": "Convoyeur", "desc": "Les seaux partent tout seuls vers la machine (toutes les 5 s)", "cost": {3: 60, 5: 25, "planches": 20, "res": 300}, "min": 1200},
    {"key": "table", "level": 2, "name": "Trieuse automatique", "desc": "La table trie toute seule ce que tu y déposes (3 objets/s)", "cost": {3: 80, 1: 30, "planches": 40, "res": 400}, "min": 1500},
]

# Position des constructions dans les sauvegardes d'avant le menu Tab (elles étaient fixes)
const LEGACY_POS := {
    "table": Vector3(0, 0, 0), "machine": MACHINE_POS, "scierie": Vector3(-5.5, 0, -2.5),
    "chemin": Vector3(0, 0, 7.0), "nichoir": Vector3(-3.5, 0, -3.5), "pont": Vector3(STREAM_X, 0, 0),
    "composteur": Vector3(5.0, 0, -2.0), "recyclerie": Vector3(4.85, 0, 3.5), "mangeoire": Vector3(-4.0, 0, 3.5),
    "serre": Vector3(7.0, 0, -4.0), "arbre": Vector3(-9.0, 0, -9.0),
}

# Le chalet et ses meubles : purement décoratifs, c'est la récompense de fin.
const CHALET := {"key": "chalet", "name": "Petit chalet", "desc": "Un chalet vide où t'installer : construis ensuite ses meubles", "cost": {"planches": 40, 5: 20}, "foot": 5.0, "size": Vector2(7.2, 7.4)}
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

## Nom d'une ressource de coût : index de catégorie, "planches" ou "res" (🌿).
static func res_name(k) -> String:
    if k is String:
        return "🌿" if k == "res" else "Planches"
    return String(CATS[k]["use"])

## Planches produites par bûche selon le niveau de la scierie.
static func planks_per_log(level: int) -> int:
    return [2, 2, 3, 4][clampi(level, 0, 3)]

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
    {"name": "Sentier des Écureuils", "center": Vector3(-46, 0, -42), "radius": 30.0, "weights": [2.0, 1.0, 4.0, 2.0, 2.5, 1.0]},
    {"name": "Marais aux Champignons", "center": Vector3(50, 0, -46), "radius": 28.0, "weights": [1.0, 2.5, 0.5, 1.0, 6.0, 1.0], "mud": true},
    {"name": "Vieille Scierie", "center": Vector3(-48, 0, 46), "radius": 28.0, "weights": [1.0, 6.0, 0.5, 3.0, 0.5, 1.5]},
    {"name": "Cœur de la Forêt", "center": Vector3(50, 0, 48), "radius": 30.0, "weights": [2.0, 2.0, 2.0, 2.0, 2.0, 2.0]},
]

# ---------- Glands dorés et skins ----------
# On gagne GOLD_PER_STEP glands dorés tous les GOLD_STEP objets ramassés ; ils achètent des skins (menu Tab, Boutique).
const GOLD_STEP := 100
const GOLD_PER_STEP := 10
const SKIN_CATS := [
    ["personnage", "🧑 Gardien"], ["ecureuil", "🐿 Écureuils"], ["herisson", "🦔 Hérissons"],
    ["chalet", "🏡 Chalet"], ["lit", "🛏 Lit"], ["tapis", "🟥 Tapis"], ["lampe", "💡 Lampe"],
]
# "model" : personnage (assets/characters, KayKit Adventurers CC0) ; "color" : teinte principale ; "color2" : seconde teinte.
const SKINS := [
    {"key": "perso_rodeur", "cat": "personnage", "name": "Rôdeur encapuchonné", "cost": 0, "model": "Rogue_Hooded"},
    {"key": "perso_voyageur", "cat": "personnage", "name": "Voyageur", "cost": 20, "model": "Rogue"},
    {"key": "perso_mage", "cat": "personnage", "name": "Mage des bois", "cost": 30, "model": "Mage"},
    {"key": "perso_bucheron", "cat": "personnage", "name": "Bûcheron barbu", "cost": 30, "model": "Barbarian"},
    {"key": "perso_chevalier", "cat": "personnage", "name": "Chevalier de la forêt", "cost": 40, "model": "Knight"},
    {"key": "ecu_roux", "cat": "ecureuil", "name": "Roux", "cost": 0, "color": Color(0.72, 0.36, 0.14)},
    {"key": "ecu_gris", "cat": "ecureuil", "name": "Gris", "cost": 15, "color": Color(0.5, 0.5, 0.52)},
    {"key": "ecu_noir", "cat": "ecureuil", "name": "Noir", "cost": 20, "color": Color(0.16, 0.13, 0.12)},
    {"key": "ecu_dore", "cat": "ecureuil", "name": "Doré", "cost": 35, "color": Color(0.95, 0.72, 0.25)},
    {"key": "her_brun", "cat": "herisson", "name": "Brun", "cost": 0, "color": Color(0.22, 0.16, 0.11)},
    {"key": "her_clair", "cat": "herisson", "name": "Blond", "cost": 15, "color": Color(0.7, 0.58, 0.4)},
    {"key": "her_nuit", "cat": "herisson", "name": "Nuit", "cost": 20, "color": Color(0.1, 0.1, 0.14)},
    {"key": "chalet_naturel", "cat": "chalet", "name": "Bois naturel, ardoise", "cost": 0, "color": Color(1.0, 0.9, 0.78), "color2": Color(0.75, 0.72, 0.7)},
    {"key": "chalet_fonce", "cat": "chalet", "name": "Bois sombre, toit vert", "cost": 25, "color": Color(0.62, 0.5, 0.42), "color2": Color(0.45, 0.65, 0.45)},
    {"key": "chalet_clair", "cat": "chalet", "name": "Bois blond, toit rouge", "cost": 25, "color": Color(1.0, 1.0, 0.95), "color2": Color(0.95, 0.45, 0.4)},
    {"key": "lit_vert", "cat": "lit", "name": "Couverture verte", "cost": 0, "color": Color(0.3, 0.52, 0.38)},
    {"key": "lit_rouge", "cat": "lit", "name": "Couverture rouge", "cost": 10, "color": Color(0.75, 0.2, 0.2)},
    {"key": "lit_bleu", "cat": "lit", "name": "Couverture bleue", "cost": 10, "color": Color(0.25, 0.4, 0.75)},
    {"key": "lit_jaune", "cat": "lit", "name": "Couverture moutarde", "cost": 10, "color": Color(0.9, 0.7, 0.25)},
    {"key": "tapis_rouge", "cat": "tapis", "name": "Rouge et or", "cost": 0, "color": Color(0.72, 0.2, 0.17), "color2": Color(0.98, 0.8, 0.42)},
    {"key": "tapis_bleu", "cat": "tapis", "name": "Bleu et blanc", "cost": 10, "color": Color(0.2, 0.35, 0.7), "color2": Color(0.95, 0.95, 0.95)},
    {"key": "tapis_vert", "cat": "tapis", "name": "Vert forêt", "cost": 10, "color": Color(0.2, 0.45, 0.25), "color2": Color(0.85, 0.75, 0.45)},
    {"key": "lampe_creme", "cat": "lampe", "name": "Abat-jour crème", "cost": 0, "color": Color(1.0, 0.9, 0.6)},
    {"key": "lampe_vert", "cat": "lampe", "name": "Abat-jour vert", "cost": 10, "color": Color(0.5, 0.9, 0.55)},
    {"key": "lampe_rose", "cat": "lampe", "name": "Abat-jour rose", "cost": 10, "color": Color(1.0, 0.6, 0.7)},
]

static func skin(key: String) -> Dictionary:
    for s in SKINS:
        if s["key"] == key:
            return s
    return {}

## Skin par défaut (gratuit) d'une catégorie.
static func default_skin(cat: String) -> String:
    for s in SKINS:
        if s["cat"] == cat and int(s["cost"]) == 0:
            return s["key"]
    return ""