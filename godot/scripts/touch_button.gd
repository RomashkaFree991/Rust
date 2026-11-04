extends Control
class_name TouchButton
## Круглая кнопка для мультитача. Нажатия приходят из HUD (маршрутизатор касаний).

signal pressed
signal released

var icon: Texture2D
var label := ""
var held := false
var toggled := false
var radius := 60.0
var accent := Color(0.85, 0.32, 0.18)

func setup(p_icon: Texture2D, p_label: String, p_radius: float) -> void:
	icon = p_icon
	label = p_label
	radius = p_radius
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func contains(p: Vector2) -> bool:
	return visible and (p - (global_position + size * 0.5)).length() <= radius * 1.12

func press() -> void:
	held = true
	queue_redraw()
	pressed.emit()

func release() -> void:
	held = false
	queue_redraw()
	released.emit()

func _draw() -> void:
	var c := size * 0.5
	var bg := Color(0.08, 0.08, 0.08, 0.55)
	if held:
		bg = Color(accent.r, accent.g, accent.b, 0.75)
	elif toggled:
		bg = Color(accent.r, accent.g, accent.b, 0.45)
	draw_circle(c, radius, bg)
	draw_arc(c, radius - 1.5, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	if icon:
		var s := radius * 1.05
		draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5 - Vector2(0, 6 if label != "" else 0), Vector2(s, s)), false, Color(1, 1, 1, 0.92))
	if label != "":
		var f := get_theme_default_font()
		var fs := int(radius * 0.28)
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, Vector2(c.x - w * 0.5, c.y + (radius * 0.68 if icon else fs * 0.35)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
