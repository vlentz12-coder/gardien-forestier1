class_name LoadMenu
extends PanelContainer
## Fenêtre « Charger une partie » (menu principal et menu pause) : une fiche par sauvegarde,
## avec la date de début, la dernière sauvegarde, le temps de jeu et l'avancement.

signal chosen(n: int)
signal closed

var list: VBoxContainer
var empty_lbl: Label
var in_game := false     # true dans le menu pause : la partie en cours ne peut pas être supprimée
var _confirm_del := 0    # partie dont la suppression attend une confirmation

func _ready() -> void:
	var vb := UiTheme.vbox(self, 12)
	UiTheme.title(vb, "Charger une partie")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	list = UiTheme.vbox(scroll, 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_lbl = Label.new()
	empty_lbl.text = "Aucune partie sauvegardée pour l'instant."
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.72))
	vb.add_child(empty_lbl)
	var back := UiTheme.button(vb, "Retour", close, 160.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END

func open() -> void:
	visible = true
	_confirm_del = 0
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _refresh() -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var slots := SaveGame.slots()
	empty_lbl.visible = slots.is_empty()
	var first: Button
	for n in slots:
		var b := _card(n)
		if first == null:
			first = b
	if first != null:
		first.grab_focus.call_deferred()

## Fiche d'une partie. Renvoie son bouton « Charger ».
func _card(n: int) -> Button:
	var m := SaveGame.read_meta(n)
	var current: bool = in_game and n == SaveGame.slot
	var card := PanelContainer.new()
	var sb := UiTheme._box(Color(0.12, 0.2, 0.13), UiTheme.ACCENT if current else Color(0.3, 0.46, 0.3), 2 if current else 1)
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	list.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var head := Label.new()
	head.text = "Partie %d%s" % [n, "  (en cours)" if current else ""]
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", UiTheme.ACCENT)
	info.add_child(head)
	var restored := float(m.get("restored", -1.0))
	var chalet := ""
	if m.get("chalet", false):
		chalet = "  ·  🏡 Chalet : %d/%d meubles" % [int(m.get("furniture", 0)), GameData.FURNITURE.size()]
	var lines := [
		"Commencée le %s" % SaveGame.date_text(float(m.get("started", 0.0))),
		"Dernière sauvegarde le %s" % SaveGame.date_text(float(m.get("saved", 0.0))),
		"⏱ Temps de jeu : %s" % (SaveGame.duration_text(float(m["play_time"])) if float(m.get("play_time", 0.0)) > 0.0 else "inconnu"),
		"🌿 %d / %d objets ramassés  ·  %d triés" % [int(m.get("collected", 0)), GameData.TOTAL, int(m.get("sorted", 0))]
			+ ("  ·  forêt restaurée à %d %%" % roundi(restored * 100.0) if restored >= 0.0 else "") + chalet,
	]
	for l in lines:
		var lb := Label.new()
		lb.text = l
		lb.add_theme_font_size_override("font_size", 15)
		lb.add_theme_color_override("font_color", Color(0.85, 0.9, 0.82))
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(lb)

	var btns := VBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 8)
	row.add_child(btns)
	var load_btn := UiTheme.button(btns, "Reprendre" if current else "Charger", func() -> void: chosen.emit(n), 150.0)
	var del := UiTheme.button(btns, "Supprimer", func() -> void: _delete(n), 150.0)
	if current:
		del.disabled = true
		del.tooltip_text = "On ne peut pas supprimer la partie en cours."
	elif _confirm_del == n:
		del.text = "Confirmer ?"
		del.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	return load_btn

func _delete(n: int) -> void:
	if _confirm_del != n:
		_confirm_del = n   # premier clic : on demande confirmation
	else:
		_confirm_del = 0
		SaveGame.delete(n)
	_refresh()
