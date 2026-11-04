extends Control
## Мобильный интерфейс: плавающий джойстик, обзор свайпом, кнопки стрельбы/прицела/перезарядки/осмотра/прыжка,
## хотбар снизу (6 ячеек) и инвентарь. Все касания маршрутизируются вручную — работает мультитач.

const SLOT := 86.0
const GAP := 6.0
const LOOK_SENS := 0.16          # градусов на пиксель
const JOY_RADIUS := 95.0

var player: Player
var inv: Inventory

var touches := {}                # index -> {type, ...}
var joy_idx := -1
var joy_center := Vector2.ZERO
var joy_pos := Vector2.ZERO

var btn_fire: TouchButton
var btn_fire_l: TouchButton
var btn_aim: TouchButton
var btn_reload: TouchButton
var btn_inspect: TouchButton
var btn_jump: TouchButton
var btn_inv: TouchButton
var game_buttons: Array = []

var hot_slots: Array = []
var main_slots: Array = []
var inv_open := false
var inv_panel: Control
var dim: ColorRect
var inv_title: Label
var inv_info: Label
var sel_slot := -1
var active_slot := -1
var active_item = null

var ammo_label: Label
var ammo_icon: TextureRect
var toast: Label
var toast_t := 0.0
var hit_t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := func(n: String) -> Texture2D: return load("res://assets/icons/%s.png" % n)

	btn_fire = _mk_btn(ic.call("ammunition"), "ОГОНЬ", 80.0)
	btn_fire_l = _mk_btn(ic.call("ammunition"), "", 52.0)
	btn_aim = _mk_btn(ic.call("target"), "ПРИЦЕЛ", 50.0)
	btn_reload = _mk_btn(ic.call("refresh"), "ПЕРЕЗАР.", 46.0)
	btn_inspect = _mk_btn(ic.call("examine"), "ОСМОТР", 44.0)
	btn_jump = _mk_btn(ic.call("upgrade"), "ПРЫЖОК", 46.0)
	btn_inv = _mk_btn(ic.call("backpack"), "", 40.0)
	btn_aim.accent = Color(0.2, 0.5, 0.8)
	game_buttons = [btn_fire, btn_fire_l, btn_aim, btn_reload, btn_inspect, btn_jump]

	btn_fire.pressed.connect(func(): player.viewmodel.set_trigger(true))
	btn_fire.released.connect(func(): _fire_released())
	btn_fire_l.pressed.connect(func(): player.viewmodel.set_trigger(true))
	btn_fire_l.released.connect(func(): _fire_released())
	btn_aim.pressed.connect(func():
		player.viewmodel.toggle_aim()
		btn_aim.toggled = player.viewmodel.aiming)
	btn_reload.pressed.connect(func(): player.viewmodel.reload(inv))
	btn_inspect.pressed.connect(func(): player.viewmodel.inspect())
	btn_jump.pressed.connect(func(): player.jump())
	btn_inv.pressed.connect(func(): _toggle_inventory())

	# инвентарь (под хотбаром рисуется затемнение)
	inv_panel = Control.new()
	inv_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_panel.visible = false
	add_child(inv_panel)
	move_child(inv_panel, 0)
	dim = ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.05, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_panel.add_child(dim)
	inv_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_title = Label.new()
	inv_title.text = "ИНВЕНТАРЬ"
	inv_title.add_theme_font_size_override("font_size", 30)
	inv_title.add_theme_color_override("font_color", Color(0.85, 0.82, 0.76))
	inv_panel.add_child(inv_title)
	inv_info = Label.new()
	inv_info.add_theme_font_size_override("font_size", 20)
	inv_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	inv_info.add_theme_color_override("font_color", Color(0.85, 0.82, 0.76))
	inv_panel.add_child(inv_info)
	for i in Inventory.MAIN:
		var s := SlotView.new()
		s.index = Inventory.HOTBAR + i
		s.size = Vector2(SLOT, SLOT)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inv_panel.add_child(s)
		main_slots.append(s)

	for i in Inventory.HOTBAR:
		var s := SlotView.new()
		s.index = i
		s.hotkey = str(i + 1)
		s.size = Vector2(SLOT, SLOT)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(s)
		hot_slots.append(s)

	ammo_label = Label.new()
	ammo_label.add_theme_font_size_override("font_size", 34)
	ammo_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	ammo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	ammo_label.add_theme_constant_override("outline_size", 6)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ammo_label)
	ammo_icon = TextureRect.new()
	ammo_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ammo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ammo_icon.size = Vector2(44, 44)
	add_child(ammo_icon)
	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 26)
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("outline_size", 6)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(toast)

	get_viewport().size_changed.connect(_layout)
	_layout()

func bind(p: Player, i: Inventory) -> void:
	player = p
	inv = i
	inv.changed.connect(_on_inv_changed)
	player.viewmodel.ammo_changed.connect(_refresh)
	_on_inv_changed()

