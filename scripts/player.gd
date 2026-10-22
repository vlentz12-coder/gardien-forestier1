class_name Player
extends CharacterBody3D
## Joueur à la première personne.
## Vue : souris capturée, OU clic maintenu, OU flèches, OU mode "bords d'écran" (C).
## Espace : sauter (enchaîner les sauts dès l'atterrissage = bunny hop).

signal pick_pressed
signal interact_pressed

const SPEED := 4.2
const SENS := 0.003

var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var enabled := true
var edge_mode := false   # C : regarder en poussant la souris vers les bords
var motion_count := 0
var speed_mult := 1.0
var stamina := 100.0
var exhausted := false
var sprinting := false
var regen_delay := 0.0
var stamina_max := 100.0   # +50 % avec la cabane perchée
var regen_mult := 1.0      # ×1,5 avec le puits
var in_water := false      # dans la rivière : impossible de sauter
var base_fov := 75.0      # champ de vision (Options > Graphismes)
var sens_mult := 1.0       # sensibilité (Options > Commandes)
var invert_y := false

const SPRINT_MULT := 1.65
const STAMINA_MAX := 100.0
# Saut et « bunny hop » : ressauter dès l'atterrissage (ou garder Espace enfoncé) garde l'élan et l'augmente un peu.
const JUMP_SPEED := 4.8
const GRAVITY := 13.0
const JUMP_COST := 4.0
const HOP_GAIN := 0.08       # +8 % de vitesse par saut enchaîné
const HOP_MAX := 1.6
const HOP_WINDOW := 0.15     # temps au sol toléré entre deux sauts pour garder l'élan
const AIR_STEER := 5.0       # contrôle en l'air (on peut tourner sans perdre sa vitesse)

var hop := 1.0              # multiplicateur d'élan du bunny hop
var ground_time := 1.0
var jump_buffer := 0.0
var jumps := 0

# Corps du gardien (vue à la première personne) : bras devant la caméra, jambes visibles en regardant en bas
const JACKET := Color(0.16, 0.55, 0.36)   # même vert que la cape du rôdeur
const GLOVE := Color(0.62, 0.34, 0.22)
const PANTS := Color(0.55, 0.45, 0.32)
const BOOTS := Color(0.22, 0.15, 0.1)
const SKIN := Color(0.93, 0.76, 0.62)
var carrying := false       # un seau dans la main gauche
var _arms: Node3D
var _arm_r: Node3D
var _arm_l: Node3D
var _hips: Array = []       # [pivot hanche, pivot genou] pour chaque jambe
var _walk := 0.0
var _stride := 0.0
var _arm_tw: Tween
var _body_tw: Tween
var third_person := false   # vue à la 3e personne (touche V)
var avatar_model := "Rogue_Hooded"   # personnage 3D (assets/characters, KayKit Adventurers, CC0)
var _anim: AnimationPlayer
var _anim_cur := ""
var _oneshot := 0.0
var _grip_l: Node3D
const AVATAR_SCALE := 0.78
const LOOP_ANIMS := ["Unarmed_Idle", "Walking_A", "Running_A", "Jump_Idle"]
var _upper: Array = []      # pièces du corps cachées à la 1re personne
var _shoulders: Array = []  # [épaule, coude, prise] pour chaque bras du corps
signal view_changed

func _ready() -> void:
    cam = Camera3D.new()
    cam.position = Vector3(0, 1.6, 0)
    cam.current = true
    add_child(cam)
    var body_shape := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.4
    capsule.height = 1.8
    body_shape.shape = capsule
    body_shape.position.y = 0.9
    add_child(body_shape)
    _build_body()
    grab()

func grab() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if edge_mode else Input.MOUSE_MODE_CAPTURED

func _look(dx: float, dy: float) -> void:
    yaw -= dx
    pitch = clampf(pitch - dy, -1.4, 1.4)

