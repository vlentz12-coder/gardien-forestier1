class_name PauseMenu
extends CanvasLayer
## Menu pause (Échap) : reprendre, sauvegarder, charger, options, menu principal, quitter.

var main
var box: PanelContainer
var options: OptionsMenu
var loader: LoadMenu
var confirm: PanelContainer
var confirm_title: Label
var confirm_yes: Button
var confirm_no: Button
var status: Label
var first_btn: Button
var _pending := ""      # "menu" | "quit" | "load"
var _load_slot := 0
var _open_frame := -1

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	box = PanelContainer.new()
	center.add_child(box)
	var vb := UiTheme.vbox(box, 12)
	UiTheme.title(vb, "Pause", 34)
	first_btn = UiTheme.button(vb, "Reprendre", resume)
	UiTheme.button(vb, "Sauvegarder", _save)
	UiTheme.button(vb, "Charger", _show_load)
	UiTheme.button(vb, "Options", _show_options)
	UiTheme.button(vb, "Menu principal", func() -> void: _ask("menu"))
	UiTheme.button(vb, "Quitter le jeu", func() -> void: _ask("quit"))
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", UiTheme.ACCENT)
	status.visible = false
	vb.add_child(status)

	options = OptionsMenu.new()
	options.visible = false
	options.closed.connect(_back)
	center.add_child(options)

	loader = LoadMenu.new()
	loader.in_game = true
	loader.visible = false
	loader.closed.connect(_back)
	loader.chosen.connect(_on_load_chosen)
	center.add_child(loader)

	confirm = PanelContainer.new()
	confirm.visible = false
	center.add_child(confirm)
	var cv := UiTheme.vbox(confirm, 12)
	confirm_title = UiTheme.title(cv, "Sauvegarder avant de quitter ?", 24)
	confirm_yes = UiTheme.button(cv, "Sauvegarder et quitter", func() -> void: _leave(true))
	confirm_no = UiTheme.button(cv, "Quitter sans sauvegarder", func() -> void: _leave(false))
	UiTheme.button(cv, "Annuler", _back)

func open() -> void:
	visible = true
	status.visible = false
	_back()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_open_frame = Engine.get_process_frames()

func resume() -> void:
	visible = false
	get_tree().paused = false
	Settings.save()
	main.resume_play()

func _input(event: InputEvent) -> void:
	if not visible or options.visible or loader.visible or Engine.get_process_frames() == _open_frame:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if confirm.visible:
			_back()
		else:
			resume()

func _back() -> void:
	options.visible = false
	loader.visible = false
	confirm.visible = false
	box.visible = true
	first_btn.grab_focus()

func _save() -> void:
	status.visible = true
	if main.save_game():
		var t := Time.get_datetime_dict_from_system()
		status.text = "💾 Partie sauvegardée à %02dh%02d" % [t["hour"], t["minute"]]
	else:
		status.text = "⚠ La sauvegarde a échoué"

func _show_options() -> void:
	box.visible = false
	options.open()

func _show_load() -> void:
	box.visible = false
	loader.open()

func _on_load_chosen(n: int) -> void:
	loader.visible = false
	if n == SaveGame.slot:
		resume()
		return
	_load_slot = n
	_ask("load")

func _ask(what: String) -> void:
	_pending = what
	if what == "load":
		confirm_title.text = "Sauvegarder la partie en cours avant de charger la partie %d ?" % _load_slot
		confirm_yes.text = "Sauvegarder et charger"
		confirm_no.text = "Charger sans sauvegarder"
	else:
		confirm_title.text = "Sauvegarder avant de quitter ?"
		confirm_yes.text = "Sauvegarder et quitter"
		confirm_no.text = "Quitter sans sauvegarder"
	box.visible = false
	confirm.visible = true

func _leave(save_first: bool) -> void:
	if save_first:
		main.save_game()
	get_tree().paused = false
	if _pending == "quit":
		get_tree().quit()
	elif _pending == "load":
		SaveGame.slot = _load_slot
		SaveGame.load_requested = true
		get_tree().change_scene_to_file("res://main.tscn")
	else:
		get_tree().change_scene_to_file("res://menu.tscn")
