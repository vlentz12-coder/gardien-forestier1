class_name Minimap
extends Control
## Mini-carte (en haut à droite) : camp, chemins, repères de zones (S, M, V, C), joueur.
## Les objets restants n'apparaissent qu'avec le Drone forestier.

var main
const RANGE_M := 45.0

func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    if main == null or main.player == null:
        return
    var c: Vector2 = size / 2.0
    var rad: float = size.x / 2.0
    var px: float = rad / RANGE_M
    draw_circle(c, rad, Color(0.05, 0.1, 0.05, 0.55))
    draw_arc(c, rad, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 2.0)
    var pp: Vector3 = main.player.global_position
    var here := Vector2(pp.x, pp.z)
    for p in main.path_pts:
        var q: Vector2 = c + (Vector2(p.x, p.y) - here) * px
        if q.distance_to(c) < rad - 2.0:
            draw_circle(q, 1.4, Color(0.75, 0.58, 0.35, 0.8))
    var camp: Vector2 = c + (Vector2.ZERO - here) * px
    if camp.distance_to(c) < rad - 5.0:
        draw_rect(Rect2(camp - Vector2(4, 4), Vector2(8, 8)), Color(0.95, 0.75, 0.3))
    if main.up["drone"]:
        for o in main.items:
            var op: Vector3 = o.global_position
            var q2: Vector2 = c + (Vector2(op.x, op.z) - here) * px
            if q2.distance_to(c) < rad - 2.0:
                draw_circle(q2, 1.4, GameData.CATS[o.get_meta("cat")]["color"])
    for zone in GameData.ZONES:
        var zc: Vector3 = zone["center"]
        var d: Vector2 = (Vector2(zc.x, zc.z) - here) * px
        var inside := d.length() <= rad - 9.0
        if not inside:
            d = d.normalized() * (rad - 9.0)
        draw_circle(c + d, 8.0, Color(0.95, 0.9, 0.4, 0.9 if not inside else 0.4))
        var initial: String = String(zone["name"]).substr(0, 1)
        draw_string(ThemeDB.fallback_font, c + d + Vector2(-4, 5), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)
    var yaw: float = main.player.yaw
    var f := Vector2(-sin(yaw), -cos(yaw))
    var r := Vector2(f.y, -f.x)
    draw_colored_polygon(PackedVector2Array([c + f * 8.0, c - f * 5.0 + r * 5.0, c - f * 5.0 - r * 5.0]), Color.WHITE)