func _input(event: InputEvent) -> void:
    if not enabled:
        return
    if event is InputEventMouseMotion:
        motion_count += 1
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            _look(event.relative.x * SENS * sens_mult, event.relative.y * SENS * sens_mult * (-1.0 if invert_y else 1.0))
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if not edge_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        pick_pressed.emit()
    elif event.is_action_pressed("view"):
        toggle_view()
    elif event.is_action_pressed("edge_mode"):
        edge_mode = not edge_mode
        grab()
    elif event.is_action_pressed("pick"):
        pick_pressed.emit()
    elif event.is_action_pressed("interact"):
        interact_pressed.emit()
        get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
    if not enabled:
        velocity = Vector3.ZERO
        return
    # Flèches (modifiables) : regarder au clavier
    var lx := Input.get_action_strength("look_left") - Input.get_action_strength("look_right")
    var ly := Input.get_action_strength("look_up") - Input.get_action_strength("look_down")
    yaw += lx * 1.8 * delta
    pitch = clampf(pitch + ly * 1.5 * delta, -1.4, 1.4)
    # Mode bords d'écran (ne dépend d'aucun événement souris)
    if edge_mode:
        var vp := get_viewport()
        var m := vp.get_mouse_position() / vp.get_visible_rect().size - Vector2(0.5, 0.5)
        m = m.clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
        if absf(m.x) > 0.15:
            yaw -= (m.x - signf(m.x) * 0.15) * 3.5 * delta
        if absf(m.y) > 0.15:
            pitch = clampf(pitch - (m.y - signf(m.y) * 0.15) * 2.5 * delta, -1.4, 1.4)
    rotation.y = yaw
    cam.rotation.x = pitch
    if third_person:
        _place_third_cam()
    # Déplacement
    var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    # Sprint (Maj par défaut) avec endurance
    var moving := dir.length() > 0.1
    sprinting = Input.is_action_pressed("sprint") and moving and not exhausted and stamina > 0.0
    if sprinting:
        stamina = maxf(0.0, stamina - 28.0 * delta)
        regen_delay = 0.8
        if stamina <= 0.0:
            exhausted = true
    else:
        regen_delay = maxf(0.0, regen_delay - delta)
        if regen_delay <= 0.0:
            stamina = minf(stamina_max, stamina + (16.0 if moving else 24.0) * regen_mult * delta)
        if exhausted and stamina >= 25.0:
            exhausted = false
    cam.fov = lerpf(cam.fov, base_fov + (9.0 if sprinting else 0.0) + (hop - 1.0) * 15.0, 8.0 * delta)
    var target := (transform.basis * Vector3(dir.x, 0, dir.y)) * SPEED * speed_mult * (SPRINT_MULT if sprinting else 1.0)
    var on_floor := is_on_floor() or position.y <= 0.001
    jump_buffer = maxf(0.0, jump_buffer - delta)
    if Input.is_action_just_pressed("jump"):
        jump_buffer = 0.15     # un appui juste avant d'atterrir compte quand même
    if on_floor:
        ground_time += delta
        if ground_time > HOP_WINDOW:
            hop = 1.0          # resté au sol : l'élan retombe
        velocity.x = target.x * hop
        velocity.z = target.z * hop
        velocity.y = 0.0
        if (jump_buffer > 0.0 or Input.is_action_pressed("jump")) and stamina >= JUMP_COST and not in_water:
            if ground_time <= HOP_WINDOW and moving and jumps > 0:
                hop = minf(HOP_MAX, hop + HOP_GAIN)
                velocity.x = target.x * hop
                velocity.z = target.z * hop
            velocity.y = JUMP_SPEED
            stamina -= JUMP_COST
            regen_delay = maxf(regen_delay, 0.4)
            jump_buffer = 0.0
            ground_time = 0.0
            jumps += 1
    else:
        ground_time = 0.0
        velocity.y -= GRAVITY * delta
        # En l'air : on garde sa vitesse, les touches orientent la trajectoire
        var hv := Vector2(velocity.x, velocity.z)
        if moving:
            var want := Vector2(target.x, target.z).normalized() * maxf(hv.length(), target.length())
            hv = hv.lerp(want, clampf(AIR_STEER * delta, 0.0, 1.0))
        velocity.x = hv.x
        velocity.z = hv.y
    move_and_slide()
    position.x = clampf(position.x, -GameData.AREA, GameData.AREA)
    position.z = clampf(position.z, -GameData.AREA, GameData.AREA)
    if position.y < 0.0:
        position.y = 0.0
        velocity.y = maxf(velocity.y, 0.0)
    _animate_body(delta, is_on_floor() or position.y <= 0.001)

