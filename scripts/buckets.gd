class_name BucketRack
extends Node3D
## Les 6 seaux posés devant la table de tri : chaque bac y verse son produit.
## make_bucket() sert aussi pour le seau que le joueur porte à la main.

var _buckets: Array = []
var _labels: Array = []

func _ready() -> void:
	for i in GameData.CATS.size():
		var b := make_bucket(GameData.CATS[i]["color"])
		b.position = Vector3(-1.6 + i * 0.64, 0, 0.95)
		add_child(b)
		_buckets.append(b)
		var l := Label3D.new()
		l.font_size = 32
		l.pixel_size = 0.0035
		l.outline_size = 8
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = b.position + Vector3(0, 0.55 + (i % 2) * 0.18, 0)   # hauteurs alternées : lisible
		add_child(l)
		_labels.append(l)

func update_fill(fill: Array, cap: int) -> void:
	for i in _buckets.size():
		var n: int = fill[i]
		set_level(_buckets[i], float(n) / float(cap))
		var l: Label3D = _labels[i]
		l.text = "%s\n%d/%d" % [GameData.CATS[i]["product"], n, cap]
		l.modulate = Color(1.0, 0.45, 0.35) if n >= cap else Color(1, 1, 1)

## Point visé par le joueur pour prendre le seau i.
func point(i: int) -> Vector3:
	return (_buckets[i] as Node3D).global_position + Vector3(0, 0.2, 0)

static func make_bucket(col: Color) -> Node3D:
	var root := Node3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.2
	body.bottom_radius = 0.15
	body.height = 0.34
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.62, 0.66, 0.7)
	bm.metallic = 0.6
	bm.roughness = 0.35
	var b := MeshInstance3D.new()
	b.mesh = body
	b.material_override = bm
	b.position.y = 0.17
	root.add_child(b)
	var content := CylinderMesh.new()
	content.top_radius = 0.19
	content.bottom_radius = 0.19
	content.height = 0.02
	var cm := StandardMaterial3D.new()
	cm.albedo_color = col
	var c := MeshInstance3D.new()
	c.name = "Content"
	c.mesh = content
	c.material_override = cm
	c.visible = false
	root.add_child(c)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.185
	handle.outer_radius = 0.205
	var h := MeshInstance3D.new()
	h.mesh = handle
	h.material_override = bm
	h.rotation.x = PI / 2.0
	h.position.y = 0.34
	root.add_child(h)
	return root

## Hauteur du produit dans le seau (0 = vide, 1 = plein).
static func set_level(bucket: Node3D, ratio: float) -> void:
	var c := bucket.get_node("Content") as Node3D
	ratio = clampf(ratio, 0.0, 1.0)
	c.visible = ratio > 0.0
	c.position.y = lerpf(0.05, 0.32, ratio)
	var s := lerpf(0.82, 1.0, ratio)   # le seau s'évase vers le haut
	c.scale = Vector3(s, 1.0, s)
