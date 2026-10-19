class_name OptionsMenu
extends PanelContainer
## Fenêtre d'options (menu principal et menu pause) : graphismes, audio, commandes, jeu.
## Chaque réglage s'applique tout de suite ; tout est enregistré en fermant la fenêtre.

signal closed

const TAB_SECTIONS := ["graphics", "audio", "controls", "game"]

var tabs: TabContainer
var key_buttons := {}
var waiting := ""    # action en attente d'une nouvelle touche

func _ready() -> void:
	var vb := UiTheme.vbox(self, 12)
	UiTheme.title(vb, "Options")
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(720, 360)
	vb.add_child(tabs)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	UiTheme.button(row, "Valeurs par défaut (cet onglet)", _reset_tab, 0.0)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	UiTheme.button(row, "Retour", close, 160.0)

func open() -> void:
	visible = true
	waiting = ""
	_build_tabs()

func close() -> void:
	waiting = ""
	Settings.save()
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if waiting != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			if code != KEY_ESCAPE:
				Settings.set_key(waiting, code)
			waiting = ""
			_refresh_keys()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

# ---------- Construction des onglets ----------
func _build_tabs() -> void:
	var cur := maxi(tabs.current_tab, 0)
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	key_buttons.clear()
	_tab_graphics()
	_tab_audio()
	_tab_controls()
	_tab_game()
	tabs.current_tab = cur

func _tab_graphics() -> void:
	var g := _page("Graphismes")
	_choice(g, "Mode d'affichage", "graphics", "window_mode", ["Fenêtré", "Plein écran", "Plein écran exclusif"])
	var res := []
	for r in Settings.RESOLUTIONS:
		res.append("%d × %d" % [r.x, r.y])
	_choice(g, "Résolution (mode fenêtré)", "graphics", "resolution", res)
	_check(g, "Synchronisation verticale (VSync)", "graphics", "vsync")
	var fps := ["Illimitée"]
	for f in Settings.FPS_LIMITS.slice(1):
		fps.append("%d images/s" % f)
	_choice(g, "Limite d'images par seconde", "graphics", "max_fps", fps)
	_slider(g, "Échelle de rendu 3D", "graphics", "render_scale", 0.5, 1.0, 0.05, " %", 100.0)
	_choice(g, "Anticrénelage MSAA", "graphics", "msaa", ["Désactivé", "2×", "4×", "8×"])
	_check(g, "Anticrénelage FXAA", "graphics", "fxaa")
	_choice(g, "Qualité des ombres", "graphics", "shadows", ["Désactivées", "Basse", "Moyenne", "Haute"])
	_check(g, "Occlusion ambiante (SSAO)", "graphics", "ssao")
	_check(g, "Halo lumineux (glow)", "graphics", "glow")
	_check(g, "Brouillard", "graphics", "fog")
	_slider(g, "Densité de l'herbe", "graphics", "grass", 0.0, 1.0, 0.05, " %", 100.0)
	_slider(g, "Distance d'affichage", "graphics", "view_distance", 0.5, 1.5, 0.05, " %", 100.0)
	_slider(g, "Champ de vision", "graphics", "fov", 60.0, 100.0, 1.0, "°", 1.0)
	_slider(g, "Luminosité", "graphics", "brightness", 0.5, 1.5, 0.05, " %", 100.0)
	_check(g, "Afficher les images par seconde", "graphics", "show_fps")

func _tab_audio() -> void:
	var g := _page("Audio")
	_slider(g, "Volume général", "audio", "master", 0.0, 1.0, 0.05, " %", 100.0)
	_slider(g, "Musique", "audio", "music", 0.0, 1.0, 0.05, " %", 100.0)
	_slider(g, "Effets sonores", "audio", "sfx", 0.0, 1.0, 0.05, " %", 100.0)
	_slider(g, "Ambiance (oiseaux)", "audio", "ambient", 0.0, 1.0, 0.05, " %", 100.0)
	_check(g, "Couper le son", "audio", "mute")

func _tab_controls() -> void:
	var g := _page("Commandes")
	_slider(g, "Sensibilité de la souris", "controls", "sensitivity", 0.2, 3.0, 0.05, " %", 100.0)
	_check(g, "Inverser l'axe vertical", "controls", "invert_y")
	_header(g, "Touches : clique sur une touche puis appuie sur la nouvelle (Échap annule)")
	for a in Settings.ACTIONS:
		var action: String = a[0]
		_name(g, a[1])
		var b := Button.new()
		b.custom_minimum_size = Vector2(320, 40)
		b.pressed.connect(func() -> void: _wait_key(action))
		g.add_child(b)
		key_buttons[action] = b
	_refresh_keys()
	_header(g, "Fixes : clic gauche = ramasser · 1-4 / molette = outils · 1-6 = poubelles · Échap = pause")

func _tab_game() -> void:
	var g := _page("Jeu")
	_check(g, "Sauvegarde automatique (toutes les 3 min et à la fermeture)", "game", "autosave")
	_check(g, "Afficher la mini-carte", "game", "minimap")
	_slider(g, "Taille de l'interface", "game", "ui_scale", 0.75, 1.25, 0.05, " %", 100.0)

func _reset_tab() -> void:
	Settings.reset(TAB_SECTIONS[tabs.current_tab])
	waiting = ""
	_build_tabs()

# ---------- Touches ----------
func _wait_key(action: String) -> void:
	_refresh_keys()
	waiting = action
	key_buttons[action].text = "Appuie sur une touche…"

func _refresh_keys() -> void:
	for a in key_buttons:
		key_buttons[a].text = Settings.key_name(a)

# ---------- Petits constructeurs ----------
func _page(title: String) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_bottom", 12)
	sc.add_child(m)
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 10)
	m.add_child(g)
	tabs.add_child(sc)
	tabs.set_tab_title(tabs.get_tab_count() - 1, title)
	return g

func _name(g: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.add_child(l)

func _header(g: GridContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UiTheme.ACCENT)
	l.add_theme_font_size_override("font_size", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	g.add_child(l)
	g.add_child(Control.new())

func _slider(g: GridContainer, text: String, sec: String, key: String, mn: float, mx: float, step: float, unit: String, shown_mult: float) -> void:
	_name(g, text)
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(320, 0)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value = float(Settings.data[sec][key])
	var v := Label.new()
	v.custom_minimum_size = Vector2(70, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text = "%d%s" % [roundi(s.value * shown_mult), unit]
	var on_change := func(x: float) -> void:
		v.text = "%d%s" % [roundi(x * shown_mult), unit]
		Settings.set_value(sec, key, x)
	s.value_changed.connect(on_change)
	h.add_child(s)
	h.add_child(v)
	g.add_child(h)

func _check(g: GridContainer, text: String, sec: String, key: String) -> void:
	_name(g, text)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.data[sec][key])
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(sec, key, on))
	g.add_child(c)

func _choice(g: GridContainer, text: String, sec: String, key: String, labels: Array) -> void:
	_name(g, text)
	var o := OptionButton.new()
	for l in labels:
		o.add_item(l)
	o.select(clampi(int(Settings.data[sec][key]), 0, labels.size() - 1))
	o.custom_minimum_size = Vector2(320, 40)
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(sec, key, i))
	g.add_child(o)