# ---------- Corps ----------
func _body_mat(c: Color, cloth: bool) -> StandardMaterial3D:
    var m: StandardMaterial3D
    if cloth:
        m = Chalet._material("tissu", c).duplicate()   # tissu tricoté, teinté
    else:
        m = StandardMaterial3D.new()
    m.disable_receive_shadows = true   # l'ombre du gardien ne noircit pas ses propres bras et jambes
    if cloth:
        return m
    m.albedo_color = c
    m.roughness = 0.7
    return m

func _limb(parent: Node3D, mesh: Mesh, c: Color, cloth: bool, pos: Vector3, rot: Vector3 = Vector3.ZERO, shadows := true) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = _body_mat(c, cloth)
    mi.position = pos
    mi.rotation = rot
    if not shadows:
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi

func _capsule(r: float, h: float) -> CapsuleMesh:
    var c := CapsuleMesh.new()
    c.radius = r
    c.height = h
    c.radial_segments = 12
    c.rings = 4
    return c

func _sphere_m(r: float) -> SphereMesh:
    var s := SphereMesh.new()
    s.radius = r
    s.height = r * 2.0
    return s

func _boxm(x: float, y: float, z: float) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = Vector3(x, y, z)
    return b

func _build_body() -> void:
    # Corps entier du gardien. À la 1re personne, le haut du corps ne sert qu'à l'ombre portée
    # (vu d'en haut il cacherait les jambes) ; à la 3e personne (touche V) on le voit en entier.
    var body := Node3D.new()
    body.name = "Body"
    add_child(body)
    if _build_avatar(body):
        _arms = Node3D.new()
        cam.add_child(_arms)
        _arm_r = _make_arm(1.0)
        _arm_l = _make_arm(-1.0)
        _apply_view()
        return
    _upper.append(_limb(body, _boxm(0.4, 0.58, 0.24), JACKET, true, Vector3(0, 1.24, 0.06)))          # veste
    _upper.append(_limb(body, _boxm(0.42, 0.07, 0.26), Color(0.3, 0.2, 0.12), false, Vector3(0, 0.97, 0.06)))   # ceinture
    _upper.append(_limb(body, _boxm(0.3, 0.36, 0.14), Color(0.5, 0.36, 0.2), true, Vector3(0, 1.28, 0.25)))     # sac à dos
    _upper.append(_limb(body, _capsule(0.055, 0.12), SKIN, false, Vector3(0, 1.56, 0.05)))              # cou
    var head := Node3D.new()
    head.position = Vector3(0, 1.7, 0.04)
    body.add_child(head)
    _upper.append(_limb(head, _sphere_m(0.115), SKIN, false, Vector3.ZERO))
    _upper.append(_limb(head, _sphere_m(0.118), Color(0.38, 0.24, 0.14), false, Vector3(0, 0.03, 0.025)))   # cheveux
    for sx in [-0.04, 0.04]:
        _upper.append(_limb(head, _sphere_m(0.014), Color(0.08, 0.06, 0.05), false, Vector3(sx, 0.01, -0.105)))
    _upper.append(_limb(head, _sphere_m(0.02), SKIN.darkened(0.08), false, Vector3(0, -0.02, -0.115)))   # nez
    var hat_brim := CylinderMesh.new()
    hat_brim.top_radius = 0.22
    hat_brim.bottom_radius = 0.22
    hat_brim.height = 0.02
    _upper.append(_limb(head, hat_brim, Color(0.45, 0.36, 0.22), true, Vector3(0, 0.09, 0)))            # chapeau de garde forestier
    var hat_top := CylinderMesh.new()
    hat_top.top_radius = 0.1
    hat_top.bottom_radius = 0.13
    hat_top.height = 0.13
    _upper.append(_limb(head, hat_top, Color(0.45, 0.36, 0.22), true, Vector3(0, 0.16, 0)))
    _upper.append(_limb(head, _boxm(0.27, 0.025, 0.27), Color(0.3, 0.45, 0.25), false, Vector3(0, 0.11, 0)))  # ruban
    # Bras du corps (visibles à la 3e personne)
    for side in [1.0, -1.0]:
        var sh := Node3D.new()
        sh.position = Vector3(side * 0.26, 1.48, 0.06)
        body.add_child(sh)
        _upper.append(_limb(sh, _capsule(0.06, 0.34), JACKET, true, Vector3(0, -0.15, 0)))
        var elbow := Node3D.new()
        elbow.position = Vector3(0, -0.3, 0)
        sh.add_child(elbow)
        _upper.append(_limb(elbow, _capsule(0.05, 0.3), JACKET, true, Vector3(0, -0.13, 0)))
        _upper.append(_limb(elbow, _sphere_m(0.045), SKIN, false, Vector3(0, -0.3, 0)))
        var grip := Node3D.new()   # point d'attache d'un objet tenu
        grip.position = Vector3(0, -0.34, 0)
        elbow.add_child(grip)
        _shoulders.append([sh, elbow, grip])
    for sx in [-0.11, 0.11]:
        var hip := Node3D.new()
        hip.position = Vector3(sx, 0.94, 0.08)
        body.add_child(hip)
        _upper.append(_limb(hip, _capsule(0.08, 0.5), PANTS, true, Vector3(0, -0.23, 0)))   # cuisse (cachée vue d'en haut)
        var knee := Node3D.new()
        knee.position = Vector3(0, -0.46, 0)
        hip.add_child(knee)
        _limb(knee, _capsule(0.068, 0.46), PANTS, true, Vector3(0, -0.21, 0))
        _limb(knee, _boxm(0.12, 0.11, 0.28), BOOTS, false, Vector3(0, -0.43, -0.07))
        _hips.append([hip, knee])
    # Bras de la vue 1re personne (attachés à la caméra : ils suivent le regard)
    _arms = Node3D.new()
    cam.add_child(_arms)
    _arm_r = _make_arm(1.0)
    _arm_l = _make_arm(-1.0)
    _apply_view()