func _mk_btn(icon: Texture2D, text: String, r: float) -> TouchButton:
	var b := TouchButton.new()
	b.setup(icon, text, r)
	add_child(b)
	return b

func _fire_released() -> void:
	if not btn_fire.held and not btn_fire_l.held:
		player.viewmodel.set_trigger(false)

func _place(b: Control, center: Vector2) -> void:
	b.position = center - b.size * 0.5

func _layout() -> void:
	var vs := get_viewport_rect().size
	var w := vs.x
	var h := vs.y
	var m := 28.0
	_place(btn_fire, Vector2(w - 150 - m, h - 260))
	_place(btn_aim, Vector2(w - 330 - m, h - 330))
	_place(btn_reload, Vector2(w - 85 - m, h - 440))
	_place(btn_inspect, Vector2(w - 215 - m, h - 470))
	_place(btn_jump, Vector2(w - 310 - m, h - 190))
	_place(btn_fire_l, Vector2(110 + m, h - 470))
	inv_panel.position = Vector2.ZERO
	inv_panel.size = vs
	dim.position = Vector2.ZERO
	dim.size = vs
	var hb_w := Inventory.HOTBAR * SLOT + (Inventory.HOTBAR - 1) * GAP
	var x0 := (w - hb_w) * 0.5
	var y0 := h - SLOT - 14.0
	for i in hot_slots.size():
		hot_slots[i].position = Vector2(x0 + i * (SLOT + GAP), y0)
	_place(btn_inv, Vector2(x0 - 58, y0 + SLOT * 0.5))
	var gy := y0 - 26.0 - 4 * SLOT - 3 * GAP
	for i in main_slots.size():
		var cx := i % 6
		var cy := i / 6
		main_slots[i].position = Vector2(x0 + cx * (SLOT + GAP), gy + cy * (SLOT + GAP))
	inv_title.position = Vector2(x0, gy - 46)
	inv_info.position = Vector2(x0 + hb_w + 24, gy)
	inv_info.size = Vector2(max(160.0, w - (x0 + hb_w + 24) - 24), 300)
	ammo_label.position = Vector2(w - 260 - m, h - 70)
	ammo_label.size = Vector2(200, 46)
	ammo_icon.position = Vector2(w - 54 - m, h - 68)
	toast.position = Vector2(0, h * 0.62)
	toast.size = Vector2(w, 40)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position, event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		# удобство для теста на ПК
		match event.keycode:
			KEY_R: player.viewmodel.reload(inv)
			KEY_F: player.viewmodel.inspect()
			KEY_SPACE: player.jump()
			KEY_TAB: _toggle_inventory()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6: _tap_hotbar(event.keycode - KEY_1)

func _touch_down(idx: int, p: Vector2) -> void:
	if btn_inv.contains(p):
		touches[idx] = {"type": "btn", "b": btn_inv}
		btn_inv.press()
		return
	if inv_open:
		for s in hot_slots + main_slots:
			if s.contains(p):
				_tap_inv_slot(s.index)
				break
		touches[idx] = {"type": "none"}
		return
	for b in game_buttons:
		if b.contains(p):
			touches[idx] = {"type": "btn", "b": b}
			b.press()
			return
	for s in hot_slots:
		if s.contains(p):
			_tap_hotbar(s.index)
			touches[idx] = {"type": "none"}
			return
	var w := get_viewport_rect().size.x
	if p.x < w * 0.45 and joy_idx == -1:
		joy_idx = idx
		joy_center = p
		joy_pos = p
		touches[idx] = {"type": "joy"}
		queue_redraw()
		return
	touches[idx] = {"type": "look"}

func _touch_drag(idx: int, p: Vector2, rel: Vector2) -> void:
	var t = touches.get(idx)
	if t == null:
		return
	match t.type:
		"joy":
			joy_pos = p
			var d := joy_pos - joy_center
			if d.length() > JOY_RADIUS * 1.6:
				# база джойстика тянется за пальцем
				joy_center = joy_pos - d.normalized() * JOY_RADIUS * 1.6
			queue_redraw()
		"look":
			player.add_look(rel * LOOK_SENS * _look_mul())
		"btn":
			# стрельба с одновременным наведением (как в мобильных шутерах)
			if t.b == btn_fire or t.b == btn_fire_l:
				player.add_look(rel * LOOK_SENS * _look_mul())

func _look_mul() -> float:
	return 0.55 if player.viewmodel.aiming else 1.0

func _touch_up(idx: int, _p: Vector2) -> void:
	var t = touches.get(idx)
	touches.erase(idx)
	if t == null:
		return
	if t.type == "btn":
		t.b.release()
	elif t.type == "joy":
		joy_idx = -1
		queue_redraw()

