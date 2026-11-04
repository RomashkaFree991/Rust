class_name TouchControls
extends Control
## Mobile on-screen controls: floating joystick (left half), look by dragging
## (right half), buttons FIRE / JUMP / RELOAD / AIM / VIEW.
## Dragging the FIRE button also turns the camera (shoot and aim at once).

signal button_pressed(name: String)

const JOY_RADIUS := 110.0

var move_vector := Vector2.ZERO
var look_delta := Vector2.ZERO
var fire_held := false
var aim_on := false

var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_index := -1
var _btn_touches := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _u() -> float:
	return maxf(size.y, 1.0) / 720.0


func _buttons() -> Dictionary:
	var s := size
	var u := _u()
	return {
		"fire": [Vector2(s.x - 180 * u, s.y - 200 * u), 90 * u, "ОГОНЬ"],
		"jump": [Vector2(s.x - 360 * u, s.y - 110 * u), 62 * u, "ПРЫЖОК"],
		"reload": [Vector2(s.x - 110 * u, s.y - 390 * u), 52 * u, "ПЕРЕЗ."],
		"aim": [Vector2(s.x - 330 * u, s.y - 300 * u), 55 * u, "ПРИЦЕЛ"],
		"view": [Vector2(s.x - 70 * u, 70 * u), 42 * u, "ВИД"],
	}


func _hit_button(p: Vector2) -> String:
	var bs := _buttons()
	for k in bs:
		var c: Vector2 = bs[k][0]
		var r: float = bs[k][1]
		if p.distance_to(c) <= r * 1.15:
			return k
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var b := _hit_button(e.position)
			if b != "":
				_btn_touches[e.index] = b
				if b == "fire":
					fire_held = true
				elif b == "aim":
					aim_on = not aim_on
				else:
					button_pressed.emit(b)
			elif e.position.x < size.x * 0.45 and _joy_index == -1:
				_joy_index = e.index
				_joy_center = e.position
				_joy_pos = e.position
			elif _look_index == -1:
				_look_index = e.index
		else:
			if _btn_touches.has(e.index):
				if _btn_touches[e.index] == "fire":
					fire_held = false
				_btn_touches.erase(e.index)
			if e.index == _joy_index:
				_joy_index = -1
				move_vector = Vector2.ZERO
			if e.index == _look_index:
				_look_index = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_index:
			var r := JOY_RADIUS * _u()
			_joy_pos = d.position
			var off := _joy_pos - _joy_center
			if off.length() > r:
				_joy_center = _joy_pos - off.normalized() * r
			move_vector = (_joy_pos - _joy_center) / r
			queue_redraw()
		elif d.index == _look_index or _btn_touches.get(d.index, "") == "fire":
			look_delta += d.relative


func _draw() -> void:
	var u := _u()
	var font := ThemeDB.fallback_font
	# joystick
	var r := JOY_RADIUS * u
	var center := _joy_center if _joy_index != -1 else Vector2(200 * u, size.y - 190 * u)
	var knob := _joy_pos if _joy_index != -1 else center
	draw_circle(center, r, Color(1, 1, 1, 0.12))
	draw_arc(center, r, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0 * u)
	draw_circle(knob, r * 0.42, Color(1, 1, 1, 0.4))
	# buttons
	var bs := _buttons()
	for k in bs:
		var c: Vector2 = bs[k][0]
		var br: float = bs[k][1]
		var pressed: bool = k in _btn_touches.values() or (k == "aim" and aim_on)
		var col := Color(0.85, 0.35, 0.15, 0.55) if k == "fire" else Color(1, 1, 1, 0.18)
		if pressed:
			col = col.lightened(0.4)
			col.a = 0.75
		draw_circle(c, br, col)
		draw_arc(c, br, 0, TAU, 40, Color(1, 1, 1, 0.5), 2.0 * u)
		var fs := int(maxf(12.0, 20.0 * u))
		var label: String = bs[k][2]
		draw_string(font, c + Vector2(-br, fs * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, fs, Color(1, 1, 1, 0.9))
