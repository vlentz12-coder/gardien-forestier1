extends Node3D
## Gardien forestier – prototype : une grande forêt, 3000 objets, 6 catégories.

var rng := RandomNumberGenerator.new()
var world_seed := 0          # graine de génération du monde (sauvegardée : même forêt au chargement)
var collected := 0           # objets ramassés (par le joueur et les écureuils)
var sun: DirectionalLight3D
var pause_menu: PauseMenu
var helpers: Array = []
var hud_stamina_lbl: Label
var _k_pick := ""
var _k_interact := ""
var _k_recall := ""
var _k_edge := ""
var _vis_nodes: Array = []   # objets dont la distance d'affichage suit les options
var _view_mult := 1.0
var machine: Machine
var rack: BucketRack
var bin_fill := [0, 0, 0, 0, 0, 0]   # produits dans le seau de chaque bac
var carried := {}                     # seau porté : {"cat": int, "amount": int}, vide sinon
var delivered := 0                    # produits versés dans la machine (fait avancer la restauration)
var carry_node: Node3D
var hud_bucket: Label
# Constructions posées par le joueur (menu Tab) : clé → Node3D
var placed := {}
var sawmill: Sawmill
var chalet: Chalet
var planks := 0                      # planches sorties de la scierie
var furniture := {}                  # meubles du chalet construits : clé → true
var build_menu: BuildMenu
var menu_frame := -1
var ghost: Node3D                    # fantôme de la construction en cours de placement
var ghost_key := ""
var ghost_rot := 0.0
var ghost_err := ""
var ghost_mat: StandardMaterial3D
# Tutoriel
const TUTO_DONE := 6
var tuto_step := TUTO_DONE
var tuto_panel: PanelContainer
var tuto_title: Label
var tuto_label: Label
const MODEL_NAMES := ["feuille", "branche", "pomme_de_pin", "dechet", "champignon", "caillou"]
const MODEL_SIZES := [0.3, 0.8, 0.2, 0.25, 0.2, 0.25]
const GRASS_COUNT := 6000
var sky_mat: ProceduralSkyMaterial
var grass_mm: MultiMesh
var player: Player
var sort_ui: SortUI
var items: Array = []        # Node3D (meta: cat, item_name)
var bag: Array = []          # {"cat": int, "name": String}
var table: Array = []
var cap := 10
var res := 0
var sorted := 0
var up := {"rake": false, "pinces": false, "bag": false, "multi": false, "chariot": false, "trieuse": false, "seau": false, "drone": false}
var mode := "play"           # "play" | "sort" | "menu" (construction) | "place" (fantôme)

var env: Environment
var ground_mat: StandardMaterial3D
var foliage_mat: StandardMaterial3D
var flowers: Array = []
var sfx := {}
var msg_id := 0
var sort_frame := -1
var stock := [0, 0, 0, 0, 0, 0]
var tools_msg := false
var cur_tool := 0
var lv := {"squirrel": 0, "hedgehog": 0}
var proj := {}
var beacons := {}
var animals_spawned := false
var finished := false
var hud_stamina: ProgressBar
var hotbar_row: HBoxContainer
var hotbar_desc: Label

var hud_info: Label
var hud_bar: ProgressBar
var hud_msg: Label
var hud_prompt: Label
var hud_dbg: Label

func _ready() -> void:
	var save: Dictionary = SaveGame.read() if SaveGame.load_requested else {}
	SaveGame.load_requested = false
	world_seed = int(save.get("seed", randi()))
	rng.seed = world_seed
	_view_mult = float(Settings.data["graphics"]["view_distance"])
	for p in GameData.PROJECTS:
		proj[p["key"]] = false
	_build_world(save.is_empty())
	_build_player()
	_build_hud()
	_build_sfx()
	sort_ui = SortUI.new()
	add_child(sort_ui)
	sort_ui.bin_chosen.connect(choose_bin)
	sort_ui.bought.connect(buy)
	sort_ui.closed.connect(_close_sort)
	build_menu = BuildMenu.new()
	add_child(build_menu)
	build_menu.place.connect(start_placing)
	build_menu.furnish.connect(build_furniture)
	build_menu.closed.connect(_close_build_menu)
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var timer := Timer.new()
	timer.wait_time = 2.5
	timer.autostart = true
	timer.timeout.connect(func(): if _pct() > (0.25 if proj["nichoir"] else 0.5): _play("chirp"))
	add_child(timer)
	var btimer := Timer.new()
	btimer.wait_time = 0.5
	btimer.autostart = true
	btimer.timeout.connect(_update_beacons)
	add_child(btimer)
	var save_timer := Timer.new()
	save_timer.wait_time = 180.0
	save_timer.autostart = true
	save_timer.timeout.connect(func(): if Settings.data["game"]["autosave"]: save_game(true))
	add_child(save_timer)
	pause_menu = PauseMenu.new()
	pause_menu.main = self
	add_child(pause_menu)
	Settings.changed.connect(_apply_settings)
	if save.is_empty():
		tuto_step = 0   # nouvelle partie : la clairière est vide, le tutoriel guide la mise en place
		_restore()
	else:
		_apply_save(save)
	_refresh_buckets()
	_apply_settings()
	_refresh_tuto()

# ---------- Entrées (touches définies dans Options > Commandes, voir settings.gd) ----------
func _input(event: InputEvent) -> void:
	if mode == "play":
		_play_input(event)
		return
	if mode == "menu":
		if Engine.get_process_frames() != menu_frame and (event.is_action_pressed("build_menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
			get_viewport().set_input_as_handled()
			_close_build_menu()
		return
	if mode == "place":
		_place_input(event)
		return
	if mode != "sort" or Engine.get_process_frames() == sort_frame:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_sort()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_6 and sort_ui.on_sort_tab():
			choose_bin(k - KEY_1)

# ---------- Monde ----------
func _mesh(m: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	return mi

func _build_world(spawn_items: bool) -> void:
	env = Environment.new()
	sky_mat = ProceduralSkyMaterial.new()
	var sky_res := Sky.new()
	sky_res.sky_material = sky_mat
	env.sky = sky_res
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.85)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.1
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	var plane := PlaneMesh.new()
	plane.size = Vector2(GameData.AREA * 2.0 + 120.0, GameData.AREA * 2.0 + 120.0)
	var ground := _mesh(plane, Color.WHITE)
	ground_mat = ground.material_override
	add_child(ground)
	_box(Vector3(2.6, 0.04, GameData.AREA * 2.0 + 30.0), Color(0.25, 0.55, 0.8), Vector3(10.3, 0.02, 0.0))   # ruisseau

	# La table de tri, la machine et les chantiers sont posés par le joueur (menu Tab, voir plus bas)
	foliage_mat = StandardMaterial3D.new()
	_trunk_mat = StandardMaterial3D.new()
	_trunk_mat.albedo_color = Color(0.35, 0.24, 0.13)
	_build_path()
	_build_mud()
	_scatter_trees()
	_scatter_obstacles()
	_build_grass()
	_build_flowers()
	if spawn_items:
		_spawn_items()

func _make_item(cat: int) -> Node3D:
	var model := Models.make(MODEL_NAMES[cat], MODEL_SIZES[cat])
	if model == null and cat == 3:
		model = Models.make("canette", MODEL_SIZES[cat])   # accepte aussi canette.glb
	if model != null:
		return model
	var col: Color = GameData.CATS[cat]["color"]
	col = col.lerp(Color.WHITE, rng.randf_range(0.0, 0.2))
	var mi: MeshInstance3D
	match cat:
		0:
			var leaf_cols := [Color(0.3, 0.62, 0.2), Color(0.62, 0.62, 0.22), Color(0.45, 0.3, 0.15)]   # verte, fanée, brune
			var tint := [Color(1, 1, 1), Color(1.0, 0.9, 0.5), Color(0.78, 0.52, 0.32)]
			var ci := rng.randi() % 3
			var tex: Texture2D = _leaf_texture()
			if tex != null:
				# ton "skin" de feuille (assets/models/feuille.png) sur un quad plat
				var q := QuadMesh.new()
				q.size = Vector2(0.34, 0.34)
				mi = MeshInstance3D.new()
				mi.mesh = q
				var lm := StandardMaterial3D.new()
				lm.albedo_texture = tex
				lm.albedo_color = (tint[ci] as Color).lerp(Color.WHITE, rng.randf_range(0.0, 0.15))
				lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				lm.alpha_scissor_threshold = 0.5
				lm.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.material_override = lm
				mi.rotation = Vector3(-PI / 2.0 + rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(0.0, TAU))
				mi.position.y = 0.02
			else:
				var lc: Color = leaf_cols[ci]
				lc = lc.lerp(Color.WHITE, rng.randf_range(0.0, 0.12))
				var m := SphereMesh.new()
				m.radius = 0.5
				m.height = 1.0
				mi = _mesh(m, lc)
				mi.scale = Vector3(0.28, 0.02, 0.18)
				mi.position.y = 0.02
				mi.rotation.x = rng.randf_range(-0.2, 0.2)
		1:
			var m := CylinderMesh.new()
			m.top_radius = 0.035
			m.bottom_radius = 0.035
			m.height = 0.7
			mi = _mesh(m, col)
			mi.rotation.z = PI / 2.0
			mi.position.y = 0.04
		2:
			var m := CylinderMesh.new()
			m.top_radius = 0.0
			m.bottom_radius = 0.08
			m.height = 0.22
			mi = _mesh(m, col)
			mi.position.y = 0.08
		3:
			var m := BoxMesh.new()
			m.size = Vector3(0.16, 0.22, 0.16)
			mi = _mesh(m, col)
			mi.position.y = 0.11
		4:
			var m := SphereMesh.new()
			m.radius = 0.09
			m.height = 0.18
			mi = _mesh(m, col)
			mi.position.y = 0.09
		_:
			var m := SphereMesh.new()
			m.radius = 0.12
			m.height = 0.14
			mi = _mesh(m, col)
			mi.scale = Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.6, 1.0), rng.randf_range(0.8, 1.3))
			mi.position.y = 0.07
	return mi

