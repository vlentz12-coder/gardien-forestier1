class_name Helper
extends Node3D
## Petits personnages autonomes : écureuils collecteurs, hérissons balayeurs, renards, cerfs, oiseaux.
## Les animaux sont modelés ici (formes simples + pelage généré, voir Nature.fur) sauf si un modèle
## ecureuil.glb, herisson.glb… est déposé dans assets/models.

var main
var kind := "squirrel"
var state := "idle"
var target = null      # objet visé
var info = null        # objet transporté (écureuil)
var dest := Vector3.ZERO
var speed := 3.0
var wait := 0.5
var t := 0.0
var body: Node3D
var _wings: Array = []      # oiseaux : pivots des ailes
var _fly_from := Vector3.ZERO
var _fly_h := 0.0
var pet_name := ""
var _tag: Label3D

const TAG_H := {"squirrel": 0.75, "hedgehog": 0.5, "fox": 1.0, "deer": 2.1, "bird": 0.32}
const KIND_NAMES := {"squirrel": "Écureuil", "hedgehog": "Hérisson", "fox": "Renard", "deer": "Cerf", "bird": "Oiseau"}

func setup(m, k: String, pos: Vector3) -> void:
    main = m
    kind = k
    position = pos
    speed = {"squirrel": 3.2, "hedgehog": 2.0, "fox": 2.2, "deer": 1.6, "bird": 5.5}[kind]
    body = Node3D.new()
    add_child(body)
    _build()

## Pièce du modèle. fine > 0 : pelage (finesse des poils) ; 0 : couleur unie.
func _part(mesh: Mesh, color: Color, pos: Vector3, scl: Vector3 = Vector3.ONE, fine := 9.0, parent: Node3D = null) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    if fine > 0.0:
        mi.material_override = Nature.fur(color, fine)
    else:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        mat.roughness = 0.35
        mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    (parent if parent != null else body).add_child(mi)
    return mi

func _sphere(r: float) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    s.radial_segments = 16
    s.rings = 8
    return s

func _box(x: float, y: float, z: float) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = Vector3(x, y, z)
    return b

func _cone(r: float, h: float) -> CylinderMesh:
    var c := CylinderMesh.new()
    c.top_radius = 0.0
    c.bottom_radius = r
    c.height = h
    c.radial_segments = 6
    c.rings = 1
    return c

## Deux yeux noirs brillants.
func _eyes(y: float, z: float, dx: float, r: float) -> void:
    for sx in [-1.0, 1.0]:
        _part(_sphere(r), Color(0.03, 0.03, 0.03), Vector3(sx * dx, y, z), Vector3.ONE, 0.0)

static var fur_colors := {}   # skins : couleur du pelage par espèce (Boutique)

## Reconstruit le modèle (changement de skin).
func rebuild() -> void:
    for c in body.get_children():
        c.queue_free()
    _wings.clear()
    _build()

const MODEL_YAW := PI   # si un animal avance à reculons, change cette valeur (0 ou PI)

