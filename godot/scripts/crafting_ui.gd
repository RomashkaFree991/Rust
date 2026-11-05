extends Control
class_name CraftingUI
## Меню крафта — перенос gRust (gamemode/core/ui/crafting/crafting_cl.lua, vgui/crafting/*):
## слева категории с количеством предметов, по центру сетка предметов категории,
## справа карточка: иконка, название, время/количество, описание, таблица рецепта,
## количество (− / + / MAX) и кнопка CRAFT. Крафт бесплатный и мгновенный.

const BG := Color(37 / 255.0, 36 / 255.0, 31 / 255.0, 0.93)
const TEXT := Color(231 / 255.0, 219 / 255.0, 210 / 255.0)
const PANEL := Color(106 / 255.0, 104 / 255.0, 94 / 255.0, 75 / 255.0)
const SECONDARY := Color(24 / 255.0, 94 / 255.0, 141 / 255.0, 210 / 255.0)
const CAT_SEL := Color(49 / 255.0, 116 / 255.0, 175 / 255.0, 0.9)
const COUNT_COL := Color(55 / 255.0, 150 / 255.0, 167 / 255.0, 0.9)
const CRAFT_COL := Color(97 / 255.0, 119 / 255.0, 59 / 255.0)
const CELL := 70.0

var inv: Inventory
var hud
var category := "Weapons"
var selected := "assault_rifle"
var qty := 1
var scroll := 0.0
var icons := {}
var rects := {}          # имя -> Rect2 (для касаний)
var cat_rects := []      # [Rect2, name]
var item_rects := []     # [Rect2, id]
var grid_rect := Rect2()
var touch_start := Vector2.ZERO
var touch_scroll := 0.0
var touch_idx := -1
var dragged := false
var flash_t := 0.0
var flash_text := ""
var snd_craft: AudioStream
var snd_blip: AudioStream

func setup(p_inv: Inventory, p_hud) -> void:
	inv = p_inv
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	snd_craft = load("res://assets/sounds/notify.wav")
	snd_blip = load("res://assets/sounds/blip.wav")

func _icon(p: String) -> Texture2D:
	if not icons.has(p):
		icons[p] = load(p) if ResourceLoader.exists(p) else null
	return icons[p]

func _items() -> Array:
	return Items.in_category(category)

func _process(delta: float) -> void:
	if visible:
		if flash_t > 0.0:
			flash_t -= delta
		queue_redraw()

func _panel(r: Rect2, col := PANEL) -> void:
	SlotView.draw_panel(self, r, col)

