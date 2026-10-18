class_name UiTheme
## Thème commun des menus (couleurs « forêt ») et petites aides pour construire les écrans.

const ACCENT := Color(0.98, 0.82, 0.35)
const PANEL_BG := Color(0.07, 0.11, 0.08, 0.95)

static var _theme: Theme

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	t.set_stylebox("normal", "Button", _box(Color(0.16, 0.27, 0.17), Color(0.3, 0.46, 0.3), 1))
	t.set_stylebox("hover", "Button", _box(Color(0.22, 0.37, 0.22), ACCENT, 2))
	t.set_stylebox("pressed", "Button", _box(Color(0.11, 0.19, 0.12), ACCENT, 2))
	t.set_stylebox("disabled", "Button", _box(Color(0.12, 0.15, 0.12, 0.7), Color(0.2, 0.25, 0.2), 1))
	var focus := _box(Color(0, 0, 0, 0), ACCENT, 2)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.6, 0.55))
	# Les interrupteurs (CheckButton) gardent un fond transparent
	for s in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		t.set_stylebox(s, "CheckButton", StyleBoxEmpty.new())
	var panel := _box(PANEL_BG, Color(0.35, 0.5, 0.35), 1)
	panel.set_corner_radius_all(14)
	panel.set_content_margin_all(22)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	_theme = t
	return t

static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func vbox(parent: Control, sep: int = 10) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", sep)
	parent.add_child(vb)
	return vb

static func title(parent: Control, text: String, size: int = 28) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l

static func button(parent: Control, text: String, cb: Callable, width: float = 340.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 46)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
