class_name Machine
extends Node3D
## LaMachineQuiRestoreLaForêtator : un réceptacle (entonnoir) par produit.
## Le joueur y verse ses seaux ; la machine fume, ses engrenages tournent, la forêt se restaure.

const WIDTH := 6.4
const METAL := Color(0.36, 0.47, 0.42)

var _funnels: Array = []     # Node3D, un par catégorie (même ordre que GameData.CATS)
var _gears: Array = []
var _display: Label3D
var _chimney_top := Vector3(0, 4.35, -0.5)
var _spin := 0.0
# Cuves : un liquide vert lumineux qui monte avec la restauration de la forêt
const TANK_BOTTOM := 2.62
const TANK_H := 1.24
var _liquids: Array = []
var _fill := 0.0          # niveau affiché (0..1), suit _fill_target en douceur
var _fill_target := 0.0
var _liquid_mat: StandardMaterial3D
var _bubble_t := 0.0

func _ready() -> void:
	# Corps + collision
	_box(Vector3(WIDTH, 2.4, 2.0), METAL, Vector3(0, 1.2, 0))
	_box(Vector3(WIDTH + 0.2, 0.18, 2.2), METAL.darkened(0.3), Vector3(0, 2.49, 0))
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(WIDTH, 2.6, 2.0)
	cs.shape = sh
	cs.position.y = 1.3
	sb.add_child(cs)
	add_child(sb)
	# Cuves vitrées et cheminée
	_liquid_mat = StandardMaterial3D.new()
	_liquid_mat.albedo_color = Color(0.25, 0.95, 0.35, 0.85)
	_liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_liquid_mat.emission_enabled = true
	_liquid_mat.emission = Color(0.2, 0.9, 0.3)
	_liquid_mat.emission_energy_multiplier = 0.9
	_liquid_mat.roughness = 0.1
	for x in [-2.0, 2.0]:
		var liquid := _cyl(0.69, 0.69, 1.0, Color.WHITE, Vector3(x, TANK_BOTTOM, -0.3))
		liquid.material_override = _liquid_mat
		liquid.scale.y = 0.001
		liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_liquids.append(liquid)
		var tank := _cyl(0.75, 0.75, 1.3, Color(0.7, 0.9, 0.85, 0.22), Vector3(x, 3.25, -0.3))
		var tm := tank.material_override as StandardMaterial3D
		tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.roughness = 0.05
		tm.metallic_specular = 1.0
		tank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cyl(0.8, 0.8, 0.1, METAL.darkened(0.25), Vector3(x, 3.95, -0.3))
	_cyl(0.22, 0.28, 1.8, Color(0.3, 0.3, 0.32), Vector3(0, 3.4, -0.5))
	# Engrenages sur les côtés
	for side in [-1.0, 1.0]:
		var g := _cyl(0.6, 0.6, 0.12, Color(0.8, 0.62, 0.25), Vector3(side * (WIDTH / 2.0 + 0.07), 1.4, 0))
		g.rotation.z = PI / 2.0
		_gears.append(g)
	# Panneau avec le nom
	_box(Vector3(5.6, 0.62, 0.08), Color(0.2, 0.14, 0.08), Vector3(0, 2.95, 1.0))
	var sign_lbl := _label(GameData.MACHINE_NAME, 64, 0.0042, Color(1.0, 0.85, 0.35))
	sign_lbl.position = Vector3(0, 2.95, 1.05)
	# Écran de restauration
	_box(Vector3(2.4, 0.42, 0.06), Color(0.04, 0.08, 0.05), Vector3(0, 2.0, 1.0))
	_display = _label("Restauration : 0 %", 44, 0.004, Color(0.45, 1.0, 0.55))
	_display.position = Vector3(0, 2.0, 1.04)
	# Réceptacles : un entonnoir par produit, à la couleur de sa catégorie
	for i in GameData.CATS.size():
		var col: Color = GameData.CATS[i]["color"]
		var holder := Node3D.new()
		holder.position = Vector3(-2.5 + i * 1.0, 0, 1.35)
		add_child(holder)
		var f := _cyl(0.34, 0.12, 0.5, col, Vector3(0, 1.15, 0), holder)
		(f.material_override as StandardMaterial3D).metallic = 0.3
		_cyl(0.3, 0.3, 0.02, Color(0.05, 0.05, 0.05), Vector3(0, 1.405, 0), holder)
		_cyl(0.09, 0.09, 0.9, METAL.darkened(0.4), Vector3(0, 0.45, 0), holder)
		var pipe := _cyl(0.08, 0.08, 0.45, METAL.darkened(0.4), Vector3(0, 0.45, -0.22), holder)
		pipe.rotation.x = PI / 2.0
		var l := _label("%s\n(%s)" % [GameData.CATS[i]["product"], GameData.CATS[i]["name"]], 36, 0.0034, col.lightened(0.45), holder)
		l.position = Vector3(0, 1.68, 0)
		_funnels.append(holder)

