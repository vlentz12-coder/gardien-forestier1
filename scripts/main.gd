extends Node3D
## Gardien forestier – prototype : une clairière, 200 objets, 4 catégories.

var rng := RandomNumberGenerator.new()
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
var up := {"rake": false, "pinces": false, "bag": false, "multi": false, "chariot": false, "trieuse": false, "drone": false}
var mode := "play"           # "play" | "sort"

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
	rng.randomize()
	for p in GameData.PROJECTS:
		proj[p["key"]] = false
	_setup_input()
	_build_world()
	_build_player()
	_build_hud()
	_build_sfx()
	sort_ui = SortUI.new()
	add_child(sort_ui)
	sort_ui.bin_chosen.connect(choose_bin)
	sort_ui.bought.connect(buy)
	sort_ui.built.connect(build_project)
	sort_ui.closed.connect(_close_sort)
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
	_restore()

# ---------- Entrées (clavier physique : ZQSD sur AZERTY, WASD sur QWERTY) ----------
func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _setup_input() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("pick", KEY_F)
	_add_key("interact", KEY_E)

func _input(event: InputEvent) -> void:
	if mode == "play":
		_play_input(event)
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

func _build_world() -> void:
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
	var sun := DirectionalLight3D.new()
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

	# Table + 4 bacs
	var tb := BoxMesh.new()
	tb.size = Vector3(3.8, 0.9, 1.1)
	var table_node := _mesh(tb, Color(0.54, 0.35, 0.17))
	table_node.position = Vector3(0, 0.45, 0)
	add_child(table_node)
	for i in GameData.CATS.size():
		var bb := BoxMesh.new()
		bb.size = Vector3(0.5, 0.3, 0.5)
		var bin_node := _mesh(bb, Color(0.62, 0.45, 0.28))
		bin_node.position = Vector3(-1.6 + i * 0.64, 1.05, 0)
		add_child(bin_node)
		var tag := Label3D.new()
		tag.text = GameData.CATS[i]["name"]
		tag.font_size = 48
		tag.pixel_size = 0.0035
		tag.outline_size = 10
		tag.no_depth_test = true
		tag.position = Vector3(-1.6 + i * 0.64, 1.45, 0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(tag)

	foliage_mat = StandardMaterial3D.new()
	_trunk_mat = StandardMaterial3D.new()
	_trunk_mat.albedo_color = Color(0.35, 0.24, 0.13)
	_build_path()
	_build_mud()
	_scatter_trees()
	_scatter_obstacles()
	_build_grass()
	_build_flowers()
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
	player.interact_pressed.connect(try_open_sort)

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
	hud_bar.position = Vector2(16, 118)
	hud_bar.show_percentage = false
	hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_bar.max_value = 100.0
	layer.add_child(hud_bar)
	hud_stamina = ProgressBar.new()
	hud_stamina.custom_minimum_size = Vector2(220, 10)
	hud_stamina.position = Vector2(16, 134)
	hud_stamina.show_percentage = false
	hud_stamina.max_value = 100.0
	hud_stamina.value = 100.0
	hud_stamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_stamina)
	var sl := _label(layer)
	sl.text = "Endurance (Maj)"
	sl.position = Vector2(244, 126)
	sl.add_theme_font_size_override("font_size", 12)
	hud_msg = _label(layer)
	hud_prompt = _label(layer)
	for l in [hud_msg, hud_prompt]:
		l.anchor_left = 0.0
		l.anchor_right = 1.0
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_msg.offset_top = -170
	hud_msg.offset_bottom = -140
	hud_prompt.offset_top = -120
	hud_prompt.offset_bottom = -90
	hud_dbg = _label(layer)
	hud_dbg.position = Vector2(16, 160)
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

func _update_hud() -> void:
	var st := PackedStringArray()
	for i in GameData.CATS.size():
		st.append("%s %d" % [GameData.CATS[i]["use"], stock[i]])
	hud_info.text = "🎒 Sac : %d / %d\n🌿 Ressources : %d  ·  Table : %d\nRestauration : %d %%\n%s" % [
		bag.size(), cap, res, table.size(), roundi(_pct() * 100.0), " · ".join(st)]
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
	hud_recall.text = "R : retour au camp" if recall_cd <= 0.0 else "R : retour au camp (%d s)" % ceili(recall_cd)
	hud_dbg.text = "Souris : %s | mouvements reçus : %d | Tab : mode bords d'écran (%s)" % [
		"capturée" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "libre", player.motion_count, "ON" if player.edge_mode else "off"]
	hud_stamina.value = player.stamina
	hud_stamina.modulate = Color(1, 0.4, 0.3) if player.exhausted else Color(1, 1, 1)
	player.speed_mult = _speed_mult()
	if mode != "play":
		hud_prompt.text = ""
		return
	var near := Vector2(player.global_position.x, player.global_position.z).length() < GameData.TABLE_RADIUS
	if _find_target() != null:
		hud_prompt.text = "Clic / F : ramasser"
	elif near and (bag.size() > 0 or table.size() > 0):
		hud_prompt.text = "E : trier à la table"
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
	}
	for k in defs:
		var d: Array = defs[k]
		var p := AudioStreamPlayer.new()
		p.stream = Sfx.tone(d[0], d[1], d[2], d[3], d[4])
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
	if mode != "play":
		return
	var t = _find_target()
	if t == null:
		return
	if bag.size() >= cap:
		_say("Sac plein ! Retourne à la table (E)")
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
	_play("pick")
	_update_hud()