func _build_player() -> void:
	player = Player.new()
	player.position = Vector3(0, 0, 3)
	add_child(player)
	player.pick_pressed.connect(try_pick)
	player.interact_pressed.connect(on_interact)

# ---------- HUD ----------
func _label(parent: Node) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	return l

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_info = _label(layer)
	hud_info.position = Vector2(16, 12)
	hud_bar = ProgressBar.new()
	hud_bar.custom_minimum_size = Vector2(220, 12)
	hud_bar.position = Vector2(16, 132)
	hud_bar.show_percentage = false
	hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_bar.max_value = 100.0
	layer.add_child(hud_bar)
	hud_stamina = ProgressBar.new()
	hud_stamina.custom_minimum_size = Vector2(220, 10)
	hud_stamina.position = Vector2(16, 148)
	hud_stamina.show_percentage = false
	hud_stamina.max_value = 100.0
	hud_stamina.value = 100.0
	hud_stamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_stamina)
	hud_stamina_lbl = _label(layer)
	hud_stamina_lbl.position = Vector2(244, 140)
	hud_stamina_lbl.add_theme_font_size_override("font_size", 12)
	hud_msg = _label(layer)
	hud_prompt = _label(layer)
	for l in [hud_msg, hud_prompt]:
		l.anchor_left = 0.0
		l.anchor_right = 1.0
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_msg.offset_top = -196
	hud_msg.offset_bottom = -166
	hud_prompt.offset_top = -152
	hud_prompt.offset_bottom = -122
	hud_dbg = _label(layer)
	hud_bucket = _label(layer)
	hud_bucket.position = Vector2(16, 166)
	hud_dbg.position = Vector2(16, 194)
	hud_dbg.add_theme_font_size_override("font_size", 13)
	hud_dbg.visible = false   # F3 pour afficher le diagnostic souris
	var cross := ColorRect.new()
	cross.color = Color(1, 1, 1, 0.6)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.anchor_left = 0.5
	cross.anchor_right = 0.5
	cross.anchor_top = 0.5
	cross.anchor_bottom = 0.5
	cross.offset_left = -3
	cross.offset_right = 3
	cross.offset_top = -3
	cross.offset_bottom = 3
	layer.add_child(cross)
	_build_hotbar(layer)
	_build_extra_hud(layer)
	_build_tuto(layer)

func _update_hud() -> void:
	var st := PackedStringArray()
	for i in GameData.CATS.size():
		st.append("%s %d" % [GameData.CATS[i]["use"], stock[i]])
	if planks > 0 or placed.has("scierie"):
		st.append("Planches %d" % planks)
	hud_info.text = "🎒 Sac : %d / %d  ·  Ramassés : %d / %d\n🌿 Ressources : %d  ·  Table : %d\nRestauration : %d %%\n%s" % [
		bag.size(), cap, collected, GameData.TOTAL, res, table.size(), roundi(_pct() * 100.0), " · ".join(st)]
	hud_bar.value = _pct() * 100.0

func _say(t: String) -> void:
	msg_id += 1
	var id := msg_id
	hud_msg.text = t
	await get_tree().create_timer(2.5).timeout
	if id == msg_id:
		hud_msg.text = ""

func _process(delta: float) -> void:
	recall_cd = maxf(0.0, recall_cd - delta)
	var zn: String = _zone_name(Vector2(player.position.x, player.position.z))
	if zn != cur_zone:
		cur_zone = zn
		hud_zone.text = "📍 " + zn
	hud_recall.text = "%s : retour au camp" % _k_recall if recall_cd <= 0.0 else "%s : retour au camp (%d s)" % [_k_recall, ceili(recall_cd)]
	hud_dbg.text = "Souris : %s | mouvements reçus : %d | %s : mode bords d'écran (%s)" % [
		"capturée" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "libre", player.motion_count, _k_edge, "ON" if player.edge_mode else "off"]
	hud_stamina.value = player.stamina
	hud_stamina.modulate = Color(1, 0.4, 0.3) if player.exhausted else Color(1, 1, 1)
	player.speed_mult = _speed_mult()
	_tuto_check()
	if mode == "place":
		_update_ghost()
		return
	if mode != "play":
		hud_prompt.text = ""
		return
	var near := _near_table()
	var rec := _aim_receptacle()
	var bk := _aim_bucket()
	if rec >= 0:
		hud_prompt.text = "%s : verser dans le réceptacle « %s »" % [_k_interact, _product(rec)] if not carried.is_empty() else "Réceptacle « %s » : apporte un seau de ce produit" % _product(rec)
	elif bk >= 0:
		hud_prompt.text = "%s : prendre le seau « %s » (%d/%d)" % [_k_interact, _product(bk), bin_fill[bk], _bucket_cap()]
	elif _aim_sawmill():
		hud_prompt.text = "%s : charger %d bûche(s) dans la scierie" % [_k_interact, stock[1]] if stock[1] > 0 else "Scierie : trie du bois à la table pour avoir des bûches"
	elif _find_target() != null:
		hud_prompt.text = "Clic / %s : ramasser" % _k_pick
	elif near and (bag.size() > 0 or table.size() > 0):
		hud_prompt.text = "%s : trier à la table" % _k_interact
	else:
		hud_prompt.text = ""

# ---------- Audio ----------
func _build_sfx() -> void:
	var defs := {
		"pick": [500.0, 650.0, 0.08, "sine", 0.5],
		"plop": [300.0, 600.0, 0.14, "sine", 0.6],
		"bad": [140.0, 90.0, 0.22, "saw", 0.35],
		"buy": [700.0, 1200.0, 0.3, "sine", 0.5],
		"chirp": [2200.0, 3200.0, 0.12, "sine", 0.25],
		"pour": [420.0, 160.0, 0.45, "sine", 0.55],
		"machine": [180.0, 520.0, 0.6, "saw", 0.25],
		"saw": [900.0, 650.0, 0.12, "saw", 0.12],
	}
	for k in defs:
		var d: Array = defs[k]
		var p := AudioStreamPlayer.new()
		p.stream = Sfx.tone(d[0], d[1], d[2], d[3], d[4])
		p.bus = "Ambiance" if k == "chirp" else "Effets"
		add_child(p)
		sfx[k] = p

func _play(sound: String) -> void:
	if sfx.has(sound):
		sfx[sound].play()

# ---------- Ramassage ----------
func _find_target():
	var cam := player.cam
	var origin := cam.global_position
	var f := -cam.global_transform.basis.z
	var best = null
	var bs := 9.0
	for o in items:
		if o.get_meta("busy", false):
			continue
		var w: Vector3 = o.global_position - origin
		var t := w.dot(f)
		if not _accepts(o.get_meta("cat")):
			continue
		if t < 0.3 or t > _reach():
			continue
		var pp := (w - f * t).length()
		if pp < 0.45 and pp + t * 0.03 < bs:
			bs = pp + t * 0.03
			best = o
	return best

func try_pick() -> void:
	if mode == "place":
		_confirm_place()
		return
	if mode != "play":
		return
	var t = _find_target()
	if t == null:
		return
	if bag.size() >= cap:
		_say("Sac plein ! Retourne à la table (%s)" % _k_interact)
		return
	var list: Array = [t]
	if cur_tool == 1:
		for o in items:
			if o != t and o.get_meta("cat") == 0 and not o.get_meta("busy", false) and o.global_position.distance_to(t.global_position) < 2.4:
				list.append(o)
	if cur_tool == 3:
		var rest: Array = items.filter(func(o): return not list.has(o) and not o.get_meta("busy", false))
		rest.sort_custom(func(a, b): return a.global_position.distance_to(t.global_position) < b.global_position.distance_to(t.global_position))
		for i in mini(2, rest.size()):
			list.append(rest[i])
	for o in list:
		if bag.size() >= cap:
			break
		items.erase(o)
		bag.append({"cat": o.get_meta("cat"), "name": o.get_meta("item_name")})
		o.queue_free()
		collected += 1
	_play("pick")
	_check_unlock()
	_update_hud()

func _check_unlock() -> void:
	if collected >= GameData.TOOLS_UNLOCK_COUNT and not tools_msg:
		tools_msg = true
		_say("🔧 Outils débloqués à la table de tri !")

# ---------- Tri ----------
func try_open_sort() -> void:
	if mode != "play":
		return
	if not placed.has("table"):
		_say("Pose d'abord ta table de tri : menu de construction (%s), onglet Essentiel" % Settings.key_name("build_menu"))
		return
	if not _near_table():
		_say("Approche-toi de la table")
		return
	var auto := 0
	if up["trieuse"]:
		var n := int(bag.size() * 0.25)
		for it in bag.duplicate():
			if auto >= n:
				break
			if bin_fill[it["cat"]] < _bucket_cap():
				bag.erase(it)
				_gain(it)
				auto += 1
		if auto > 0:
			_refresh_buckets()
	table.append_array(bag)
	bag.clear()
	_update_hud()
	if table.is_empty():
		_say("Rien à trier" if auto == 0 else "Trieuse : %d objets triés automatiquement" % auto)
		return
	if auto > 0:
		_say("Trieuse : %d objets triés automatiquement" % auto)
	mode = "sort"
	sort_frame = Engine.get_process_frames()
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sort_ui.open(_ui())

func _close_sort() -> void:
	if mode != "sort":
		return
	mode = "play"
	sort_ui.visible = false
	player.enabled = true
	player.grab()

func choose_bin(i: int) -> void:
	if table.is_empty():
		return
	if table[0]["cat"] == i and bin_fill[i] >= _bucket_cap():
		_play("bad")
		sort_ui.shake()
		sort_ui.refresh(_ui())
		sort_ui.flash("🪣 Le seau « %s » est plein ! Ferme la table, prends le seau et vide-le dans %s." % [_product(i), GameData.MACHINE_NAME])
		return
	if table[0]["cat"] == i:
		_gain(table.pop_front())
		_play("plop")
		_refresh_buckets()
		if sorted == GameData.TOTAL and _pct() < 1.0:
			_say("Tout est trié ! Apporte les derniers seaux à la machine.")
	else:
		table.append(table.pop_front())
		_play("bad")
		sort_ui.shake()
	sort_ui.refresh(_ui())
	_update_hud()