## 1re personne : haut du corps invisible (mais ombre portée), bras devant la caméra.
## 3e personne : tout le corps visible, caméra derrière l'épaule.
func _apply_view() -> void:
    for mi in _upper:
        (mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if third_person else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
    _arms.visible = not third_person
    if not third_person:
        cam.position = Vector3(0, 1.6, 0)
    view_changed.emit()

## Cinématiques : le gardien est vu de l'extérieur, on montre tout son corps.
func show_full_body(on: bool) -> void:
    for mi in _upper:
        (mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (on or third_person) else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
    _arms.visible = not on and not third_person

func toggle_view() -> void:
    third_person = not third_person
    _apply_view()

## Où la main gauche tient le seau (dépend de la vue).
func carry_parent() -> Node3D:
    if not third_person:
        return cam
    if _grip_l != null:
        return _grip_l
    return _shoulders[1][2]

## Origine des visées (ramasser, verser…) : les yeux du gardien, même en vue 3e personne.
func aim_origin() -> Vector3:
    return global_position + Vector3(0, 1.6, 0) if third_person else cam.global_position

## Caméra derrière l'épaule, rapprochée si un obstacle est entre elle et le gardien.
func _place_third_cam() -> void:
    var head := Vector3(0, 1.6, 0)
    var want := head + Vector3(0.45, 0.35, 3.0).rotated(Vector3.RIGHT, pitch)
    var from := to_global(head)
    var to := to_global(want)
    var q := PhysicsRayQueryParameters3D.create(from, to)
    q.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(q)
    if not hit.is_empty():
        want = head + (want - head) * maxf(0.15, from.distance_to(hit["position"]) / from.distance_to(to) - 0.08)
    cam.position = want
func _make_arm(side: float) -> Node3D:
    var pivot := Node3D.new()
    pivot.position = Vector3(side * 0.25, -0.37, -0.04)
    pivot.rotation = Vector3(0.22, side * 0.16, 0)
    _arms.add_child(pivot)
    _limb(pivot, _capsule(0.045, 0.44), JACKET, true, Vector3(0, 0, -0.2), Vector3(-PI / 2.0, 0, 0), false)
    _limb(pivot, _capsule(0.05, 0.08), JACKET.darkened(0.2), true, Vector3(0, 0, -0.4), Vector3(-PI / 2.0, 0, 0), false)   # poignet
    var hand := _limb(pivot, _sphere_m(0.042), GLOVE, false, Vector3(0, -0.005, -0.47), Vector3.ZERO, false)   # main
    hand.scale = Vector3(1.0, 0.65, 1.35)
    for k in 4:   # doigts repliés
        _limb(pivot, _capsule(0.011, 0.06), GLOVE, false, Vector3(side * (-0.024 + k * 0.016), -0.02, -0.52), Vector3(-2.1, 0, 0), false)
    _limb(pivot, _capsule(0.012, 0.06), GLOVE, false, Vector3(side * -0.04, -0.008, -0.465), Vector3(-1.9, side * 0.5, 0), false)   # pouce
    return pivot

func _animate_body(delta: float, on_floor: bool) -> void:
    var hv := Vector2(velocity.x, velocity.z).length()
    _animate_avatar(delta, on_floor, hv)
    _stride = lerpf(_stride, clampf(hv / SPEED, 0.0, 1.4) if on_floor else 0.0, 10.0 * delta)
    _walk += hv * delta * 2.4
    for i in _hips.size():
        var hip: Node3D = _hips[i][0]
        var knee: Node3D = _hips[i][1]
        var s := sin(_walk + PI * i)
        if on_floor:
            hip.rotation.x = lerpf(hip.rotation.x, -0.14 + s * 0.55 * _stride, 14.0 * delta)   # jambes un peu en avant : on les voit en baissant les yeux
            knee.rotation.x = lerpf(knee.rotation.x, 0.14 + maxf(0.0, -cos(_walk + PI * i)) * 0.8 * _stride, 14.0 * delta)
        else:
            hip.rotation.x = lerpf(hip.rotation.x, -0.45 if i == 0 else -0.15, 10.0 * delta)   # jambes repliées en l'air
            knee.rotation.x = lerpf(knee.rotation.x, 0.9, 10.0 * delta)
    # Bras du corps : balancement opposé aux jambes (vue 3e personne)
    for i in _shoulders.size():
        var shp: Node3D = _shoulders[i][0]
        var elb: Node3D = _shoulders[i][1]
        var target_sh := -sin(_walk + PI * i) * 0.5 * _stride if on_floor else -0.6
        if i == 1 and carrying:
            target_sh = 0.0
        if _body_tw == null or not _body_tw.is_running() or i == 1:
            shp.rotation.x = lerpf(shp.rotation.x, target_sh, 10.0 * delta)
        elb.rotation.x = lerpf(elb.rotation.x, -0.35 if on_floor else -1.0, 10.0 * delta)
    # Bras : léger balancement en marchant
    _arms.position = Vector3(sin(_walk * 0.5) * 0.012 * _stride, -absf(cos(_walk * 0.5)) * 0.015 * _stride, 0)
    if _arm_tw == null or not _arm_tw.is_running():
        _arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.3 if carrying else 0.22, 8.0 * delta)

## Geste de ramassage : la main droite descend attraper l'objet.
func play_pick() -> void:
    _oneshot_anim("PickUp", 1.8)
    if not _shoulders.is_empty():
        _body_tw = create_tween()
        _body_tw.tween_property(_shoulders[0][0], "rotation:x", -1.3, 0.14)
        _body_tw.tween_property(_shoulders[0][0], "rotation:x", 0.0, 0.25)
    _arm_gesture(_arm_r, Vector3(-0.55, 0.3, 0), Vector3(0.12, -0.3, -0.3))

## Geste pour trier, verser ou charger : les deux mains poussent vers l'avant.
func play_interact() -> void:
    _oneshot_anim("Interact", 1.6)
    _arm_gesture(_arm_r, Vector3(0.35, 0, 0), Vector3(0.2, -0.22, -0.28))
    _arm_gesture(_arm_l, Vector3(0.35, 0, 0), Vector3(-0.2, -0.22, -0.28), false)

func _arm_gesture(arm: Node3D, rot: Vector3, pos: Vector3, own := true) -> void:
    var side := 1.0 if arm == _arm_r else -1.0
    var base_rot := Vector3(0.22, side * 0.16, 0)
    var base_pos := Vector3(side * 0.25, -0.37, -0.04)
    var tw := create_tween()
    tw.tween_property(arm, "rotation", rot, 0.12).set_trans(Tween.TRANS_SINE)
    tw.parallel().tween_property(arm, "position", pos, 0.12).set_trans(Tween.TRANS_SINE)
    tw.tween_property(arm, "rotation", base_rot, 0.22).set_trans(Tween.TRANS_SINE)
    tw.parallel().tween_property(arm, "position", base_pos, 0.22).set_trans(Tween.TRANS_SINE)
    if own:
        _arm_tw = tw

# ---------- Personnage 3D (modèle animé) ----------
## Charge le personnage choisi (skin) dans "body". Renvoie false si le modèle est absent.
func _build_avatar(body: Node3D) -> bool:
    var path := "res://assets/characters/%s.glb" % avatar_model
    if not ResourceLoader.exists(path):
        return false
    var inst := (load(path) as PackedScene).instantiate() as Node3D
    inst.scale = Vector3.ONE * AVATAR_SCALE
    inst.rotation.y = PI   # le modèle regarde vers +z, le gardien vers -z
    body.add_child(inst)
    _grip_l = null
    for c in inst.find_children("*", "", true, false):
        if c is BoneAttachment3D and String(c.name).begins_with("handslot"):
            for w in c.get_children():
                if w is MeshInstance3D:
                    (w as MeshInstance3D).visible = false   # pas d'armes : c'est un gardien !
            if String(c.name) == "handslot_l":
                var g := Node3D.new()
                g.scale = Vector3.ONE / AVATAR_SCALE
                c.add_child(g)
                _grip_l = g
        elif c is MeshInstance3D and (c as MeshInstance3D).visible:
            # 1re personne : on ne voit que les jambes (le reste ne fait que de l'ombre)
            if not String(c.name).contains("Leg"):
                _upper.append(c)
    _anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if _anim != null:
        for n in LOOP_ANIMS:
            if _anim.has_animation(n):
                _anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
        _anim_cur = ""
        _play_anim("Unarmed_Idle")
    return true

## Change de personnage (skin) en gardant tout le reste.
func set_avatar(model: String) -> void:
    if model == avatar_model and get_node_or_null("Body") != null:
        return
    avatar_model = model
    var old := get_node_or_null("Body")
    if old != null:
        remove_child(old)
        old.queue_free()
    if _arms != null:
        _arms.queue_free()
    _upper.clear()
    _hips.clear()
    _shoulders.clear()
    _anim = null
    _build_body()
    view_changed.emit()

func _play_anim(n: String, speed := 1.0) -> void:
    if _anim == null or not _anim.has_animation(n):
        return
    _anim.speed_scale = speed
    if n != _anim_cur:
        _anim.play(n, 0.2)
        _anim_cur = n

func _oneshot_anim(n: String, speed: float) -> void:
    if _anim == null or not _anim.has_animation(n):
        return
    _anim.speed_scale = speed
    _anim.play(n, 0.1)
    _anim_cur = n
    _oneshot = _anim.get_animation(n).length / speed * 0.85

func _animate_avatar(delta: float, on_floor: bool, hv: float) -> void:
    if _anim == null:
        return
    if _oneshot > 0.0:
        _oneshot -= delta
        return
    if not on_floor:
        _play_anim("Jump_Idle")
    elif hv > SPEED * 1.25:
        _play_anim("Running_A", clampf(hv / (SPEED * SPRINT_MULT), 0.7, 1.6))
    elif hv > 0.3:
        _play_anim("Walking_A", clampf(hv / SPEED, 0.6, 1.8))
    else:
        _play_anim("Unarmed_Idle")