func _text(t: String, p: Vector2, fs: int, col := TEXT, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(get_theme_default_font(), p, t, align, w, fs, col)

func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), BG)
	var f := get_theme_default_font()
	var m := 12.0
	var top := 70.0
	# вкладки (как TabButtons в gRust)
	var tw := 260.0
	rects["tab_inv"] = Rect2(vs.x * 0.5 - tw - 4, 8, tw, 52)
	rects["tab_craft"] = Rect2(vs.x * 0.5 + 4, 8, tw, 52)
	_panel(rects.tab_inv, Color(250 / 255.0, 240 / 255.0, 220 / 255.0, 40 / 255.0))
	_panel(rects.tab_craft, SECONDARY)
	_text("ИНВЕНТАРЬ", rects.tab_inv.position + Vector2(0, 36), 26, TEXT, tw, HORIZONTAL_ALIGNMENT_CENTER)
	_text("КРАФТ", rects.tab_craft.position + Vector2(0, 36), 26, TEXT, tw, HORIZONTAL_ALIGNMENT_CENTER)
	rects["close"] = Rect2(vs.x - 72, 8, 60, 52)
	draw_rect(rects.close, Color(0.6, 0.2, 0.15, 0.7))
	var c: Vector2 = rects.close.get_center()
	draw_line(c - Vector2(12, 12), c + Vector2(12, 12), Color.WHITE, 4)
	draw_line(c - Vector2(12, -12), c + Vector2(12, -12), Color.WHITE, 4)
	# категории
	var cw := 230.0
	var ch: float = min(42.0, (vs.y - top - m) / Items.CATEGORIES.size() - 2.0)
	cat_rects.clear()
	_panel(Rect2(m, top, cw, vs.y - top - m))
	for i in Items.CATEGORIES.size():
		var cat: Array = Items.CATEGORIES[i]
		var r := Rect2(m, top + i * (ch + 2), cw, ch)
		cat_rects.append([r, cat[0]])
		if cat[0] == category:
			_panel(r, CAT_SEL)
		var ic := _icon("res://assets/icons/cat_%s.png" % cat[1])
		if ic:
			draw_texture_rect(ic, Rect2(r.position + Vector2(10, 7), Vector2(ch - 14, ch - 14)), false, Color(TEXT, 0.6))
		_text(String(cat[0]).to_upper(), r.position + Vector2(ch + 6, ch * 0.5 + 8), 20, Color(TEXT, 0.85 if cat[0] == category else 0.55))
		_text(str(Items.in_category(cat[0]).size()), r.position + Vector2(0, ch * 0.5 + 8), 20, COUNT_COL, cw - 10, HORIZONTAL_ALIGNMENT_RIGHT)
	# сетка предметов
	var gx := m + cw + 8
	var right_w: float = clamp(vs.x * 0.36, 380.0, 520.0)
	var gw := vs.x - gx - right_w - m - 8
	grid_rect = Rect2(gx, top, gw, vs.y - top - m)
	_panel(grid_rect)
	var cols: int = max(1, int((gw - 8) / (CELL + 6)))
	var list := _items()
	var rows := int(ceil(list.size() / float(cols)))
	var max_scroll: float = max(0.0, rows * (CELL + 6) + 8 - grid_rect.size.y)
	scroll = clamp(scroll, 0.0, max_scroll)
	item_rects.clear()
	for i in list.size():
		var id: String = list[i]
		var r := Rect2(gx + 8 + (i % cols) * (CELL + 6), top + 8 + (i / cols) * (CELL + 6) - scroll, CELL, CELL)
		if r.end.y < top or r.position.y > grid_rect.end.y:
			continue
		var rr := r.intersection(grid_rect)
		item_rects.append([rr, id])
		_panel(r, SECONDARY if id == selected else PANEL)
		var d := Items.get_def(id)
		var ic := _icon(d.get("icon", ""))
		if ic and r.position.y >= top - 1 and r.end.y <= grid_rect.end.y + 1:
			draw_texture_rect(ic, r.grow(-7), false, Color(0.85, 0.85, 0.85))
		if int(d.get("craft_amount", 1)) > 1:
			_text("x%d" % d.craft_amount, r.position + Vector2(0, CELL - 6), 15, Color(1, 1, 1, 0.5), CELL - 5, HORIZONTAL_ALIGNMENT_RIGHT)
	# карточка предмета
	var rx := vs.x - right_w - m
	var d := Items.get_def(selected)
	if d.is_empty():
		return
	var info := Rect2(rx, top, right_w, vs.y - top - m - 236)
	_panel(info)
	var ic := _icon(d.get("icon", ""))
	if ic:
		draw_texture_rect(ic, Rect2(info.position + Vector2(10, 10), Vector2(90, 90)), false)
	var name_w := right_w - 210
	_text(String(d.name).to_upper(), info.position + Vector2(108, 46), 28, TEXT, name_w)
	_tier_badge(Rect2(info.position + Vector2(108, 62), Vector2(130, 28)), int(d.get("tier", 0)))
	# статы: время и количество
	_stat(Rect2(info.end.x - 96, info.position.y + 10, 86, 38), "0.0", "stopwatch")
	_stat(Rect2(info.end.x - 96, info.position.y + 54, 86, 38), str(int(d.get("craft_amount", 1))), "authorize")
	# описание
	var desc: String = d.get("desc", "")
	var lines := _wrap(desc, right_w - 24, 17)
	var y := info.position.y + 128
	for ln in lines:
		if y > info.end.y - 8:
			break
		_text(ln, Vector2(info.position.x + 12, y), 17, Color(TEXT, 0.85))
		y += 21
	# рецепт
	var rp := Rect2(rx, info.end.y + 6, right_w, 230)
	_panel(rp)
	var cx := [rp.position.x + 12, rp.position.x + 80, rp.position.x + right_w - 150, rp.position.x + right_w - 74]
	_text("КОЛ-ВО", Vector2(cx[0], rp.position.y + 24), 15, Color(TEXT, 0.5))
	_text("ПРЕДМЕТ", Vector2(cx[1], rp.position.y + 24), 15, Color(TEXT, 0.5))
	_text("ВСЕГО", Vector2(cx[2], rp.position.y + 24), 15, Color(TEXT, 0.5))
	_text("ЕСТЬ", Vector2(cx[3], rp.position.y + 24), 15, Color(TEXT, 0.5))
	var recipe: Array = d.get("recipe", [])
	for i in min(recipe.size(), 4):
		var ry: float = rp.position.y + 52 + i * 26
		var ing: String = recipe[i][0]
		var nm: String = Items.get_def(ing).get("name", ing.replace("_", " ").capitalize())
		_text(str(int(recipe[i][1])), Vector2(cx[0], ry), 18)
		_text(nm, Vector2(cx[1], ry), 18, TEXT, cx[2] - cx[1] - 8)
		_text(str(int(recipe[i][1]) * qty), Vector2(cx[2], ry), 18)
		_text(str(inv.count(ing)), Vector2(cx[3], ry), 18, Color(0.6, 0.85, 0.4))
	if recipe.is_empty():
		_text("Без рецепта", Vector2(cx[1], rp.position.y + 52), 18, Color(TEXT, 0.6))
	_text("Крафт бесплатный и мгновенный", Vector2(rp.position.x + 12, rp.position.y + 160), 15, Color(0.6, 0.85, 0.4, 0.8))
	# количество и кнопка
	var by := rp.end.y - 50
	rects["minus"] = Rect2(rp.position.x + 10, by, 50, 42)
	rects["plus"] = Rect2(rp.position.x + 126, by, 50, 42)
	rects["max"] = Rect2(rp.position.x + 182, by, 50, 42)
	rects["craft"] = Rect2(rp.end.x - 150, by, 140, 42)
	for k in ["minus", "plus", "max"]:
		_panel(rects[k], Color(250 / 255.0, 240 / 255.0, 220 / 255.0, 40 / 255.0))
	_icon_in(rects.minus, "res://assets/icons/cat_subtract.png")
	_icon_in(rects.plus, "res://assets/icons/cat_add.png")
	_icon_in(rects.max, "res://assets/icons/cat_maximum.png")
	_panel(Rect2(rp.position.x + 64, by, 58, 42), Color(0, 0, 0, 0.3))
	_text(str(qty), Vector2(rp.position.x + 64, by + 30), 24, TEXT, 58, HORIZONTAL_ALIGNMENT_CENTER)
	draw_rect(rects.craft, CRAFT_COL)
	_text("CRAFT", rects.craft.position + Vector2(0, 31), 26, Color(0.75, 0.9, 0.5), 140, HORIZONTAL_ALIGNMENT_CENTER)
	if flash_t > 0.0:
		_text(flash_text, Vector2(rx, rp.position.y - 12), 22, Color(0.6, 0.9, 0.4, clamp(flash_t, 0.0, 1.0)), right_w, HORIZONTAL_ALIGNMENT_CENTER)