func buy(key: String) -> void:
	if collected < GameData.TOOLS_UNLOCK_COUNT:
		return
	for u in GameData.UPGRADES:
		if u["key"] != key:
			continue
		var mx: int = u.get("max", 1)
		var level: int = lv.get(key, 0) if mx > 1 else (1 if up.get(key, false) else 0)
		if level >= mx:
			continue
		var cost: int = int(u["cost"]) * (level + 1)
		if res < cost:
			continue
		var req: String = u.get("req", "")
		if req != "" and not _has(req):
			continue
		res -= cost
		if mx > 1:
			lv[key] = level + 1
		else:
			up[key] = true
		match key:
			"bag":
				cap = 20
			"chariot":
				cap = 50
				_show_cart()
			"squirrel":
				_spawn_helper("squirrel")
			"hedgehog":
				_spawn_helper("hedgehog")
				_show_piles()
			"seau":
				_refresh_buckets()
		_play("buy")
		_say("Obtenu : %s" % u["name"])
		for i in GameData.TOOLS.size():
			if GameData.TOOLS[i]["up"] == key:
				cur_tool = i
		_refresh_hotbar()
	sort_ui.refresh(_ui())
	_update_hud()

# ---------- Restauration visuelle ----------
func _restore() -> void:
	var p := _pct()
	ground_mat.albedo_color = Color(0.48, 0.48, 0.43).lerp(Color(0.31, 0.60, 0.23), p)
	foliage_mat.albedo_color = Color(0.42, 0.42, 0.35).lerp(Color(0.18, 0.49, 0.2), p)
	var sky := Color(0.6, 0.63, 0.63).lerp(Color(0.56, 0.82, 0.94), p)
	sky_mat.sky_top_color = Color(0.45, 0.5, 0.52).lerp(Color(0.25, 0.5, 0.85), p)
	sky_mat.sky_horizon_color = sky
	sky_mat.ground_horizon_color = sky
	sky_mat.ground_bottom_color = sky.darkened(0.3)
	env.fog_light_color = sky
	_restore_grass()
	if machine != null:
		machine.set_display("Restauration : %d %%" % roundi(p * 100.0))
	env.fog_density = lerpf(0.02, 0.004, p)
	var shown := 0
	if p > 0.25:
		shown = int((p - 0.25) / 0.75 * flowers.size())
	for i in flowers.size():
		flowers[i].visible = i < shown
	if p >= 0.75 and not animals_spawned:
		animals_spawned = true
		for k in ["fox", "fox", "deer", "deer"]:
			_spawn_helper(k)
	if p >= 1.0 and not finished:
		finished = true
		_say("🎉 La clairière est entièrement restaurée ! Merci, gardien !")
	_update_hud()


func _show_cart() -> void:
	var cart := Node3D.new()
	cart.position = Vector3(0.65, -1.0, -1.1)
	var body := BoxMesh.new()
	body.size = Vector3(0.6, 0.25, 0.8)
	cart.add_child(_mesh(body, Color(0.55, 0.36, 0.18)))
	for sx in [-0.34, 0.34]:
		var w := CylinderMesh.new()
		w.top_radius = 0.16
		w.bottom_radius = 0.16
		w.height = 0.05
		var wm := _mesh(w, Color(0.2, 0.2, 0.2))
		wm.rotation.z = PI / 2.0
		wm.position = Vector3(sx, -0.08, 0.15)
		cart.add_child(wm)
	player.cam.add_child(cart)

# ---------- Barre d'outils (bas de l'écran) ----------
func _accepts(cat: int) -> bool:
	match cur_tool:
		1:
			return cat == 0
		2:
			return cat == 1 or cat == 3
	return true

func _reach() -> float:
	return GameData.REACH_TONGS if cur_tool == 2 else GameData.REACH

func _tool_owned(i: int) -> bool:
	var u: String = GameData.TOOLS[i]["up"]
	return u == "" or up[u]

func select_tool(i: int) -> void:
	if i < 0 or i >= GameData.TOOLS.size():
		return
	if not _tool_owned(i):
		_say("Outil pas encore débloqué")
		return
	cur_tool = i
	_refresh_hotbar()

func cycle_tool(d: int) -> void:
	var n := GameData.TOOLS.size()
	var i := cur_tool
	for _s in n:
		i = (i + d + n) % n
		if _tool_owned(i):
			cur_tool = i
			break
	_refresh_hotbar()

func _play_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		pause_menu.open()
	elif event.is_action_pressed("debug"):
		hud_dbg.visible = not hud_dbg.visible
	elif event.is_action_pressed("recall"):
		recall()
	elif event.is_action_pressed("build_menu"):
		get_viewport().set_input_as_handled()
		open_build_menu()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1 and tuto_step < TUTO_DONE:
		tuto_step = TUTO_DONE
		_refresh_tuto()
		_say("Tutoriel passé. Le menu de construction reste sur %s." % Settings.key_name("build_menu"))
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_4:
			select_tool(k - KEY_1)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_tool(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_tool(1)

func _build_hotbar(layer: CanvasLayer) -> void:
	var vb := VBoxContainer.new()
	vb.anchor_left = 0.5
	vb.anchor_right = 0.5
	vb.anchor_top = 1.0
	vb.anchor_bottom = 1.0
	vb.offset_top = -112
	vb.offset_bottom = -12
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vb)
	hotbar_desc = _label(vb)
	hotbar_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotbar_desc.add_theme_font_size_override("font_size", 14)
	hotbar_row = HBoxContainer.new()
	hotbar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_row.add_theme_constant_override("separation", 6)
	hotbar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(hotbar_row)
	_refresh_hotbar()

func _refresh_hotbar() -> void:
	for c in hotbar_row.get_children():
		c.queue_free()
	for i in GameData.TOOLS.size():
		var t = GameData.TOOLS[i]
		_add_slot(str(i + 1), t["icon"], t["name"], _tool_owned(i), i == cur_tool)
	var sep := VSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar_row.add_child(sep)
	for p in GameData.PASSIVES:
		_add_slot("", p["icon"], p["name"], _has(p["up"]), false)
	hotbar_desc.text = "%s – %s" % [GameData.TOOLS[cur_tool]["name"], GameData.TOOLS[cur_tool]["desc"]]

func _add_slot(key: String, icon: String, lbl: String, owned: bool, selected: bool) -> void:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(84, 62)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.modulate = Color(1, 1, 1, 1) if owned else Color(1, 1, 1, 0.5)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.08, 0.8)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(3 if selected else 1)
	sb.border_color = Color(1.0, 0.85, 0.3) if selected else Color(1, 1, 1, 0.25)
	p.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(vb)
	var top := Label.new()
	top.text = ("%s  " % key if key != "" else "") + (icon if owned else "🔒")
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(top)
	var bottom := Label.new()
	bottom.text = lbl
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_theme_font_size_override("font_size", 12)
	vb.add_child(bottom)
	hotbar_row.add_child(p)

# ---------- Phase 3 : état, gains, chantiers, aides ----------
func _pct() -> float:
	var done := 0
	for k in proj:
		if proj[k]:
			done += 1
	return 0.7 * float(delivered) / GameData.TOTAL + 0.3 * float(done) / GameData.PROJECTS.size()

func _has(k: String) -> bool:
	return up.get(k, false) or lv.get(k, 0) > 0 or proj.get(k, false) or placed.has(k)

func _ui() -> Dictionary:
	return {"table": table, "res": res, "up": up, "lv": lv, "proj": proj, "stock": stock, "pct": _pct(), "collected": collected, "fill": bin_fill, "bucket_cap": _bucket_cap()}

func _gain(it) -> void:
	var c: int = it["cat"]
	stock[c] += 1
	res += 1
	if c == 0 and proj["composteur"]:
		res += 1
	elif c == 1 and placed.has("scierie"):
		res += 1
	elif c == 3 and proj["recyclerie"]:
		res += 2
	sorted += 1
	bin_fill[c] += 1

func _speed_mult() -> float:
	var m := 1.0
	if up["chariot"]:
		m *= 0.85
	if proj["chemin"]:
		m *= 1.1
	var px := player.position.x
	var here := Vector2(player.position.x, player.position.z)
	if _path_dist(here) < 1.4:
		m *= 1.2   # on marche plus vite sur les chemins
	for md in mud:
		var mp: Vector2 = md["p"]
		if here.distance_to(mp) < float(md["r"]):
			m *= 0.55   # on s'enlise dans la boue
			break
	if px > 9.0 and px < 11.6 and not (placed.has("pont") and absf(player.position.z - (placed["pont"] as Node3D).position.z) < 1.5):
		m *= 0.5   # on patauge dans le ruisseau
	return m

func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := _mesh(m, color)
	mi.position = pos
	add_child(mi)
	return mi

