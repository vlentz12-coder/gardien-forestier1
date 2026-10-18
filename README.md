# Gardien forestier

Petit jeu 3D réalisé avec **Godot 4.7.2** (prototype, version 0.4.0).
Tu explores la forêt, tu ramasses les déchets et les objets, et tu les tries.

## Jouer (Windows)

1. Va dans l'onglet **Releases** de ce dépôt (colonne de droite).
2. Télécharge `Gardien_forestier_v0.4.0_windows.zip`.
3. Fais clic droit sur le zip puis **Extraire tout...** (ne lance pas le jeu depuis l'intérieur du zip).
4. Double-clique sur **`Gardien forestier.exe`**.

> Windows peut afficher « Windows a protégé votre PC » parce que le jeu n'est pas signé.
> Clique sur **Informations complémentaires** puis **Exécuter quand même**.

Configuration conseillée : Windows 10/11 64 bits, carte graphique compatible Vulkan ou OpenGL 3.3.

## Commandes

| Touche | Action |
|---|---|
| `W` `A` `S` `D` | Se déplacer (touches physiques, donc `Z` `Q` `S` `D` sur un clavier AZERTY) |
| Souris / flèches | Regarder autour |
| `Maj` | Sprinter (consomme l'endurance) |
| Clic gauche / `F` | Ramasser |
| `E` | Interagir / ouvrir et fermer le tri |
| `1` à `4`, molette | Changer d'outil |
| `1` à `6` (dans le tri) | Choisir une poubelle |
| `R` | Rappel |
| `Tab` | Basculer la caméra en mode « bords d'écran » |
| `Échap` | Libérer la souris |
| `F3` | Infos de debug |

## Ouvrir le projet dans Godot

1. Installe [Godot 4.7.2](https://godotengine.org/download) (version standard, pas .NET).
2. Télécharge ce dépôt (bouton vert **Code** puis **Download ZIP**) et décompresse-le.
3. Dans Godot : **Importer**, puis choisis le fichier `project.godot`.

## Structure

```
project.godot          configuration du projet
main.tscn              scène principale (le monde est construit par scripts/main.gd)
scripts/               code GDScript
assets/models/         modèles 3D et textures (voir assets/models/LISEZMOI.txt)
export_presets.cfg     préréglage d'export Windows
.github/workflows/     compilation automatique sur GitHub
```

## Compilation automatique

Le workflow `.github/workflows/build-windows.yml` compile le jeu pour Windows sur les serveurs GitHub :
- à la main : onglet **Actions**, puis **Build Windows**, puis **Run workflow** (le zip apparaît dans *Artifacts*) ;
- automatiquement : quand tu publies un tag `v...` (par ex. `v0.5.0`), le zip est ajouté à la Release.
