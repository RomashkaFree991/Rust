extends Control
## Мобильный интерфейс: плавающий джойстик, обзор свайпом, кнопки стрельбы/прицела/перезарядки/осмотра/прыжка/
## 3-го лица, пояс снизу (6 ячеек) и полный инвентарь. Все касания маршрутизируются вручную — работает мультитач.

const SLOT := 86.0
const GAP := 6.0
const LOOK_SENS := 0.16          # градусов на пиксель
const JOY_RADIUS := 95.0
# полоски состояния как в gRust (hud_cl.lua): еда, вода, здоровье
const BAR_W := 250.0
const BAR_H := 34.0
const BAR_SP := 4.0
const BAR_PAD := 4.0
const BARS := [
	["hunger", Color(198 / 255.0, 110 / 255.0, 47 / 255.0, 175 / 255.0), "calories", 500.0],
	["cup_water", Color(69 / 255.0, 149 / 255.0, 205 / 255.0), "hydration", 250.0],
	["health", Color(140 / 255.0, 186 / 255.0, 59 / 255.0, 150 / 255.0), "health", 100.0],
]

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
var btn_view: TouchButton
var game_buttons: Array = []

var hot_slots: Array = []
var inv_open := false
var inv_ui: InventoryUI
var active_slot := -1
var active_item = null

var ammo_label: Label
var ammo_icon: TextureRect
var toast: Label
var toast_t := 0.0
var hit_t := 0.0
var hit_head := false
var kill_label: Label
var kill_t := 0.0
var kills := 0
var btn_open: TouchButton
var looking_chest := false
var calories := 412.0
var hydration := 186.0
var health := 100.0
var bar_icons := {}
var snd_open: AudioStream
var snd_close: AudioStream

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
	btn_view = _mk_btn(ic.call("rotate"), "3 ЛИЦО", 40.0)
	btn_inv = _mk_btn(ic.call("backpack"), "", 40.0)
	btn_open = _mk_btn(ic.call("open"), "ОТКРЫТЬ", 48.0)
	btn_open.accent = Color(0.35, 0.5, 0.2)
	btn_open.visible = false
	btn_open.pressed.connect(func(): open_loot())
	for k in ["hunger", "cup_water", "health"]:
		bar_icons[k] = ic.call(k)
	snd_open = load("res://assets/sounds/box_open.wav")
	snd_close = load("res://assets/sounds/box_close.wav")
	btn_aim.accent = Color(0.2, 0.5, 0.8)
	btn_view.accent = Color(0.2, 0.5, 0.8)
	game_buttons = [btn_fire, btn_fire_l, btn_aim, btn_reload, btn_inspect, btn_jump, btn_view, btn_open]

	btn_fire.pressed.connect(func(): player.viewmodel.set_trigger(true))
	btn_fire.released.connect(func(): _fire_released())
	btn_fire_l.pressed.connect(func(): player.viewmodel.set_trigger(true))
	btn_fire_l.released.connect(func(): _fire_released())
	btn_aim.pressed.connect(func(): player.viewmodel.toggle_aim())
	btn_reload.pressed.connect(func(): player.viewmodel.reload(inv))
	btn_inspect.pressed.connect(func(): player.viewmodel.inspect())
	btn_jump.pressed.connect(func(): player.jump())
	btn_view.pressed.connect(func():
		player.set_third_person(not player.third_person)
		btn_view.toggled = player.third_person)
	btn_inv.pressed.connect(func(): toggle_inventory())

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
	toast = _outlined(26)
	kill_label = _outlined(24)
	kill_label.add_theme_color_override("font_color", Color(1, 0.45, 0.35))
	# инвентарь поверх всего
	inv_ui = InventoryUI.new()
	inv_ui.visible = false
	add_child(inv_ui)

	get_viewport().size_changed.connect(_layout)

