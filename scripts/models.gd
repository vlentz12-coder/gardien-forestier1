class_name Models
## Chargeur de modèles 3D (.glb) : si le fichier existe dans res://assets/models/, on l'utilise,
## sinon le jeu garde ses formes simples. Le modèle est automatiquement redimensionné
## (plus grande dimension = "target" en mètres), centré et posé au sol.
## Variantes : nom.glb, nom_2.glb, nom_3.glb, nom_4.glb (une au hasard à chaque fois).

const DIR := "res://assets/models/"
static var _paths := {}

static func _find(model_name: String) -> Array:
    if _paths.has(model_name):
        return _paths[model_name]
    var found := []
    for suffix in ["", "_1", "_2", "_3", "_4"]:
        for ext in [".glb", ".gltf"]:
            var p: String = DIR + model_name + suffix + ext
            if ResourceLoader.exists(p):
                found.append(p)
                break
    _paths[model_name] = found
    return found

static func make(model_name: String, target: float) -> Node3D:
    var list := _find(model_name)
    if list.is_empty():
        return null
    var path: String = list[randi() % list.size()]
    var scene = load(path)
    if not (scene is PackedScene):
        return null
    var inst := (scene as PackedScene).instantiate() as Node3D
    if inst == null:
        return null
    var box := _aabb(inst, Transform3D.IDENTITY)
    var root := Node3D.new()
    root.add_child(inst)
    var m := maxf(box.size.x, maxf(box.size.y, box.size.z))
    if m > 0.0001:
        var s := target / m
        inst.scale = Vector3.ONE * s
        inst.position = Vector3(-(box.position.x + box.size.x / 2.0) * s, -box.position.y * s, -(box.position.z + box.size.z / 2.0) * s)
    return root

static func _aabb(n: Node, xf: Transform3D) -> AABB:
    var t := xf
    if n is Node3D:
        t = xf * (n as Node3D).transform
    var out := AABB()
    var first := true
    if n is MeshInstance3D:
        out = t * (n as MeshInstance3D).get_aabb()
        first = false
    for c in n.get_children():
        var b := _aabb(c, t)
        if b.size != Vector3.ZERO:
            out = b if first else out.merge(b)
            first = false
    return out
