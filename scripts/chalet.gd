class_name Chalet
extends Node3D
## Petit chalet du gardien : murs, toit, porte ouverte (côté +z).
## Les meubles pas encore construits apparaissent en fantômes translucides à leur emplacement.

const W := 7.0     # largeur (x)
const D := 6.0     # profondeur (z)
const H := 2.6     # hauteur des murs
const WOOD := Color(0.56, 0.38, 0.21)
const DARK := Color(0.36, 0.23, 0.12)

# Emplacement de chaque meuble dans le chalet : [position, rotation y]
const SLOTS := {
	"tapis": [Vector3(-0.9, 0, 0.7), 0.0],
	"table_repas": [Vector3(1.0, 0, 0.4), 0.0],
	"chaise": [Vector3(1.0, 0, 1.15), PI],
	"lit": [Vector3(-2.3, 0, -1.75), 0.0],
	"coffre": [Vector3(-2.3, 0, -0.4), 0.0],
	"armoire": [Vector3(3.05, 0, -1.5), -PI / 2.0],
	"etagere": [Vector3(-3.2, 0, 1.3), PI / 2.0],
	"cheminee": [Vector3(1.0, 0, -2.65), 0.0],
	"lampe": [Vector3(2.9, 0, 1.5), 0.0],
	"plante": [Vector3(-3.0, 0, 2.5), 0.0],
}

var _slots := {}          # clé → Node3D du meuble (vrai ou fantôme)
var _ghost_mat: StandardMaterial3D
var _t := 0.0

func _ready() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(1, 1, 1, 0.2)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Plancher et murs
	_box(self, Vector3(W, 0.04, D), Color(0.66, 0.47, 0.28), Vector3(0, 0.02, 0))
	_box(self, Vector3(W, H, 0.2), WOOD, Vector3(0, H / 2.0, -D / 2.0 + 0.1))
	for sx in [-1.0, 1.0]:
		_box(self, Vector3(0.2, H, D), WOOD, Vector3(sx * (W / 2.0 - 0.1), H / 2.0, 0))
		_box(self, Vector3(2.8, H, 0.2), WOOD, Vector3(sx * 2.1, H / 2.0, D / 2.0 - 0.1))   # façade, de part et d'autre de la porte
		# Fenêtres
		_box(self, Vector3(0.26, 0.8, 1.2), Color(0.6, 0.82, 0.95), Vector3(sx * (W / 2.0 - 0.1), 1.5, -0.4))
		_box(self, Vector3(1.0, 0.7, 0.26), Color(0.6, 0.82, 0.95), Vector3(sx * 2.1, 1.5, D / 2.0 - 0.1))
	_box(self, Vector3(1.4, 0.5, 0.2), WOOD, Vector3(0, 2.35, D / 2.0 - 0.1))   # linteau de la porte
	_box(self, Vector3(1.6, 0.12, 0.7), DARK, Vector3(0, 0.06, D / 2.0 + 0.35))   # marche
	# Poutres d'angle
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(self, Vector3(0.28, H, 0.28), DARK, Vector3(sx * (W / 2.0 - 0.1), H / 2.0, sz * (D / 2.0 - 0.1)))
	# Toit à deux pans + pignons
	var half := W / 2.0 + 0.4
	var slope := deg_to_rad(30.0)
	var rise := (W / 2.0) * tan(slope)
	var plen := half / cos(slope)
	for sx in [-1.0, 1.0]:
		var r := _box(self, Vector3(plen, 0.15, D + 0.8), Color(0.55, 0.2, 0.15), Vector3(sx * plen / 2.0 * cos(slope), H + rise - plen / 2.0 * sin(slope), 0))
		r.rotation.z = -sx * slope
	for sz in [-1.0, 1.0]:
		var pm := PrismMesh.new()
		pm.size = Vector3(W, rise, 0.2)
		_add(self, pm, WOOD, Vector3(0, H + rise / 2.0, sz * (D / 2.0 - 0.1)))
	_box(self, Vector3(0.5, 1.4, 0.5), Color(0.5, 0.5, 0.48), Vector3(1.0, H + rise + 0.1, -1.6))   # conduit de cheminée
	# Enseigne
	var sign_lbl := Label3D.new()
	sign_lbl.text = "Chalet du gardien"
	sign_lbl.font_size = 56
	sign_lbl.pixel_size = 0.004
	sign_lbl.outline_size = 10
	sign_lbl.modulate = Color(1.0, 0.88, 0.55)
	sign_lbl.position = Vector3(0, H + 0.45, D / 2.0 + 0.02)
	add_child(sign_lbl)
	# Collisions des murs (la porte reste libre)
	var sb := StaticBody3D.new()
	add_child(sb)
	_shape(sb, Vector3(W, H, 0.2), Vector3(0, H / 2.0, -D / 2.0 + 0.1))
	for sx in [-1.0, 1.0]:
		_shape(sb, Vector3(0.2, H, D), Vector3(sx * (W / 2.0 - 0.1), H / 2.0, 0))
		_shape(sb, Vector3(2.8, H, 0.2), Vector3(sx * 2.1, H / 2.0, D / 2.0 - 0.1))
	# Lumière douce à l'intérieur
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 0.6
	light.omni_range = 5.5
	light.position = Vector3(0, 2.2, 0)
	add_child(light)
	set_furniture({})

