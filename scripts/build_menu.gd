class_name BuildMenu
extends CanvasLayer
## Menu de construction (Tab) : onglets Essentiel (+ améliorations) / Outils / Chantiers (3 paliers) / Chalet / Animaux.
## « Placer » ferme le menu et lance le placement (fantôme vert/rouge) ; on ne paie qu'en posant.

signal place(key: String)
signal furnish(key: String)
signal upgrade(key: String)
signal bought(key: String)    # outil ou aide achetés avec les 🌿
signal rename(index: int, new_name: String)   # nom d'un animal
signal skin(key: String)    # acheter / équiper un skin (Boutique)
signal closed

var tabs: TabContainer
var boxes: Array = []        # VBoxContainer de chaque onglet
var box_ess: VBoxContainer
var box_tools: VBoxContainer
var box_proj: VBoxContainer
var box_chalet: VBoxContainer
var box_animals: VBoxContainer
var box_shop: VBoxContainer
var _name_edits: Array = []   # LineEdit des noms (onglet Animaux)
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
	for t in ["Essentiel", "Outils", "Chantiers", "Chalet", "Animaux", "Boutique"]:
		var sc := ScrollContainer.new()
		sc.name = t
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(sc)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		sc.add_child(box)
		boxes.append(box)
	box_ess = boxes[0]
	box_tools = boxes[1]
	box_proj = boxes[2]
	box_chalet = boxes[3]
	box_animals = boxes[4]
	box_shop = boxes[5]
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
		if box == box_animals:
			continue   # reconstruit seulement si la liste change : on ne coupe pas la saisie d'un nom
		for c in box.get_children():
			c.queue_free()
	_animals_tab(st)
	_shop_tab(st)
	# Essentiel
	_header(box_ess, "La table de tri et la machine sont gratuites : elles sont indispensables. Tu choisis où les poser.")
	for d in GameData.BUILDINGS:
		_place_row(box_ess, d, st)
		var nu: Dictionary = st["next"].get(d["key"], {})
		if not nu.is_empty() and st["placed"].has(d["key"]):
			_upgrade_row(box_ess, nu, st)
	# Chantiers
	_header(box_proj, "Les chantiers coûtent des ressources triées. Chaque chantier terminé fait avancer la restauration.")
	var tier := 0
	for d in GameData.PROJECTS:
		var dt: int = d.get("tier", 1)
		var unlock: int = GameData.TIER_UNLOCK[dt]
		if dt != tier:
			tier = dt
			if dt > 1:
				var got: int = st["collected"]
				_header(box_proj, "Palier %d : dès %d objets ramassés %s" % [dt, unlock, "✔" if got >= unlock else "(encore %d)" % (unlock - got)])
		_place_row(box_proj, d, st, unlock)
	# Chalet
	var has_chalet: bool = st["placed"].has("chalet")
	_header(box_chalet, "Le chalet et ses meubles sont la récompense : un endroit à toi dans la forêt rangée. Les planches viennent de la scierie (1 bûche → %d planches)." % GameData.planks_per_log(int(st["blv"]["scierie"])))
	_place_row(box_chalet, GameData.CHALET, st)
	var furn: Dictionary = st["furniture"]
	for f in GameData.FURNITURE:
		var key: String = f["key"]
		var done: bool = furn.get(key, false)
		var c: Array = cost_text(f["cost"], st)
		var btn := "Construit ✔" if done else ("Chalet requis" if not has_chalet else "Construire")
		_row(box_chalet, "🪑 " + f["name"], "", "Coût : " + c[0], btn, done or not has_chalet or not c[1], func() -> void: furnish.emit(key))
	# Outils et aides (achetés avec les 🌿 gagnés en triant)
	_tools_tab(st)
	# Ressources disponibles
	var parts := PackedStringArray()
	for i in GameData.CATS.size():
		parts.append("%s %d" % [GameData.CATS[i]["use"], st["stock"][i]])
	parts.append("Planches %d" % st["planks"])
	parts.append("🌿 %d" % st["res"])
	res_label.text = "Tes ressources : " + " · ".join(parts)

