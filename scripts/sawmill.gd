class_name Sawmill
extends Node3D
## Scierie : le joueur y charge ses bûches (E), la lame les découpe en planches
## (GameData.PLANKS_PER_LOG par bûche). Les planches servent au chalet et à ses meubles.

signal produced(planks: int)

const TIME_PER_LOG := 0.45
const WOOD := Color(0.55, 0.37, 0.2)

var queue := 0               # bûches en attente de découpe
var _t := 0.0
var _blade: MeshInstance3D
var _hopper_logs: Array = []
var _stack: Array = []
var _label: Label3D

func _ready() -> void:
	# Établi + collision
	_box(Vector3(2.4, 0.12, 1.0), WOOD, Vector3(0, 0.82, 0))
	for x in [-1.05, 1.05]:
		for z in [-0.4, 0.4]:
			_box(Vector3(0.12, 0.8, 0.12), WOOD.darkened(0.25), Vector3(x, 0.4, z))
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.4, 1.2, 1.0)
	cs.shape = sh
	cs.position.y = 0.6
	sb.add_child(cs)
	add_child(sb)
	# Lame circulaire et son carter
	_blade = _cyl(0.42, 0.42, 0.04, Color(0.75, 0.77, 0.8), Vector3(0.1, 1.05, 0))
	_blade.rotation.x = PI / 2.0
	(_blade.material_override as StandardMaterial3D).metallic = 0.8
	_box(Vector3(0.9, 0.08, 0.3), Color(0.8, 0.3, 0.15), Vector3(0.1, 1.5, 0))
	# Trémie à bûches (à gauche) : c'est là qu'on vise pour charger
	_box(Vector3(0.8, 0.5, 0.8), WOOD.darkened(0.1), Vector3(-1.3, 1.15, 0))
	for k in 4:
		var lg := _cyl(0.1, 0.1, 0.7, Color(0.45, 0.3, 0.16), Vector3(-1.3, 1.45 + k * 0.17, -0.2 + (k % 2) * 0.4))
		lg.rotation.x = PI / 2.0
		lg.visible = false
		_hopper_logs.append(lg)
	# Pile de planches produites (à droite)
	for k in 8:
		var p := _box(Vector3(0.9, 0.05, 0.22), Color(0.82, 0.64, 0.4), Vector3(1.75, 0.03 + k * 0.06, -0.25 + (k % 2) * 0.5))
		p.visible = false
		_stack.append(p)
	_label = Label3D.new()
	_label.font_size = 40
	_label.pixel_size = 0.0035
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.1, 0)
	add_child(_label)
	set_info(0)

func _process(delta: float) -> void:
	if queue <= 0:
		_blade.rotate_object_local(Vector3.UP, 0.4 * delta)
		return
	_blade.rotate_object_local(Vector3.UP, 25.0 * delta)
	_t += delta
	if _t >= TIME_PER_LOG:
		_t = 0.0
		queue -= 1
		_dust()
		produced.emit(GameData.PLANKS_PER_LOG)

## Point visé par le joueur pour charger les bûches (la trémie).
func hopper_point() -> Vector3:
	return to_global(Vector3(-1.3, 1.3, 0))

func add_logs(n: int) -> void:
	queue += n

## Met à jour l'étiquette, la trémie et la pile de planches.
func set_info(planks: int) -> void:
	_label.text = "Scierie\nBûches à scier : %d · Planches : %d" % [queue, planks] if queue > 0 else "Scierie\nPlanches : %d" % planks
	for k in _hopper_logs.size():
		_hopper_logs[k].visible = queue > k * 3
	for k in _stack.size():
		_stack[k].visible = planks > k * 6

func _dust() -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.24
	mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.78, 0.55, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.5, 1.0, 0)
	add_child(mi)
	var tw := create_tween().set_parallel()
	tw.tween_property(mi, "position", Vector3(randf_range(0.6, 1.2), 1.6, randf_range(-0.4, 0.4)), 0.7)
	tw.tween_property(mi, "scale", Vector3.ONE * 2.0, 0.7)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(mi.queue_free)

# ---------- Petits constructeurs ----------
func _box(size: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(b, c, pos)

func _cyl(r_top: float, r_bot: float, h: float, c: Color, pos: Vector3) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	return _add(m, c, pos)

func _add(m: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi
