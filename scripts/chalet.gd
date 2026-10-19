class_name Chalet
extends Node3D
## Petit chalet du gardien : murs, toit, porte ouverte (côté +z).
## Les meubles pas encore construits apparaissent en fantômes translucides à leur emplacement.

const W := 7.0     # largeur (x)
const D := 6.0     # profondeur (z)
const H := 2.6     # hauteur des murs
const FLOOR := 0.12   # dessus du plancher (au-dessus des chemins de terre qui traversent parfois le chalet)
const WALL := Color(1.0, 0.9, 0.78)     # teintes appliquées sur les textures (assets/textures)
const DARK := Color(0.62, 0.5, 0.42)
const ROOF := Color(0.75, 0.72, 0.7)
const STONE := Color(0.86, 0.82, 0.76)
const GLASS := Color(0.62, 0.8, 0.92)
# Matières : texture, nombre de répétitions par mètre
const MATERIALS := {
	"plancher": ["plancher", 0.55], "murs": ["murs", 0.5], "meubles": ["meubles", 0.9],
	"toit": ["toit", 0.7], "pierre": ["pierre", 0.9], "tissu": ["tissu", 3.0], "drap": ["drap", 1.2],
}

static var _mats := {}

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
	_box(self, Vector3(W - 0.2, FLOOR + 0.04, D - 0.2), Color(1.0, 0.93, 0.85), Vector3(0, (FLOOR - 0.04) / 2.0, 0), "plancher")
	_box(self, Vector3(W, H, 0.2), WALL, Vector3(0, H / 2.0, -D / 2.0 + 0.1), "murs")
	for sx in [-1.0, 1.0]:
		_box(self, Vector3(0.2, H, D), WALL, Vector3(sx * (W / 2.0 - 0.1), H / 2.0, 0), "murs")
		_box(self, Vector3(2.8, H, 0.2), WALL, Vector3(sx * 2.1, H / 2.0, D / 2.0 - 0.1), "murs")   # façade, de part et d'autre de la porte
		# Fenêtres
		_box(self, Vector3(0.26, 0.8, 1.2), GLASS, Vector3(sx * (W / 2.0 - 0.1), 1.5, -0.4), "vitre")
		_box(self, Vector3(1.0, 0.7, 0.26), GLASS, Vector3(sx * 2.1, 1.5, D / 2.0 - 0.1), "vitre")
		_box(self, Vector3(0.3, 0.1, 1.36), DARK, Vector3(sx * (W / 2.0 - 0.1), 1.07, -0.4), "meubles")   # appuis de fenêtre
		_box(self, Vector3(1.16, 0.1, 0.3), DARK, Vector3(sx * 2.1, 1.12, D / 2.0 - 0.1), "meubles")
		# Croisillons des fenêtres
		_box(self, Vector3(0.3, 0.06, 1.2), DARK, Vector3(sx * (W / 2.0 - 0.1), 1.5, -0.4), "meubles")
		_box(self, Vector3(0.3, 0.8, 0.06), DARK, Vector3(sx * (W / 2.0 - 0.1), 1.5, -0.4), "meubles")
		_box(self, Vector3(1.0, 0.06, 0.3), DARK, Vector3(sx * 2.1, 1.5, D / 2.0 - 0.1), "meubles")
		_box(self, Vector3(0.06, 0.7, 0.3), DARK, Vector3(sx * 2.1, 1.5, D / 2.0 - 0.1), "meubles")
	_box(self, Vector3(1.4, 0.5, 0.2), WALL, Vector3(0, 2.35, D / 2.0 - 0.1), "murs")   # linteau de la porte
	_box(self, Vector3(1.6, 0.1, 0.7), DARK, Vector3(0, 0.05, D / 2.0 + 0.35), "meubles")   # marche
	# Poutres d'angle
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(self, Vector3(0.28, H, 0.28), DARK, Vector3(sx * (W / 2.0 - 0.1), H / 2.0, sz * (D / 2.0 - 0.1)), "meubles")
	# Toit à deux pans + pignons
	var half := W / 2.0 + 0.4
	var slope := deg_to_rad(30.0)
	var rise := (W / 2.0) * tan(slope)
	var plen := half / cos(slope)
	for sx in [-1.0, 1.0]:
		# Pan de toit : les rangées d'ardoises suivent la pente (le pan est tourné d'un quart de tour dans son pivot)
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * plen / 2.0 * cos(slope), H + rise - plen / 2.0 * sin(slope), 0)
		pivot.rotation.z = -sx * slope
		add_child(pivot)
		var r := _box(pivot, Vector3(D + 0.8, 0.15, plen), ROOF, Vector3.ZERO, "toit")
		r.rotation.y = PI / 2.0
	for sz in [-1.0, 1.0]:
		var pm := PrismMesh.new()
		pm.size = Vector3(W, rise, 0.2)
		_add(self, pm, WALL, Vector3(0, H + rise / 2.0, sz * (D / 2.0 - 0.1)), "murs")
	_box(self, Vector3(0.5, 1.4, 0.5), STONE, Vector3(1.0, H + rise + 0.1, -1.6), "pierre")   # conduit de cheminée
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
		n.position = slot[0] + Vector3(0, FLOOR, 0)
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
	var wood := Color(1.0, 0.94, 0.86)      # teinte du bois des meubles (texture "meubles")
	var dark := Color(0.72, 0.66, 0.6)
	var brass := Color(0.85, 0.68, 0.3)
	match key:
		"tapis":
			_box(n, Vector3(2.0, 0.02, 1.3), Color(0.72, 0.2, 0.17), Vector3(0, 0.05, 0), "tissu")
			_box(n, Vector3(1.6, 0.025, 0.9), Color(0.98, 0.8, 0.42), Vector3(0, 0.055, 0), "tissu")
			_box(n, Vector3(1.2, 0.03, 0.5), Color(0.72, 0.2, 0.17), Vector3(0, 0.06, 0), "tissu")
		"table_repas":
			_box(n, Vector3(1.4, 0.07, 0.85), wood, Vector3(0, 0.76, 0), "meubles")
			_box(n, Vector3(1.26, 0.08, 0.7), dark, Vector3(0, 0.69, 0), "meubles")   # ceinture sous le plateau
			for x in [-0.62, 0.62]:
				for z in [-0.35, 0.35]:
					_box(n, Vector3(0.07, 0.72, 0.07), dark, Vector3(x, 0.36, z), "meubles")
		"chaise":
			_box(n, Vector3(0.46, 0.06, 0.46), wood, Vector3(0, 0.46, 0), "meubles")
			_box(n, Vector3(0.4, 0.04, 0.4), Color(0.35, 0.55, 0.4), Vector3(0, 0.51, 0.01), "tissu")   # coussin
			for x in [-0.19, 0.19]:
				for z in [-0.19, 0.19]:
					_box(n, Vector3(0.05, 0.46, 0.05), dark, Vector3(x, 0.23, z), "meubles")
			for x in [-0.19, 0.19]:
				_box(n, Vector3(0.05, 0.52, 0.05), dark, Vector3(x, 0.74, -0.2), "meubles")
			for y in [0.62, 0.78, 0.94]:
				_box(n, Vector3(0.38, 0.07, 0.03), wood, Vector3(0, y, -0.2), "meubles")   # barreaux du dossier
		"lit":
			_box(n, Vector3(1.25, 0.32, 2.1), dark, Vector3(0, 0.2, 0), "meubles")
			_box(n, Vector3(1.15, 0.16, 1.98), Color(0.96, 0.95, 0.92), Vector3(0, 0.44, 0.02), "drap")
			_box(n, Vector3(0.8, 0.12, 0.35), Color(1, 1, 1), Vector3(0, 0.57, -0.75), "drap")
			_box(n, Vector3(1.21, 0.07, 1.3), Color(0.3, 0.52, 0.38), Vector3(0, 0.54, 0.38), "tissu")
			_box(n, Vector3(1.25, 0.9, 0.08), dark, Vector3(0, 0.45, -1.05), "meubles")
			_box(n, Vector3(1.25, 0.5, 0.06), dark, Vector3(0, 0.25, 1.05), "meubles")   # pied de lit
		"coffre":
			_box(n, Vector3(0.9, 0.45, 0.5), wood, Vector3(0, 0.25, 0), "meubles")
			_box(n, Vector3(0.94, 0.1, 0.54), dark, Vector3(0, 0.52, 0), "meubles")
			for x in [-0.36, 0.36]:
				_box(n, Vector3(0.05, 0.52, 0.52), Color(0.3, 0.3, 0.32), Vector3(x, 0.28, 0))   # ferrures
			_box(n, Vector3(0.12, 0.12, 0.04), brass, Vector3(0, 0.42, 0.27))
		"armoire":
			_box(n, Vector3(1.15, 2.0, 0.55), wood, Vector3(0, 1.0, 0), "meubles")
			_box(n, Vector3(1.25, 0.08, 0.62), dark, Vector3(0, 2.04, 0), "meubles")   # corniche
			_box(n, Vector3(1.2, 0.1, 0.6), dark, Vector3(0, 0.05, 0), "meubles")      # socle
			for x in [-0.29, 0.29]:
				_box(n, Vector3(0.48, 1.7, 0.02), dark, Vector3(x, 1.05, 0.28), "meubles")   # portes
			_box(n, Vector3(0.02, 1.8, 0.02), Color(0.2, 0.15, 0.1), Vector3(0, 1.02, 0.29))
			for x in [-0.08, 0.08]:
				_box(n, Vector3(0.05, 0.12, 0.05), brass, Vector3(x, 1.05, 0.31))
		"etagere":
			_box(n, Vector3(1.0, 1.7, 0.05), dark, Vector3(0, 0.85, -0.16), "meubles")
			for x in [-0.48, 0.48]:
				_box(n, Vector3(0.04, 1.7, 0.35), wood, Vector3(x, 0.85, 0), "meubles")
			var book_cols := [Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.25, 0.55, 0.3), Color(0.85, 0.7, 0.3)]
			var r := RandomNumberGenerator.new()
			r.seed = 7
			for s in 4:
				_box(n, Vector3(0.96, 0.04, 0.35), wood, Vector3(0, 0.05 + s * 0.45, 0), "meubles")
				if s < 3:
					var x := -0.4
					while x < 0.36:
						var bw := r.randf_range(0.06, 0.11)
						var bh := r.randf_range(0.24, 0.34)
						_box(n, Vector3(bw - 0.01, bh, 0.24), book_cols[r.randi() % 4].darkened(r.randf() * 0.3), Vector3(x + bw / 2.0, 0.07 + bh / 2.0 + s * 0.45, 0.02), "tissu")
						x += bw
		"cheminee":
			var stone := Color(0.88, 0.84, 0.78)
			_box(n, Vector3(1.5, 1.1, 0.5), stone, Vector3(0, 0.55, 0), "pierre")
			_box(n, Vector3(0.8, 0.6, 0.06), Color(0.08, 0.06, 0.05), Vector3(0, 0.4, 0.23))
			_box(n, Vector3(1.7, 0.12, 0.6), dark, Vector3(0, 1.16, 0), "meubles")   # manteau en bois
			_box(n, Vector3(0.6, 1.4, 0.4), stone, Vector3(0, 1.9, -0.05), "pierre")
			for i in 2:
				var bl := _cyl(n, 0.06, 0.06, 0.6, Color(0.45, 0.32, 0.2), Vector3(0, 0.17 + i * 0.09, 0.18 - i * 0.04), "meubles")
				bl.rotation = Vector3(0, 0.3 - i * 0.6, PI / 2.0)
			var flame := _box(n, Vector3(0.4, 0.25, 0.1), Color(1.0, 0.55, 0.15), Vector3(0, 0.33, 0.2))
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
			_cyl(n, 0.18, 0.2, 0.05, dark, Vector3(0, 0.03, 0), "meubles")
			_cyl(n, 0.025, 0.025, 1.45, dark, Vector3(0, 0.75, 0), "meubles")
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
			_cyl(n, 0.2, 0.15, 0.32, Color(0.75, 0.45, 0.3), Vector3(0, 0.16, 0), "pierre")
			_cyl(n, 0.19, 0.19, 0.03, Color(0.3, 0.2, 0.12), Vector3(0, 0.31, 0))   # terreau
			var leaves := [[Vector3(0, 0.62, 0), 0.26], [Vector3(0.14, 0.52, 0.08), 0.18], [Vector3(-0.13, 0.55, -0.06), 0.2],
				[Vector3(0.02, 0.8, -0.05), 0.17], [Vector3(-0.08, 0.5, 0.14), 0.15]]
			for i in leaves.size():
				var s := SphereMesh.new()
				s.radius = leaves[i][1]
				s.height = s.radius * 1.7
				_add(n, s, Color(0.2, 0.5, 0.22).lerp(Color(0.4, 0.68, 0.3), i * 0.2), leaves[i][0], "tissu")
	return n