func _icon_in(r: Rect2, p: String) -> void:
	var ic := _icon(p)
	if ic:
		draw_texture_rect(ic, r.grow(-9), false, Color(TEXT, 0.8))

func _stat(r: Rect2, t: String, icon: String) -> void:
	draw_rect(r, Color(0, 0, 0, 75 / 255.0))
	_text(t, r.position + Vector2(0, r.size.y * 0.5 + 9), 22, Color(TEXT, 0.6), r.size.x - 8, HORIZONTAL_ALIGNMENT_RIGHT)
	var ic := _icon("res://assets/icons/cat_%s.png" % icon)
	if ic:
		draw_texture_rect(ic, Rect2(r.position + Vector2(6, 6), Vector2(r.size.y - 12, r.size.y - 12)), false, Color(TEXT, 0.6))

## Плашка верстака (WorkbenchTier в gRust)
func _tier_badge(r: Rect2, tier: int) -> void:
	if tier <= 0:
		return
	var cols := {1: [Color(68 / 255.0, 80 / 255.0, 42 / 255.0), Color(139 / 255.0, 206 / 255.0, 2 / 255.0)],
		2: [Color(36 / 255.0, 62 / 255.0, 84 / 255.0), Color(3 / 255.0, 122 / 255.0, 204 / 255.0)],
		3: [Color(105 / 255.0, 68 / 255.0, 42 / 255.0), Color(204 / 255.0, 93 / 255.0, 7 / 255.0)]}
	var cc: Array = cols.get(tier, cols[1])
	draw_rect(r, cc[0])
	_text("ВЕРСТАК %d" % tier, r.position + Vector2(0, 21), 16, cc[1], r.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func _wrap(t: String, w: float, fs: int) -> Array:
	var f := get_theme_default_font()
	var res := []
	for para in t.split("\n"):
		var line := ""
		for word in para.split(" "):
			var test := word if line == "" else line + " " + word
			if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w and line != "":
				res.append(line)
				line = word
			else:
				line = test
		res.append(line)
	return res

func _play(st: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = st
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func craft() -> void:
	var d := Items.get_def(selected)
	if d.is_empty():
		return
	var n: int = int(d.get("craft_amount", 1)) * qty
	var left := inv.give(selected, n)
	_play(snd_craft)
	flash_text = ("Скрафчено: %s x%d" % [d.name, n - left]) if left < n else "Нет места в инвентаре"
	flash_t = 2.0

# ---- касания (вызывает HUD) ----

func touch_down(idx: int, p: Vector2) -> void:
	touch_idx = idx
	touch_start = p
	touch_scroll = scroll
	dragged = false

func touch_drag(idx: int, p: Vector2, _rel: Vector2) -> void:
	if idx != touch_idx:
		return
	if grid_rect.has_point(touch_start) and (p - touch_start).length() > 10.0:
		dragged = true
		scroll = touch_scroll - (p.y - touch_start.y)

func touch_up(idx: int, p: Vector2) -> void:
	if idx != touch_idx:
		return
	touch_idx = -1
	if dragged:
		return
	if rects.get("close", Rect2()).has_point(p):
		hud.close_crafting()
		return
	if rects.get("tab_inv", Rect2()).has_point(p):
		hud.close_crafting()
		hud.toggle_inventory()
		return
	for cr in cat_rects:
		if cr[0].has_point(p):
			category = cr[1]
			scroll = 0.0
			var l := _items()
			if l.size() > 0 and not selected in l:
				selected = l[0]
			qty = 1
			_play(snd_blip)
			return
	for ir in item_rects:
		if ir[0].has_point(p):
			selected = ir[1]
			qty = 1
			_play(snd_blip)
			return
	if rects.get("minus", Rect2()).has_point(p):
		qty = max(1, qty - 1)
	elif rects.get("plus", Rect2()).has_point(p):
		qty = min(10, qty + 1)
	elif rects.get("max", Rect2()).has_point(p):
		qty = 10
	elif rects.get("craft", Rect2()).has_point(p):
		craft()
