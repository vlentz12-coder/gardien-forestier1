class_name Items
## Les 18 objets à ramasser, chacun avec sa forme et sa matière (textures ambientCG CC0, pelage généré,
## modèles de assets/models quand ils existent). Maillages et matières sont partagés : 3000 objets restent légers.

const TEX := "res://assets/textures/"
static var _mats := {}
static var _meshes := {}

## Objet prêt à poser au sol (origine = point de contact avec le sol).
static func make(item_name: String, rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	match item_name:
		# ---------- Feuilles ----------
		"Feuille morte":
			var leaf: String = ["objet_erable_rouge", "objet_erable_orange", "objet_noisetier_jaune", "objet_noisetier_brun"][rng.randi() % 4]
			var q := _part(n, _m("leaf"), _leaf_mat(leaf), Vector3(0, 0.015, 0))
			q.rotation = Vector3(-PI / 2.0 + rng.randf_range(-0.15, 0.15), 0, rng.randf_range(0, TAU))
			q.scale = Vector3.ONE * rng.randf_range(0.8, 1.25)
		"Aiguilles de pin":
			for i in 14:
				var a := _part(n, _m("needle"), _flat("needle", Color(0.62, 0.42, 0.2), 0.8), Vector3(rng.randf_range(-0.08, 0.08), 0.008, rng.randf_range(-0.08, 0.08)))
				a.rotation = Vector3(PI / 2.0, rng.randf_range(0, TAU), 0)
				a.rotation.y = rng.randf_range(0, TAU)
		"Herbe sèche":
			var tuft := _part(n, _m("tuft"), _flat("straw", Color(0.82, 0.7, 0.42), 0.9), Vector3.ZERO)
			tuft.scale = Vector3(0.35, rng.randf_range(0.18, 0.26), 0.35)
			(tuft.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
		# ---------- Bois ----------
		"Branche":
			var b := _part(n, _m("branch"), _bark("bark_branch", 6.0), Vector3(0, 0.035, 0))
			b.rotation.z = PI / 2.0
			var twig := _part(n, _m("twig"), _bark("bark_twig", 3.0), Vector3(0.12, 0.03, 0.08))
			twig.rotation = Vector3(0, 0, PI / 2.0)
			twig.rotate_y(0.7)
		"Bûchette":
			var lg := _part(n, _m("log"), _bark("bark_log", 3.0), Vector3(0, 0.06, 0))
			lg.rotation.z = PI / 2.0
			for sx in [-1.0, 1.0]:
				var cap := _part(n, _m("logcap"), _flat("wood_end", Color(0.86, 0.7, 0.48), 0.8), Vector3(sx * 0.19, 0.06, 0))
				cap.rotation.z = PI / 2.0
		"Écorce":
			var piece := _part(n, _m("barkpiece"), _bark("bark_piece", 2.0), Vector3(0, 0.03, 0))
			piece.scale = Vector3(1.0, 1.0, 0.25)   # morceau courbé et plat
			piece.rotation = Vector3(PI / 2.0, 0, 0)
		# ---------- Graines ----------
		"Pomme de pin":
			var cone := _part(n, _m("pinecone"), Nature.fur(Color(0.5, 0.32, 0.17), 40.0), Vector3(0, 0.055, 0))
			cone.scale = Vector3(0.85, 0.85, 1.6)
			cone.rotation.y = rng.randf_range(0, TAU)
			for k in 4:   # rangées d'écailles
				var ring := _part(n, _m("scale_ring"), Nature.fur(Color(0.42, 0.26, 0.13), 40.0), Vector3(0, 0.055, -0.06 + k * 0.04))
				ring.rotation.x = PI / 2.0
		"Gland":
			var ac := _part(n, _m("acorn"), _flat("acorn", Color(0.72, 0.52, 0.25), 0.35), Vector3(0, 0.035, 0))
			ac.scale = Vector3(1, 1, 1.35)
			var cup := _part(n, _m("acorn_cup"), Nature.fur(Color(0.45, 0.35, 0.22), 60.0), Vector3(0, 0.035, -0.028))
			cup.rotation.x = -PI / 2.0
		"Graine":
			for i in 3:
				var sd := _part(n, _m("seed"), _flat("seed", Color(0.25, 0.22, 0.18), 0.4), Vector3(rng.randf_range(-0.04, 0.04), 0.012, rng.randf_range(-0.04, 0.04)))
				sd.scale = Vector3(0.7, 0.6, 1.4)
				sd.rotation.y = rng.randf_range(0, TAU)
		# ---------- Déchets ----------
		"Canette":
			var model := Models.make("canette", 0.25)
			if model != null:
				model.rotation = Vector3(0, 0, PI / 2.0 if rng.randf() < 0.6 else 0.0)
				if model.rotation.z != 0.0:
					model.position.y = 0.0
				n.add_child(model)
			else:
				_part(n, _m("can"), _flat("can", Color(0.8, 0.15, 0.15), 0.3, 0.8), Vector3(0, 0.06, 0))
		"Sac plastique":
			var bag := _part(n, _m("bag"), _plastic(), Vector3(0, 0.035, 0))
			bag.scale = Vector3(rng.randf_range(1.0, 1.5), 0.35, rng.randf_range(0.8, 1.3))
			bag.rotation.y = rng.randf_range(0, TAU)
			var knot := _part(n, _m("bagknot"), _plastic(), Vector3(0.11, 0.03, 0))
			knot.scale = Vector3(1.5, 0.8, 1.0)
		"Bouteille":
			var bottle := Node3D.new()
			bottle.rotation = Vector3(0, rng.randf_range(0, TAU), PI / 2.0)
			bottle.position.y = 0.04
			n.add_child(bottle)
			_part(bottle, _m("bottle"), _glass(), Vector3(0, 0, 0))
			_part(bottle, _m("bottle_neck"), _glass(), Vector3(0, 0.13, 0))
			_part(bottle, _m("bottle_cap"), _flat("cap", Color(0.9, 0.85, 0.2), 0.4), Vector3(0, 0.18, 0))
		# ---------- Champignons ----------
		"Champignon":
			var mush := Models.make("champignon", 0.2)
			if mush != null:
				n.add_child(mush)
			else:
				_part(n, _m("stem"), _flat("stem", Color(0.95, 0.92, 0.85), 0.7), Vector3(0, 0.05, 0))
				_part(n, _m("capm"), _flat("capm", Color(0.75, 0.2, 0.15), 0.5), Vector3(0, 0.1, 0))
		"Baie":
			var red := rng.randf() < 0.6
			for i in 5:
				_part(n, _m("berry"), _flat("berry_r" if red else "berry_b", Color(0.8, 0.08, 0.12) if red else Color(0.2, 0.2, 0.55), 0.15), Vector3(rng.randf_range(-0.03, 0.03), 0.016 + (0.025 if i == 4 else 0.0), rng.randf_range(-0.03, 0.03)))
			var bl := _part(n, _m("leaf_small"), _leaf_mat("objet_noisetier_jaune"), Vector3(0.04, 0.004, 0.02))
			bl.rotation = Vector3(-PI / 2.0, 0, rng.randf_range(0, TAU))
		"Noisette":
			var nut := _part(n, _m("hazel"), _flat("hazel", Color(0.55, 0.36, 0.18), 0.3), Vector3(0, 0.026, 0))
			nut.scale = Vector3(1, 1.1, 1)
			_part(n, _m("hazel_base"), _flat("hazel_base", Color(0.85, 0.75, 0.55), 0.8), Vector3(0, 0.008, 0))
		# ---------- Pierres ----------
		"Caillou":
			var rock := Models.make("caillou", 0.22)
			if rock != null:
				rock.position.y = -0.02
				n.add_child(rock)
			else:
				var pb := _part(n, _m("pebble"), Chalet._material("pierre", Color(0.8, 0.8, 0.78)), Vector3(0, 0.05, 0))
				pb.scale = Vector3(1.2, 0.7, 1)
		"Gravier":
			for i in 7:
				var g := _part(n, _m("gravel"), Chalet._material("pierre", Color(0.85, 0.82, 0.78)), Vector3(rng.randf_range(-0.06, 0.06), 0.015, rng.randf_range(-0.06, 0.06)))
				g.scale = Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.5, 0.8), rng.randf_range(0.8, 1.3))
		_:   # "Terre sèche"
			var clod := _part(n, _m("clod"), _dirt(), Vector3(0, 0.03, 0))
			clod.scale = Vector3(rng.randf_range(1.0, 1.4), 0.6, rng.randf_range(0.9, 1.2))
			clod.rotation.y = rng.randf_range(0, TAU)
	return n

