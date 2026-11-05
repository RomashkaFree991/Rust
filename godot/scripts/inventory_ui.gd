extends Control
class_name InventoryUI
## Полный инвентарь как в gRust (scripts/gamemodes/rust/gamemode/core/ui/inventory/inventory_cl.lua):
## слева — модель персонажа (крутится пальцем) с защитой и 7 ячейками одежды,
## по центру — информация о предмете, рюкзак 6×4 и пояс 6 ячеек.
## Управление: перетащить предмет пальцем; или тап по предмету, затем тап по ячейке;
## двойной тап по одежде — надеть/снять.
## Обвесы (как gRust ItemInfo: инвентарь предмета-оружия из SetSlots + SWEP.Attachments): у выбранного оружия
## под описанием — ячейки обвесов и кнопки типа патронов. Обвес: перетащить на ячейку, или тап по обвесу
## и тап по ячейке, или двойной тап по обвесу; тап по занятой ячейке — снять обвес в инвентарь.

const S := 58.0           # ячейка рюкзака/пояса/ящика
const AS := 52.0          # ячейка одежды
const G := 5.0
const BG := Color(37 / 255.0, 36 / 255.0, 31 / 255.0, 0.93)
const TEXT := Color(231 / 255.0, 219 / 255.0, 210 / 255.0)   # gRust.Colors.Text

var inv: Inventory
var hud
var slots: Array = []            # все SlotView (индекс = номер ячейки)
var item_title: Label
var item_info: Label
var stats_box: VBoxContainer
var stat_labels := {}
var preview_rect: Rect2
var preview_container: SubViewportContainer
var preview_vp: SubViewport
var preview_char: Character
var preview_yaw := 35.0
var hint: Label
var info_bg: ColorRect

var sel := -1
var last_tap_slot := -1
var last_tap_time := 0.0
var drag_idx := -1               # индекс касания, которое тащит предмет
var drag_from := -1
var drag_start := Vector2.ZERO
var drag_pos := Vector2.ZERO
var dragging := false
var rot_idx := -1
var close_rect := Rect2()
var craft_rect := Rect2()
var overlay: Control
var looting := false
var loot_title := "LARGE WOOD BOX"
var snd_move: Dictionary = {}
var mod_weapon_idx := -1         # оружие, чьи обвесы показаны
var mod_rects: Array = []        # [Rect2, "mod"|"ammo", индекс/id]
var mod_panel := Rect2()
var mod_touch: Array = []
const MOD_H := 128.0

func setup(p_inv: Inventory, p_hud) -> void:
	inv = p_inv
	hud = p_hud
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var tex := TextureRect.new()
	tex.texture = load("res://assets/icons/background_linear.png")
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.modulate = Color(BG.r, BG.g, BG.b, 0.6)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tex)

	# превью персонажа в отдельном мире
	preview_container = SubViewportContainer.new()
	preview_container.stretch = true
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview_container)
	preview_vp = SubViewport.new()
	preview_vp.own_world_3d = true
	preview_vp.transparent_bg = true
	preview_vp.msaa_3d = Viewport.MSAA_2X
	preview_container.add_child(preview_vp)
	var root := Node3D.new()
	preview_vp.add_child(root)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.73, 0.7)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-30, 35, 0)
	l.light_energy = 0.9
	root.add_child(l)
	var l2 := DirectionalLight3D.new()
	l2.rotation_degrees = Vector3(-10, -150, 0)
	l2.light_energy = 0.35
	root.add_child(l2)
	preview_char = Character.new()
	root.add_child(preview_char)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.position = Vector3(0, 1.08, 6.0)
	cam.rotation_degrees.x = -2.0
	root.add_child(cam)
	cam.current = true

	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 14)
	add_child(stats_box)
	for st in [["bullet", "Пули"], ["stab", "Ближний бой"], ["bite", "Укусы"], ["radiation", "Радиация"], ["freezing", "Холод"], ["explosion", "Взрывы"]]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		var lab := Label.new()
		lab.add_theme_font_size_override("font_size", 22)
		lab.add_theme_color_override("font_color", TEXT)
		lab.custom_minimum_size = Vector2(70, 0)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(lab)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/icons/%s.png" % st[0])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(30, 30)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(ic)
		stats_box.add_child(row)
		stat_labels[st[0]] = [lab, ic]

	info_bg = ColorRect.new()
	info_bg.color = Color(0.5, 0.48, 0.42, 0.12)
	info_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info_bg)
	item_title = _label(30)
	item_info = _label(19)
	item_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint = _label(17)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.text = "Перетащите предмет пальцем или нажмите на предмет, затем на ячейку.\n\nДвойной тап по одежде — надеть / снять.\nПри открытом ящике двойной тап — переложить в ящик / из ящика.\n\nКрутите персонажа пальцем."

	for i in Inventory.SIZE:
		var s := SlotView.new()
		s.index = i
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < Inventory.HOTBAR:
			s.hotkey = str(i + 1)
		add_child(s)
		slots.append(s)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	for k in ["gun", "cloth", "metal", "stone"]:
		snd_move[k] = load("res://assets/sounds/drop_%s_1.wav" % k)
	inv.changed.connect(refresh)
	inv.attire_changed.connect(_on_attire)
	_on_attire()
	refresh()