func _build() -> void:
    var mname: String = {"squirrel": "ecureuil", "hedgehog": "herisson", "fox": "renard", "deer": "cerf", "bird": "oiseau"}[kind]
    var msize: float = {"squirrel": 0.4, "hedgehog": 0.3, "fox": 0.8, "deer": 1.8, "bird": 0.2}[kind]
    var model := Models.make(mname, msize)
    if model != null:
        model.rotation.y = MODEL_YAW
        body.add_child(model)
        return
    match kind:
        "squirrel":
            var fur: Color = fur_colors.get("squirrel", Color(0.72, 0.36, 0.14))
            var cream := Color(0.95, 0.86, 0.7)
            _part(_sphere(0.1), fur, Vector3(0, 0.13, 0.02), Vector3(0.85, 0.9, 1.45))
            _part(_sphere(0.08), cream, Vector3(0, 0.13, -0.06), Vector3(0.8, 1.0, 0.9), 12.0)   # ventre
            _part(_sphere(0.075), fur, Vector3(0, 0.27, -0.13))
            _part(_sphere(0.04), cream, Vector3(0, 0.25, -0.19), Vector3(1, 0.8, 1), 12.0)       # museau
            _part(_sphere(0.012), Color(0.1, 0.06, 0.05), Vector3(0, 0.26, -0.225), Vector3.ONE, 0.0)
            _eyes(0.3, -0.18, 0.04, 0.013)
            for sx in [-1.0, 1.0]:
                _part(_cone(0.022, 0.06), fur, Vector3(sx * 0.04, 0.35, -0.12))   # oreilles
                _part(_sphere(0.03), fur, Vector3(sx * 0.06, 0.06, -0.08), Vector3(0.8, 1.4, 0.9))
                _part(_sphere(0.035), fur, Vector3(sx * 0.07, 0.06, 0.09), Vector3(0.9, 1.0, 1.4))
            # Queue en panache, recourbée
            var tail := [[Vector3(0, 0.16, 0.2), 0.05], [Vector3(0, 0.25, 0.28), 0.065], [Vector3(0, 0.37, 0.31), 0.07], [Vector3(0, 0.48, 0.28), 0.065], [Vector3(0, 0.54, 0.2), 0.05]]
            for p in tail:
                _part(_sphere(p[1]), fur.darkened(0.08), p[0], Vector3(0.7, 1.1, 0.9), 16.0)
        "hedgehog":
            var skin := Color(0.62, 0.48, 0.34)
            var spikes: Color = fur_colors.get("hedgehog", Color(0.22, 0.16, 0.11))
            _part(_sphere(0.16), spikes.lightened(0.25), Vector3(0, 0.13, 0.02), Vector3(1.0, 0.78, 1.25))
            _part(_sphere(0.075), skin, Vector3(0, 0.1, -0.2), Vector3(1, 0.9, 1.1), 12.0)      # tête
            var snout := _part(_cone(0.035, 0.09), skin, Vector3(0, 0.09, -0.29), Vector3.ONE, 12.0)
            snout.rotation.x = -PI / 2.0
            _part(_sphere(0.016), Color(0.05, 0.04, 0.04), Vector3(0, 0.09, -0.335), Vector3.ONE, 0.0)
            _eyes(0.13, -0.25, 0.04, 0.012)
            for sx in [-1.0, 1.0]:
                for sz in [-0.1, 0.12]:
                    _part(_sphere(0.025), skin, Vector3(sx * 0.08, 0.025, sz), Vector3.ONE, 12.0)
            # Piquants : plein de petits cônes plantés sur le dos, pointés vers l'arrière
            var mm := MultiMesh.new()
            mm.transform_format = MultiMesh.TRANSFORM_3D
            mm.use_colors = true
            mm.mesh = _cone(0.014, 0.12)
            mm.instance_count = 110
            var r := RandomNumberGenerator.new()
            r.seed = get_instance_id()
            for i in mm.instance_count:
                var n := Vector3(r.randf_range(-1, 1), r.randf_range(0.15, 1.0), r.randf_range(-0.6, 1.0)).normalized()
                var pos := Vector3(n.x * 0.15, 0.13 + n.y * 0.12, 0.02 + n.z * 0.19)
                var dir := (n + Vector3(0, 0, 0.9)).normalized()
                var b := Basis(Quaternion(Vector3.UP, dir))
                mm.set_instance_transform(i, Transform3D(b, pos + dir * 0.04))
                mm.set_instance_color(i, spikes if r.randf() < 0.7 else spikes.lightened(0.6))
            var mmi := MultiMeshInstance3D.new()
            mmi.multimesh = mm
            var sm := StandardMaterial3D.new()
            sm.vertex_color_use_as_albedo = true
            sm.roughness = 0.6
            mmi.material_override = sm
            body.add_child(mmi)
        "bird":
            var robin := randf() < 0.55
            var back := Color(0.45, 0.36, 0.26) if robin else Color(0.3, 0.5, 0.75)
            var chest := Color(0.92, 0.45, 0.2) if robin else Color(0.95, 0.85, 0.3)
            _part(_sphere(0.055), back, Vector3(0, 0.07, 0.01), Vector3(0.9, 0.95, 1.35), 18.0)
            _part(_sphere(0.045), chest, Vector3(0, 0.06, -0.035), Vector3(0.9, 1.0, 0.9), 18.0)
            _part(_sphere(0.04), back, Vector3(0, 0.12, -0.05), Vector3.ONE, 18.0)
            var beak := _part(_cone(0.012, 0.035), Color(0.95, 0.65, 0.2), Vector3(0, 0.115, -0.1), Vector3.ONE, 0.0)
            beak.rotation.x = -PI / 2.0
            _eyes(0.13, -0.075, 0.025, 0.008)
            _part(_box(0.035, 0.008, 0.06), back.darkened(0.2), Vector3(0, 0.08, 0.09), Vector3.ONE, 0.0)   # queue
            for sx in [-1.0, 1.0]:
                var wing := Node3D.new()
                wing.position = Vector3(sx * 0.04, 0.09, 0.0)
                body.add_child(wing)
                _part(_box(0.09, 0.008, 0.06), back.darkened(0.1), Vector3(sx * 0.045, 0, 0.01), Vector3.ONE, 18.0, wing)
                _wings.append(wing)
        "fox":
            _part(_box(0.25, 0.22, 0.6), Color(0.85, 0.4, 0.1), Vector3(0, 0.35, 0))
            _part(_box(0.2, 0.18, 0.22), Color(0.9, 0.45, 0.12), Vector3(0, 0.45, -0.38))
            _part(_box(0.1, 0.1, 0.35), Color(0.95, 0.9, 0.85), Vector3(0, 0.38, 0.45))
        _:
            _part(_box(0.35, 0.5, 0.9), Color(0.7, 0.5, 0.3), Vector3(0, 0.85, 0))
            _part(_box(0.15, 0.5, 0.15), Color(0.7, 0.5, 0.3), Vector3(0, 1.2, -0.5))
            _part(_box(0.17, 0.17, 0.32), Color(0.65, 0.45, 0.27), Vector3(0, 1.5, -0.6))
            for sx in [-0.12, 0.12]:
                for sz in [-0.3, 0.3]:
                    _part(_box(0.08, 0.6, 0.08), Color(0.55, 0.38, 0.22), Vector3(sx, 0.3, sz))