func _tools_tab(st: Dictionary) -> void:
	var collected: int = st["collected"]
	if collected < GameData.TOOLS_UNLOCK_COUNT:
		_header(box_tools, "🔒 Les outils se débloquent après %d objets ramassés (actuellement %d)." % [GameData.TOOLS_UNLOCK_COUNT, collected])
		return
	_header(box_tools, "Outils et aides : ils s'achètent avec les 🌿 gagnés en triant (tu en as %d)." % int(st["res"]))
	for u in GameData.UPGRADES:
		var key: String = u["key"]
		var mx: int = u.get("max", 1)
		var lvl: int = st["lv"].get(key, 0) if mx > 1 else (1 if st["up"].get(key, false) else 0)
		var cost: int = int(u["cost"]) * (lvl + 1)
		var req: String = u.get("req", "")
		var blocked: bool = req != "" and not (st["up"].get(req, false) or st["lv"].get(req, 0) > 0 or st["proj"].get(req, false))
		var done: bool = lvl >= mx
		var title: String = u["name"] + ("  [niv. %d/%d]" % [lvl, mx] if mx > 1 else "")
		var line: String = "✔ Acquis" if done else ("Coût : %d 🌿" % cost + ("  (requiert : %s)" % req if blocked else ""))
		_row(box_tools, "🔧 " + title, u["desc"], line, "Acquis" if done else "Acheter", done or blocked or int(st["res"]) < cost, func() -> void: bought.emit(key))

const ANIMAL_ICONS := {"squirrel": "🐿", "hedgehog": "🦔", "fox": "🦊", "deer": "🦌", "bird": "🐦"}
const ANIMAL_KINDS := {"squirrel": "Écureuil", "hedgehog": "Hérisson", "fox": "Renard", "deer": "Cerf", "bird": "Oiseau"}

func _animals_tab(st: Dictionary) -> void:
	var list: Array = st.get("animals", [])
	if list.size() == _name_edits.size() and box_animals.get_child_count() > 0:
		return
	for c in box_animals.get_children():
		c.queue_free()
	_name_edits.clear()
	if list.is_empty():
		_header(box_animals, "Pas encore d'animaux. Les écureuils et hérissons s'achètent dans l'onglet Outils ; les oiseaux arrivent avec le nichoir, les renards avec la mangeoire, les cerfs quand la forêt revit.")
		return
	_header(box_animals, "Tes compagnons de la forêt. Clique sur un nom pour le changer : il s'affiche au-dessus de l'animal quand tu t'approches.")
	for i in list.size():
		var a: Dictionary = list[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.text = "%s  %s" % [ANIMAL_ICONS.get(a["kind"], "🐾"), ANIMAL_KINDS.get(a["kind"], "Animal")]
		l.custom_minimum_size = Vector2(200, 0)
		l.add_theme_font_size_override("font_size", 17)
		row.add_child(l)
		var e := LineEdit.new()
		e.text = a["name"]
		e.max_length = 20
		e.custom_minimum_size = Vector2(320, 40)
		e.placeholder_text = "Nom"
		e.text_changed.connect(func(txt: String) -> void: rename.emit(i, txt))
		e.text_submitted.connect(func(_txt: String) -> void: e.release_focus())
		row.add_child(e)
		box_animals.add_child(row)
		_name_edits.append(e)

## Après l'achat d'un écureuil ou d'un hérisson : on ouvre l'onglet Animaux sur son nom, prêt à être changé.
func focus_last_animal() -> void:
	if _name_edits.is_empty():
		return
	tabs.current_tab = 4
	var e: LineEdit = _name_edits[-1]
	e.grab_focus.call_deferred()
	e.select_all.call_deferred()

func _shop_tab(st: Dictionary) -> void:
	var gold: int = st.get("gold", 0)
	_header(box_shop, "✨ Glands dorés : %d  ·  tu en gagnes %d tous les %d objets ramassés. Achète des skins et change-les quand tu veux." % [gold, GameData.GOLD_PER_STEP, GameData.GOLD_STEP])
	var owned: Dictionary = st.get("skins_owned", {})
	var worn: Dictionary = st.get("skins_on", {})
	for c in GameData.SKIN_CATS:
		var cat: String = c[0]
		var t := Label.new()
		t.text = c[1]
		t.add_theme_font_size_override("font_size", 19)
		t.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
		box_shop.add_child(t)
		for s in GameData.SKINS:
			if s["cat"] != cat:
				continue
			var key: String = s["key"]
			var cost: int = s["cost"]
			var equipped: bool = worn.get(cat, GameData.default_skin(cat)) == key
			var have: bool = cost == 0 or owned.has(key)
			var line := "Gratuit" if cost == 0 else ("Acheté" if have else "Prix : %d ✨" % cost)
			var btn := "Équipé ✔" if equipped else ("Équiper" if have else "Acheter")
			var key_c := key
			_row(box_shop, "   " + s["name"], "", line, btn, equipped or (not have and gold < cost), skin.emit.bind(key_c))