func _label(fs: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", TEXT)
	add_child(l)
	return l

func layout(vs: Vector2) -> void:
	size = vs
	var mid_w := 6 * S + 5 * G
	var left_w := 7 * AS + 6 * G
	var gap := 24.0
	var right_w := mid_w
	var total := left_w + gap + mid_w + gap + right_w
	var x0: float = max(12.0, (vs.x - total) * 0.5)
	var xm := x0 + left_w + gap
	var xr := xm + mid_w + gap
	var belt_y := vs.y - S - 12.0
	for i in Inventory.HOTBAR:
		_place(i, Vector2(xm + i * (S + G), belt_y), S)
	var gy := belt_y - 16.0 - (4 * S + 3 * G)
	for i in Inventory.MAIN:
		_place(Inventory.MAIN_START + i, Vector2(xm + (i % 6) * (S + G), gy + (i / 6) * (S + G)), S)
	var ay := belt_y + S - AS
	for i in Inventory.WEAR:
		_place(Inventory.WEAR_START + i, Vector2(x0 + i * (AS + G), ay), AS)
	# ящик: 6 x 8 справа, низ по уровню пояса
	var ly := belt_y + S - (8 * S + 7 * G)
	for i in Inventory.LOOT:
		_place(Inventory.LOOT_START + i, Vector2(xr + (i % 6) * (S + G), ly + (i / 6) * (S + G)), S)
		slots[Inventory.LOOT_START + i].visible = looting
	item_title.position = Vector2(xm, 10)
	item_title.size = Vector2(mid_w, 40)
	item_info.position = Vector2(xm, 54)
	item_info.size = Vector2(mid_w, gy - 54 - 44 - MOD_H)
	item_info.clip_contents = true
	mod_panel = Rect2(xm, gy - 44 - MOD_H + 4, mid_w, MOD_H - 8)
	preview_rect = Rect2(x0, 10, left_w, ay - 34)
	preview_container.position = preview_rect.position
	preview_container.size = preview_rect.size
	stats_box.position = Vector2(x0 + left_w - 110, 66)
	stats_box.size = Vector2(100, 300)
	hint.position = Vector2(xr, 70)
	hint.size = Vector2(max(120.0, vs.x - xr - 20), 300)
	hint.visible = not looting
	close_rect = Rect2(vs.x - 76, 10, 60, 60)
	craft_rect = Rect2(vs.x - 76 - 170, 10, 160, 60)
	info_bg.position = item_info.position - Vector2(8, 48)
	info_bg.size = Vector2(item_info.size.x + 16, item_info.size.y + 52)
	_redraw()

func set_looting(on: bool) -> void:
	looting = on
	sel = -1
	layout(size)
	refresh()

func _play_move(i: int) -> void:
	var it = inv.get_item(i)
	var t: String = "metal"
	if it != null:
		t = Items.get_def(it.id).get("type", "")
	var k := "cloth" if t == "attire" else ("gun" if t == "weapon" else ("stone" if t == "melee" else "metal"))
	var p := AudioStreamPlayer.new()
	p.stream = snd_move[k]
	p.volume_db = -6.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _place(i: int, p: Vector2, sz: float) -> void:
	slots[i].position = p
	slots[i].size = Vector2(sz, sz)

func refresh() -> void:
	for s in slots:
		s.set_item(inv.get_item(s.index))
		s.selected = s.index == sel
		s.active = hud != null and s.index == hud.active_slot
		s.queue_redraw()
	_update_info()
	_redraw()

func _on_attire() -> void:
	var worn := inv.worn()
	preview_char.set_attire(worn)
	var it = inv.get_item(hud.active_slot) if hud and hud.active_slot != -1 else null
	preview_char.set_meta("weapon_item", it if it != null else {})
	preview_char.set_weapon(it.id if it != null else "")
	var p := inv.protection()
	var vals := {"bullet": p, "stab": 0.0, "bite": 0.0, "radiation": 0.0, "freezing": 0.0, "explosion": 0.0}
	for id in worn:
		var d := Items.get_def(id)
		vals.stab += d.get("melee_prot", 0.0)
		vals.freezing += 0.04
		vals.bite += 0.02
		vals.explosion += d.get("prot", 0.0) * 0.3
	for k in stat_labels:
		var v: float = min(vals[k], 0.8)
		stat_labels[k][0].text = ("%d%%" % roundi(v * 100)) if v > 0.0 else ""
		stat_labels[k][1].modulate = TEXT if v > 0.0 else Color(0.8, 0.8, 0.8, 0.12)

func sync_weapon() -> void:
	_on_attire()

func _update_info() -> void:
	var idx := sel
	if idx == -1 and hud and hud.active_slot != -1:
		idx = hud.active_slot
	var it = inv.get_item(idx) if idx != -1 else null
	if it != null and _moddable(it):
		mod_weapon_idx = idx
	elif it != null and (Attachments.is_attachment(it.id) or Items.get_def(it.id).get("type") == "ammo"):
		if not _moddable(inv.get_item(mod_weapon_idx)):
			mod_weapon_idx = -1
	else:
		mod_weapon_idx = -1
	if it == null:
		item_title.text = ""
		item_info.text = ""
		return
	var d := Items.get_def(it.id)
	if d.get("type") == "weapon" and not Attachments.weapon_info(it.id).is_empty():
		d = Attachments.modded_def(d, it)
	if d.get("type") == "weapon" and it.has("ammo_type"):
		d = d.duplicate()
		d["ammo"] = it.ammo_type
	item_title.text = d.name.to_upper()
	var t := ""
	match d.type:
		"weapon":
			match d.get("kind", ""):
				"gun", "shotgun", "launcher":
					t += "Урон: %d   Магазин: %d / %d\nТемп: %d выстр/мин   %s" % [d.damage, it.get("ammo", 0), d.clip, int(d.rpm), "Автомат" if d.auto else "Полуавтомат"]
					t += "\nПатроны: %s (%d)" % [Items.get_def(d.ammo).get("name", ""), inv.count(d.ammo)]
				"bow":
					t += "Урон: %d   Стрелы: %d" % [d.damage, inv.count(d.ammo)]
				"melee":
					t += "Урон: %d   Ударов в минуту: %d" % [d.damage, int(d.rpm)]
				"throw":
					t += "Урон: %d   Радиус: %.1f м   Запал: %.1f с\nКоличество: %d" % [d.damage, d.radius, d.fuse, it.amount]
				"medical":
					t += "Лечение: %d   Количество: %d" % [d.get("heal", 0), it.amount]
		"melee":
			pass
		"attire":
			t += "Защита от пуль: %d%%   Ближний бой: %d%%" % [roundi(d.prot * 100), roundi(d.melee_prot * 100)]
		_:
			t += "Количество: %d / %d" % [it.amount, Items.max_stack(it.id)]
	# сначала характеристики, затем описание; текст не налезает на панель обвесов
	t = (t + "\n\n" + String(d.desc)) if t != "" else String(d.desc)
	var lh: float = item_info.get_theme_font("font").get_height(19) + 2.0
	item_info.max_lines_visible = max(1, int(item_info.size.y / lh))
	item_info.text = t

# ---------- обвесы и патроны ----------

func _moddable(it) -> bool:
	if it == null or not it is Dictionary:
		return false
	var d := Items.get_def(it.id)
	if d.get("type") != "weapon":
		return false
	return not Attachments.weapon_info(it.id).is_empty() or d.get("ammo_types", []).size() > 1

func _mod_weapon():
	var it = inv.get_item(mod_weapon_idx)
	return it if _moddable(it) else null

func _layout_mods() -> void:
	mod_rects.clear()
	var it = _mod_weapon()
	if it == null:
		return
	var d := Items.get_def(it.id)
	var ms := 50.0
	var y := mod_panel.position.y + 22
	var n := Attachments.slot_count(it.id)
	for i in n:
		mod_rects.append([Rect2(mod_panel.position.x + i * (ms + 5), y, ms, ms), "mod", i])
	var at: Array = d.get("ammo_types", [])
	if at.size() > 1 or (at.size() == 1 and n == 0):
		var ax: float = mod_panel.position.x + (n * (ms + 5) + 16 if n > 0 else 0.0)
		var aw: float = min(50.0, (mod_panel.end.x - ax) / max(at.size(), 1) - 4)
		for i in at.size():
			mod_rects.append([Rect2(ax + i * (aw + 4), y, aw, ms), "ammo", at[i]])

func _icon_tex(id: String) -> Texture2D:
	var p: String = Items.get_def(id).get("icon", "")
	return load(p) if p != "" and ResourceLoader.exists(p) else null

func _draw_mods(o: Control, f: Font) -> void:
	_layout_mods()
	var it = _mod_weapon()
	if it == null:
		return
	var mods := Attachments.mods_of(it)
	var w := Attachments.weapon_info(it.id)
	var d := Items.get_def(it.id)
	var cur_ammo: String = it.get("ammo_type", d.get("ammo", ""))
	if Attachments.slot_count(it.id) > 0:
		o.draw_string(f, mod_panel.position + Vector2(2, 16), "ОБВЕСЫ: " + String(d.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, mod_panel.size.x * 0.6, 15, Color(TEXT, 0.7))
	var has_ammo := false
	for r in mod_rects:
		var rect: Rect2 = r[0]
		if r[1] == "mod":
			var i: int = r[2]
			SlotView.draw_panel(o, rect, SlotView.PANEL_TINT)
			if i < mods.size():
				var t := _icon_tex(mods[i])
				if t:
					o.draw_texture_rect(t, rect.grow(-4), false, SlotView.ICON_COL)
			else:
				o.draw_rect(rect.grow(-1), Color(1, 1, 1, 0.06), false, 1.0)
				o.draw_string(f, rect.position + Vector2(0, rect.size.y * 0.5 + 6), "+", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 22, Color(1, 1, 1, 0.18))
		else:
			has_ammo = true
			var aid: String = r[2]
			var selc := aid == cur_ammo
			SlotView.draw_panel(o, rect, SlotView.SECONDARY if selc else SlotView.PANEL_TINT)
			var t := _icon_tex(aid)
			if t:
				o.draw_texture_rect(t, rect.grow(-5), false, SlotView.ICON_COL if inv.count(aid) > 0 or selc else Color(1, 1, 1, 0.25))
			var cnt := str(inv.count(aid))
			o.draw_string(f, Vector2(rect.position.x, rect.end.y - 3), cnt, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 3, 13, SlotView.TEXT_COL)
	if has_ammo:
		var ar: Rect2 = mod_rects[-1][0]
		for r in mod_rects:
			if r[1] == "ammo":
				ar = r[0]
				break
		o.draw_string(f, Vector2(ar.position.x, mod_panel.position.y + 16), "ПАТРОНЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(TEXT, 0.7))
	# подсказка с эффектом
	var st := Attachments.stats(it)
	var fx := []
	if st.silenced: fx.append("глушитель")
	if st.scope != "": fx.append("прицел " + st.scope)
	if st.laser: fx.append("ЛЦУ")
	if st.flashlight: fx.append("фонарь")
	if abs(st.recoil_mul - 1.0) > 0.01: fx.append("отдача ×%.2f" % st.recoil_mul)
	if abs(st.damage_mul - 1.0) > 0.01: fx.append("урон ×%.2f" % st.damage_mul)
	if abs(st.rof_mul - 1.0) > 0.01: fx.append("темп ×%.2f" % st.rof_mul)
	if fx.size() > 0:
		o.draw_string(f, Vector2(mod_panel.position.x + 2, mod_panel.end.y - 4), ", ".join(fx), HORIZONTAL_ALIGNMENT_LEFT, mod_panel.size.x, 14, Color(0.6, 0.85, 0.4, 0.9))
	elif w.is_empty() == false and mods.is_empty():
		o.draw_string(f, Vector2(mod_panel.position.x + 2, mod_panel.end.y - 4), "Перетащите обвес на ячейку", HORIZONTAL_ALIGNMENT_LEFT, mod_panel.size.x, 14, Color(TEXT, 0.45))

func _mod_rect_at(p: Vector2) -> Array:
	for r in mod_rects:
		if (r[0] as Rect2).has_point(p):
			return r
	return []

## Оружие с изменёнными обвесами — пересоздать модели в руках и на персонаже
func _weapon_changed() -> void:
	if hud and mod_weapon_idx != -1 and mod_weapon_idx == hud.active_slot and hud.player:
		hud.player.equip_item(inv.get_item(mod_weapon_idx))
	inv.changed.emit()
	sync_weapon()

## Поставить обвес из ячейки src на оружие, чьи обвесы показаны
func _attach_from(src: int) -> bool:
	var w = _mod_weapon()
	var a = inv.get_item(src)
	if w == null or a == null or not Attachments.is_attachment(a.id):
		return false
	if not Attachments.attach(w, a.id):
		return false
	a.amount = int(a.get("amount", 1)) - 1
	if a.amount <= 0:
		inv.slots[src] = null
	_play_snd("res://assets/sounds/mod-attach.wav")
	_weapon_changed()
	return true

func _play_snd(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _mod_tap(r: Array) -> void:
	var w = _mod_weapon()
	if w == null:
		return
	if r[1] == "mod":
		var mods := Attachments.mods_of(w)
		var i: int = r[2]
		if i < mods.size():
			# снять обвес в инвентарь
			if inv.give(mods[i], 1) == 0:
				mods.remove_at(i)
				_play_move(-1)
				_weapon_changed()
		elif sel != -1 and sel != mod_weapon_idx:
			if _attach_from(sel):
				sel = -1
	else:
		var aid: String = r[2]
		var d := Items.get_def(w.id)
		if mod_weapon_idx == hud.active_slot and hud.player and hud.player.viewmodel.has_method("set_ammo_type"):
			hud.player.viewmodel.set_ammo_type(aid)
		elif aid != w.get("ammo_type", d.get("ammo", "")):
			var cur: String = w.get("ammo_type", d.get("ammo", ""))
			if int(w.get("ammo", 0)) > 0:
				inv.give(cur, int(w.ammo))
			w["ammo"] = 0
			w["ammo_type"] = aid
		inv.changed.emit()
	refresh()

func _process(delta: float) -> void:
	if not visible:
		return
	preview_char.rotation_degrees.y = preview_yaw
	if rot_idx == -1:
		preview_yaw += delta * 6.0

func _draw_overlay() -> void:
	var o := overlay
	var f := get_theme_default_font()
	# заголовки
	var mid_x: float = slots[Inventory.MAIN_START].position.x
	o.draw_string(f, Vector2(mid_x + 2, slots[Inventory.MAIN_START].position.y - 10), "ИНВЕНТАРЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TEXT)
	var ax: float = slots[Inventory.WEAR_START].position.x
	o.draw_string(f, Vector2(ax + 2, slots[Inventory.WEAR_START].position.y - 10), "ОДЕЖДА", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(TEXT, 0.7))
	o.draw_string(f, Vector2(preview_rect.end.x - 110, preview_rect.position.y + 40), "PLAYER", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, TEXT)
	if looting:
		var lp: Vector2 = slots[Inventory.LOOT_START].position
		o.draw_string(f, Vector2(lp.x + 2, lp.y - 10), loot_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, TEXT)
	# панель информации: обвесы и патроны выбранного оружия
	_draw_mods(o, f)
	# вкладка крафта
	SlotView.draw_panel(o, craft_rect, Color(250 / 255.0, 240 / 255.0, 220 / 255.0, 40 / 255.0))
	o.draw_string(f, craft_rect.position + Vector2(0, 40), "КРАФТ", HORIZONTAL_ALIGNMENT_CENTER, craft_rect.size.x, 26, TEXT)
	# закрыть
	o.draw_rect(close_rect, Color(0.6, 0.2, 0.15, 0.7))
	var c := close_rect.get_center()
	o.draw_line(c - Vector2(14, 14), c + Vector2(14, 14), Color.WHITE, 4)
	o.draw_line(c - Vector2(14, -14), c + Vector2(14, -14), Color.WHITE, 4)
	# перетаскиваемый предмет
	if dragging and drag_from != -1:
		var it = inv.get_item(drag_from)
		if it != null:
			var tex: Texture2D = load(Items.get_def(it.id).icon)
			o.draw_texture_rect(tex, Rect2(drag_pos - Vector2(40, 40), Vector2(80, 80)), false, Color(1, 1, 1, 0.85))

func _redraw() -> void:
	if overlay:
		overlay.queue_redraw()

func _slot_at(p: Vector2) -> int:
	for s in slots:
		if s.visible and s.get_global_rect().has_point(p):
			return s.index
	return -1

# ---- касания (вызывает HUD) ----

func touch_down(idx: int, p: Vector2) -> bool:
	if close_rect.has_point(p):
		hud.toggle_inventory()
		return true
	if craft_rect.has_point(p):
		hud.open_crafting()
		return true
	var mr := _mod_rect_at(p)
	if not mr.is_empty():
		mod_touch = mr
		return true
	var i := _slot_at(p)
	if i != -1:
		drag_idx = idx
		drag_from = i
		drag_start = p
		drag_pos = p
		dragging = false
		return true
	if preview_rect.has_point(p):
		rot_idx = idx
		return true
	sel = -1
	refresh()
	return true

func touch_drag(idx: int, p: Vector2, rel: Vector2) -> void:
	if idx == rot_idx:
		preview_yaw += rel.x * 0.5
	elif idx == drag_idx:
		drag_pos = p
		if not dragging and (p - drag_start).length() > 14.0 and inv.get_item(drag_from) != null:
			dragging = true
			sel = -1
		_redraw()

func touch_up(idx: int, p: Vector2) -> void:
	if idx == rot_idx:
		rot_idx = -1
		return
	if not mod_touch.is_empty() and idx != drag_idx:
		var r := _mod_rect_at(p)
		if not r.is_empty() and r[1] == mod_touch[1] and r[2] == mod_touch[2]:
			_mod_tap(r)
		mod_touch = []
		return
	if idx != drag_idx:
		return
	drag_idx = -1
	var from := drag_from
	drag_from = -1
	if dragging:
		dragging = false
		var to := _slot_at(p)
		var it_d = inv.get_item(from)
		if (mod_panel.has_point(p) or not _mod_rect_at(p).is_empty()) and it_d != null and Attachments.is_attachment(it_d.id):
			_attach_from(from)
			refresh()
			return
		if to != -1:
			inv.move(from, to)
		elif preview_rect.has_point(p) and not Inventory.is_wear_slot(from):
			inv.quick_toggle_wear(from)
		refresh()
		return
	# тап
	var now := Time.get_ticks_msec() / 1000.0
	if from == last_tap_slot and now - last_tap_time < 0.35 and inv.get_item(from) != null:
		last_tap_slot = -1
		sel = -1
		_play_move(from)
		var dt = inv.get_item(from)
		if dt != null and Attachments.is_attachment(dt.id) and _mod_weapon() != null and _attach_from(from):
			refresh()
			return
		if looting:
			inv.quick_move(from)
		elif not inv.quick_toggle_wear(from) and from < Inventory.HOTBAR:
			hud.tap_hotbar_from_inventory(from)
		refresh()
		return
	last_tap_slot = from
	last_tap_time = now
	if sel == -1:
		if inv.get_item(from) != null:
			sel = from
	elif sel == from:
		sel = -1
	else:
		if inv.move(sel, from):
			_play_move(from)
		sel = -1
	refresh()
