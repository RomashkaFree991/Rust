extends Control
class_name SlotView
## Ячейка инвентаря / хотбара в стиле Rust.

var index := 0
var item = null
var selected := false      # выбрана для перемещения (инвентарь)
var active := false        # оружие в руках
var hotkey := ""
var _icons := {}

func contains(p: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(p)

func set_item(it) -> void:
	item = it
	queue_redraw()

func _icon(path: String) -> Texture2D:
	if not _icons.has(path):
		_icons[path] = load(path)
	return _icons[path]

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := Color(0.2, 0.2, 0.2, 0.62)
	if active:
		bg = Color(0.17, 0.42, 0.62, 0.78)
	draw_rect(r, bg)
	if selected:
		draw_rect(r.grow(-2), Color(0.95, 0.75, 0.3, 1.0), false, 3.0)
	if hotkey != "":
		draw_string(get_theme_default_font(), Vector2(6, 18), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35))
	if item == null:
		return
	var d := Items.get_def(item.id)
	if d.is_empty():
		return
	var pad := size.x * 0.1
	draw_texture_rect(_icon(d.icon), Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0), false)
	var f := get_theme_default_font()
	var fs := int(size.y * 0.2)
	if d.type == "weapon":
		# полоска с количеством патронов как в Rust
		var t: String = str(item.get("ammo", 0))
		draw_string(f, Vector2(6, size.y - 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
	else:
		var t := "x%d" % item.amount
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(size.x - w - 6, size.y - 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