func _process(delta: float) -> void:
	_t += delta
	for k in _slots:
		var fire := (_slots[k] as Node3D).get_node_or_null("Fire") as OmniLight3D
		if fire != null:
			fire.light_energy = 1.4 + sin(_t * 9.0) * 0.25 + sin(_t * 23.0) * 0.15

## Construit les meubles achetés et montre les autres en fantômes. "pop" : meuble qui vient d'être construit.
func set_furniture(built: Dictionary, pop: String = "") -> void:
	for f in GameData.FURNITURE:
		var key: String = f["key"]
		if _slots.has(key):
			(_slots[key] as Node).queue_free()
		var n := make_furniture(key)
		var slot: Array = SLOTS[key]
		n.position = slot[0]
		n.rotation.y = slot[1]
		add_child(n)
		_slots[key] = n
		if not built.get(key, false):
			_ghostify(n, f["name"])
		elif key == pop:
			n.scale = Vector3.ONE * 0.2
			create_tween().tween_property(n, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _ghostify(n: Node, label: String) -> void:
	for c in n.find_children("*", "", true, false):
		if c is Light3D:
			c.queue_free()
		elif c is GeometryInstance3D:
			(c as GeometryInstance3D).material_override = _ghost_mat
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := Label3D.new()
	l.text = "%s\n(à construire)" % label
	l.font_size = 30
	l.pixel_size = 0.003
	l.outline_size = 8
	l.modulate = Color(1, 1, 1, 0.75)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 1.0, 0)
	n.add_child(l)

