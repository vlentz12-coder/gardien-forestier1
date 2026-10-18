class_name Models
## Chargeur de modèles 3D (.glb) : si le fichier existe dans res://assets/models/, on l'utilise,
## sinon le jeu garde ses formes simples. Le modèle est automatiquement redimensionné
## (plus grande dimension = "target" en mètres), centré et posé au sol.
## Variantes : nom.glb, nom_2.glb, nom_3.glb, nom_4.glb (une au hasard à chaque fois).

## Chaque fichier est préparé une seule fois (taille + maillages) puis ses maillages sont partagés :
## créer 3000 objets reste rapide. Les modèles animés ou squelettés sont instanciés normalement.

const DIR := "res://assets/models/"
static var _paths := {}
static var _protos := {}   # chemin -> {"box": AABB, "parts": [[mesh, transform, material_override, surfaces]]} ou {"box", "scene"}

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
    var proto := _proto(path)
    if proto.is_empty():
        return null
    var inst: Node3D
    if proto.has("parts"):
        inst = Node3D.new()
        for part in proto["parts"]:
            var mi := MeshInstance3D.new()
            mi.mesh = part[0]
            mi.transform = part[1]
            mi.material_override = part[2]
            var mats: Array = part[3]
            for i in mats.size():
                if mats[i] != null:
                    mi.set_surface_override_material(i, mats[i])
            inst.add_child(mi)
    else:
        inst = (proto["scene"] as PackedScene).instantiate() as Node3D
    var box: AABB = proto["box"]
    var root := Node3D.new()
    root.add_child(inst)
    var m := maxf(box.size.x, maxf(box.size.y, box.size.z))
    if m > 0.0001:
        var s := target / m
        inst.scale = Vector3.ONE * s
        inst.position = Vector3(-(box.position.x + box.size.x / 2.0) * s, -box.position.y * s, -(box.position.z + box.size.z / 2.0) * s)
    return root

static func _proto(path: String) -> Dictionary:
    if _protos.has(path):
        return _protos[path]
    var proto := {}
    var scene = load(path)
    if scene is PackedScene:
        var inst := (scene as PackedScene).instantiate() as Node3D
        if inst != null:
            proto["box"] = _aabb(inst, Transform3D.IDENTITY)
            # Comme avant : la transformation propre de la racine est remplacée par la mise à l'échelle
            var parts := []
            var ok := _flatten(inst, Transform3D.IDENTITY, parts, true)
            if ok:
                proto["parts"] = parts
            else:
                proto["scene"] = scene
            inst.free()
    _protos[path] = proto
    return proto

static func _flatten(n: Node, xf: Transform3D, out: Array, is_root: bool) -> bool:
    if n is Skeleton3D or n is AnimationPlayer or n is AnimationTree:
        return false
    var t := xf
    if n is Node3D and not is_root:
        t = xf * (n as Node3D).transform
    if n is MeshInstance3D:
        var mi := n as MeshInstance3D
        if mi.skin != null:
            return false
        if mi.mesh != null:
            var mats := []
            for i in mi.get_surface_override_material_count():
                mats.append(mi.get_surface_override_material(i))
            out.append([mi.mesh, t, mi.material_override, mats])
    for c in n.get_children():
        if not _flatten(c, t, out, false):
            return false
    return true

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
