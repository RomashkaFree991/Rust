class_name Player
extends CharacterBody3D
## Player controller: movement, jump, sprint, first/third person camera,
## shooting (hitscan), aiming, reloading, sounds. Works with keyboard+mouse
## and with on-screen touch controls.

const WALK_SPEED := 4.2
const SPRINT_SPEED := 6.8
const JUMP_VELOCITY := 5.2
const GRAVITY := 14.0
const MAG_SIZE := 30
const FIRE_INTERVAL := 0.1
const FOV := 70.0
const ADS_FOV := 55.0
const MOUSE_SENS := 0.0025
const TOUCH_SENS := 0.006

var touch: TouchControls
var hud: Hud
var rig: Rig
var spring: SpringArm3D
var cam3p: Camera3D

var yaw := 0.0
var pitch := 0.0
var ammo := MAG_SIZE
var reserve := 120
var fire_cd := 0.0
var recoil := 0.0
var reload_t := -1.0
var ads_t := 0.0
var sprint_t := 0.0
var third_person := false
var flash_t := 0.0

var _was_on_floor := true
var _fall_speed := 0.0
var _snd := {}
var _step_sounds: Array[AudioStreamWAV] = []
var _decals: Array[Node3D] = []


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	rig = Rig.new()
	add_child(rig)
	rig.footstep.connect(_on_footstep)

	spring = SpringArm3D.new()
	spring.position = Vector3(0.55, 1.7, 0)
	spring.spring_length = 2.6
	var sph := SphereShape3D.new()
	sph.radius = 0.2
	spring.shape = sph
	spring.collision_mask = 1
	add_child(spring)
	spring.add_excluded_object(get_rid())
	cam3p = Camera3D.new()
	cam3p.fov = FOV
	spring.add_child(cam3p)

	_add_sound("shot", Sfx.gunshot(), -4.0, 8)
	_add_sound("empty", Sfx.empty_click(), -6.0)
	_add_sound("mag_out", Sfx.mag_out(), -4.0)
	_add_sound("mag_in", Sfx.mag_in(), -4.0)
	_add_sound("bolt", Sfx.bolt(), -4.0)
	_add_sound("jump", Sfx.jump(), -8.0)
	_add_sound("land", Sfx.land(), -4.0)
	_add_sound("step", Sfx.footstep(1), -10.0, 4)
	_add_sound("impact", Sfx.impact(), -14.0, 6)
	for i in 4:
		_step_sounds.append(Sfx.footstep(100 + i))

	if touch:
		touch.button_pressed.connect(_on_touch_button)
	_set_view(false)
	_update_hud()


func _add_sound(n: String, stream: AudioStream, db: float, poly := 2) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.max_polyphony = poly
	add_child(p)
	_snd[n] = p


func _play(n: String, pitch_var := 0.0) -> void:
	var p: AudioStreamPlayer = _snd[n]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		_apply_look(mm.relative * MOUSE_SENS)
	elif event is InputEventMouseButton and event.pressed and not _touch_active():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("jump"):
		_jump()
	if event.is_action_pressed("reload"):
		_start_reload()
	if event.is_action_pressed("toggle_view"):
		_set_view(not third_person)
	if event.is_action_pressed("toggle_touch") and touch:
		touch.visible = not touch.visible


func _touch_active() -> bool:
	return touch != null and touch.visible


func _on_touch_button(n: String) -> void:
	match n:
		"jump":
			_jump()
		"reload":
			_start_reload()
		"view":
			_set_view(not third_person)


func _apply_look(d: Vector2) -> void:
	var zoom := lerpf(1.0, 0.6, ads_t)
	yaw -= d.x * zoom
	pitch = clampf(pitch - d.y * zoom, deg_to_rad(-80), deg_to_rad(80))


func _set_view(tp: bool) -> void:
	third_person = tp
	rig.fp_camera.current = not tp
	cam3p.current = tp


# ---------------------------------------------------------------- update

func _physics_process(delta: float) -> void:
	if touch:
		_apply_look(touch.look_delta * TOUCH_SENS)
		touch.look_delta = Vector2.ZERO

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch and touch.move_vector != Vector2.ZERO:
		input = touch.move_vector.limit_length(1.0)

	var aiming := Input.is_action_pressed("aim") or (touch != null and touch.aim_on)
	aiming = aiming and reload_t < 0.0
	var want_sprint := Input.is_action_pressed("sprint") or (touch != null and touch.move_vector.length() > 0.95)
	var firing := (Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) \
			or (touch != null and touch.fire_held)
	var sprinting := want_sprint and input.y < -0.5 and not aiming and not firing and is_on_floor()

	ads_t = move_toward(ads_t, 1.0 if aiming else 0.0, delta * 6.0)
	sprint_t = move_toward(sprint_t, 1.0 if sprinting else 0.0, delta * 5.0)

	rotation.y = yaw
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	speed *= lerpf(1.0, 0.55, ads_t)
	var dir := transform.basis * Vector3(input.x, 0, input.y)
	var accel := 40.0 if is_on_floor() else 8.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		if _fall_speed > 2.0:
			_play("land", 0.1)
		_fall_speed = 0.0
	_was_on_floor = is_on_floor()

	# weapon
	fire_cd = maxf(0.0, fire_cd - delta)
	recoil = move_toward(recoil, 0.0, delta * 9.0)
	if firing and sprint_t < 0.3:
		_try_fire()
	if reload_t >= 0.0:
		var prev := reload_t
		reload_t += delta
		_reload_events(prev, reload_t)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			rig.show_flash(false)


