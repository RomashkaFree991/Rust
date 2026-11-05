extends Node3D
class_name Projectile
## Снаряд: ракета / граната 40 мм / брошенная взрывчатка (rust_bomb: fuse, stick, impact, beep) / стрела.
## Летит с гравитацией; по попаданию вызывает owner_player.projectile_hit(self, hit).

var vel := Vector3.ZERO
var grav := 9.8
var fuse := 3.0              # секунд до взрыва (для mode "bomb"); <= 0 — только по удару
var mode := "bomb"           # bomb, rocket, grenade, arrow
var bounce := true           # граната отскакивает
var stick := false           # C4 / сачель прилипают к поверхности (rust_bomb SetStick)
var impact := false          # взрыв при ударе (40 мм, ракета)
var t := 0.0
var owner_player
var damage := 80.0
var radius := 4.0
var ammo_id := ""
var exclude: Array = []
var beep_sound := ""
var beep_delay := 0.8
var explode_sound := ""
var stuck := false
var _next_beep := 0.8
var _bounces := 0
var _loop: AudioStreamPlayer3D
var max_life := 30.0

func _ready() -> void:
	_next_beep = beep_delay
	if mode == "rocket":
		_loop = FX.sound(self, Vector3.ZERO, "res://assets/sounds/rocket-engine-loop.wav", -2.0, 10.0, self)
		var trail := FX._particles(20, 0.6, Color(0.6, 0.6, 0.6, 0.5), FX.soft_tex(), 0.3, 0.7, false)
		trail.local_coords = false
		trail.gravity = Vector3(0, 0.5, 0)
		trail.initial_velocity_min = 0.0
		trail.initial_velocity_max = 0.3
		add_child(trail)
		var fl := OmniLight3D.new()
		fl.light_color = Color(1, 0.6, 0.2)
		fl.light_energy = 1.5
		fl.omni_range = 3.0
		add_child(fl)
	elif mode == "arrow":
		FX.sound(get_parent(), global_position, "res://assets/sounds/bow-arrow-flight.wav", -10.0, 4.0)

func _physics_process(delta: float) -> void:
	t += delta
	if beep_sound != "":
		_next_beep -= delta
		if _next_beep <= 0.0:
			_next_beep = beep_delay
			FX.sound(get_parent(), global_position, beep_sound, -2.0, 6.0)
	if mode == "bomb" and fuse > 0.0 and t >= fuse:
		_detonate()
		return
	if t > max_life:
		queue_free()
		return
	if stuck:
		return
	vel += Vector3.DOWN * grav * delta
	var nxt := global_position + vel * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, nxt)
	q.exclude = exclude
	q.collision_mask = 3
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		global_position = nxt
		if vel.length() > 0.5 and mode != "bomb":
			_face(vel)
		elif mode == "bomb" and not stuck:
			rotate_object_local(Vector3.RIGHT, delta * 8.0)
		return
	if mode == "arrow":
		global_position = h.position
		stuck = true
		if owner_player:
			owner_player.projectile_hit(self, h)
		_attach_to(h.collider)
		var tw := create_tween()
		tw.tween_interval(15.0)
		tw.tween_callback(queue_free)
		return
	if impact or mode in ["rocket", "grenade"]:
		global_position = h.position + h.normal * 0.05
		_detonate()
		return
	if stick:
		# прилипнуть: ориентировать по нормали (rust_bomb PhysicsCollide)
		stuck = true
		global_position = h.position + h.normal * 0.02
		var n: Vector3 = h.normal
		var up := Vector3.FORWARD if abs(n.y) > 0.9 else Vector3.UP
		global_basis = Basis.looking_at(-n, up) * Basis(Vector3.RIGHT, -PI * 0.5)
		_attach_to(h.collider)
		FX.sound(get_parent(), global_position, "res://assets/sounds/c4-stick.mp3", 0.0, 6.0)
		if h.collider is Node and (h.collider as Node).has_meta("bot"):
			pass
		return
	# отскок
	vel = vel.bounce(h.normal) * 0.4
	global_position = h.position + h.normal * 0.04
	_bounces += 1
	if _bounces < 4 and vel.length() > 1.5:
		FX.sound(get_parent(), global_position, "res://assets/sounds/beancan-grenade-bounce-%d.mp3" % (1 + randi() % 2), -4.0, 6.0)
	if vel.length() < 0.6:
		stuck = true   # лежит на земле

func _face(v: Vector3) -> void:
	var up := Vector3.UP if abs(v.normalized().y) < 0.99 else Vector3.FORWARD
	look_at(global_position + v, up)

## Прилипшая стрела / C4 двигается вместе с ботом или ящиком
func _attach_to(col: Object) -> void:
	if col is Node3D and (col is RigidBody3D or (col as Node).has_meta("bot")):
		var gt := global_transform
		var target: Node3D = col
		if (col as Node).has_meta("bot"):
			target = col   # хитбокс кости бота — следует за скелетом
		get_parent().remove_child(self)
		target.add_child(self)
		global_transform = gt

func _detonate() -> void:
	set_physics_process(false)
	if _loop:
		_loop.stop()
	if owner_player:
		owner_player.projectile_explode(self)
	queue_free()
