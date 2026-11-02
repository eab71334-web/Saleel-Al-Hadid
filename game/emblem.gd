extends Control
# Heraldic crest: shield, crossed swords, crown. Drawn in code.

var t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.5
	var gold := Color(1.0, 0.82, 0.35)
	var gold2 := Color(0.72, 0.5, 0.15)
	# glow
	for k in 5:
		draw_circle(c, s * (1.1 - k * 0.12), Color(1, 0.7, 0.2, 0.025 + 0.012 * sin(t * 2.0)))
	# crossed swords behind the shield
	for sgn in [-1.0, 1.0]:
		var a: Vector2 = c + Vector2(sgn * s * 0.85, -s * 0.8)
		var b: Vector2 = c + Vector2(-sgn * s * 0.45, s * 0.75)
		draw_line(a, b, Color(0.85, 0.88, 0.95), s * 0.1)
		draw_line(a, b, Color(1, 1, 1, 0.5), s * 0.03)
		var mid: Vector2 = c + (b - c) * 0.55 + (a - c) * 0.1
		var dir: Vector2 = (a - b).normalized()
		var perp := Vector2(-dir.y, dir.x)
		draw_line(mid - perp * s * 0.28, mid + perp * s * 0.28, gold2, s * 0.09)
		draw_circle(b + dir * s * 0.02, s * 0.1, gold)
	# shield
	var pts := PackedVector2Array([c + Vector2(-s * 0.62, -s * 0.5), c + Vector2(s * 0.62, -s * 0.5), c + Vector2(s * 0.62, s * 0.1), c + Vector2(s * 0.4, s * 0.55), c + Vector2(0, s * 0.85), c + Vector2(-s * 0.4, s * 0.55), c + Vector2(-s * 0.62, s * 0.1)])
	draw_colored_polygon(pts, gold2)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.88)
	draw_colored_polygon(inner, Color(0.55, 0.08, 0.1))
	var inner2 := PackedVector2Array()
	for p in inner:
		inner2.append(c + (p - c) * 0.0 + (p - c) * 1.0)
	# vertical split (half dark red / half royal blue)
	var right := PackedVector2Array([c + Vector2(0, -s * 0.44), c + Vector2(s * 0.54, -s * 0.44), c + Vector2(s * 0.54, s * 0.08), c + Vector2(s * 0.35, s * 0.5), c + Vector2(0, s * 0.76)])
	draw_colored_polygon(right, Color(0.1, 0.2, 0.55))
	# tower on shield
	var tc := c + Vector2(0, s * 0.1)
	draw_rect(Rect2(tc.x - s * 0.2, tc.y - s * 0.35, s * 0.4, s * 0.55), gold)
	for i in 3:
		draw_rect(Rect2(tc.x - s * 0.2 + i * s * 0.16, tc.y - s * 0.46, s * 0.1, s * 0.12), gold)
	draw_rect(Rect2(tc.x - s * 0.07, tc.y - s * 0.02, s * 0.14, s * 0.22), Color(0.12, 0.05, 0.03))
	# crown
	var cr := c + Vector2(0, -s * 0.72)
	var crown := PackedVector2Array([cr + Vector2(-s * 0.4, s * 0.16), cr + Vector2(-s * 0.4, -s * 0.12), cr + Vector2(-s * 0.2, s * 0.02), cr + Vector2(0, -s * 0.22), cr + Vector2(s * 0.2, s * 0.02), cr + Vector2(s * 0.4, -s * 0.12), cr + Vector2(s * 0.4, s * 0.16)])
	draw_colored_polygon(crown, gold)
	draw_rect(Rect2(cr.x - s * 0.4, cr.y + s * 0.1, s * 0.8, s * 0.1), gold2)
	for dx in [-0.4, 0.0, 0.4]:
		draw_circle(cr + Vector2(s * dx, -s * (0.22 if dx == 0.0 else 0.12)), s * 0.055, Color(0.9, 0.15, 0.2))
	# sparkle
	var sp := 0.5 + 0.5 * sin(t * 3.0)
	draw_line(cr + Vector2(s * 0.5, -s * 0.2), cr + Vector2(s * 0.5, -s * 0.2) + Vector2(0, -s * 0.2 * sp), Color(1, 1, 0.8, sp), 2.0)
	draw_line(cr + Vector2(s * 0.5 - s * 0.1 * sp, -s * 0.3), cr + Vector2(s * 0.5 + s * 0.1 * sp, -s * 0.3), Color(1, 1, 0.8, sp), 2.0)
