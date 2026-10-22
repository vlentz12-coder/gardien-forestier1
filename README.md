# Gardien forestier

Petit jeu 3D réalisé avec **Godot 4.7.2** (prototype, version 0.7.1).
Tu explores la forêt, tu ramasses les 3000 objets, tu les tries à la table et tu apportes les produits à LaMachineQuiRestoreLaForêtator pour restaurer la clairière. Pour finir, tu te construis un chalet meublé dans la forêt rangée.

## Jouer (Windows)

1. Va dans l'onglet **Releases** de ce dépôt (colonne de droite).
2. Télécharge le zip de la dernière version (`Gardien_forestier_windows.zip`).
3. Fais clic droit sur le zip puis **Extraire tout...** (ne lance pas le jeu depuis l'intérieur du zip).
4. Double-clique sur **`Gardien forestier.exe`**.

> Windows peut afficher « Windows a protégé votre PC » parce que le jeu n'est pas signé.
> Clique sur **Informations complémentaires** puis **Exécuter quand même**.

Configuration conseillée : Windows 10/11 64 bits, carte graphique compatible Vulkan ou OpenGL 3.3.

## Tutoriel et menu de construction (`Tab`)

Une nouvelle partie commence dans une clairière vide. Un tutoriel (que `F1` permet de passer) te guide :
poser la table de tri, ramasser, trier, poser la machine, prendre un seau, le verser.

Le menu de construction s'ouvre avec `Tab` et comporte trois onglets :

- **Essentiel** : la table de tri et LaMachineQuiRestoreLaForêtator, gratuites, et la scierie.
- **Chantiers** : chemin de pierres, nichoir, pont, composteur, recyclerie, mangeoire, serre, arbre ancien.
- **Chalet** : le petit chalet, puis ses 10 meubles (tapis, table, chaise, lit, coffre, armoire, étagère, cheminée, lampe, plante).

Le bouton **Placer** fait apparaître un fantôme de la construction devant toi :

- il est **vert** si l'endroit est libre, **rouge** sinon, et la raison s'affiche ;
- la **molette** le tourne, le **clic** le pose, le **clic droit** annule ;
- le pont, lui, se cale toujours sur le ruisseau ;
- une construction déjà posée peut être **déplacée** gratuitement.

Les meubles apparaissent en fantômes dans le chalet tant qu'ils ne sont pas construits. Ils sont décoratifs :
c'est la récompense de fin, un endroit où t'installer dans la forêt rangée.

## Le monde

- Carte de **150 × 150 m** : la clairière du camp, quatre zones (Sentier des Écureuils, Marais aux Champignons,
  Vieille Scierie, Cœur de la Forêt) reliées par des chemins de terre.
- Une **rivière large** : on y avance très lentement, on ne peut pas y sauter et patauger fatigue. Le **pont** la traverse.
- Le gardien a un corps : on voit ses **mains** (elles attrapent les objets, tiennent le seau) et ses **jambes** en baissant les yeux.
- Les **constructions se collent** les unes aux autres et aux arbres : chacune a une empreinte rectangulaire
  qui suit sa rotation, et seuls les troncs (pas les feuillages) gênent la pose.
- Écureuils, hérissons et **oiseaux** (autour du nichoir) ont un pelage ou un plumage.
- Chaque animal a un **nom**, affiché au-dessus de lui : on le choisit en achetant un écureuil ou un hérisson,
  et on renomme tout le monde dans le menu `Tab`, onglet **Animaux**.
- Le gardien est un **personnage 3D animé** (rôdeur encapuchonné, KayKit) : il marche, court, saute, ramasse.
  Touche `V` pour le voir à la 3e personne.
- **Glands dorés** : +10 tous les 100 objets ramassés. Ils achètent des **skins** dans le menu `Tab`, onglet **Boutique** :
  personnage (5 au choix), pelage des écureuils et hérissons, couleurs du chalet, du lit, du tapis et de la lampe.
- 18 objets à ramasser, chacun avec sa forme et sa matière : feuilles d'érable et de noisetier en couleurs d'automne,
  aiguilles de pin, branches en écorce, pommes de pin, glands, bouteilles en verre, sacs plastique, baies, gravier…
- Les **cuves de la machine se remplissent** d'un liquide vert lumineux à mesure que la forêt se restaure.
- **Cinématiques** : au premier versement (une onde verte part de la machine), puis à 25, 50 et 75 %,
  et un tour complet « avant / après » à 100 %. Chacune n'est jouée qu'une fois (Échap pour passer,
  désactivables dans *Options > Jeu*). L'herbe, les arbres, les chemins et l'eau y passent vraiment de l'état abîmé à restauré.
## Paliers de constructions et automatisation

Les chantiers (onglet *Chantiers* du menu `Tab`) se débloquent en trois paliers :

| Palier | Débloqué à | Constructions |
|---|---|---|
| 1 | dès le début | chemin de pierres, nichoir, pont, composteur, recyclerie, mangeoire, serre, arbre ancien |
| 2 | 900 objets ramassés | puits (endurance plus rapide), potager (Graines +1 🌿), ruches (les fleurs refleurissent plus tôt), étang et ponton (Champignons +1 🌿) |
| 3 | 1800 objets ramassés | cabane perchée (endurance max +50 %), kiosque (animaux aides +40 %), observatoire (balise les 600 derniers objets), Monument du gardien |

Onglet *Essentiel* : améliorations des constructions de base.
- **Scierie niveau 2** (3 planches par bûche, 2× plus rapide) puis **niveau 3** (4 planches par bûche, dès 1200 objets).
- **Convoyeur** (dès 1200 objets) : les seaux partent tout seuls vers la machine.
- **Trieuse automatique** (dès 1500 objets) : on dépose son sac à la table, elle trie seule.

## Scierie et planches

Chaque objet en bois trié te donne une **bûche**. Vise la trémie de la scierie et appuie sur `E` pour y charger
toutes tes bûches : elle les découpe en **planches** (1 bûche → 2 planches). Le chalet coûte 40 planches et 20 pierres,
et ses meubles environ 70 planches au total.

## LaMachineQuiRestoreLaForêtator

1. Trie tes objets à la table : chaque bac verse son **produit** dans le seau posé devant lui
   (30 par seau, 75 avec l'amélioration « Seau XXL »).
2. Vise un seau et appuie sur `E` pour le prendre (un seul à la fois).
3. Apporte-le à **LaMachineQuiRestoreLaForêtator** et vise le bon réceptacle (`E` pour verser).
4. Mauvais réceptacle ? La machine refuse et te dit lequel il faut. Bon réceptacle ? Elle fume et la forêt se restaure.

| Bac | Produit |
|---|---|
| Feuilles | Compost |
| Bois | Sciure |
| Graines | Semences |
| Déchets | Recyclé |
| Champignons | Spores |
| Pierres | Gravier |

Un seau plein bloque son bac : va le vider avant de continuer à trier.

## Menus, options et sauvegarde

- **Menu principal** : Continuer (dernière partie jouée), Charger une partie, Nouvelle partie, Options, Quitter.
- **Échap** en jeu : menu pause (Reprendre, Sauvegarder, Charger, Options, Menu principal, Quitter).
- **Options** :
  - *Graphismes* : mode d'affichage, résolution, VSync, limite d'images/s, échelle de rendu, MSAA, FXAA, ombres, SSAO, halo, brouillard, herbe, distance d'affichage, champ de vision, luminosité, compteur d'images/s.
  - *Audio* : volume général, musique, effets, ambiance, couper le son.
  - *Commandes* : sensibilité, inversion de l'axe vertical, toutes les touches modifiables.
  - *Jeu* : sauvegarde automatique, mini-carte, taille de l'interface.
- **Sauvegarde** : manuelle depuis la pause, automatique toutes les 3 minutes et à la fermeture.
  Chaque nouvelle partie a sa propre sauvegarde : rien n'est écrasé.
- **Charger** : une fiche par partie, avec la date de début, la dernière sauvegarde, le temps de jeu,
  les objets ramassés, l'avancement de la restauration et du chalet. Une partie peut aussi être supprimée.
  Fichiers : `%APPDATA%\Godot\app_userdata\Gardien forestier\saves\`.

## Musique

Une playlist calme (piano, guitare) pendant la partie, un morceau lo-fi différent dans le menu,
reliés par des fondus enchaînés. Volume réglable dans *Options > Audio > Musique*.

## Commandes par défaut

| Touche | Action |
|---|---|
| `W` `A` `S` `D` | Se déplacer (touches physiques, donc `Z` `Q` `S` `D` sur un clavier AZERTY) |
| Souris / flèches | Regarder autour |
| `Maj` | Sprinter (consomme l'endurance) |
| `Espace` | Sauter ; ressauter dès l'atterrissage (ou garder Espace enfoncé) = *bunny hop*, l'élan augmente jusqu'à +60 % |
| Clic gauche / `F` | Ramasser |
| `E` | Interagir : trier, prendre un seau, verser dans la machine, charger la scierie |
| `Tab` | Menu de construction |
| Molette / clic / clic droit | Pendant un placement : tourner / poser / annuler |
| `1` à `4`, molette | Changer d'outil |
| `1` à `6` (dans le tri) | Choisir une poubelle |
| `R` | Retour au camp |
| `C` | Basculer la caméra en mode « bords d'écran » |
| `V` | Vue à la 1re / 3e personne |
| `Échap` | Pause |
| `F1` | Passer le tutoriel |
| `F3` | Infos de debug |

Les outils (râteau, pinces, sac…) se débloquent après **100 objets ramassés** : ils s'achètent dans le menu `Tab`, onglet **Outils**.

## Ouvrir le projet dans Godot

1. Installe [Godot 4.7.2](https://godotengine.org/download) (version standard, pas .NET).
2. Télécharge ce dépôt (bouton vert **Code** puis **Download ZIP**) et décompresse-le.
3. Dans Godot : **Importer**, puis choisis le fichier `project.godot`.

## Structure

```
project.godot          configuration (scène de départ : menu.tscn, autoloads Settings et Music)
menu.tscn              menu principal
main.tscn              la partie (le monde est construit par scripts/main.gd)
scripts/
  main.gd              monde, ramassage, tri, seaux, placement des constructions, tutoriel, sauvegarde
  build_menu.gd        menu de construction (Tab) : Essentiel / Outils / Chantiers / Chalet / Animaux / Boutique
  machine.gd           LaMachineQuiRestoreLaForêtator (réceptacles, fumée, écran)
  buckets.gd           les seaux de produits devant la table
  sawmill.gd           la scierie (bûches → planches)
  chalet.gd            le chalet et ses meubles
  items.gd             les 18 objets à ramasser (formes et matières)
  cinematic.gd         cinématiques de restauration
  nature.gd            matières du décor : sol, chemins, boue, feuillage, herbe au vent, eau, buissons
  game_data.gd         constantes : nombre d'objets, catégories, outils, chantiers
  settings.gd          options du joueur (autoload), touches, audio, affichage
  save_game.gd         sauvegardes (une par partie) et leur résumé
  load_menu.gd         fenêtre « Charger une partie »
  music.gd             musique du menu et playlist du jeu (autoload)
  menu.gd              menu principal
  pause_menu.gd        menu pause
  options_menu.gd      fenêtre d'options
  ui_theme.gd          style commun des menus
  player.gd, helper.gd, sort_ui.gd, minimap.gd, models.gd, sfx.gd
assets/models/         modèles 3D et textures (voir assets/models/LISEZMOI.txt)
assets/textures/       textures du chalet et des meubles (voir CREDITS.txt)
assets/music/          musiques (voir CREDITS.txt)
assets/characters/     personnages 3D animés (voir CREDITS.txt)
export_presets.cfg     préréglage d'export Windows
.github/workflows/     compilation automatique sur GitHub
```

## Compilation automatique

Le workflow `.github/workflows/build-windows.yml` compile le jeu pour Windows sur les serveurs GitHub :
- à la main : onglet **Actions**, puis **Build Windows**, puis **Run workflow** (le zip apparaît dans *Artifacts*) ;
- automatiquement : quand tu publies un tag `v...` (par ex. `v0.8.0`), le zip est ajouté à la Release.

## Crédits

Tous ces fichiers sont sous licence **CC0** (domaine public). Merci à leurs auteurs !

- **Musiques** : *Chill lofi inspired* par omfgdude ; *Relaxing Instrumentals* par Holizna (OpenGameArt).
  Détails : `assets/music/CREDITS.txt`.
- **Textures du chalet et du décor** (herbe, chemins, boue, feuillage) : [ambientCG](https://ambientcg.com). Détails : `assets/textures/CREDITS.txt`.
- **Personnages** : *KayKit Adventurers* par Kay Lousberg (CC0). Détails : `assets/characters/CREDITS.txt`.
- **Arbres, rochers, champignons** : voir `assets/models/LISEZMOI.txt`.