func _process(delta: float) -> void:
	var local_vel := transform.basis.inverse() * velocity
	var hspeed := Vector2(velocity.x, velocity.z).length()
	rig.update_pose(delta, {
		"pitch": pitch,
		"ads": ads_t,
		"speed": hspeed,
		"forward_sign": -1.0 if local_vel.z > 0.3 else 1.0,
		"on_floor": is_on_floor(),
		"recoil": recoil,
		"reload_t": reload_t,
		"sprint": sprint_t,
	})
	spring.rotation.x = pitch
	spring.spring_length = lerpf(2.6, 1.4, ads_t)
	spring.position.x = lerpf(0.55, 0.6, ads_t)
	var fov := lerpf(FOV, ADS_FOV, ads_t) + sprint_t * 6.0
	rig.fp_camera.fov = fov
	cam3p.fov = fov
	if hud:
		hud.ads = ads_t > 0.8 and not third_person


# ---------------------------------------------------------------- actions

func _jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
		_play("jump", 0.1)


func _on_footstep() -> void:
	if not is_on_floor():
		return
	var p: AudioStreamPlayer = _snd["step"]
	p.stream = _step_sounds[randi() % _step_sounds.size()]
	p.volume_db = -10.0 + sprint_t * 3.0
	_play("step", 0.08)


func _try_fire() -> void:
	if reload_t >= 0.0 or fire_cd > 0.0:
		return
	if ammo <= 0:
		_play("empty")
		fire_cd = 0.3
		if reserve > 0:
			_start_reload()
		return
	ammo -= 1
	fire_cd = FIRE_INTERVAL
	_play("shot", 0.06)
	recoil = 1.0
	pitch = minf(pitch + lerpf(0.012, 0.006, ads_t), deg_to_rad(80))
	yaw += randf_range(-0.004, 0.004)
	rig.show_flash(true)
	flash_t = 0.04

	var cam := cam3p if third_person else rig.fp_camera
	var from := cam.global_position
	var spread := lerpf(0.02, 0.002, ads_t) + Vector2(velocity.x, velocity.z).length() * 0.004
	var dir := (-cam.global_basis.z + cam.global_basis.x * randf_range(-spread, spread)
			+ cam.global_basis.y * randf_range(-spread, spread)).normalized()
	var to := from + dir * 300.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not hit.is_empty():
		end = hit.position
		_spawn_impact(hit.position, hit.normal, hit.collider)
		var col: Object = hit.collider
		if col is RigidBody3D:
			(col as RigidBody3D).apply_impulse(dir * 3.0, hit.position - (col as RigidBody3D).global_position)
		if col.has_method("hit"):
			col.call("hit", hit.position)
			if hud:
				hud.hit_marker = 1.0
	_spawn_tracer(rig.muzzle.global_position, end)
	_update_hud()


func _start_reload() -> void:
	if reload_t >= 0.0 or ammo >= MAG_SIZE or reserve <= 0:
		return
	reload_t = 0.0
	_update_hud()


func _reload_events(prev: float, t: float) -> void:
	if prev < 0.4 and t >= 0.4:
		_play("mag_out")
	if prev < Rig.MAG_DROP_T and t >= Rig.MAG_DROP_T:
		_drop_mag()
	if prev < Rig.MAG_IN_T and t >= Rig.MAG_IN_T:
		_play("mag_in")
	if prev < 1.85 and t >= 1.85:
		_play("bolt")
	if t >= Rig.RELOAD_TIME:
		var need := MAG_SIZE - ammo
		var take := mini(need, reserve)
		ammo += take
		reserve -= take
		reload_t = -1.0
		_update_hud()


func _update_hud() -> void:
	if hud:
		hud.ammo = ammo
		hud.reserve = reserve
		hud.reloading = reload_t >= 0.0


# ---------------------------------------------------------------- effects

func _drop_mag() -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = 2
	rb.collision_mask = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.04, 0.16, 0.07)
	cs.shape = bs
	rb.add_child(cs)
	Rig.box(rb, Vector3(0.04, 0.16, 0.07), Vector3.ZERO, rig.mat_metal)
	get_parent().add_child(rb)
	rb.global_transform = rig.mag.global_transform
	rb.linear_velocity = velocity + rig.weapon.global_basis.y * -1.0
	rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	get_tree().create_timer(12.0).timeout.connect(rb.queue_free)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.5:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, minf(dist, 6.0))
	mi.mesh = bm
	mi.material_override = rig.mat_flash
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	var dir := (to - from).normalized()
	mi.look_at_from_position(from + dir * (minf(dist, 6.0) / 2.0 + 0.3), to, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", mi.position + dir * clampf(dist - 3.0, 0.0, 40.0), 0.06)
	tw.tween_callback(mi.queue_free)


func _spawn_impact(pos: Vector3, normal: Vector3, col: Object) -> void:
	# spark
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	spark.mesh = sm
	spark.material_override = rig.mat_flash
	get_parent().add_child(spark)
	spark.global_position = pos + normal * 0.03
	var tw := spark.create_tween()
	tw.tween_property(spark, "scale", Vector3.ONE * 0.1, 0.12)
	tw.tween_callback(spark.queue_free)
	# bullet hole
	var hole := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.05, 0.05, 0.005)
	hole.mesh = hm
	hole.material_override = Rig.make_mat(Color(0.05, 0.05, 0.05))
	# stick holes to moving objects (crates, barrels)
	if col is RigidBody3D:
		(col as Node).add_child(hole)
	else:
		get_parent().add_child(hole)
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.FORWARD
	hole.look_at_from_position(pos + normal * 0.004, pos + normal, up)
	_decals.append(hole)
	if _decals.size() > 60:
		var old: Node3D = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var ip: AudioStreamPlayer = _snd["impact"]
	ip.volume_db = -14.0 - clampf(pos.distance_to(global_position) * 0.3, 0.0, 14.0)
	_play("impact", 0.15)
