class_name Player
extends CharacterBody3D
## Joueur à la première personne.
## Vue : souris capturée, OU clic maintenu, OU flèches, OU mode "bords d'écran" (C).

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
var base_fov := 75.0      # champ de vision (Options > Graphismes)
var sens_mult := 1.0       # sensibilité (Options > Commandes)
var invert_y := false

const SPRINT_MULT := 1.65
const STAMINA_MAX := 100.0

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
            stamina = minf(STAMINA_MAX, stamina + (16.0 if moving else 24.0) * delta)
        if exhausted and stamina >= 25.0:
            exhausted = false
    cam.fov = lerpf(cam.fov, base_fov + 9.0 if sprinting else base_fov, 8.0 * delta)
    velocity = (transform.basis * Vector3(dir.x, 0, dir.y)) * SPEED * speed_mult * (SPRINT_MULT if sprinting else 1.0)
    move_and_slide()
    position.x = clampf(position.x, -GameData.AREA, GameData.AREA)
    position.z = clampf(position.z, -GameData.AREA, GameData.AREA)
    position.y = 0.0
