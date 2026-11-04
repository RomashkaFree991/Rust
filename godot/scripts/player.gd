extends CharacterBody3D
class_name Player
## Игрок: движение от виртуального джойстика, обзор свайпом, стрельба лучом.
## Вьюмодель рисуется отдельной камерой в SubViewport (как ViewModelFOV в GMod).

const WALK_SPEED := 5.2
const JUMP_VELOCITY := 4.6
const GRAVITY := 12.0

var head: Node3D
var cam: Camera3D
var vm_viewport: SubViewport
var vm_container: SubViewportContainer
var vm_cam: Camera3D
var viewmodel: ViewModel
var inv: Inventory
var hud

var move_input := Vector2.ZERO
var look_accum := Vector2.ZERO
var look_frame := Vector2.ZERO
var pitch := 0.0
var recoil := Vector2.ZERO       # текущий «пинок» камеры (градусы)
var base_fov := 75.0
var step_t := 0.0
var steps: Array = []
var impacts_sand: Array = []
var impacts_wood: Array = []
var step_player: AudioStreamPlayer
var hole_tex: Texture2D
var holes: Array = []

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.35; cap.height = 1.8
	col.shape = cap; col.position.y = 0.9
	add_child(col)
	head = Node3D.new(); head.position.y = 1.62; add_child(head)
	cam = Camera3D.new(); cam.fov = base_fov; cam.near = 0.05; cam.far = 600.0
	cam.cull_mask = 0xFFFFF & ~ViewModel.VM_LAYER
	cam.current = true
	head.add_child(cam)

	# отдельный проход для рук/оружия
	vm_container = SubViewportContainer.new()
	vm_container.stretch = true
	vm_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vm_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new(); layer.layer = 0
	add_child(layer)
	layer.add_child(vm_container)
	vm_viewport = SubViewport.new()
	vm_viewport.transparent_bg = true
	vm_viewport.handle_input_locally = false
	vm_viewport.msaa_3d = Viewport.MSAA_2X
	vm_container.add_child(vm_viewport)
	vm_cam = Camera3D.new()
	vm_cam.near = 0.01; vm_cam.far = 10.0
	vm_cam.cull_mask = ViewModel.VM_LAYER
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	vm_cam.environment = env
	vm_cam.current = true
	vm_viewport.add_child(vm_cam)
	viewmodel = ViewModel.new()
	viewmodel.cam = vm_cam
	vm_cam.add_child(viewmodel)
	viewmodel.fired.connect(_on_fired)

	step_player = AudioStreamPlayer.new(); step_player.volume_db = -8.0; add_child(step_player)
	for i in range(1, 5):
		steps.append(load("res://assets/sounds/footstep-barefoot-grass-walk-00%d.mp3" % i))
	for i in range(1, 4):
		impacts_sand.append(load("res://assets/sounds/bullet-impact-sand-%d.mp3" % i))
		impacts_wood.append(load("res://assets/sounds/wood_bullet_impact-%d.mp3" % i))
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.02, 0.02, 1.0))
	g.set_color(1, Color(0.05, 0.04, 0.03, 0.0))
	g.add_point(0.45, Color(0.04, 0.035, 0.03, 0.95))
	var gt := GradientTexture2D.new()
	gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64; gt.height = 64
	hole_tex = gt

func add_look(delta_deg: Vector2) -> void:
	look_accum += delta_deg