# ---------- Constructeurs ----------
static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## Maillage partagé, créé à la première demande.
static func _m(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match key:
		"leaf":
			m = _quad(0.3)
		"leaf_small":
			m = _quad(0.09)
		"needle":
			m = _cyl(0.004, 0.004, 0.16)
		"tuft":
			m = Nature.grass_tuft()
		"branch":
			m = _cyl(0.025, 0.035, 0.75)
		"twig":
			m = _cyl(0.01, 0.018, 0.25)
		"log":
			m = _cyl(0.06, 0.06, 0.38)
		"logcap":
			m = _cyl(0.055, 0.055, 0.01)
		"barkpiece":
			m = _cyl(0.09, 0.09, 0.26)
		"pinecone":
			m = _sphere(0.06)
		"scale_ring":
			m = _cyl(0.058, 0.04, 0.025)
		"acorn":
			m = _sphere(0.032)
		"acorn_cup":
			m = _hemi(0.034, 0.04)
		"seed":
			m = _sphere(0.018)
		"can":
			m = _cyl(0.035, 0.035, 0.12)
		"bag":
			m = _sphere(0.1)
		"bagknot":
			m = _sphere(0.03)
		"bottle":
			m = _cyl(0.038, 0.038, 0.18)
		"bottle_neck":
			m = _cyl(0.014, 0.036, 0.08)
		"bottle_cap":
			m = _cyl(0.016, 0.016, 0.02)
		"stem":
			m = _cyl(0.02, 0.025, 0.1)
		"capm":
			m = _hemi(0.06, 0.06)
		"berry":
			m = _sphere(0.016)
		"hazel":
			m = _sphere(0.026)
		"hazel_base":
			m = _sphere(0.017)
		"pebble":
			m = _sphere(0.08)
		"gravel":
			m = _sphere(0.025)
		_:   # "clod" : motte de terre
			var s := _sphere(0.09)
			s.height = 0.12
			s.radial_segments = 7
			s.rings = 4
			m = s
	_meshes[key] = m
	return m

static func _quad(sz: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(sz, sz)
	return q

static func _hemi(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.is_hemisphere = true
	return s

static func _cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = 10
	m.rings = 1
	return m

static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m

static func _flat(key: String, c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]

static func _leaf_mat(tex: String) -> StandardMaterial3D:
	if not _mats.has(tex):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(TEX + tex + ".png")
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.8
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats[tex] = m
	return _mats[tex]

static func _bark(key: String, rep: float) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/models/Bark_NormalTree.png")
		m.albedo_color = Color(0.7, 0.58, 0.5)
		m.uv1_scale = Vector3(2.0, rep, 1.0)
		m.roughness = 0.95
		_mats[key] = m
	return _mats[key]

static func _plastic() -> StandardMaterial3D:
	if not _mats.has("plastic"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.9, 0.93, 0.98, 0.75)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.25
		m.metallic_specular = 0.8
		_mats["plastic"] = m
	return _mats["plastic"]

static func _glass() -> StandardMaterial3D:
	if not _mats.has("glass"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.6, 0.3, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic_specular = 1.0
		_mats["glass"] = m
	return _mats["glass"]

static func _dirt() -> StandardMaterial3D:
	if not _mats.has("dirt"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(TEX + "terre_couleur.jpg")
		m.normal_enabled = true
		m.normal_texture = load(TEX + "terre_normal.jpg")
		m.albedo_color = Color(0.85, 0.7, 0.55)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 3.0
		m.roughness = 1.0
		_mats["dirt"] = m
	return _mats["dirt"]
