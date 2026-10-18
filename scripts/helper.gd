class_name Helper
extends Node3D
## Petits personnages autonomes : écureuils collecteurs, hérissons balayeurs, renards, cerfs.

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

func setup(m, k: String, pos: Vector3) -> void:
    main = m
    kind = k
    position = pos
    speed = {"squirrel": 3.2, "hedgehog": 2.0, "fox": 2.2, "deer": 1.6}[kind]
    body = Node3D.new()
    add_child(body)
    _build()

func _part(mesh: Mesh, color: Color, pos: Vector3, scl: Vector3 = Vector3.ONE) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    body.add_child(mi)

func _sphere(r: float) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    return s

func _box(x: float, y: float, z: float) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = Vector3(x, y, z)
    return b

const MODEL_YAW := PI   # si un animal avance à reculons, change cette valeur (0 ou PI)

func _build() -> void:
    var mname: String = {"squirrel": "ecureuil", "hedgehog": "herisson", "fox": "renard", "deer": "cerf"}[kind]
    var msize: float = {"squirrel": 0.4, "hedgehog": 0.3, "fox": 0.8, "deer": 1.8}[kind]
    var model := Models.make(mname, msize)
    if model != null:
        model.rotation.y = MODEL_YAW
        body.add_child(model)
        return
    match kind:
        "squirrel":
            _part(_sphere(0.14), Color(0.55, 0.32, 0.14), Vector3(0, 0.18, 0))
            _part(_sphere(0.09), Color(0.6, 0.36, 0.17), Vector3(0, 0.3, -0.15))
            _part(_box(0.08, 0.34, 0.14), Color(0.65, 0.4, 0.2), Vector3(0, 0.34, 0.18))
        "hedgehog":
            _part(_sphere(0.17), Color(0.32, 0.24, 0.17), Vector3(0, 0.16, 0), Vector3(1, 0.8, 1.3))
            _part(_sphere(0.07), Color(0.85, 0.7, 0.55), Vector3(0, 0.13, -0.27))
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

func _process(delta: float) -> void:
    t += delta
    if state == "idle":
        wait -= delta
        if wait <= 0.0:
            _think()
    else:
        _step(delta)
    body.position.y = (absf(sin(t * 12.0)) * 0.05) if state != "idle" else 0.0

func _think() -> void:
    if kind == "squirrel" or kind == "hedgehog":
        target = main.helper_find_item(kind, global_position)
        if target == null:
            wait = 2.0
            return
        target.set_meta("busy", true)
        dest = target.global_position
        state = "go"
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
    global_position += flat.normalized() * speed * delta
    look_at(Vector3(dest.x, global_position.y, dest.z), Vector3.UP)
    if kind == "hedgehog" and state == "return" and is_instance_valid(target):
        target.global_position = global_position + Vector3(0, 0.22, 0)

func _arrive() -> void:
    match state:
        "go":
            if kind == "squirrel":
                info = main.helper_take(target)
                target = null
                dest = Vector3(0, 0, 1.4)
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
        _:
            state = "idle"
            wait = randf_range(1.0, 4.0)
