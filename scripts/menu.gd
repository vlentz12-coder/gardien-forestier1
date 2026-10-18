extends Control
## Menu principal : continuer, nouvelle partie, options, quitter.
## Le fond (ciel, sapins, lucioles) est dessiné dans _draw().

var home: VBoxContainer
var options: OptionsMenu
var confirm: PanelContainer
var loading: Label
var t := 0.0
var flies: Array = []    # [position relative, phase, vitesse]

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UiTheme.get_theme()
	for i in 45:
		flies.append([Vector2(randf(), randf_range(0.35, 0.95)), randf() * TAU, randf_range(0.3, 1.0)])

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	home = UiTheme.vbox(center, 14)
	var title := UiTheme.title(home, "Gardien forestier", 64)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_color", Color(0.93, 0.97, 0.85))
	var sub := UiTheme.title(home, "Restaure la forêt, un objet à la fois", 20)
	sub.add_theme_color_override("font_color", Color(0.8, 0.9, 0.75))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	home.add_child(gap)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home.add_child(panel)
	var vb := UiTheme.vbox(panel, 12)
	var has_save := SaveGame.exists()
	var cont := UiTheme.button(vb, "Continuer", func() -> void: _start(true))
	cont.disabled = not has_save
	if has_save:
		var info := Label.new()
		info.text = SaveGame.summary()
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", Color(0.75, 0.82, 0.72))
		vb.add_child(info)
	var new_btn := UiTheme.button(vb, "Nouvelle partie", _new_game)
	UiTheme.button(vb, "Options", _show_options)
	UiTheme.button(vb, "Quitter", func() -> void: get_tree().quit())
	(cont if has_save else new_btn).grab_focus.call_deferred()

	options = OptionsMenu.new()
	options.visible = false
	options.closed.connect(_back)
	center.add_child(options)

	confirm = PanelContainer.new()
	confirm.visible = false
	center.add_child(confirm)
	var cv := UiTheme.vbox(confirm, 12)
	UiTheme.title(cv, "Une sauvegarde existe déjà", 24)
	var warn := Label.new()
	warn.text = "Elle sera remplacée dès que la nouvelle partie sera sauvegardée."
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(warn)
	UiTheme.button(cv, "Commencer une nouvelle partie", func() -> void: _start(false))
	UiTheme.button(cv, "Annuler", _back)

	loading = UiTheme.title(self, "Chargement de la forêt…", 34)
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading.visible = false

	var version := Label.new()
	version.text = "Version %s" % ProjectSettings.get_setting("application/config/version", "")
	version.add_theme_font_size_override("font_size", 13)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = 14.0
	version.offset_top = -30.0
	add_child(version)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _input(event: InputEvent) -> void:
	if confirm.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

func _new_game() -> void:
	if SaveGame.exists():
		home.visible = false
		confirm.visible = true
	else:
		_start(false)

func _show_options() -> void:
	home.visible = false
	options.open()

func _back() -> void:
	options.visible = false
	confirm.visible = false
	home.visible = true

func _start(load_save: bool) -> void:
	SaveGame.load_requested = load_save
	home.visible = false
	confirm.visible = false
	loading.visible = true
	# Deux images pour afficher "Chargement…" avant que la génération de la forêt ne bloque l'écran
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://main.tscn")

# ---------- Fond animé ----------
func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := Color(0.05, 0.09, 0.16)
	var bottom := Color(0.16, 0.27, 0.2)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([top, top, bottom, bottom]))
	var moon := Vector2(w * 0.8, h * 0.2)
	draw_circle(moon, 60.0, Color(1, 0.95, 0.8, 0.08))
	draw_circle(moon, 32.0, Color(1, 0.96, 0.85, 0.85))
	_pines(h * 0.8, 30, 120.0, Color(0.09, 0.17, 0.12), 1)
	_pines(h * 0.92, 20, 170.0, Color(0.04, 0.09, 0.06), 2)
	draw_rect(Rect2(0, h * 0.92, w, h * 0.08 + 1.0), Color(0.04, 0.09, 0.06))
	for f in flies:
		var base: Vector2 = f[0]
		var ph: float = f[1]
		var sp: float = f[2]
		var p := Vector2(base.x * w + sin(t * sp + ph) * 24.0, base.y * h + cos(t * sp * 0.7 + ph) * 14.0)
		var a := 0.5 + 0.5 * sin(t * 2.0 * sp + ph)
		draw_circle(p, 6.0, Color(1, 0.9, 0.4, 0.12 * a))
		draw_circle(p, 2.0, Color(1, 0.95, 0.6, 0.9 * a))

func _pines(base_y: float, count: int, height: float, col: Color, seed_value: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var w := size.x
	for i in count:
		var x := (float(i) + r.randf_range(-0.35, 0.35)) / float(count - 1) * w
		var th := height * r.randf_range(0.6, 1.3)
		var wid := th * 0.5
		draw_rect(Rect2(x - th * 0.03, base_y - th * 0.15, th * 0.06, th * 0.16), col)
		for k in 3:
			var y0 := base_y - th * 0.12 - th * 0.26 * k
			var hw := wid * (1.0 - k * 0.25) * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(x - hw, y0), Vector2(x + hw, y0), Vector2(x, y0 - th * 0.42)]), col)