func _physics_process(delta: float) -> void:
	# обзор
	var l := look_accum
	look_accum = Vector2.ZERO
	look_frame = l
	rotate_y(deg_to_rad(-l.x))
	pitch = clamp(pitch - l.y, -88.0, 88.0)

	# отдача возвращается
	recoil = recoil.lerp(Vector2.ZERO, clamp(delta * 9.0, 0.0, 1.0))
	head.rotation_degrees.x = clamp(pitch + recoil.x, -89.0, 89.0)
	head.rotation_degrees.y = recoil.y

	# движение
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var dir := (transform.basis * Vector3(move_input.x, 0.0, move_input.y))
	dir.y = 0.0
	var spd := WALK_SPEED * (0.55 if viewmodel.aiming else 1.0)
	var target := dir * spd
	var accel := 12.0 if is_on_floor() else 3.0
	velocity.x = move_toward(velocity.x, target.x, accel * spd * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * spd * delta)
	move_and_slide()

	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.8:
		step_t += delta * hspeed
		if step_t > 2.0:
			step_t = 0.0
			step_player.stream = steps[randi() % steps.size()]
			step_player.play()

func jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY

func _process(delta: float) -> void:
	vm_cam.global_transform = cam.global_transform
	var target_fov := base_fov * (0.82 if viewmodel.aiming else 1.0)
	cam.fov = lerp(cam.fov, target_fov, clamp(delta * 10.0, 0.0, 1.0))
	var hspeed := Vector2(velocity.x, velocity.z).length() / WALK_SPEED
	viewmodel.process_weapon(delta, inv, hspeed if is_on_floor() else 0.2, look_frame / max(delta, 0.001) * 0.016)

func _on_fired(def: Dictionary) -> void:
	# отдача
	var k: Vector2 = def.kick
	var ads_mul := 0.6 if viewmodel.aiming else 1.0
	recoil.x += k.x * ads_mul
	recoil.y += randf_range(-k.y, k.y) * ads_mul
	pitch = clamp(pitch + k.x * 0.25 * ads_mul, -88.0, 88.0)
	# луч
	var spread_deg: float = def.spread * (0.25 if viewmodel.aiming else 1.0)
	spread_deg += Vector2(velocity.x, velocity.z).length() * 0.25
	var b := cam.global_transform.basis
	var dir := -b.z
	var a := randf() * TAU
	var r := deg_to_rad(spread_deg) * sqrt(randf())
	dir = (dir + b.x * cos(a) * tan(r) + b.y * sin(a) * tan(r)).normalized()
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	var is_wood: bool = col is Node and (col as Node).is_in_group("target")
	_spawn_impact(hit.position, hit.normal, col, is_wood)
	if col is RigidBody3D:
		(col as RigidBody3D).apply_impulse(dir * def.damage * 0.06, hit.position - (col as RigidBody3D).global_position)
	if is_wood and hud:
		hud.show_hitmarker()
		if col.has_method("damage"):
			col.damage(def.damage)

func _spawn_impact(pos: Vector3, normal: Vector3, col: Object, wood: bool) -> void:
	# звук
	var sp := AudioStreamPlayer3D.new()
	var arr := impacts_wood if wood else impacts_sand
	sp.stream = arr[randi() % arr.size()]
	sp.unit_size = 6.0
	get_parent().add_child(sp)
	sp.global_position = pos
	sp.play()
	sp.finished.connect(sp.queue_free)
	# след от пули
	var hole := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.albedo_texture = hole_tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.material = m
	hole.mesh = qm
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent: Node3D = col if (col is RigidBody3D or col is StaticBody3D) and not (col as Node).is_in_group("ground") else get_parent()
	parent.add_child(hole)
	var up := Vector3.UP if abs(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	hole.global_transform = Transform3D(Basis.looking_at(-normal, up), pos + normal * 0.004)
	hole.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	holes.append(hole)
	if holes.size() > 80:
		var old = holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	# пыль / щепки
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 10
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3(0, 0, 1)
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var pm := BoxMesh.new(); pm.size = Vector3(0.025, 0.025, 0.025)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.45, 0.33, 0.2) if wood else Color(0.42, 0.38, 0.28)
	pm.material = pmat
	p.mesh = pm
	get_parent().add_child(p)
	p.global_transform = Transform3D(Basis.looking_at(-normal, Vector3.UP if abs(normal.y) < 0.95 else Vector3.FORWARD), pos)
	p.emitting = true
	p.finished.connect(p.queue_free)