# ---------- Tri ----------
func try_open_sort() -> void:
	if mode != "play":
		return
	if Vector2(player.global_position.x, player.global_position.z).length() > GameData.TABLE_RADIUS:
		_say("Approche-toi de la table")
		return
	var auto := 0
	if up["trieuse"]:
		auto = int(bag.size() * 0.25)
		for i in auto:
			_gain(bag.pop_front())
		if auto > 0:
			_restore()
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
	if table[0]["cat"] == i:
		_gain(table.pop_front())
		_play("plop")
		_restore()
		if sorted == GameData.TOTAL and _pct() < 1.0:
			_say("Tout est trié ! Termine les chantiers pour restaurer la clairière.")
	else:
		table.append(table.pop_front())
		_play("bad")
		sort_ui.shake()
	sort_ui.refresh(_ui())
	_update_hud()

func buy(key: String) -> void:
	if _pct() < GameData.TOOLS_UNLOCK:
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
	if p >= GameData.TOOLS_UNLOCK and not tools_msg:
		tools_msg = true
		_say("🔧 Outils débloqués à la table de tri !")
	ground_mat.albedo_color = Color(0.48, 0.48, 0.43).lerp(Color(0.31, 0.60, 0.23), p)
	foliage_mat.albedo_color = Color(0.42, 0.42, 0.35).lerp(Color(0.18, 0.49, 0.2), p)
	var sky := Color(0.6, 0.63, 0.63).lerp(Color(0.56, 0.82, 0.94), p)
	sky_mat.sky_top_color = Color(0.45, 0.5, 0.52).lerp(Color(0.25, 0.5, 0.85), p)
	sky_mat.sky_horizon_color = sky
	sky_mat.ground_horizon_color = sky
	sky_mat.ground_bottom_color = sky.darkened(0.3)
	env.fog_light_color = sky
	if grass_mm != null:
		grass_mm.visible_instance_count = int(clampf((p - 0.1) / 0.9, 0.0, 1.0) * grass_mm.instance_count)
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
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_4:
			select_tool(k - KEY_1)
		elif k == KEY_F3:
			hud_dbg.visible = not hud_dbg.visible
		elif k == KEY_R:
			recall()
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
	return 0.7 * float(sorted) / GameData.TOTAL + 0.3 * float(done) / GameData.PROJECTS.size()

func _has(k: String) -> bool:
	return up.get(k, false) or lv.get(k, 0) > 0 or proj.get(k, false)

func _ui() -> Dictionary:
	return {"table": table, "res": res, "up": up, "lv": lv, "proj": proj, "stock": stock, "pct": _pct()}

func _gain(it) -> void:
	var c: int = it["cat"]
	stock[c] += 1
	res += 1
	if c == 0 and proj["composteur"]:
		res += 1
	elif c == 1 and proj["scierie"]:
		res += 1
	elif c == 3 and proj["recyclerie"]:
		res += 2
	sorted += 1

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
	if px > 9.0 and px < 11.6 and not (proj["pont"] and absf(player.position.z) < 1.5):
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

func build_project(key: String) -> void:
	if proj.get(key, false):
		return
	for p in GameData.PROJECTS:
		if p["key"] != key:
			continue
		for c in p["cost"]:
			if stock[c] < p["cost"][c]:
				return
		for c in p["cost"]:
			stock[c] -= p["cost"][c]
		proj[key] = true
		_build_visual(key)
		_play("buy")
		_say("Chantier terminé : %s" % p["name"])
		_restore()
	sort_ui.refresh(_ui())
	_update_hud()

