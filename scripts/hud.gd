class_name Hud
extends Control
## Crosshair, ammo counter, hints.

var ammo := 30
var reserve := 120
var reloading := false
var ads := false
var hint := ""
var hit_marker := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _process(delta: float) -> void:
	hit_marker = maxf(0.0, hit_marker - delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var u := maxf(size.y, 1.0) / 720.0
	var c := size / 2.0
	if not ads:
		var g := 6.0 * u
		var l := 10.0 * u
		var col := Color(1, 1, 1, 0.85)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * g, c + d * (g + l), col, 2.0 * u)
		draw_circle(c, 1.5 * u, col)
	if hit_marker > 0.0:
		var hc := Color(1, 0.3, 0.2, hit_marker)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + d * 8.0 * u, c + d * 16.0 * u, hc, 2.5 * u)
	var fs := int(30 * u)
	var txt := "%d / %d" % [ammo, reserve]
	if reloading:
		txt = "ПЕРЕЗАРЯДКА..."
	elif ammo == 0:
		txt = "ПУСТО  (R)"
	var col2 := Color(1, 0.4, 0.3) if ammo == 0 and not reloading else Color(1, 1, 1)
	draw_string(font, Vector2(c.x - 200 * u, size.y - 30 * u), txt, HORIZONTAL_ALIGNMENT_CENTER, 400 * u, fs, col2)
	if hint != "":
		var y := 24.0 * u
		for line in hint.split("\n"):
			draw_string(font, Vector2(16 * u, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u), Color(1, 1, 1, 0.75))
			y += 20.0 * u