func _process(delta: float) -> void:
	_spin = maxf(0.0, _spin - delta * 2.5)
	for g in _gears:
		g.rotate_object_local(Vector3.UP, (0.3 + _spin) * delta)
	# Le liquide monte doucement jusqu'au niveau de restauration, en ondulant un peu
	_fill = move_toward(_fill, _fill_target, delta * 0.08)
	for i in _liquids.size():
		var h := maxf(0.001, _fill * TANK_H + sin(Time.get_ticks_msec() * 0.003 + i) * 0.01 * signf(_fill))
		var l: MeshInstance3D = _liquids[i]
		l.scale.y = h
		l.position.y = TANK_BOTTOM + h / 2.0
	_liquid_mat.emission_energy_multiplier = 0.7 + _spin * 0.15
	if _fill > 0.02:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble_t = randf_range(0.15, 0.5) / (1.0 + _spin * 0.3)
			_bubble()

## Niveau du liquide vert dans les cuves (0 : vide, 1 : pleines = forêt restaurée).
func set_fill(p: float, instant := false) -> void:
	_fill_target = clampf(maxf(p, 0.05) if p > 0.0 else 0.0, 0.0, 1.0)   # dès le 1er versement, on voit du liquide
	if instant:
		_fill = _fill_target

func _bubble() -> void:
	var tank: MeshInstance3D = _liquids[randi() % _liquids.size()]
	var s := SphereMesh.new()
	s.radius = randf_range(0.03, 0.07)
	s.height = s.radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 1.0, 0.8, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var a := randf() * TAU
	var r := randf() * 0.5
	var top := TANK_BOTTOM + _fill * TANK_H
	mi.position = Vector3(tank.position.x + cos(a) * r, TANK_BOTTOM + 0.05, -0.3 + sin(a) * r)
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(mi, "position:y", top, randf_range(0.8, 1.6) * maxf(0.2, _fill))
	tw.tween_callback(mi.queue_free)
## Point visé par le joueur pour le réceptacle i (ouverture de l'entonnoir).
func receptacle_point(i: int) -> Vector3:
	return (_funnels[i] as Node3D).global_position + Vector3(0, 1.3, 0)

func set_display(text: String) -> void:
	_display.text = text

## Mauvais produit : l'entonnoir tremble.
func shake(i: int) -> void:
	var h: Node3D = _funnels[i]
	var x0 := -2.5 + i * 1.0
	var tw := create_tween()
	for dx in [0.08, -0.08, 0.06, -0.04, 0.0]:
		tw.tween_property(h, "position:x", x0 + dx, 0.05)

## Bon produit : fumée de la couleur du produit et engrenages qui s'emballent.
func puff(col: Color) -> void:
	_spin = 7.0
	for k in 7:
		var s := SphereMesh.new()
		s.radius = 0.25
		s.height = 0.5
		var mi := MeshInstance3D.new()
		mi.mesh = s
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(col.r, col.g, col.b, 0.85).lerp(Color(0.85, 1.0, 0.85, 0.85), 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = _chimney_top
		mi.scale = Vector3.ONE * 0.3
		add_child(mi)
		var d := 1.6 + k * 0.15
		var tw := create_tween().set_parallel()
		tw.tween_property(mi, "position", _chimney_top + Vector3(randf_range(-0.7, 0.7), 2.4 + k * 0.3, randf_range(-0.7, 0.7)), d).set_delay(k * 0.12)
		tw.tween_property(mi, "scale", Vector3.ONE * 2.2, d).set_delay(k * 0.12)
		tw.tween_property(mat, "albedo_color:a", 0.0, d).set_delay(k * 0.12)
		tw.chain().tween_callback(mi.queue_free)

# ---------- Petits constructeurs ----------
static var _paint_normal: NoiseTexture2D

## Métal peint : un peu brillant, avec un léger relief de tôle martelée.
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if c.a >= 0.99:
		if _paint_normal == null:
			var nz := FastNoiseLite.new()
			nz.frequency = 0.05
			_paint_normal = NoiseTexture2D.new()
			_paint_normal.seamless = true
			_paint_normal.as_normal_map = true
			_paint_normal.bump_strength = 2.0
			_paint_normal.noise = nz
		m.metallic = 0.45
		m.roughness = 0.5
		m.normal_enabled = true
		m.normal_texture = _paint_normal
		m.normal_scale = 0.35
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.8
	return m

func _box(size: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = _mat(c)
	mi.position = pos
	add_child(mi)
	return mi

func _cyl(r_top: float, r_bot: float, h: float, c: Color, pos: Vector3, parent: Node = null) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat(c)
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi

func _label(text: String, size: int, px: float, c: Color, parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.outline_size = 12
	l.modulate = c
	(parent if parent != null else self).add_child(l)
	return l
