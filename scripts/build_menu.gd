class_name BuildMenu
extends CanvasLayer
## Menu de construction (Tab) : onglets Essentiel (+ améliorations) / Chantiers (3 paliers) / Chalet.
## « Placer » ferme le menu et lance le placement (fantôme vert/rouge) ; on ne paie qu'en posant.

signal place(key: String)
signal furnish(key: String)
signal upgrade(key: String)
signal closed

var tabs: TabContainer
var boxes: Array = []        # VBoxContainer de chaque onglet
var res_label: Label
var close_btn: Button

func _ready() -> void:
	layer = 20
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
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := UiTheme.vbox(panel, 10)
	UiTheme.title(vb, "Menu de construction", 26)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(760, 400)
	vb.add_child(tabs)
	for t in ["Essentiel", "Chantiers", "Chalet"]:
		var sc := ScrollContainer.new()
		sc.name = t
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(sc)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		sc.add_child(box)
		boxes.append(box)
	res_label = Label.new()
	res_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	res_label.custom_minimum_size = Vector2(760, 0)
	res_label.add_theme_font_size_override("font_size", 15)
	res_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.75))
	vb.add_child(res_label)
	close_btn = UiTheme.button(vb, "Fermer", func() -> void: closed.emit(), 760.0)

func open(st: Dictionary) -> void:
	visible = true
	close_btn.text = "Fermer (%s)" % Settings.key_name("build_menu")
	refresh(st)

## Texte d'un coût et indique s'il est payable.
static func cost_text(cost: Dictionary, st: Dictionary) -> Array:
	if cost.is_empty():
		return ["Gratuit", true]
	var parts := PackedStringArray()
	var ok := true
	for k in cost:
		var have: int = (st["res"] if k == "res" else st["planks"]) if k is String else st["stock"][k]
		var need: int = cost[k]
		parts.append("%s %d/%d" % [GameData.res_name(k), mini(have, need), need])
		if have < need:
			ok = false
	return [" · ".join(parts), ok]

func _header(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(720, 0)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(l)

func _row(box: VBoxContainer, title: String, desc: String, cost_line: String, btn_text: String, disabled: bool, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = "%s – %s\n%s" % [title, desc, cost_line] if desc != "" else "%s\n%s" % [title, cost_line]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(540, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 16)
	var b := Button.new()
	b.text = btn_text
	b.disabled = disabled
	b.custom_minimum_size = Vector2(170, 44)
	b.pressed.connect(cb)
	row.add_child(l)
	row.add_child(b)
	box.add_child(row)
	box.add_child(HSeparator.new())

## Ligne d'une construction à poser : Placer / Déplacer (ou verrouillée tant que son palier n'est pas atteint).
func _place_row(box: VBoxContainer, d: Dictionary, st: Dictionary, unlock: int = 0) -> void:
	var key: String = d["key"]
	var placed: bool = st["placed"].has(key)
	var c: Array = cost_text(d["cost"], st)
	var line: String = "✔ Construit" if placed else "Coût : " + c[0]
	var txt := "Déplacer" if placed else ("Placer (gratuit)" if d["cost"].is_empty() else "Placer")
	var locked: bool = not placed and int(st["collected"]) < unlock
	if locked:
		txt = "🔒 %d objets" % unlock
	_row(box, d["name"], d["desc"], line, txt, locked or (not placed and not c[1]), func() -> void: place.emit(key))

## Ligne d'amélioration d'une construction essentielle (scierie, machine, table).
func _upgrade_row(box: VBoxContainer, u: Dictionary, st: Dictionary) -> void:
	var key: String = u["key"]
	var c: Array = cost_text(u["cost"], st)
	var locked: bool = int(st["collected"]) < int(u["min"])
	var txt := "🔒 %d objets" % int(u["min"]) if locked else "Améliorer"
	_row(box, "   ⬆ " + u["name"], u["desc"], "Coût : " + c[0], txt, locked or not c[1], func() -> void: upgrade.emit(key))

func refresh(st: Dictionary) -> void:
	for box in boxes:
		for c in box.get_children():
			c.queue_free()
	# Essentiel
	_header(boxes[0], "La table de tri et la machine sont gratuites : elles sont indispensables. Tu choisis où les poser.")
	for d in GameData.BUILDINGS:
		_place_row(boxes[0], d, st)
		var nu: Dictionary = st["next"].get(d["key"], {})
		if not nu.is_empty() and st["placed"].has(d["key"]):
			_upgrade_row(boxes[0], nu, st)
	# Chantiers
	_header(boxes[1], "Les chantiers coûtent des ressources triées. Chaque chantier terminé fait avancer la restauration.")
	var tier := 0
	for d in GameData.PROJECTS:
		var dt: int = d.get("tier", 1)
		var unlock: int = GameData.TIER_UNLOCK[dt]
		if dt != tier:
			tier = dt
			if dt > 1:
				var got: int = st["collected"]
				_header(boxes[1], "Palier %d : dès %d objets ramassés %s" % [dt, unlock, "✔" if got >= unlock else "(encore %d)" % (unlock - got)])
		_place_row(boxes[1], d, st, unlock)
	# Chalet
	var has_chalet: bool = st["placed"].has("chalet")
	_header(boxes[2], "Le chalet et ses meubles sont la récompense : un endroit à toi dans la forêt rangée. Les planches viennent de la scierie (1 bûche → %d planches)." % GameData.planks_per_log(int(st["blv"]["scierie"])))
	_place_row(boxes[2], GameData.CHALET, st)
	var furn: Dictionary = st["furniture"]
	for f in GameData.FURNITURE:
		var key: String = f["key"]
		var done: bool = furn.get(key, false)
		var c: Array = cost_text(f["cost"], st)
		var btn := "Construit ✔" if done else ("Chalet requis" if not has_chalet else "Construire")
		_row(boxes[2], "🪑 " + f["name"], "", "Coût : " + c[0], btn, done or not has_chalet or not c[1], func() -> void: furnish.emit(key))
	# Ressources disponibles
	var parts := PackedStringArray()
	for i in GameData.CATS.size():
		parts.append("%s %d" % [GameData.CATS[i]["use"], st["stock"][i]])
	parts.append("Planches %d" % st["planks"])
	parts.append("🌿 %d" % st["res"])
	res_label.text = "Tes ressources : " + " · ".join(parts)