# ---------- Petits constructeurs ----------
static func _box(parent: Node, size: Vector3, c: Color, pos: Vector3, kind: String = "") -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(parent, b, c, pos, kind)

static func _cyl(parent: Node, r_top: float, r_bot: float, h: float, c: Color, pos: Vector3, kind: String = "") -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	return _add(parent, m, c, pos, kind)

## kind : matière texturée (voir MATERIALS) ou "" pour une couleur unie. La couleur sert alors de teinte.
static func _add(parent: Node, m: Mesh, c: Color, pos: Vector3, kind: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if kind == "":
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mi.material_override = mat
	else:
		mi.material_override = _material(kind, c)
	mi.position = pos
	parent.add_child(mi)
	return mi

## Matière partagée (une par texture et par teinte), avec relief (normal map) et rugosité.
## Les textures sont plaquées en « triplanaire » : pas de coordonnées UV à calculer, et le motif
## garde la même taille quelle que soit la taille de la boîte.
static func _material(kind: String, tint: Color) -> StandardMaterial3D:
	var id := "%s|%s" % [kind, tint.to_html()]
	if _mats.has(id):
		return _mats[id]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if kind == "vitre":
		mat.roughness = 0.12   # vitre : les murs sont pleins derrière, elle reste opaque mais brillante
		mat.metallic_specular = 0.9
	else:
		var def: Array = MATERIALS[kind]
		var base := "res://assets/textures/%s_" % def[0]
		mat.albedo_texture = load(base + "couleur.jpg")
		mat.normal_enabled = true
		mat.normal_texture = load(base + "normal.jpg")
		mat.roughness_texture = load(base + "rugosite.jpg")
		mat.roughness = 1.0
		mat.uv1_triplanar = true
		mat.uv1_triplanar_sharpness = 4.0
		mat.uv1_scale = Vector3.ONE * float(def[1])
	_mats[id] = mat
	return mat
func _shape(sb: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	sb.add_child(cs)