func _build_visual(key: String) -> void:
	var wood := Color(0.55, 0.36, 0.18)
	match key:
		"chemin":
			for i in 14:
				_cyl(0.4, 0.4, 0.05, Color(0.6, 0.6, 0.58), Vector3(rng.randf_range(-0.25, 0.25), 0.03, 2.8 + i * 1.05))
		"nichoir":
			_cyl(0.05, 0.05, 1.6, wood, Vector3(-3.5, 0.8, -3.5))
			_box(Vector3(0.4, 0.35, 0.35), Color(0.7, 0.5, 0.3), Vector3(-3.5, 1.75, -3.5))
			_box(Vector3(0.5, 0.08, 0.45), Color(0.7, 0.2, 0.15), Vector3(-3.5, 1.98, -3.5))
		"pont":
			_box(Vector3(3.2, 0.12, 2.2), wood, Vector3(10.3, 0.1, 0.0))
			_box(Vector3(3.2, 0.5, 0.08), wood, Vector3(10.3, 0.4, 1.1))
			_box(Vector3(3.2, 0.5, 0.08), wood, Vector3(10.3, 0.4, -1.1))
		"composteur":
			_box(Vector3(1.1, 0.7, 1.1), Color(0.25, 0.35, 0.15), Vector3(5.0, 0.35, -2.0))
			_box(Vector3(1.2, 0.1, 1.2), wood, Vector3(5.0, 0.75, -2.0))
		"scierie":
			_box(Vector3(1.6, 0.8, 0.7), wood, Vector3(-5.5, 0.4, -2.5))
			var d := _cyl(0.45, 0.45, 0.05, Color(0.7, 0.7, 0.72), Vector3(-5.5, 0.95, -2.5))
			d.rotation.x = PI / 2.0
		"recyclerie":
			var cols := [Color(0.2, 0.45, 0.85), Color(0.2, 0.65, 0.3), Color(0.9, 0.8, 0.2)]
			for i in 3:
				_box(Vector3(0.7, 0.9, 0.7), cols[i], Vector3(4.0 + i * 0.85, 0.45, 3.5))
		"mangeoire":
			_cyl(0.06, 0.06, 1.0, wood, Vector3(-4.0, 0.5, 3.5))
			_box(Vector3(0.8, 0.08, 0.5), wood, Vector3(-4.0, 1.05, 3.5))
			_spawn_helper("fox")
		"serre":
			var g := _box(Vector3(2.4, 1.6, 2.0), Color(0.7, 0.9, 1.0, 0.35), Vector3(7.0, 0.8, -4.0))
			(g.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for i in 12:
				var a := rng.randf_range(0.0, TAU)
				var r := rng.randf_range(6.0, 9.0)
				var pos := Vector3(cos(a) * r, 0.0, sin(a) * r)
				if pos.x > 8.8:
					pos.x = -pos.x
				_cyl(0.04, 0.06, 0.6, Color(0.35, 0.24, 0.13), pos + Vector3(0, 0.3, 0))
				_cyl(0.0, 0.35, 0.8, Color(0.22, 0.6, 0.25), pos + Vector3(0, 0.95, 0))
		"arbre":
			_cyl(0.5, 0.7, 4.0, Color(0.35, 0.24, 0.13), Vector3(-9.0, 2.0, -9.0))
			var s := SphereMesh.new()
			s.radius = 2.6
			s.height = 5.0
			var crown := _mesh(s, Color(0.2, 0.55, 0.25))
			crown.position = Vector3(-9.0, 5.5, -9.0)
			add_child(crown)

func _show_piles() -> void:
	if has_meta("piles"):
		return
	set_meta("piles", true)
	for p in GameData.PILES:
		_cyl(1.6, 1.6, 0.02, Color(0.4, 0.3, 0.2), Vector3(p.x, 0.012, p.z))

func _spawn_helper(kind: String) -> void:
	var h := Helper.new()
	add_child(h)
	var pos := Vector3(rng.randf_range(-1.5, 1.5), 0, 2.0)
	if kind == "fox" or kind == "deer":
		pos = Vector3(rng.randf_range(-GameData.AREA, GameData.AREA), 0, rng.randf_range(-GameData.AREA, GameData.AREA))
	h.setup(self, kind, pos)

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
	for o in items:
		if o.get_meta("busy", false):
			continue
		if Vector2(o.global_position.x, o.global_position.z).length() > GameData.HELPER_RANGE:
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

func _limit_vis(n: Node, d: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).visibility_range_end = d
	for c in n.get_children():
		_limit_vis(c, d)

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
		var o: Node3D = _make_item(cat)
		o.position += Vector3(pos.x, 0.0, pos.y)
		o.rotation.y = rng.randf_range(0.0, TAU)
		o.set_meta("cat", cat)
		o.set_meta("rest_y", o.position.y)
		o.set_meta("item_name", GameData.CATS[cat]["items"][rng.randi() % 3])
		_limit_vis(o, 75.0)
		add_child(o)
		items.append(o)

func recall() -> void:
	if mode != "play":
		return
	if recall_cd > 0.0:
		_say("Retour au camp disponible dans %d s" % ceili(recall_cd))
		return
	player.position = Vector3(0.0, 0.0, 3.0)
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
