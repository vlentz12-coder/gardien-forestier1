class_name SortUI
extends CanvasLayer
## Table : onglets Tri / Outils (les chantiers sont dans le menu de construction, Tab).

signal bin_chosen(i: int)
signal bought(key: String)
signal closed

var panel: PanelContainer
var tabs: TabContainer
var swatch: Label
var cur_label: Label
var left_label: Label
var cur_row: HBoxContainer
var bins_box: GridContainer
var ups_box: VBoxContainer
var back: Button
var note: Label

func _ready() -> void:
    visible = false
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    panel = PanelContainer.new()
    center.add_child(panel)
    var margin := MarginContainer.new()
    for s in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + s, 16)
    panel.add_child(margin)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 8)
    margin.add_child(vb)

    var title := Label.new()
    title.text = "Table du gardien"
    title.add_theme_font_size_override("font_size", 22)
    vb.add_child(title)

    tabs = TabContainer.new()
    tabs.custom_minimum_size = Vector2(620, 380)
    vb.add_child(tabs)

    # --- Onglet Tri ---
    var t1 := VBoxContainer.new()
    t1.add_theme_constant_override("separation", 10)
    tabs.add_child(t1)
    cur_row = HBoxContainer.new()
    cur_row.add_theme_constant_override("separation", 12)
    swatch = Label.new()
    swatch.add_theme_font_size_override("font_size", 36)
    cur_label = Label.new()
    cur_label.add_theme_font_size_override("font_size", 22)
    cur_row.add_child(swatch)
    cur_row.add_child(cur_label)
    t1.add_child(cur_row)
    bins_box = GridContainer.new()
    bins_box.columns = 2
    bins_box.add_theme_constant_override("h_separation", 8)
    bins_box.add_theme_constant_override("v_separation", 8)
    t1.add_child(bins_box)
    left_label = Label.new()
    t1.add_child(left_label)
    note = Label.new()
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.custom_minimum_size = Vector2(600, 0)
    note.add_theme_font_size_override("font_size", 15)
    t1.add_child(note)
    tabs.set_tab_title(0, "Tri (touches 1-6)")

    # --- Onglet Outils ---
    var t2 := ScrollContainer.new()
    t2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    ups_box = VBoxContainer.new()
    ups_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    t2.add_child(ups_box)
    tabs.add_child(t2)
    tabs.set_tab_title(1, "Outils")

    back = Button.new()
    back.pressed.connect(func(): closed.emit())
    vb.add_child(back)

func open(st: Dictionary) -> void:
    visible = true
    tabs.current_tab = 0
    back.text = "Retourner dans la forêt (%s)" % Settings.key_name("interact")
    refresh(st)

func on_sort_tab() -> bool:
    return tabs.current_tab == 0

func _color_button(b: Button, c: Color) -> void:
    for state in ["normal", "hover", "pressed"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = c if state != "hover" else c.lightened(0.15)
        sb.set_corner_radius_all(8)
        sb.content_margin_top = 10
        sb.content_margin_bottom = 10
        b.add_theme_stylebox_override(state, sb)

func _has(st: Dictionary, k: String) -> bool:
    return st["up"].get(k, false) or st["lv"].get(k, 0) > 0 or st["proj"].get(k, false)

func _row(text: String, btn_text: String, disabled: bool, cb: Callable) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    var l := Label.new()
    l.text = text
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(430, 0)
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var b := Button.new()
    b.text = btn_text
    b.disabled = disabled
    b.custom_minimum_size = Vector2(110, 0)
    b.pressed.connect(cb)
    row.add_child(l)
    row.add_child(b)
    return row

func refresh(st: Dictionary) -> void:
    var table: Array = st["table"]
    var has := not table.is_empty()
    cur_row.visible = has
    if has:
        swatch.text = GameData.CATS[table[0]["cat"]]["icon"]
        cur_label.text = table[0]["name"]
    left_label.text = ("%d objet(s) sur la table" % table.size()) if has else "Table vide : bien joué !"

    for c in bins_box.get_children():
        c.queue_free()
    var fill: Array = st["fill"]
    var bcap: int = st["bucket_cap"]
    note.text = "Chaque bac verse son produit dans un seau posé devant la table. Apporte les seaux à %s !" % GameData.MACHINE_NAME
    note.add_theme_color_override("font_color", Color(0.8, 0.9, 0.75))
    for i in GameData.CATS.size():
        var b := Button.new()
        var full: bool = fill[i] >= bcap
        b.text = "%d · %s %s
🪣 %s %d/%d%s" % [i + 1, GameData.CATS[i]["icon"], GameData.CATS[i]["name"], GameData.CATS[i]["product"], fill[i], bcap, "  PLEIN" if full else ""]
        if full:
            b.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.disabled = not has
        b.pressed.connect(func(): bin_chosen.emit(i))
        bins_box.add_child(b)

    # Outils
    for c in ups_box.get_children():
        c.queue_free()
    var collected: int = st["collected"]
    if collected < GameData.TOOLS_UNLOCK_COUNT:
        var lock := Label.new()
        lock.text = "🔒 Outils débloqués après %d objets ramassés (actuellement %d)" % [GameData.TOOLS_UNLOCK_COUNT, collected]
        ups_box.add_child(lock)
    else:
        for u in GameData.UPGRADES:
            var key: String = u["key"]
            var mx: int = u.get("max", 1)
            var lvl: int = st["lv"].get(key, 0) if mx > 1 else (1 if st["up"].get(key, false) else 0)
            var cost: int = int(u["cost"]) * (lvl + 1)
            var req: String = u.get("req", "")
            var blocked: bool = req != "" and not _has(st, req)
            var done: bool = lvl >= mx
            var txt: String = "%s – %s" % [u["name"], u["desc"]]
            if mx > 1:
                txt += "  [niv %d/%d]" % [lvl, mx]
            ups_box.add_child(_row(txt, "Acquis" if done else "%d 🌿" % cost, done or blocked or int(st["res"]) < cost, func(): bought.emit(key)))

## Message important dans la fenêtre de tri (le HUD est caché derrière).
func flash(text: String) -> void:
    note.text = text
    note.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))

func shake() -> void:
    panel.pivot_offset = panel.size / 2.0
    var tw := create_tween()
    tw.tween_property(panel, "rotation_degrees", 2.0, 0.05)
    tw.tween_property(panel, "rotation_degrees", -2.0, 0.1)
    tw.tween_property(panel, "rotation_degrees", 0.0, 0.05)
