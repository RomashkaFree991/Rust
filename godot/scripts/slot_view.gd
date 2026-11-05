extends Control
class_name SlotView
## Ячейка инвентаря / пояса — перенос gRust.Slot (gamemode/core/vgui/inventory/slot_cl.lua):
## фон — текстура ui/background.png с оттенком (106,104,94,75), выделенная — Secondary (24,94,141,210),
## иконка (200,200,200), количество — справа внизу (255,255,255,100), у оружия — полоска состояния слева.

const PANEL_TINT := Color(106 / 255.0, 104 / 255.0, 94 / 255.0, 75 / 255.0)
const SECONDARY := Color(24 / 255.0, 94 / 255.0, 141 / 255.0, 210 / 255.0)
const PICK := Color(195 / 255.0, 60 / 255.0, 40 / 255.0, 0.55)
const ICON_COL := Color(200 / 255.0, 200 / 255.0, 200 / 255.0)
const TEXT_COL := Color(1, 1, 1, 100 / 255.0)

static var panel_tex: Texture2D

var index := 0
var item = null
var selected := false      # выбрана для перемещения (инвентарь)
var active := false        # в руках
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

static func draw_panel(ci: CanvasItem, r: Rect2, col: Color) -> void:
	if panel_tex == null:
		panel_tex = load("res://assets/icons/background.png")
	ci.draw_texture_rect(panel_tex, r, true, col)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_panel(self, r, SECONDARY if active else PANEL_TINT)
	if selected:
		draw_rect(r, PICK)
	var k := size.y / 120.0           # масштаб как gRust.Hud.Scaling для слота 120px
	if hotkey != "":
		draw_string(get_theme_default_font(), Vector2(6, 16), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.25))
	if item == null:
		return
	var d := Items.get_def(item.id)
	if d.is_empty():
		return
	var pad := 10.0 * k
	draw_texture_rect(_icon(d.icon), Rect2(Vector2(pad, pad - 6.0 * k), size - Vector2(pad, pad) * 2.0), false, ICON_COL)
	var f := get_theme_default_font()
	var fs := int(max(13.0, 34.0 * k))
	var text := ""
	if d.type == "weapon" and d.get("kind", "") in ["gun", "shotgun", "launcher"]:
		text = str(item.get("ammo", 0))
	elif item.get("amount", 1) > 1:
		text = "x%d" % item.amount
	if d.type == "weapon" and d.get("kind", "") in ["gun", "shotgun", "launcher", "bow", "melee"]:
		# полоска состояния
		var bw := 8.0 * k
		draw_rect(Rect2(0, 0, bw, size.y), Color(83 / 255.0, 102 / 255.0, 51 / 255.0, 100 / 255.0))
		var cond: float = item.get("condition", 1.0)
		draw_rect(Rect2(0, size.y - size.y * cond, bw, size.y * cond), Color(103 / 255.0, 129 / 255.0, 58 / 255.0))
	if text != "":
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(size.x - w - 6.0 * k, size.y - 6.0 * k), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT_COL)