func _outlined(fs: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l

func bind(p: Player, i: Inventory) -> void:
	player = p
	inv = i
	inv.changed.connect(_on_inv_changed)
	inv.attire_changed.connect(func(): player.apply_attire(inv.worn()))
	player.viewmodel.ammo_changed.connect(_refresh)
	inv_ui.setup(inv, self)
	_layout()
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
	_place(btn_view, Vector2(w - 60 - m, 60 + m))
	_place(btn_fire_l, Vector2(110 + m, h - 470))
	var hb_w := Inventory.HOTBAR * SLOT + (Inventory.HOTBAR - 1) * GAP
	var x0 := (w - hb_w) * 0.5
	var y0 := h - SLOT - 14.0
	for i in hot_slots.size():
		hot_slots[i].position = Vector2(x0 + i * (SLOT + GAP), y0)
	_place(btn_inv, Vector2(x0 - 58, y0 + SLOT * 0.5))
	var bars_top := h - 14.0 - 3 * (BAR_H + BAR_SP)
	ammo_label.position = Vector2(w - 250 - m, bars_top - 50)
	ammo_label.size = Vector2(200, 46)
	ammo_icon.position = Vector2(w - 48 - m, bars_top - 48)
	_place(btn_open, Vector2(w * 0.5, h * 0.66))
	toast.position = Vector2(0, h * 0.62)
	toast.size = Vector2(w, 40)
	kill_label.position = Vector2(0, h * 0.3)
	kill_label.size = Vector2(w, 40)
	if inv_ui and inv:
		inv_ui.layout(vs)
		# кнопка инвентаря в режиме инвентаря — у пояса
		if inv_open:
			var bx: float = inv_ui.slots[Inventory.HOTBAR - 1].position.x + SLOT + 50
			_place(btn_inv, Vector2(bx, inv_ui.slots[0].position.y + 33))

func _input(event: InputEvent) -> void:
	if player == null:
		return
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
			KEY_V: btn_view.pressed.emit()
			KEY_SPACE: player.jump()
			KEY_TAB: toggle_inventory()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6: _tap_hotbar(event.keycode - KEY_1)

func _touch_down(idx: int, p: Vector2) -> void:
	if btn_inv.contains(p):
		touches[idx] = {"type": "btn", "b": btn_inv}
		btn_inv.press()
		return
	if inv_open:
		inv_ui.touch_down(idx, p)
		touches[idx] = {"type": "inv"}
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
		return
	touches[idx] = {"type": "look"}

func _touch_drag(idx: int, p: Vector2, rel: Vector2) -> void:
	var t = touches.get(idx)
	if t == null:
		return
	match t.type:
		"inv":
			inv_ui.touch_drag(idx, p, rel)
		"joy":
			joy_pos = p
			var d := joy_pos - joy_center
			if d.length() > JOY_RADIUS * 1.6:
				joy_center = joy_pos - d.normalized() * JOY_RADIUS * 1.6
		"look":
			player.add_look(rel * LOOK_SENS * _look_mul())
		"btn":
			# стрельба с одновременным наведением (как в мобильных шутерах)
			if t.b == btn_fire or t.b == btn_fire_l:
				player.add_look(rel * LOOK_SENS * _look_mul())

func _look_mul() -> float:
	return 0.55 if player.viewmodel.aiming else 1.0

func _touch_up(idx: int, p: Vector2) -> void:
	var t = touches.get(idx)
	touches.erase(idx)
	if t == null:
		return
	if t.type == "btn":
		t.b.release()
	elif t.type == "inv":
		inv_ui.touch_up(idx, p)
	elif t.type == "joy":
		joy_idx = -1

func _process(delta: float) -> void:
	if player == null:
		return
	var mv := Vector2.ZERO
	if joy_idx != -1:
		var d := (joy_pos - joy_center) / JOY_RADIUS
		if d.length() > 1.0:
			d = d.normalized()
		mv = d
	var k := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if k != Vector2.ZERO:
		mv = k.normalized()
	player.move_input = mv if not inv_open else Vector2.ZERO
	btn_aim.toggled = player.viewmodel.aiming
	btn_aim.queue_redraw()
	if toast_t > 0.0:
		toast_t -= delta
		toast.modulate.a = clamp(toast_t, 0.0, 1.0)
	if kill_t > 0.0:
		kill_t -= delta
		kill_label.modulate.a = clamp(kill_t, 0.0, 1.0)
	if hit_t > 0.0:
		hit_t -= delta
	calories = max(0.0, calories - delta * 0.12)
	hydration = max(0.0, hydration - delta * 0.18)
	looking_chest = player.looking_at_chest()
	btn_open.visible = looking_chest and not inv_open
	queue_redraw()
	_refresh_ammo()

func show_hitmarker(headshot := false, killed := false) -> void:
	hit_t = 0.22
	hit_head = headshot
	if killed:
		kills += 1
		kill_label.text = "УБИТ%s  (всего: %d)" % [" В ГОЛОВУ" if headshot else "", kills]
		kill_t = 2.0

func _draw() -> void:
	if inv_open:
		return
	var vs := get_viewport_rect().size
	var c := vs * 0.5
	if player and not player.viewmodel.aiming:
		draw_circle(c, 3.0, Color(1, 1, 1, 0.85))
		draw_arc(c, 3.5, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.0, true)
	if hit_t > 0.0:
		var a: float = clamp(hit_t / 0.22, 0.0, 1.0)
		var col := Color(1, 0.25, 0.2, a) if hit_head else Color(1, 1, 1, a)
		var r := 1.3 if hit_head else 1.0
		for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + s * 7.0 * r, c + s * 17.0 * r, col, 3.0, true)
	_draw_bars(vs)
	# джойстик
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

func _draw_bars(vs: Vector2) -> void:
	var f := get_theme_default_font()
	for i in BARS.size():
		var d: Array = BARS[i]
		var x := vs.x - 14.0 - BAR_W
		var y := vs.y - 14.0 - (BAR_H + BAR_SP) * (i + 1) + BAR_SP
		SlotView.draw_panel(self, Rect2(x, y, BAR_W, BAR_H), Color(106 / 255.0, 104 / 255.0, 94 / 255.0, 75 / 255.0))
		var ip := 6.0
		var isz := BAR_H - ip * 2.0
		draw_texture_rect(bar_icons[d[0]], Rect2(x + ip + 1, y + ip + 1, isz, isz), false, Color(0, 0, 0, 100 / 255.0))
		draw_texture_rect(bar_icons[d[0]], Rect2(x + ip, y + ip, isz, isz), false, Color(190 / 255.0, 180 / 255.0, 170 / 255.0, 150 / 255.0))
		var v: float = get(d[2])
		var frac: float = clamp(v / d[3], 0.0, 1.0)
		var bx := x + BAR_H - 2.0
		SlotView.draw_panel(self, Rect2(bx, y + BAR_PAD, (BAR_W - BAR_H - BAR_PAD) * frac, BAR_H - BAR_PAD * 2.0), d[1])
		var t := str(int(ceil(v)))
		draw_string(f, Vector2(bx + 10 + 1, y + BAR_H * 0.5 + 8 + 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, 0.4))
		draw_string(f, Vector2(bx + 10, y + BAR_H * 0.5 + 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(231 / 255.0, 219 / 255.0, 210 / 255.0, 215 / 255.0))

func open_loot() -> void:
	if inv_open:
		return
	_play(snd_open)
	player.body.play_use()
	toggle_inventory(true)

func _play(st: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = st
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func toggle_inventory(loot := false) -> void:
	if inv_open and inv_ui.looting:
		_play(snd_close)
	inv_open = not inv_open
	inv_ui.visible = inv_open
	inv_ui.sel = -1
	inv_ui.set_looting(inv_open and loot)
	btn_inv.visible = not inv_open
	for b in game_buttons:
		b.visible = not inv_open
		if b.held:
			b.release()
	for s in hot_slots:
		s.visible = not inv_open
	ammo_label.visible = not inv_open
	ammo_icon.visible = not inv_open
	player.viewmodel.set_trigger(false)
	if joy_idx != -1:
		touches.erase(joy_idx)
		joy_idx = -1
	move_child(btn_inv, get_child_count() - 1)
	_layout()
	inv_ui.sync_weapon()
	inv_ui.refresh()

func tap_hotbar_from_inventory(i: int) -> void:
	_tap_hotbar_equip(i)
	inv_ui.sync_weapon()

func _tap_hotbar(i: int) -> void:
	if inv_open:
		return
	_tap_hotbar_equip(i)

func _tap_hotbar_equip(i: int) -> void:
	var it = inv.get_item(i)
	if active_slot == i:
		_set_active(-1)
	elif it != null and Items.is_weapon(it.id):
		_set_active(i)

func _set_active(i: int) -> void:
	active_slot = i
	var it = inv.get_item(i) if i != -1 else null
	active_item = it
	player.equip_item(it)
	if it != null:
		toast.text = Items.get_def(it.id).name
		toast_t = 1.6
	_update_slots()

func _on_inv_changed() -> void:
	# если оружие убрали из активной ячейки или положили новое — переэкипировать
	if active_slot != -1:
		var it = inv.get_item(active_slot)
		if not is_same(it, active_item):
			if it != null and Items.is_weapon(it.id):
				_set_active(active_slot)
			else:
				_set_active(-1)
			if inv_ui:
				inv_ui.sync_weapon()
	_update_slots()

func _update_slots() -> void:
	for s in hot_slots:
		s.set_item(inv.get_item(s.index))
		s.active = s.index == active_slot
		s.queue_redraw()
	if inv_ui and inv_open:
		inv_ui.refresh()

func _refresh() -> void:
	for s in hot_slots:
		s.queue_redraw()
	_refresh_ammo()

func _refresh_ammo() -> void:
	var vm := player.viewmodel
	if vm.has_weapon() and not vm.is_melee() and not inv_open:
		var d := vm.def
		ammo_label.text = "%d  /  %d" % [vm.item.ammo, inv.count(d.ammo)]
		ammo_icon.texture = load(Items.get_def(d.ammo).icon)
		ammo_label.visible = true
		ammo_icon.visible = true
	else:
		ammo_label.visible = false
		ammo_icon.visible = false