## Nom de l'animal, affiché au-dessus de lui quand le gardien s'approche.
func set_pet_name(n: String) -> void:
    pet_name = n
    if _tag == null:
        _tag = Label3D.new()
        _tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _tag.font_size = 40
        _tag.pixel_size = 0.0028
        _tag.outline_size = 10
        _tag.modulate = Color(1.0, 0.93, 0.7)
        _tag.no_depth_test = false
        _tag.position = Vector3(0, TAG_H[kind], 0)
        add_child(_tag)
    _tag.text = n

func _process(delta: float) -> void:
    t += delta
    if _tag != null and main.player != null:
        _tag.visible = pet_name != "" and global_position.distance_to(main.player.global_position) < 9.0
    if state == "idle":
        wait -= delta
        if wait <= 0.0:
            _think()
    else:
        _step(delta)
    if kind == "bird":
        _bird_anim()
    else:
        body.position.y = (absf(sin(t * 12.0)) * 0.05) if state != "idle" else 0.0

func _bird_anim() -> void:
    var flying := state == "fly"
    for i in _wings.size():
        var side := -1.0 if i == 0 else 1.0
        if flying:
            _wings[i].rotation = Vector3(0, 0, side * sin(t * 32.0) * 0.9)
        else:
            _wings[i].rotation = Vector3(0.1, side * 1.25, side * -0.25)   # ailes repliées le long du corps
    if not flying:
        # Au sol : petits sauts et coups de bec
        body.position.y = absf(sin(t * 7.0)) * 0.03 if fmod(t, 3.0) < 1.0 else 0.0
        body.rotation.x = 0.4 if fmod(t, 3.0) > 2.2 else 0.0
    else:
        body.rotation.x = 0.0

func _think() -> void:
    if kind == "squirrel" or kind == "hedgehog":
        target = main.helper_find_item(kind, global_position)
        if target == null:
            wait = 2.0
            return
        target.set_meta("busy", true)
        dest = target.global_position
        state = "go"
    elif kind == "bird":
        # S'envole vers un autre endroit, pas trop loin
        var a := randf() * TAU
        dest = global_position + Vector3(cos(a), 0, sin(a)) * randf_range(6.0, 22.0)
        dest.x = clampf(dest.x, -GameData.AREA, GameData.AREA)
        dest.z = clampf(dest.z, -GameData.AREA, GameData.AREA)
        dest.y = 0.0
        _fly_from = Vector3(global_position.x, 0, global_position.z)
        _fly_h = clampf(_fly_from.distance_to(dest) * 0.35, 2.0, 7.0)
        state = "fly"
    else:
        dest = Vector3(randf_range(-GameData.AREA, GameData.AREA), 0, randf_range(-GameData.AREA, GameData.AREA))
        state = "wander"

func _target_ok() -> bool:
    return is_instance_valid(target) and main.items.has(target)

func _step(delta: float) -> void:
    if state == "go" and not _target_ok():
        state = "idle"
        wait = 0.5
        target = null
        return
    var flat := Vector3(dest.x - global_position.x, 0, dest.z - global_position.z)
    if flat.length() < 0.25:
        _arrive()
        return
    global_position += flat.normalized() * speed * main.helper_speed * delta
    if kind == "bird":
        # Vol en arc : monte puis redescend se poser
        var total := maxf(0.1, _fly_from.distance_to(dest))
        var done := clampf(1.0 - flat.length() / total, 0.0, 1.0)
        global_position.y = sin(done * PI) * _fly_h
    look_at(Vector3(dest.x, global_position.y, dest.z), Vector3.UP)
    if kind == "hedgehog" and state == "return" and is_instance_valid(target):
        target.global_position = global_position + Vector3(0, 0.22, 0)

func _arrive() -> void:
    match state:
        "go":
            if kind == "squirrel":
                info = main.helper_take(target)
                target = null
                dest = main.table_drop_point()
            else:
                dest = main.pile_pos()
            state = "return"
        "return":
            if kind == "squirrel":
                main.helper_deliver(info)
                info = null
            else:
                main.helper_drop(target, dest)
                target = null
            state = "idle"
            wait = 0.4
        "fly":
            global_position.y = 0.0
            state = "idle"
            wait = randf_range(2.0, 6.0)
        _:
            state = "idle"
            wait = randf_range(1.0, 4.0)