func _cyl(r_top: float, r_bot: float, h: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	var mi := _mesh(m, color)
	mi.position = pos
	add_child(mi)
	return mi

## Modèle d'un chantier, centré sur son point de pose (il est ensuite placé et tourné par le joueur).
func _make_project(key: String) -> Node3D:
	var n := Node3D.new()
	var wood := Color(0.55, 0.36, 0.18)
	match key:
		"chemin":
			for i in 8:
				_part(n, _cyl_mesh(0.4, 0.4, 0.05), Color(0.6, 0.6, 0.58), Vector3(rng.randf_range(-0.25, 0.25), 0.03, -3.15 + i * 0.9))
		"nichoir":
			_part(n, _cyl_mesh(0.05, 0.05, 1.6), wood, Vector3(0, 0.8, 0))
			_part(n, _box_mesh(Vector3(0.4, 0.35, 0.35)), Color(0.7, 0.5, 0.3), Vector3(0, 1.75, 0))
			_part(n, _box_mesh(Vector3(0.5, 0.08, 0.45)), Color(0.7, 0.2, 0.15), Vector3(0, 1.98, 0))
		"pont":
			_part(n, _box_mesh(Vector3(3.2, 0.12, 2.2)), wood, Vector3(0, 0.1, 0))
			_part(n, _box_mesh(Vector3(3.2, 0.5, 0.08)), wood, Vector3(0, 0.4, 1.1))
			_part(n, _box_mesh(Vector3(3.2, 0.5, 0.08)), wood, Vector3(0, 0.4, -1.1))
		"composteur":
			_part(n, _box_mesh(Vector3(1.1, 0.7, 1.1)), Color(0.25, 0.35, 0.15), Vector3(0, 0.35, 0))
			_part(n, _box_mesh(Vector3(1.2, 0.1, 1.2)), wood, Vector3(0, 0.75, 0))
		"recyclerie":
			var cols := [Color(0.2, 0.45, 0.85), Color(0.2, 0.65, 0.3), Color(0.9, 0.8, 0.2)]
			for i in 3:
				_part(n, _box_mesh(Vector3(0.7, 0.9, 0.7)), cols[i], Vector3(-0.85 + i * 0.85, 0.45, 0))
		"mangeoire":
			_part(n, _cyl_mesh(0.06, 0.06, 1.0), wood, Vector3(0, 0.5, 0))
			_part(n, _box_mesh(Vector3(0.8, 0.08, 0.5)), wood, Vector3(0, 1.05, 0))
		"serre":
			var g := _part(n, _box_mesh(Vector3(2.4, 1.6, 2.0)), Color(0.7, 0.9, 1.0, 0.35), Vector3(0, 0.8, 0))
			(g.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for i in 12:
				var a := rng.randf_range(0.0, TAU)
				var r := rng.randf_range(2.6, 4.6)
				var pos := Vector3(cos(a) * r, 0.0, sin(a) * r)
				_part(n, _cyl_mesh(0.04, 0.06, 0.6), Color(0.35, 0.24, 0.13), pos + Vector3(0, 0.3, 0))
				_part(n, _cyl_mesh(0.0, 0.35, 0.8), Color(0.22, 0.6, 0.25), pos + Vector3(0, 0.95, 0))
		"arbre":
			_part(n, _cyl_mesh(0.5, 0.7, 4.0), Color(0.35, 0.24, 0.13), Vector3(0, 2.0, 0))
			var s := SphereMesh.new()
			s.radius = 2.6
			s.height = 5.0
			_part(n, s, Color(0.2, 0.55, 0.25), Vector3(0, 5.5, 0))
	return n

func _part(parent: Node, m: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := _mesh(m, color)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func _cyl_mesh(r_top: float, r_bot: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	return m

## Table de tri : plateau, 6 bacs avec leur nom, et les seaux de produits devant.
func _make_table() -> Node3D:
	var root := Node3D.new()
	_part(root, _box_mesh(Vector3(3.8, 0.9, 1.1)), Color(0.54, 0.35, 0.17), Vector3(0, 0.45, 0))
	for i in GameData.CATS.size():
		_part(root, _box_mesh(Vector3(0.5, 0.3, 0.5)), Color(0.62, 0.45, 0.28), Vector3(-1.6 + i * 0.64, 1.05, 0))
		var tag := Label3D.new()
		tag.text = GameData.CATS[i]["name"]
		tag.font_size = 48
		tag.pixel_size = 0.0035
		tag.outline_size = 10
		tag.position = Vector3(-1.6 + i * 0.64, 1.45 + (i % 2) * 0.22, 0)   # hauteurs alternées : les noms ne se chevauchent plus
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(tag)
	var r := BucketRack.new()
	r.name = "Rack"
	root.add_child(r)
	return root

func _show_piles() -> void:
	if has_meta("piles"):
		return
	set_meta("piles", true)
	for p in GameData.PILES:
		_cyl(1.6, 1.6, 0.02, Color(0.4, 0.3, 0.2), Vector3(p.x, 0.012, p.z))

func _spawn_helper(kind: String) -> void:
	var h := Helper.new()
	add_child(h)
	var pos := table_drop_point() + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-0.5, 0.5))
	if kind == "fox" or kind == "deer":
		pos = Vector3(rng.randf_range(-GameData.AREA, GameData.AREA), 0, rng.randf_range(-GameData.AREA, GameData.AREA))
	h.setup(self, kind, pos)
	helpers.append(h)

# Appelées par les aides (écureuils, hérissons)
func _near_pile(p: Vector3) -> bool:
	for c in GameData.PILES:
		if Vector2(p.x - c.x, p.z - c.z).length() < 2.5:
			return true
	return false

func pile_pos() -> Vector3:
	return GameData.PILES[randi() % GameData.PILES.size()]

func helper_find_item(kind: String, from: Vector3):
	var best = null
	var bd := 1e9
	var home := table_drop_point()
	for o in items:
		if o.get_meta("busy", false):
			continue
		if Vector2(o.global_position.x - home.x, o.global_position.z - home.z).length() > GameData.HELPER_RANGE:
			continue
		var c: int = o.get_meta("cat")
		if kind == "squirrel":
			if c != 2 and c != 4:
				continue
		elif c != 0 or _near_pile(o.global_position):
			continue
		var d := from.distance_to(o.global_position)
		if d < bd:
			bd = d
			best = o
	return best

func helper_take(item) -> Dictionary:
	var inf := {"cat": item.get_meta("cat"), "name": item.get_meta("item_name")}
	items.erase(item)
	item.queue_free()
	collected += 1
	_check_unlock()
	return inf

func helper_deliver(inf) -> void:
	table.append(inf)
	_update_hud()
	if mode == "sort":
		sort_ui.refresh(_ui())

func helper_drop(item, pos: Vector3) -> void:
	if not is_instance_valid(item):
		return
	item.global_position = Vector3(pos.x + rng.randf_range(-0.8, 0.8), item.get_meta("rest_y"), pos.z + rng.randf_range(-0.8, 0.8))
	item.set_meta("busy", false)

func _update_beacons() -> void:
	if up["drone"] and items.size() <= 120:
		for o in items:
			if not beacons.has(o):
				var m := CylinderMesh.new()
				m.top_radius = 0.04
				m.bottom_radius = 0.04
				m.height = 3.0
				var b := _mesh(m, Color(1.0, 0.9, 0.2))
				var mat := b.material_override as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.85, 0.1)
				mat.emission_energy_multiplier = 2.0
				add_child(b)
				beacons[o] = b
			beacons[o].position = Vector3(o.global_position.x, 1.5, o.global_position.z)
	for o in beacons.keys():
		if not is_instance_valid(o) or not items.has(o):
			beacons[o].queue_free()
			beacons.erase(o)

# ---------- Herbe qui pousse avec la restauration ----------
func _build_grass() -> void:
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.05
	blade.height = 0.35
	blade.radial_segments = 4
	blade.rings = 1
	grass_mm = MultiMesh.new()
	grass_mm.transform_format = MultiMesh.TRANSFORM_3D
	grass_mm.mesh = blade
	grass_mm.instance_count = GRASS_COUNT
	for i in GRASS_COUNT:
		var pos := Vector3.ZERO
		while true:
			pos = Vector3(rng.randf_range(-GameData.AREA, GameData.AREA), 0.17, rng.randf_range(-GameData.AREA, GameData.AREA))
			if Vector2(pos.x, pos.z).length() > 3.0 and (pos.x < 8.8 or pos.x > 11.8) and _path_dist(Vector2(pos.x, pos.z)) > 1.6:
				break
		var s := Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.7, 1.7), rng.randf_range(0.8, 1.6))
		grass_mm.set_instance_transform(i, Transform3D(Basis.from_scale(s), pos))
	grass_mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = grass_mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.65, 0.22)
	mi.material_override = mat
	add_child(mi)

var _leaf_tex_checked := false
var _leaf_tex: Texture2D = null

func _leaf_texture() -> Texture2D:
	if not _leaf_tex_checked:
		_leaf_tex_checked = true
		for n in ["feuille.png", "feuille.webp", "feuille.jpg"]:
			var path: String = "res://assets/models/" + n
			if ResourceLoader.exists(path):
				_leaf_tex = load(path) as Texture2D
				break
	return _leaf_tex


# ---------- Phase 4 : grande carte, chemins, obstacles, mini-carte ----------
var _trunk_mat: StandardMaterial3D
var obstacles: Array = []      # {"p": Vector2, "r": float}
var path_pts: PackedVector2Array = PackedVector2Array()
var mud: Array = []            # {"p": Vector2, "r": float}
var cur_zone := ""
var recall_cd := 0.0
var minimap: Minimap
var hud_zone: Label
var hud_recall: Label

func _in_stream(x: float) -> bool:
	return x > 8.8 and x < 11.8

func _path_dist(p: Vector2) -> float:
	var best: float = 1e9
	for q in path_pts:
		var d: float = p.distance_to(q)
		if d < best:
			best = d
	return best

func _blocked(p: Vector2, margin: float) -> bool:
	for o in obstacles:
		var op: Vector2 = o["p"]
		if p.distance_to(op) < float(o["r"]) + margin:
			return true
	return false

func _free_spot(r: float, camp_clear: float, path_clear: float) -> Variant:
	for _t in 60:
		var p := Vector2(rng.randf_range(-GameData.AREA + 2.0, GameData.AREA - 2.0), rng.randf_range(-GameData.AREA + 2.0, GameData.AREA - 2.0))
		if p.length() < camp_clear or _in_stream(p.x) or _path_dist(p) < path_clear:
			continue
		if _blocked(p, r + 0.6):
			continue
		return p
	return null

func _limit_vis(n: Node, d: float, shadows: bool = true) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		gi.set_meta("vis", d)
		gi.visibility_range_end = d * _view_mult
		if not shadows:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_vis_nodes.append(gi)
	for c in n.get_children():
		_limit_vis(c, d, shadows)

