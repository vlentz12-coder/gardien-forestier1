extends Node
## Paramètres du joueur (autoload "Settings"), enregistrés dans user://settings.cfg.
## Affichage et audio s'appliquent ici ; le monde (main.gd) écoute le signal "changed".

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const FPS_LIMITS := [0, 30, 60, 120, 144, 240]

# Actions modifiables : [action, libellé, touche physique par défaut]
const ACTIONS := [
	["move_forward", "Avancer", KEY_W],
	["move_back", "Reculer", KEY_S],
	["move_left", "Aller à gauche", KEY_A],
	["move_right", "Aller à droite", KEY_D],
	["sprint", "Sprinter", KEY_SHIFT],
	["jump", "Sauter", KEY_SPACE],
	["pick", "Ramasser", KEY_F],
	["interact", "Interagir / trier", KEY_E],
	["recall", "Retour au camp", KEY_R],
	["build_menu", "Menu de construction", KEY_TAB],
	["look_left", "Regarder à gauche", KEY_LEFT],
	["look_right", "Regarder à droite", KEY_RIGHT],
	["look_up", "Regarder en haut", KEY_UP],
	["look_down", "Regarder en bas", KEY_DOWN],
	["edge_mode", "Caméra « bords d'écran »", KEY_C],
	["debug", "Infos de debug", KEY_F3],
]

const DEFAULTS := {
	"graphics": {
		"window_mode": 0, "resolution": 0, "vsync": true, "max_fps": 0,
		"render_scale": 1.0, "msaa": 2, "fxaa": false, "shadows": 2,
		"ssao": true, "glow": true, "fog": true, "grass": 1.0,
		"view_distance": 1.0, "fov": 75.0, "brightness": 1.0, "show_fps": false,
	},
	"audio": {"master": 0.8, "music": 0.6, "sfx": 1.0, "ambient": 1.0, "mute": false},
	"controls": {"sensitivity": 1.0, "invert_y": false},
	"game": {"autosave": true, "minimap": true, "ui_scale": 1.0},
}

const KEY_NAMES := {
	"Shift": "Maj", "Ctrl": "Ctrl", "Alt": "Alt", "Space": "Espace", "Enter": "Entrée",
	"Escape": "Échap", "Backspace": "Retour arrière", "Left": "Flèche gauche",
	"Right": "Flèche droite", "Up": "Flèche haut", "Down": "Flèche bas", "CapsLock": "Verr. Maj",
}

var data := {}
var keys := {}       # action -> touche physique
var _fps_label: Label
var _applied_mode := -1
var _applied_res := Vector2i.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Effets")
	_ensure_bus("Ambiance")
	_ensure_bus("Musique")
	data = DEFAULTS.duplicate(true)
	for a in ACTIONS:
		keys[a[0]] = a[2]
	_load()
	_apply_keys()
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.anchor_top = 1.0
	_fps_label.anchor_bottom = 1.0
	_fps_label.offset_left = -120.0
	_fps_label.offset_right = -10.0
	_fps_label.offset_top = -30.0
	_fps_label.offset_bottom = -8.0
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_fps_label)
	apply()

func _process(_delta: float) -> void:
	if _fps_label.visible:
		_fps_label.text = "%d i/s" % Engine.get_frames_per_second()

# ---------- Valeurs ----------
func set_value(section: String, key: String, value) -> void:
	data[section][key] = value
	apply()

func reset(section: String) -> void:
	data[section] = DEFAULTS[section].duplicate(true)
	if section == "controls":
		for a in ACTIONS:
			keys[a[0]] = a[2]
		_apply_keys()
	apply()
	save()

func save() -> void:
	var cf := ConfigFile.new()
	for s in data:
		for k in data[s]:
			cf.set_value(s, k, data[s][k])
	for a in keys:
		cf.set_value("keys", a, keys[a])
	cf.save(PATH)

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for s in data:
		for k in data[s]:
			data[s][k] = cf.get_value(s, k, data[s][k])
	for a in keys:
		keys[a] = int(cf.get_value("keys", a, keys[a]))
	# Réglages d'avant le menu de construction : Tab servait à la caméra « bords d'écran »
	if not cf.has_section_key("keys", "build_menu") and keys["edge_mode"] == KEY_TAB:
		keys["edge_mode"] = KEY_C
	# Réglages d'avant la 0.8 : l'anticrénelage était coupé par défaut, on passe une fois en MSAA 4×
	if not cf.has_section_key("audio", "music") and int(data["graphics"]["msaa"]) == 0:
		data["graphics"]["msaa"] = 2

# ---------- Touches ----------
func _apply_keys() -> void:
	for a in ACTIONS:
		_bind(a[0], keys[a[0]])
	_bind("pause", KEY_ESCAPE)

func _bind(action: String, code: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = code as Key
	InputMap.action_add_event(action, ev)

## Change la touche d'une action ; si une autre action l'utilisait, elles échangent leurs touches.
func set_key(action: String, code: int) -> void:
	for other in keys:
		if other != action and keys[other] == code:
			keys[other] = keys[action]
	keys[action] = code
	_apply_keys()
	save()
	changed.emit()

## Nom de la touche telle qu'elle est écrite sur le clavier du joueur (Z sur AZERTY pour "avancer").
func key_name(action: String) -> String:
	var code: int = keys.get(action, KEY_NONE)
	var k: Key = KEY_NONE
	if DisplayServer.get_name() != "headless":
		k = DisplayServer.keyboard_get_keycode_from_physical(code as Key)
	var s := OS.get_keycode_string(k if k != KEY_NONE else code as Key)
	return KEY_NAMES.get(s, s)

# ---------- Application ----------
func apply() -> void:
	_apply_display()
	_apply_audio()
	changed.emit()

func _apply_display() -> void:
	var g: Dictionary = data["graphics"]
	var win := get_window()
	var wm: int = int(g["window_mode"])
	var res: Vector2i = RESOLUTIONS[clampi(int(g["resolution"]), 0, RESOLUTIONS.size() - 1)]
	if wm != _applied_mode or (wm == 0 and res != _applied_res):
		_applied_mode = wm
		_applied_res = res
		match wm:
			1:
				win.mode = Window.MODE_FULLSCREEN
			2:
				win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			_:
				win.mode = Window.MODE_WINDOWED
				var usable := DisplayServer.screen_get_usable_rect(win.current_screen).size
				if usable.x > 0 and usable.y > 0:
					win.size = Vector2i(mini(res.x, usable.x), mini(res.y, usable.y))
					win.move_to_center()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if g["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_LIMITS[clampi(int(g["max_fps"]), 0, FPS_LIMITS.size() - 1)]
	var vp := get_viewport()
	vp.scaling_3d_scale = float(g["render_scale"])
	vp.msaa_3d = int(g["msaa"]) as Viewport.MSAA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if g["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	win.content_scale_factor = float(data["game"]["ui_scale"])
	_fps_label.visible = bool(g["show_fps"])

func _ensure_bus(bus: String) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus)
	AudioServer.set_bus_send(i, "Master")

func _apply_audio() -> void:
	var a: Dictionary = data["audio"]
	_bus_volume("Master", float(a["master"]))
	_bus_volume("Effets", float(a["sfx"]))
	_bus_volume("Ambiance", float(a["ambient"]))
	_bus_volume("Musique", float(a["music"]))
	if bool(a["mute"]):
		AudioServer.set_bus_mute(0, true)

func _bus_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)