# ---------- Meubles ----------
static func make_furniture(key: String) -> Node3D:
	var n := Node3D.new()
	var wood := Color(0.6, 0.4, 0.22)
	match key:
		"tapis":
			_box(n, Vector3(2.0, 0.02, 1.3), Color(0.62, 0.18, 0.16), Vector3(0, 0.05, 0))
			_box(n, Vector3(1.6, 0.025, 0.9), Color(0.86, 0.7, 0.35), Vector3(0, 0.055, 0))
			_box(n, Vector3(1.2, 0.03, 0.5), Color(0.62, 0.18, 0.16), Vector3(0, 0.06, 0))
		"table_repas":
			_box(n, Vector3(1.4, 0.07, 0.85), wood, Vector3(0, 0.76, 0))
			for x in [-0.62, 0.62]:
				for z in [-0.35, 0.35]:
					_box(n, Vector3(0.07, 0.74, 0.07), wood.darkened(0.2), Vector3(x, 0.37, z))
		"chaise":
			_box(n, Vector3(0.46, 0.06, 0.46), wood, Vector3(0, 0.46, 0))
			for x in [-0.19, 0.19]:
				for z in [-0.19, 0.19]:
					_box(n, Vector3(0.05, 0.46, 0.05), wood.darkened(0.2), Vector3(x, 0.23, z))
			_box(n, Vector3(0.46, 0.5, 0.05), wood, Vector3(0, 0.74, -0.2))
		"lit":
			_box(n, Vector3(1.25, 0.32, 2.1), wood.darkened(0.15), Vector3(0, 0.2, 0))
			_box(n, Vector3(1.15, 0.16, 1.98), Color(0.93, 0.93, 0.9), Vector3(0, 0.44, 0.02))
			_box(n, Vector3(0.8, 0.12, 0.35), Color(1, 1, 1), Vector3(0, 0.57, -0.75))
			_box(n, Vector3(1.19, 0.06, 1.25), Color(0.25, 0.45, 0.32), Vector3(0, 0.54, 0.38))
			_box(n, Vector3(1.25, 0.9, 0.08), wood.darkened(0.15), Vector3(0, 0.45, -1.05))
		"coffre":
			_box(n, Vector3(0.9, 0.45, 0.5), wood.darkened(0.1), Vector3(0, 0.25, 0))
			_box(n, Vector3(0.94, 0.1, 0.54), wood.darkened(0.35), Vector3(0, 0.52, 0))
			_box(n, Vector3(0.12, 0.12, 0.04), Color(0.85, 0.7, 0.3), Vector3(0, 0.42, 0.27))
		"armoire":
			_box(n, Vector3(1.15, 2.0, 0.55), wood.darkened(0.05), Vector3(0, 1.0, 0))
			_box(n, Vector3(0.02, 1.8, 0.02), wood.darkened(0.45), Vector3(0, 1.02, 0.28))
			for x in [-0.08, 0.08]:
				_box(n, Vector3(0.05, 0.12, 0.05), Color(0.85, 0.7, 0.3), Vector3(x, 1.05, 0.29))
		"etagere":
			_box(n, Vector3(1.0, 1.7, 0.05), wood.darkened(0.2), Vector3(0, 0.85, -0.16))
			for x in [-0.48, 0.48]:
				_box(n, Vector3(0.04, 1.7, 0.35), wood, Vector3(x, 0.85, 0))
			var book_cols := [Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.25, 0.55, 0.3), Color(0.85, 0.7, 0.3)]
			for s in 4:
				_box(n, Vector3(0.96, 0.04, 0.35), wood, Vector3(0, 0.05 + s * 0.45, 0))
				if s < 3:
					for b in 6:
						_box(n, Vector3(0.09, 0.3, 0.24), book_cols[(b + s) % 4], Vector3(-0.36 + b * 0.13, 0.22 + s * 0.45, 0.02))
		"cheminee":
			var stone := Color(0.55, 0.53, 0.5)
			_box(n, Vector3(1.5, 1.1, 0.5), stone, Vector3(0, 0.55, 0))
			_box(n, Vector3(0.8, 0.6, 0.06), Color(0.08, 0.06, 0.05), Vector3(0, 0.4, 0.23))
			_box(n, Vector3(1.7, 0.12, 0.6), stone.darkened(0.2), Vector3(0, 1.16, 0))
			_box(n, Vector3(0.6, 1.4, 0.4), stone, Vector3(0, 1.9, -0.05))
			var flame := _box(n, Vector3(0.4, 0.25, 0.1), Color(1.0, 0.55, 0.15), Vector3(0, 0.25, 0.2))
			var fm := flame.material_override as StandardMaterial3D
			fm.emission_enabled = true
			fm.emission = Color(1.0, 0.5, 0.1)
			fm.emission_energy_multiplier = 3.0
			var fire := OmniLight3D.new()
			fire.name = "Fire"
			fire.light_color = Color(1.0, 0.6, 0.3)
			fire.omni_range = 4.5
			fire.position = Vector3(0, 0.5, 0.6)
			n.add_child(fire)
		"lampe":
			_cyl(n, 0.18, 0.2, 0.05, wood.darkened(0.3), Vector3(0, 0.03, 0))
			_cyl(n, 0.025, 0.025, 1.45, wood.darkened(0.3), Vector3(0, 0.75, 0))
			var shade := _cyl(n, 0.14, 0.26, 0.3, Color(1.0, 0.9, 0.6), Vector3(0, 1.55, 0))
			var sm := shade.material_override as StandardMaterial3D
			sm.emission_enabled = true
			sm.emission = Color(1.0, 0.85, 0.5)
			sm.emission_energy_multiplier = 1.5
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.85, 0.6)
			lamp.light_energy = 1.2
			lamp.omni_range = 5.0
			lamp.position = Vector3(0, 1.45, 0)
			n.add_child(lamp)
		"plante":
			_cyl(n, 0.2, 0.15, 0.32, Color(0.7, 0.38, 0.22), Vector3(0, 0.16, 0))
			var s := SphereMesh.new()
			s.radius = 0.32
			s.height = 0.6
			_add(n, s, Color(0.22, 0.55, 0.25), Vector3(0, 0.6, 0))
	return n

# ---------- Petits constructeurs ----------
static func _box(parent: Node, size: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(parent, b, c, pos)

static func _cyl(parent: Node, r_top: float, r_bot: float, h: float, c: Color, pos: Vector3) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	return _add(parent, m, c, pos)

static func _add(parent: Node, m: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _shape(sb: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	sb.add_child(cs)