func _process(delta: float) -> void:
	if player == null:
		return
	var mv := Vector2.ZERO
	if joy_idx != -1:
		var d := (joy_pos - joy_center) / JOY_RADIUS
		if d.length() > 1.0:
			d = d.normalized()
		mv = d
	# клавиатура для теста на ПК
	var k := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if k != Vector2.ZERO:
		mv = k.normalized()
	player.move_input = mv
	btn_aim.toggled = player.viewmodel.aiming
	btn_aim.queue_redraw()
	if toast_t > 0.0:
		toast_t -= delta
		toast.modulate.a = clamp(toast_t, 0.0, 1.0)
	if hit_t > 0.0:
		hit_t -= delta
	queue_redraw()
	_refresh_ammo()

func show_hitmarker() -> void:
	hit_t = 0.18

func _draw() -> void:
	var vs := get_viewport_rect().size
	var c := vs * 0.5
	# прицел — точка как в Rust
	if not inv_open and player and not player.viewmodel.aiming:
		draw_circle(c, 3.0, Color(1, 1, 1, 0.85))
		draw_arc(c, 3.5, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.0, true)
	if hit_t > 0.0:
		var a := clamp(hit_t / 0.18, 0.0, 1.0)
		for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + s * 7.0, c + s * 16.0, Color(1, 1, 1, a), 2.5, true)
	# джойстик
	if not inv_open:
		if joy_idx != -1:
			draw_circle(joy_center, JOY_RADIUS, Color(0, 0, 0, 0.28))
			draw_arc(joy_center, JOY_RADIUS, 0, TAU, 64, Color(1, 1, 1, 0.35), 3.0, true)
			var d := joy_pos - joy_center
			if d.length() > JOY_RADIUS:
				d = d.normalized() * JOY_RADIUS
			draw_circle(joy_center + d, 42.0, Color(1, 1, 1, 0.5))
		else:
			var hint := Vector2(180, vs.y - 200)
			draw_circle(hint, JOY_RADIUS, Color(0, 0, 0, 0.16))
			draw_arc(hint, JOY_RADIUS, 0, TAU, 64, Color(1, 1, 1, 0.18), 2.0, true)
			draw_circle(hint, 42.0, Color(1, 1, 1, 0.22))

func _toggle_inventory() -> void:
	inv_open = not inv_open
	inv_panel.visible = inv_open
	sel_slot = -1
	for b in game_buttons:
		b.visible = not inv_open
		if b.held:
			b.release()
	player.viewmodel.set_trigger(false)
	if joy_idx != -1:
		touches.erase(joy_idx)
		joy_idx = -1
	_update_slots()
	_update_info()

func _tap_inv_slot(i: int) -> void:
	if sel_slot == -1:
		if inv.get_item(i) != null:
			sel_slot = i
	else:
		if i != sel_slot:
			inv.move(sel_slot, i)
		sel_slot = -1
	_update_slots()
	_update_info()

func _update_info() -> void:
	var it = inv.get_item(sel_slot) if sel_slot != -1 else null
	if it == null:
		inv_info.text = "Нажмите на предмет, затем на ячейку, чтобы переложить его.\n\nПредметы в нижнем ряду (хотбар) можно взять в руки."
	else:
		var d := Items.get_def(it.id)
		var extra := ""
		if d.type == "weapon":
			extra = "\nМагазин: %d / %d\nТемп: %d выстр/мин" % [it.ammo, d.clip, int(d.rpm)]
		else:
			extra = "\nКоличество: %d" % it.amount
		inv_info.text = "%s\n%s%s" % [d.name, d.desc, extra]

func _tap_hotbar(i: int) -> void:
	if inv_open:
		_tap_inv_slot(i)
		return
	var it = inv.get_item(i)
	if active_slot == i:
		_set_active(-1)
	elif it != null and Items.get_def(it.id).get("type") == "weapon":
		_set_active(i)

func _set_active(i: int) -> void:
	active_slot = i
	var it = inv.get_item(i) if i != -1 else null
	active_item = it
	if it == null:
		player.viewmodel.equip({})
	else:
		player.viewmodel.equip(it)
		toast.text = Items.get_def(it.id).name
		toast_t = 1.6
	_update_slots()

func _on_inv_changed() -> void:
	# если оружие убрали из активной ячейки или положили новое — переэкипировать
	if active_slot != -1:
		var it = inv.get_item(active_slot)
		if not is_same(it, active_item):
			if it != null and Items.get_def(it.id).get("type") == "weapon":
				_set_active(active_slot)
			else:
				_set_active(-1)
	_update_slots()

func _update_slots() -> void:
	for s in hot_slots + main_slots:
		s.set_item(inv.get_item(s.index))
		s.selected = s.index == sel_slot
		s.active = s.index == active_slot
		s.queue_redraw()

func _refresh() -> void:
	for s in hot_slots:
		s.queue_redraw()
	_refresh_ammo()

func _refresh_ammo() -> void:
	var vm := player.viewmodel
	if vm.has_weapon():
		var d := vm.def
		ammo_label.text = "%d  /  %d" % [vm.item.ammo, inv.count(d.ammo)]
		ammo_icon.texture = load(Items.get_def(d.ammo).icon)
		ammo_label.visible = true
		ammo_icon.visible = true
	else:
		ammo_label.visible = false
		ammo_icon.visible = false