func _apply_view_distance() -> void:
	var alive: Array = []
	for gi in _vis_nodes:
		if is_instance_valid(gi):
			gi.visibility_range_end = float(gi.get_meta("vis")) * _view_mult
			alive.append(gi)
	_vis_nodes = alive

func _add_static_cylinder(pos: Vector3, radius: float, height: float) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	sb.add_child(cs)
	sb.position = Vector3(pos.x, height / 2.0, pos.z)
	add_child(sb)

func _add_static_box(pos: Vector3, size: Vector3, yaw: float) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = Vector3(pos.x, size.y / 2.0, pos.z)
	sb.rotation.y = yaw
	add_child(sb)

func _build_path() -> void:
	var pts := PackedVector2Array()
	for zone in GameData.ZONES:
		var c: Vector3 = zone["center"]
		var start := Vector2(0.0, 5.0)
		var goal := Vector2(c.x, c.z)
		var n: int = maxi(2, int(start.distance_to(goal) / 1.3))
		var dir: Vector2 = (goal - start).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var phase: float = rng.randf_range(0.0, TAU)
		for i in n + 1:
			var t: float = float(i) / float(n)
			var wob: float = sin(t * PI * 3.0 + phase) * 3.5 * sin(t * PI)
			pts.append(start.lerp(goal, t) + perp * wob)
	path_pts = pts
	var disc := CylinderMesh.new()
	disc.top_radius = 1.3
	disc.bottom_radius = 1.3
	disc.height = 0.05
	disc.radial_segments = 8
	disc.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = disc
	mm.instance_count = pts.size()
	for i in pts.size():
		var b := Basis.from_scale(Vector3(rng.randf_range(0.9, 1.25), 1.0, rng.randf_range(0.9, 1.25)))
		mm.set_instance_transform(i, Transform3D(b, Vector3(pts[i].x, 0.025, pts[i].y)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.38, 0.24)
	mi.material_override = mat
	add_child(mi)

func _build_mud() -> void:
	for zone in GameData.ZONES:
		if not zone.get("mud", false):
			continue
		var c: Vector3 = zone["center"]
		for i in 9:
			var ang: float = rng.randf_range(0.0, TAU)
			var dist: float = rng.randf_range(2.0, float(zone["radius"]) * 0.75)
			var p := Vector2(c.x, c.z) + Vector2(cos(ang), sin(ang)) * dist
			var r: float = rng.randf_range(2.5, 4.5)
			if _path_dist(p) < r + 1.0:
				continue
			mud.append({"p": p, "r": r})
			var m := CylinderMesh.new()
			m.top_radius = r
			m.bottom_radius = r
			m.height = 0.04
			m.radial_segments = 16
			m.rings = 1
			var mi := _mesh(m, Color(0.28, 0.2, 0.12))
			mi.position = Vector3(p.x, 0.03, p.y)
			add_child(mi)

func _make_tree(pos: Vector3, collide: bool) -> void:
	var model: Node3D = Models.make("arbre", rng.randf_range(5.0, 8.0))
	if model != null:
		model.position = pos
		model.rotation.y = rng.randf_range(0.0, TAU)
		_limit_vis(model, 95.0)
		add_child(model)
	else:
		var tree := Node3D.new()
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.3
		trunk.bottom_radius = 0.4
		trunk.height = 3.0
		var t_mi := MeshInstance3D.new()
		t_mi.mesh = trunk
		t_mi.material_override = _trunk_mat
		t_mi.position.y = 1.5
		tree.add_child(t_mi)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.8
		cone.height = 5.0
		var c_mi := MeshInstance3D.new()
		c_mi.mesh = cone
		c_mi.material_override = foliage_mat
		c_mi.position.y = 5.0
		tree.add_child(c_mi)
		var cone2 := CylinderMesh.new()
		cone2.top_radius = 0.0
		cone2.bottom_radius = 1.3
		cone2.height = 3.5
		var c2 := MeshInstance3D.new()
		c2.mesh = cone2
		c2.material_override = foliage_mat
		c2.position.y = 7.2
		tree.add_child(c2)
		tree.position = pos
		tree.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		_limit_vis(tree, 95.0)
		add_child(tree)
	if collide:
		_add_static_cylinder(pos, 0.6, 4.0)

func _scatter_trees() -> void:
	for i in 110:
		var sp = _free_spot(0.8, 16.0, 3.2)
		if sp == null:
			continue
		var p: Vector2 = sp
		obstacles.append({"p": p, "r": 0.8})
		_make_tree(Vector3(p.x, 0.0, p.y), true)
	for i in 50:
		var side: int = rng.randi() % 4
		var along: float = rng.randf_range(-GameData.AREA - 12.0, GameData.AREA + 12.0)
		var off: float = rng.randf_range(GameData.AREA + 1.0, GameData.AREA + 12.0)
		var pos := Vector3(along, 0.0, off)
		match side:
			1:
				pos = Vector3(along, 0.0, -off)
			2:
				pos = Vector3(off, 0.0, along)
			3:
				pos = Vector3(-off, 0.0, along)
		_make_tree(pos, false)

func _scatter_obstacles() -> void:
	# Rochers (utilisent rocher.glb, sinon caillou.glb agrandi, sinon une forme simple)
	for i in 45:
		var rr: float = rng.randf_range(1.0, 2.0)
		var sp = _free_spot(rr, 9.0, 2.8)
		if sp == null:
			continue
		var p: Vector2 = sp
		obstacles.append({"p": p, "r": rr})
		var model: Node3D = Models.make("rocher", rr * 2.0)
		if model == null:
			model = Models.make("caillou", rr * 2.0)
		if model != null:
			model.position = Vector3(p.x, 0.0, p.y)
			model.rotation.y = rng.randf_range(0.0, TAU)
			_limit_vis(model, 95.0)
			add_child(model)
		else:
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 2.0
			var mi := _mesh(sm, Color(0.5, 0.5, 0.48).lerp(Color.WHITE, rng.randf_range(0.0, 0.2)))
			mi.scale = Vector3(rr, rr * 0.8, rr * rng.randf_range(0.8, 1.1))
			mi.position = Vector3(p.x, rr * 0.35, p.y)
			mi.rotation.y = rng.randf_range(0.0, TAU)
			_limit_vis(mi, 95.0)
			add_child(mi)
		_add_static_cylinder(Vector3(p.x, 0.0, p.y), rr * 0.9, 3.0)
	# Troncs tombés
	for i in 30:
		var log_len: float = rng.randf_range(3.5, 6.0)
		var sp = _free_spot(log_len * 0.5, 9.0, 2.8)
		if sp == null:
			continue
		var p: Vector2 = sp
		obstacles.append({"p": p, "r": log_len * 0.5})
		var yaw: float = rng.randf_range(0.0, PI)
		var holder := Node3D.new()
		holder.position = Vector3(p.x, 0.0, p.y)
		holder.rotation.y = yaw
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.42
		cyl.bottom_radius = 0.46
		cyl.height = log_len
		var lm := _mesh(cyl, Color(0.4, 0.28, 0.15))
		lm.rotation.z = PI / 2.0
		lm.position.y = 0.45
		holder.add_child(lm)
		_limit_vis(holder, 95.0)
		add_child(holder)
		_add_static_box(Vector3(p.x, 0.0, p.y), Vector3(log_len, 1.0, 0.9), yaw)
	# Fourrés d'épines
	for i in 30:
		var sp = _free_spot(1.8, 9.0, 2.8)
		if sp == null:
			continue
		var p: Vector2 = sp
		obstacles.append({"p": p, "r": 1.8})
		var holder := Node3D.new()
		holder.position = Vector3(p.x, 0.0, p.y)
		for k in 6:
			var bs := SphereMesh.new()
			var br: float = rng.randf_range(0.55, 0.95)
			bs.radius = br
			bs.height = br * 2.0
			var bm := _mesh(bs, Color(0.16, 0.34, 0.15).lerp(Color(0.1, 0.22, 0.1), rng.randf()))
			bm.position = Vector3(rng.randf_range(-1.0, 1.0), br * 0.8, rng.randf_range(-1.0, 1.0))
			holder.add_child(bm)
		_limit_vis(holder, 95.0)
		add_child(holder)
		_add_static_cylinder(Vector3(p.x, 0.0, p.y), 1.7, 2.0)

func _build_flowers() -> void:
	var palette := [Color("ff6b9d"), Color("ffd23f"), Color.WHITE, Color("c77dff")]
	for i in 400:
		var fm := SphereMesh.new()
		fm.radius = 0.09
		fm.height = 0.18
		var f := _mesh(fm, palette[i % 4])
		f.position = Vector3(rng.randf_range(-GameData.AREA + 2.0, GameData.AREA - 2.0), 0.1, rng.randf_range(-GameData.AREA + 2.0, GameData.AREA - 2.0))
		f.visible = false
		_limit_vis(f, 60.0)
		add_child(f)
		flowers.append(f)

func _pick_cat(p: Vector2) -> int:
	var w: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	if p.length() > GameData.CAMP_RADIUS:
		var best = null
		var bd: float = 1e9
		for zone in GameData.ZONES:
			var c: Vector3 = zone["center"]
			var d: float = p.distance_to(Vector2(c.x, c.z))
			if d < float(zone["radius"]) and d < bd:
				bd = d
				best = zone
		if best != null:
			w = best["weights"]
	var total: float = 0.0
	for x in w:
		total += float(x)
	var roll: float = rng.randf() * total
	for i in w.size():
		roll -= float(w[i])
		if roll <= 0.0:
			return i
	return 0

func _zone_name(p: Vector2) -> String:
	if p.length() <= GameData.CAMP_RADIUS:
		return "Clairière du camp"
	var best_name := "Sous-bois"
	var bd: float = 1e9
	for zone in GameData.ZONES:
		var c: Vector3 = zone["center"]
		var d: float = p.distance_to(Vector2(c.x, c.z))
		if d < float(zone["radius"]) and d < bd:
			bd = d
			best_name = str(zone["name"])
	return best_name

func _spawn_items() -> void:
	var lim: float = GameData.AREA - 1.5
	for i in GameData.TOTAL:
		var pos := Vector2.ZERO
		for _t in 40:
			var roll: float = rng.randf()
			if roll < 0.25:
				var a: float = rng.randf_range(0.0, TAU)
				var d: float = rng.randf_range(4.0, 16.0)
				pos = Vector2(cos(a), sin(a)) * d
			elif roll < 0.7:
				var zone = GameData.ZONES[rng.randi() % GameData.ZONES.size()]
				var zc: Vector3 = zone["center"]
				pos = Vector2(zc.x, zc.z) + Vector2(rng.randfn(0.0, 9.0), rng.randfn(0.0, 9.0))
			else:
				pos = Vector2(rng.randf_range(-lim, lim), rng.randf_range(-lim, lim))
			pos = Vector2(clampf(pos.x, -lim, lim), clampf(pos.y, -lim, lim))
			if pos.length() > 4.0 and not _in_stream(pos.x) and not _blocked(pos, 0.4):
				break
		var cat: int = _pick_cat(pos)
		var rot: float = rng.randf_range(0.0, TAU)
		_place_item(pos, cat, GameData.CATS[cat]["items"][rng.randi() % 3], rot)

func _place_item(pos: Vector2, cat: int, item_name: String, rot: float) -> void:
	var o: Node3D = _make_item(cat)
	o.position += Vector3(pos.x, 0.0, pos.y)
	o.rotation.y = rot
	o.set_meta("cat", cat)
	o.set_meta("rest_y", o.position.y)
	o.set_meta("item_name", item_name)
	_limit_vis(o, 75.0, false)   # pas d'ombre pour les petits objets : 3000 objets restent fluides
	add_child(o)
	items.append(o)

func recall() -> void:
	if mode != "play":
		return
	if recall_cd > 0.0:
		_say("Retour au camp disponible dans %d s" % ceili(recall_cd))
		return
	player.position = (placed["table"] as Node3D).to_global(Vector3(0, 0, 3.0)) if placed.has("table") else Vector3(0.0, 0.0, 3.0)
	player.position.y = 0.0
	recall_cd = 25.0
	_play("pick")
	_say("De retour au camp")

func _build_extra_hud(layer: CanvasLayer) -> void:
	hud_zone = _label(layer)
	hud_zone.anchor_left = 0.0
	hud_zone.anchor_right = 1.0
	hud_zone.offset_top = 10.0
	hud_zone.offset_bottom = 40.0
	hud_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimap = Minimap.new()
	minimap.main = self
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -186.0
	minimap.offset_right = -16.0
	minimap.offset_top = 16.0
	minimap.offset_bottom = 186.0
	layer.add_child(minimap)
	hud_recall = _label(layer)
	hud_recall.anchor_left = 1.0
	hud_recall.anchor_right = 1.0
	hud_recall.offset_left = -220.0
	hud_recall.offset_right = -16.0
	hud_recall.offset_top = 192.0
	hud_recall.offset_bottom = 214.0
	hud_recall.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_recall.add_theme_font_size_override("font_size", 13)
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.timeout.connect(minimap.queue_redraw)
	add_child(t)


# ---------- Seaux et LaMachineQuiRestoreLaForêtator ----------
func _bucket_cap() -> int:
	return GameData.BUCKET_CAP_XXL if up["seau"] else GameData.BUCKET_CAP

func _product(c: int) -> String:
	return GameData.CATS[c]["product"]

## Touche « interagir » : verser dans la machine, prendre un seau, ou ouvrir la table de tri.
func on_interact() -> void:
	if mode != "play":
		return
	var rec := _aim_receptacle()
	if rec >= 0:
		_pour(rec)
		return
	var bk := _aim_bucket()
	if bk >= 0:
		_take_bucket(bk)
		return
	if _aim_sawmill():
		_load_sawmill()
		return
	try_open_sort()

## Index du point visé par la caméra (dans la portée), ou -1.
func _aim(points: Array, reach: float) -> int:
	var origin := player.cam.global_position
	var f := -player.cam.global_transform.basis.z
	var best := -1
	var bs := 9.0
	for i in points.size():
		var w: Vector3 = points[i] - origin
		var t := w.dot(f)
		if t < 0.3 or t > reach:
			continue
		var pp := (w - f * t).length()
		if pp < 0.5 and pp + t * 0.03 < bs:
			bs = pp + t * 0.03
			best = i
	return best

func _aim_receptacle() -> int:
	if machine == null:
		return -1
	var pts: Array = []
	for i in GameData.CATS.size():
		pts.append(machine.receptacle_point(i))
	return _aim(pts, GameData.REACH_MACHINE)

func _aim_bucket() -> int:
	if rack == null:
		return -1
	var pts: Array = []
	for i in GameData.CATS.size():
		pts.append(rack.point(i))
	return _aim(pts, 3.5)

func _take_bucket(i: int) -> void:
	if not carried.is_empty():
		_play("bad")
		_say("Tu portes déjà un seau de %s : vide-le d'abord dans %s" % [_product(carried["cat"]), GameData.MACHINE_NAME])
		return
	if bin_fill[i] == 0:
		_say("Le seau « %s » est vide : trie des %s à la table" % [_product(i), String(GameData.CATS[i]["name"]).to_lower()])
		return
	carried = {"cat": i, "amount": bin_fill[i]}
	bin_fill[i] = 0
	_play("pick")
	_refresh_buckets()
	if machine == null:
		_say("🪣 Seau de %s (%d) : pose maintenant %s (%s, onglet Essentiel)" % [_product(i), carried["amount"], GameData.MACHINE_NAME, Settings.key_name("build_menu")])
	else:
		_say("🪣 Seau de %s (%d) : apporte-le à %s !" % [_product(i), carried["amount"], GameData.MACHINE_NAME])

func _pour(r: int) -> void:
	if carried.is_empty():
		_say("Il te faut un seau de %s : prends-le devant la table de tri" % _product(r))
		return
	var c: int = carried["cat"]
	if c != r:
		_play("bad")
		machine.shake(r)
		_say("❌ Mauvais réceptacle ! Celui-ci accepte « %s », ton seau contient « %s »." % [_product(r), _product(c)])
		return
	var n: int = carried["amount"]
	delivered += n
	carried = {}
	_play("pour")
	_play("machine")
	machine.puff(GameData.CATS[c]["color"])
	_refresh_buckets()
	_restore()
	if delivered >= GameData.TOTAL and _pct() < 1.0:
		_say("Tout est passé dans la machine ! Termine les chantiers pour restaurer la clairière.")
	else:
		_say("✅ %d × %s versés dans %s : la forêt se restaure !" % [n, _product(c), GameData.MACHINE_NAME])

## Met à jour les seaux devant la table, le seau en main et la ligne du HUD.
func _refresh_buckets() -> void:
	if rack != null:
		rack.update_fill(bin_fill, _bucket_cap())
	if carry_node != null:
		carry_node.queue_free()
		carry_node = null
	if carried.is_empty():
		hud_bucket.text = ""
		return
	var c: int = carried["cat"]
	carry_node = BucketRack.make_bucket(GameData.CATS[c]["color"])
	BucketRack.set_level(carry_node, float(carried["amount"]) / float(_bucket_cap()))
	carry_node.position = Vector3(-0.62, -0.55, -1.15)
	carry_node.rotation = Vector3(0.1, 0.5, 0.0)
	carry_node.scale = Vector3.ONE * 0.75
	player.cam.add_child(carry_node)
	hud_bucket.text = "🪣 Seau en main : %d × %s → %s" % [carried["amount"], _product(c), GameData.MACHINE_NAME]


# ---------- Constructions : menu Tab, placement libre ----------
func _def(key: String) -> Dictionary:
	for d in GameData.BUILDINGS + GameData.PROJECTS:
		if d["key"] == key:
			return d
	return GameData.CHALET if key == "chalet" else {}

func _make_building(key: String) -> Node3D:
	match key:
		"table":
			return _make_table()
		"machine":
			return Machine.new()
		"scierie":
			return Sawmill.new()
		"chalet":
			return Chalet.new()
	return _make_project(key)

## Crée une construction réelle à sa place (pose, chargement d'une partie).
func _spawn_building(key: String, pos: Vector3, yaw: float) -> Node3D:
	var d := _def(key)
	if d.is_empty() or placed.has(key):
		return null
	var n := _make_building(key)
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	placed[key] = n
	_set_obstacle(key, pos)
	match key:
		"table":
			rack = n.get_node("Rack")
			_refresh_buckets()
		"machine":
			machine = n
			machine.set_display("Restauration : %d %%" % roundi(_pct() * 100.0))
		"scierie":
			sawmill = n
			sawmill.produced.connect(_on_planks)
			sawmill.set_info(planks)
		"chalet":
			chalet = n
			chalet.set_furniture(furniture)
		"mangeoire":
			_spawn_helper("fox")
	return n

func _set_obstacle(key: String, pos: Vector3) -> void:
	obstacles = obstacles.filter(func(o): return o.get("key", "") != key)
	obstacles.append({"p": Vector2(pos.x, pos.z), "r": float(_def(key)["foot"]), "key": key})

func _can_pay(cost: Dictionary) -> bool:
	for k in cost:
		if (planks if k is String else stock[k]) < int(cost[k]):
			return false
	return true

func _pay(cost: Dictionary) -> void:
	for k in cost:
		if k is String:
			planks -= int(cost[k])
		else:
			stock[k] -= int(cost[k])
	if sawmill != null:
		sawmill.set_info(planks)

func _near_table() -> bool:
	if not placed.has("table"):
		return false
	var t: Vector3 = (placed["table"] as Node3D).global_position
	return Vector2(player.global_position.x - t.x, player.global_position.z - t.z).length() < GameData.TABLE_RADIUS

## Là où les écureuils déposent leurs trouvailles (devant la table).
func table_drop_point() -> Vector3:
	if not placed.has("table"):
		return Vector3(0, 0, 1.4)
	var p := (placed["table"] as Node3D).to_global(Vector3(0, 0, 1.4))
	return Vector3(p.x, 0.0, p.z)

## Repères de la mini-carte : [position, couleur, demi-taille].
func map_marks() -> Array:
	var style := {
		"table": [Color(0.95, 0.75, 0.3), Vector2(4, 4)],
		"machine": [Color(0.45, 1.0, 0.55), Vector2(6, 3)],
		"scierie": [Color(0.8, 0.55, 0.3), Vector2(4, 3)],
		"chalet": [Color(0.95, 0.45, 0.35), Vector2(6, 6)],
	}
	var out: Array = []
	for k in placed:
		var n: Node3D = placed[k]
		var s: Array = style.get(k, [Color(0.85, 0.85, 0.85, 0.8), Vector2(2.5, 2.5)])
		out.append([n.global_position, s[0], s[1]])
	return out

func _build_state() -> Dictionary:
	return {"stock": stock, "planks": planks, "placed": placed, "proj": proj, "furniture": furniture}

func open_build_menu() -> void:
	if mode != "play":
		return
	mode = "menu"
	menu_frame = Engine.get_process_frames()
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	build_menu.open(_build_state())

func _close_build_menu() -> void:
	if mode != "menu":
		return
	mode = "play"
	build_menu.visible = false
	player.enabled = true
	player.grab()

## Bouton « Placer » / « Déplacer » du menu : on passe en mode placement avec un fantôme.
func start_placing(key: String) -> void:
	var d := _def(key)
	if d.is_empty():
		return
	if not placed.has(key) and not _can_pay(d["cost"]):
		_play("bad")
		return
	_close_build_menu()
	ghost_key = key
	ghost_rot = 0.0
	ghost = _make_building(key)
	add_child(ghost)
	_ghostify(ghost)
	if placed.has(key):
		(placed[key] as Node3D).visible = false
	mode = "place"
	_update_ghost()

## Rend une construction translucide et sans collision (fantôme de placement).
func _ghostify(n: Node3D) -> void:
	n.set_process(false)
	for c in n.find_children("*", "", true, false):
		if c is CollisionObject3D or c is Light3D:
			c.queue_free()
		elif c is Label3D:
			c.visible = false
		elif c is GeometryInstance3D:
			(c as GeometryInstance3D).material_override = ghost_mat
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _place_input(event: InputEvent) -> void:
	var cancel: bool = event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("build_menu")
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				cancel = true
			MOUSE_BUTTON_WHEEL_UP:
				ghost_rot += PI / 12.0
			MOUSE_BUTTON_WHEEL_DOWN:
				ghost_rot -= PI / 12.0
	if cancel:
		get_viewport().set_input_as_handled()
		_end_place(false)

## Le fantôme suit le regard du joueur ; vert = on peut poser, rouge = impossible (raison affichée).
func _update_ghost() -> void:
	if ghost == null:
		return
	var r: float = _def(ghost_key)["foot"]
	var o := player.cam.global_position
	var f := -player.cam.global_transform.basis.z
	var fwd := Vector3(f.x, 0.0, f.z)
	fwd = fwd.normalized() if fwd.length() > 0.01 else -player.global_transform.basis.z
	var dist := r + 9.0
	if f.y < -0.02:
		var hit := o + f * (-o.y / f.y)
		dist = Vector2(hit.x - o.x, hit.z - o.z).length()
	dist = clampf(dist, r + 1.2, r + 9.0)
	var p := player.global_position + fwd * dist
	p.y = 0.0
	var yaw := player.yaw + ghost_rot
	ghost_err = ""
	if ghost_key == "pont":
		if absf(p.x - 10.3) > 6.0:
			ghost_err = "Le pont se pose sur le ruisseau : approche-toi de l'eau"
		p.x = 10.3
		yaw = 0.0
	if ghost_err == "":
		ghost_err = _place_error(ghost_key, p, r)
	ghost.position = p
	ghost.rotation.y = yaw
	ghost_mat.albedo_color = Color(0.35, 1.0, 0.45, 0.4) if ghost_err == "" else Color(1.0, 0.3, 0.25, 0.4)
	var nm: String = _def(ghost_key)["name"]
	if ghost_err == "":
		hud_prompt.text = "Clic / %s : poser %s · Molette : tourner · Clic droit : annuler" % [_k_pick, nm]
	else:
		hud_prompt.text = "❌ %s · Clic droit : annuler" % ghost_err

func _place_error(key: String, p: Vector3, r: float) -> String:
	var lim := GameData.AREA - r
	if absf(p.x) > lim or absf(p.z) > lim:
		return "Trop près du bord de la forêt"
	if key != "pont" and absf(p.x - 10.3) < 1.5 + r:
		return "Impossible de construire dans le ruisseau"
	var p2 := Vector2(p.x, p.z)
	for ob in obstacles:
		if ob.get("key", "") == key:
			continue
		if p2.distance_to(ob["p"]) < float(ob["r"]) + r:
			if ob.has("key"):
				return "Trop près de : %s" % _def(ob["key"])["name"]
			return "Quelque chose gêne (arbre, rocher, tronc…)"
	return ""

func _confirm_place() -> void:
	if ghost == null:
		return
	if ghost_err != "":
		_play("bad")
		_say("❌ " + ghost_err)
		return
	var key := ghost_key
	var p := ghost.position
	var yaw := ghost.rotation.y
	var d := _def(key)
	var moved := placed.has(key)
	if not moved and not _can_pay(d["cost"]):
		_end_place(false)
		_say("Pas assez de ressources pour %s" % d["name"])
		return
	_end_place(true)
	if moved:
		var n: Node3D = placed[key]
		n.position = p
		n.rotation.y = yaw
		n.visible = true
		_set_obstacle(key, p)
		_say("%s déplacé(e)" % d["name"])
	else:
		_pay(d["cost"])
		_spawn_building(key, p, yaw)
		if proj.has(key):
			proj[key] = true
			_say("Chantier terminé : %s" % d["name"])
		elif key == "chalet":
			_say("🏡 Ton chalet est construit ! Meuble-le depuis l'onglet Chalet (%s)." % Settings.key_name("build_menu"))
		else:
			_say("Construit : %s" % d["name"])
	_clear_items_at(p, float(d["foot"]))
	_play("buy")
	_restore()

func _end_place(_ok: bool) -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if not _ok and placed.has(ghost_key):
		(placed[ghost_key] as Node3D).visible = true   # déplacement annulé : on la remontre
	mode = "play"
	hud_prompt.text = ""
	player.grab()

## Les objets qui se trouvent sous une nouvelle construction sont poussés juste à côté.
func _clear_items_at(p: Vector3, r: float) -> void:
	for o in items:
		if o.get_meta("busy", false):
			continue
		var dv := Vector2(o.global_position.x - p.x, o.global_position.z - p.z)
		if dv.length() < r:
			var dir := dv.normalized() if dv.length() > 0.01 else Vector2(1, 0)
			var np := Vector2(p.x, p.z) + dir * (r + 0.4)
			o.global_position = Vector3(np.x, o.global_position.y, np.y)

# ---------- Scierie et chalet ----------
func _aim_sawmill() -> bool:
	return sawmill != null and _aim([sawmill.hopper_point()], 3.5) == 0

func _load_sawmill() -> void:
	var n: int = stock[1]
	if n == 0:
		_say("Pas de bûches : trie du bois à la table (bac Bois)")
		return
	stock[1] = 0
	sawmill.add_logs(n)
	sawmill.set_info(planks)
	_play("plop")
	_say("🪵 %d bûche(s) chargée(s) : la scierie les découpe en planches" % n)
	_update_hud()

func _on_planks(n: int) -> void:
	planks += n
	sawmill.set_info(planks)
	_play("saw")
	_update_hud()
	if mode == "menu":
		build_menu.refresh(_build_state())

func build_furniture(key: String) -> void:
	if chalet == null or furniture.get(key, false):
		return
	for f in GameData.FURNITURE:
		if f["key"] != key:
			continue
		if not _can_pay(f["cost"]):
			_play("bad")
			return
		_pay(f["cost"])
		furniture[key] = true
		chalet.set_furniture(furniture, key)
		_play("buy")
		if furniture.size() >= GameData.FURNITURE.size():
			_say("🏡 Ton chalet est entièrement meublé ! La forêt est rangée : tu peux t'y installer.")
		else:
			_say("🪑 %s construit(e) dans le chalet (%d/%d meubles)" % [f["name"], furniture.size(), GameData.FURNITURE.size()])
	build_menu.refresh(_build_state())
	_update_hud()

# ---------- Tutoriel (nouvelle partie) ----------
func _build_tuto(layer: CanvasLayer) -> void:
	tuto_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.1, 0.07, 0.85)
	sb.border_color = UiTheme.ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	tuto_panel.add_theme_stylebox_override("panel", sb)
	tuto_panel.position = Vector2(16, 226)
	tuto_panel.custom_minimum_size = Vector2(380, 0)
	tuto_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tuto_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	tuto_panel.add_child(vb)
	tuto_title = Label.new()
	tuto_title.add_theme_font_size_override("font_size", 17)
	tuto_title.add_theme_color_override("font_color", UiTheme.ACCENT)
	vb.add_child(tuto_title)
	tuto_label = Label.new()
	tuto_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tuto_label.custom_minimum_size = Vector2(356, 0)
	tuto_label.add_theme_font_size_override("font_size", 15)
	vb.add_child(tuto_label)
	var skip := Label.new()
	skip.text = "F1 : passer le tutoriel"
	skip.add_theme_font_size_override("font_size", 12)
	skip.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(skip)

