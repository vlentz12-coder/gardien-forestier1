# Gardien forestier

Petit jeu 3D réalisé avec **Godot 4.7.2** (prototype, version 0.7.0).
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

- **Menu principal** : Continuer, Nouvelle partie, Options, Quitter.
- **Échap** en jeu : menu pause (Reprendre, Sauvegarder, Options, Menu principal, Quitter).
- **Options** :
  - *Graphismes* : mode d'affichage, résolution, VSync, limite d'images/s, échelle de rendu, MSAA, FXAA, ombres, SSAO, halo, brouillard, herbe, distance d'affichage, champ de vision, luminosité, compteur d'images/s.
  - *Audio* : volume général, effets, ambiance, couper le son.
  - *Commandes* : sensibilité, inversion de l'axe vertical, toutes les touches modifiables.
  - *Jeu* : sauvegarde automatique, mini-carte, taille de l'interface.
- **Sauvegarde** : manuelle depuis la pause, automatique toutes les 3 minutes et à la fermeture.
  Fichiers : `%APPDATA%\Godot\app_userdata\Gardien forestier\`.

## Commandes par défaut

| Touche | Action |
|---|---|
| `W` `A` `S` `D` | Se déplacer (touches physiques, donc `Z` `Q` `S` `D` sur un clavier AZERTY) |
| Souris / flèches | Regarder autour |
| `Maj` | Sprinter (consomme l'endurance) |
| Clic gauche / `F` | Ramasser |
| `E` | Interagir : trier, prendre un seau, verser dans la machine, charger la scierie |
| `Tab` | Menu de construction |
| Molette / clic / clic droit | Pendant un placement : tourner / poser / annuler |
| `1` à `4`, molette | Changer d'outil |
| `1` à `6` (dans le tri) | Choisir une poubelle |
| `R` | Retour au camp |
| `C` | Basculer la caméra en mode « bords d'écran » |
| `Échap` | Pause |
| `F1` | Passer le tutoriel |
| `F3` | Infos de debug |

Les outils (râteau, pinces, sac…) se débloquent à la table après **100 objets ramassés**.

## Ouvrir le projet dans Godot

1. Installe [Godot 4.7.2](https://godotengine.org/download) (version standard, pas .NET).
2. Télécharge ce dépôt (bouton vert **Code** puis **Download ZIP**) et décompresse-le.
3. Dans Godot : **Importer**, puis choisis le fichier `project.godot`.

## Structure

```
project.godot          configuration (scène de départ : menu.tscn, autoload Settings)
menu.tscn              menu principal
main.tscn              la partie (le monde est construit par scripts/main.gd)
scripts/
  main.gd              monde, ramassage, tri, seaux, placement des constructions, tutoriel, sauvegarde
  build_menu.gd        menu de construction (Tab) : Essentiel / Chantiers / Chalet
  machine.gd           LaMachineQuiRestoreLaForêtator (réceptacles, fumée, écran)
  buckets.gd           les seaux de produits devant la table
  sawmill.gd           la scierie (bûches → planches)
  chalet.gd            le chalet et ses meubles
  game_data.gd         constantes : nombre d'objets, catégories, outils, chantiers
  settings.gd          options du joueur (autoload), touches, audio, affichage
  save_game.gd         lecture / écriture du fichier de sauvegarde
  menu.gd              menu principal
  pause_menu.gd        menu pause
  options_menu.gd      fenêtre d'options
  ui_theme.gd          style commun des menus
  player.gd, helper.gd, sort_ui.gd, minimap.gd, models.gd, sfx.gd
assets/models/         modèles 3D et textures (voir assets/models/LISEZMOI.txt)
export_presets.cfg     préréglage d'export Windows
.github/workflows/     compilation automatique sur GitHub
```

## Compilation automatique

Le workflow `.github/workflows/build-windows.yml` compile le jeu pour Windows sur les serveurs GitHub :
- à la main : onglet **Actions**, puis **Build Windows**, puis **Run workflow** (le zip apparaît dans *Artifacts*) ;
- automatiquement : quand tu publies un tag `v...` (par ex. `v0.8.0`), le zip est ajouté à la Release.
