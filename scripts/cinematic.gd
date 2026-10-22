class_name Cinematic
extends Node3D
## Petites cinématiques de restauration : la caméra quitte le gardien et survole la clairière
## pendant que la forêt passe de son état « avant » à son état « après ».
## Jouées une seule fois : premier versement, 25 %, 50 %, 75 % et 100 % (tour complet avant / après).

signal finished

var main
var cam: Camera3D
var _layer: CanvasLayer
var _bars: Array = []
var _caption: Label
var _hint: Label
var _t := 0.0
var _dur := 8.0
var _kind := ""
var _from := 0.0
var _to := 0.0
var _center := Vector3.ZERO
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _hidden: Array = []
var playing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	_layer = CanvasLayer.new()
	_layer.layer = 60
	_layer.visible = false
	add_child(_layer)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.92)
		bar.anchor_right = 1.0
		if top:
			bar.anchor_bottom = 0.0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
		_layer.add_child(bar)
		_bars.append(bar)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.anchor_right = 1.0
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_top = -78.0
	_caption.offset_bottom = -30.0
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_layer.add_child(_caption)
	_hint = Label.new()
	_hint.text = "Échap / Entrée : passer"
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_left = -240.0
	_hint.offset_top = 14.0
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_layer.add_child(_hint)
	# Onde verte qui part de la machine (premier versement)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 64
	tm.ring_segments = 6
	_ring = MeshInstance3D.new()
	_ring.mesh = tm
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(0.45, 1.0, 0.5, 0.0)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)

## kind : "first", "25", "50", "75" ou "100". from / to : restauration avant et après.
func play(kind: String, from_p: float, to_p: float, center: Vector3, caption: String) -> void:
	_kind = kind
	_from = from_p
	_to = to_p
	_center = center
	_t = 0.0
	_dur = {"first": 9.0, "100": 18.0}.get(kind, 10.0)
	_caption.text = caption
	_caption.modulate.a = 0.0
	playing = true
	_layer.visible = true
	for b in _bars:
		(b as ColorRect).offset_bottom = 0.0
		(b as ColorRect).offset_top = 0.0
	var vh := get_viewport().get_visible_rect().size.y * 0.11
	var tw := create_tween().set_parallel()
	tw.tween_property(_bars[0], "offset_bottom", vh, 0.6)
	tw.tween_property(_bars[1], "offset_top", -vh, 0.6)
	tw.tween_property(_caption, "modulate:a", 1.0, 1.2).set_delay(0.8)
	# On cache l'interface du jeu
	_hidden.clear()
	for c in main.get_children():
		if c is CanvasLayer and c.visible:
			c.visible = false
			_hidden.append(c)
	main.player.show_full_body(true)
	cam.current = true
	_update(0.0)

func _process(delta: float) -> void:
	if not playing:
		return
	_t += delta
	_update(delta)
	if _t >= _dur:
		stop()

func _input(event: InputEvent) -> void:
	if playing and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		stop()

func _update(_delta: float) -> void:
	var u := clampf(_t / _dur, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)   # départ et arrivée en douceur
	var look := _center + Vector3(0, 1.5, 0)
	var pos: Vector3
	match _kind:
		"first":
			# Gros plan sur la machine, puis la caméra s'élève pendant que l'onde verte se propage
			pos = _center + Vector3(sin(e * 0.9) * 6.0, lerpf(2.5, 14.0, e), lerpf(8.0, 26.0, e))
			var r := lerpf(0.5, 60.0, clampf((u - 0.15) / 0.7, 0.0, 1.0))
			_ring.visible = u > 0.15 and u < 0.9
			_ring.position = _center + Vector3(0, 0.3, 0)
			_ring.scale = Vector3(r, 3.0, r)
			_ring_mat.albedo_color.a = 0.75 * (1.0 - clampf((u - 0.15) / 0.75, 0.0, 1.0))
			# Dans le sillage de l'onde, la forêt « respire » : un aperçu de vert qui retombe à la vraie valeur
			var glow := sin(clampf((u - 0.2) / 0.6, 0.0, 1.0) * PI) * 0.35
			main.apply_visuals(lerpf(_from, _to, e) + glow)
		"100":
			var a := e * TAU
			pos = _center + Vector3(sin(a) * 34.0, 13.0 + sin(a * 2.0) * 2.0, cos(a) * 34.0)
			main.apply_visuals(lerpf(_from, _to, clampf((u - 0.15) / 0.6, 0.0, 1.0)))
		_:
			var a2 := lerpf(-0.6, 1.4, e)
			pos = _center + Vector3(sin(a2) * 26.0, lerpf(9.0, 12.0, e), cos(a2) * 26.0)
			main.apply_visuals(lerpf(_from, _to, clampf((u - 0.1) / 0.65, 0.0, 1.0)))
	cam.global_position = pos
	cam.look_at(look, Vector3.UP)

func stop() -> void:
	if not playing:
		return
	playing = false
	_ring.visible = false
	_layer.visible = false
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	main.player.show_full_body(false)
	main.player.cam.current = true
	main.apply_visuals(main._pct())
	finished.emit()