func _tuto_text(step: int) -> Array:
	var kb := Settings.key_name("build_menu")
	match step:
		0:
			return ["Pose ta table de tri", "Ouvre le menu de construction (%s), onglet Essentiel, et place la table de tri où tu veux. Le fantôme est vert quand l'endroit est libre. Clic pour poser, molette pour tourner." % kb]
		1:
			return ["Ramasse des objets", "Ramasse 10 objets dans la forêt (clic ou %s)." % _k_pick]
		2:
			return ["Trie à la table", "Retourne à la table et appuie sur %s : range chaque objet dans le bon bac (touches 1 à 6). Trie-en au moins 5." % _k_interact]
		3:
			return ["Pose la machine", "Ouvre le menu (%s) et place %s. Pas trop loin de la table : tu y feras des allers-retours !" % [kb, GameData.MACHINE_NAME]]
		4:
			return ["Prends un seau", "Devant la table, chaque bac remplit un seau de son produit. Vise un seau qui n'est pas vide et appuie sur %s." % _k_interact]
		5:
			return ["Verse-le dans la machine", "Apporte le seau à la machine et vise le réceptacle de son produit (%s). Le mauvais réceptacle le refuse !" % _k_interact]
	return ["", ""]

func _tuto_done(step: int) -> bool:
	match step:
		0:
			return placed.has("table")
		1:
			return collected >= 10 or sorted > 0
		2:
			return sorted >= 5 or (sorted > 0 and bag.is_empty() and table.is_empty())
		3:
			return placed.has("machine")
		4:
			return not carried.is_empty() or delivered > 0
		5:
			return delivered > 0
	return true

func _tuto_check() -> void:
	if tuto_step >= TUTO_DONE:
		return
	if not _tuto_done(tuto_step):
		return
	while tuto_step < TUTO_DONE and _tuto_done(tuto_step):
		tuto_step += 1
	_play("buy")
	_refresh_tuto()
	if tuto_step >= TUTO_DONE:
		_tuto_finished()

func _tuto_finished() -> void:
	tuto_title.text = "🎉 Tutoriel terminé !"
	tuto_label.text = "Continue de ramasser, trier et verser pour restaurer la forêt. Ensuite : construis la Scierie (%s, Essentiel), charge-y tes bûches (%s) et bâtis ton chalet dans l'onglet Chalet." % [Settings.key_name("build_menu"), _k_interact]
	tuto_panel.visible = true
	await get_tree().create_timer(14.0).timeout
	if tuto_step >= TUTO_DONE:
		tuto_panel.visible = false

func _refresh_tuto() -> void:
	if tuto_panel == null:
		return
	if tuto_step >= TUTO_DONE:
		tuto_panel.visible = false
		return
	var t: Array = _tuto_text(tuto_step)
	tuto_panel.visible = true
	tuto_title.text = "📘 Tutoriel – étape %d/%d : %s" % [tuto_step + 1, TUTO_DONE, t[0]]
	tuto_label.text = t[1]


# ---------- Options (Settings.changed) ----------
func _apply_settings() -> void:
	var g: Dictionary = Settings.data["graphics"]
	env.ssao_enabled = g["ssao"]
	env.glow_enabled = g["glow"]
	env.fog_enabled = g["fog"]
	env.adjustment_enabled = true
	env.adjustment_brightness = float(g["brightness"])
	var sh: int = int(g["shadows"])
	sun.shadow_enabled = sh > 0
	if sh > 0:
		RenderingServer.directional_shadow_atlas_set_size([2048, 2048, 4096, 8192][sh], true)
		sun.directional_shadow_max_distance = [60.0, 40.0, 60.0, 90.0][sh]
	player.base_fov = float(g["fov"])
	player.sens_mult = float(Settings.data["controls"]["sensitivity"])
	player.invert_y = bool(Settings.data["controls"]["invert_y"])
	minimap.visible = bool(Settings.data["game"]["minimap"])
	var vd := float(g["view_distance"])
	if not is_equal_approx(vd, _view_mult):
		_view_mult = vd
		_apply_view_distance()
	_restore_grass()
	_k_pick = Settings.key_name("pick")
	_k_interact = Settings.key_name("interact")
	_k_recall = Settings.key_name("recall")
	_k_edge = Settings.key_name("edge_mode")
	hud_stamina_lbl.text = "Endurance (%s)" % Settings.key_name("sprint")
	if tuto_step < TUTO_DONE:
		_refresh_tuto()   # les touches citées dans le tutoriel suivent les Options

func _restore_grass() -> void:
	if grass_mm == null:
		return
	var grow := clampf((_pct() - 0.1) / 0.9, 0.0, 1.0)
	grass_mm.visible_instance_count = int(grow * grass_mm.instance_count * float(Settings.data["graphics"]["grass"]))

## Appelée par le menu pause quand on reprend la partie.
func resume_play() -> void:
	if mode == "play":
		player.grab()

# ---------- Sauvegarde ----------
func save_game(auto: bool = false) -> bool:
	var ok := SaveGame.write(save_data())
	if auto and ok:
		_say("💾 Sauvegarde automatique")
	return ok

func save_data() -> Dictionary:
	var its: Array = []
	for o in items:
		its.append([o.global_position.x, o.global_position.z, o.rotation.y, o.get_meta("cat"), o.get_meta("item_name")])
	# Ce que portent les écureuils retourne sur la table : rien n'est perdu
	var tbl: Array = table.duplicate(true)
	for h in helpers:
		if is_instance_valid(h) and h.info != null:
			tbl.append(h.info)
	var pl := {}
	for k in placed:
		var n: Node3D = placed[k]
		pl[k] = [n.position.x, n.position.z, n.rotation.y]
	return {
		"seed": world_seed,
		"time": Time.get_datetime_dict_from_system(),
		"items": its,
		"bag": bag.duplicate(true),
		"table": tbl,
		"cap": cap, "res": res, "sorted": sorted, "collected": collected,
		"up": up.duplicate(), "lv": lv.duplicate(), "proj": proj.duplicate(), "stock": stock.duplicate(),
		"cur_tool": cur_tool, "tools_msg": tools_msg, "animals_spawned": animals_spawned, "finished": finished,
		"player": [player.position, player.yaw, player.pitch, player.stamina, player.edge_mode],
		"recall_cd": recall_cd,
		"bin_fill": bin_fill.duplicate(), "carried": carried.duplicate(), "delivered": delivered,
		"placed": pl, "planks": planks, "furniture": furniture.duplicate(),
		"sawmill_queue": sawmill.queue if sawmill != null else 0, "tuto": tuto_step,
	}

func _apply_save(s: Dictionary) -> void:
	for it in s.get("items", []):
		_place_item(Vector2(float(it[0]), float(it[1])), int(it[3]), str(it[4]), float(it[2]))
	bag = s.get("bag", [])
	table = s.get("table", [])
	cap = int(s.get("cap", cap))
	res = int(s.get("res", 0))
	sorted = int(s.get("sorted", 0))
	collected = int(s.get("collected", 0))
	# Anciennes sauvegardes (avant la machine) : ce qui était trié compte comme déjà versé
	delivered = int(s.get("delivered", sorted))
	var bf: Array = s.get("bin_fill", [])
	for i in mini(bf.size(), bin_fill.size()):
		bin_fill[i] = int(bf[i])
	carried = s.get("carried", {})
	var su: Dictionary = s.get("up", {})
	for k in su:
		if up.has(k):
			up[k] = bool(su[k])
	var sl: Dictionary = s.get("lv", {})
	for k in sl:
		lv[k] = int(sl[k])
	var sp: Dictionary = s.get("proj", {})
	for k in sp:
		if proj.has(k):
			proj[k] = bool(sp[k])
	var st: Array = s.get("stock", [])
	for i in mini(st.size(), stock.size()):
		stock[i] = int(st[i])
	planks = int(s.get("planks", 0))
	furniture = s.get("furniture", {})
	# Constructions posées. Anciennes sauvegardes : tout était à une place fixe, on les y remet.
	if s.has("placed"):
		var pl: Dictionary = s["placed"]
		for k in pl:
			var a: Array = pl[k]
			_spawn_building(k, Vector3(float(a[0]), 0.0, float(a[1])), float(a[2]))
		tuto_step = int(s.get("tuto", TUTO_DONE))
	else:
		_spawn_building("table", GameData.LEGACY_POS["table"], 0.0)
		_spawn_building("machine", GameData.LEGACY_POS["machine"], 0.0)
		if bool(sp.get("scierie", false)):
			_spawn_building("scierie", GameData.LEGACY_POS["scierie"], 0.0)
		for k in proj:
			if proj[k]:
				_spawn_building(k, GameData.LEGACY_POS[k], 0.0)
		tuto_step = TUTO_DONE
	if sawmill != null:
		sawmill.add_logs(int(s.get("sawmill_queue", 0)))
		sawmill.set_info(planks)
	cur_tool = int(s.get("cur_tool", 0))
	tools_msg = bool(s.get("tools_msg", false))
	finished = bool(s.get("finished", false))
	animals_spawned = bool(s.get("animals_spawned", false))
	recall_cd = float(s.get("recall_cd", 0.0))
	var pl: Array = s.get("player", [])
	if pl.size() >= 5:
		player.position = pl[0]
		player.yaw = float(pl[1])
		player.pitch = float(pl[2])
		player.stamina = float(pl[3])
		player.edge_mode = bool(pl[4])
		player.grab()
	# On reconstruit ce qui a été acheté ou construit
	if up["chariot"]:
		_show_cart()
	for i in lv.get("squirrel", 0):
		_spawn_helper("squirrel")
	for i in lv.get("hedgehog", 0):
		_spawn_helper("hedgehog")
	if lv.get("hedgehog", 0) > 0:
		_show_piles()
	if animals_spawned:
		for k in ["fox", "fox", "deer", "deer"]:
			_spawn_helper(k)
	if not _tool_owned(cur_tool):
		cur_tool = 0
	_refresh_buckets()
	_refresh_hotbar()
	_restore()
	_say("Partie chargée")

func _notification(what: int) -> void:
	# Fermeture de la fenêtre pendant la partie : sauvegarde automatique si l'option est active
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Settings.data["game"]["autosave"]:
		SaveGame.write(save_data())
