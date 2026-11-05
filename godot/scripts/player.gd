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
var body: Character               # своя модель (видна от 3-го лица, тень — всегда)
var third_person := false
var flying := false
var fly_input := 0.0
const FLY_SPEED := 12.0
var cam_dist := 0.0

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
	viewmodel.player = self
	viewmodel.reload_started.connect(func(): body.play_reload())

	body = Character.new()
	body.rotation_degrees.y = 180.0   # модель смотрит в +Z, игрок — в -Z
	add_child(body)
	body.set_layers(1, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)

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

func equip_item(it) -> void:
	if it == null:
		viewmodel.equip({})
		body.set_weapon("")
	else:
		viewmodel.equip(it)
		body.set_weapon(it.id)

func apply_attire(ids: Array) -> void:
	body.set_attire(ids)
	var arms := []
	for id in ids:
		var a: String = Items.get_def(id).get("arms", "")
		if a != "":
			arms.append(a)
	viewmodel.apply_arms(arms)

func set_third_person(on: bool) -> void:
	third_person = on
	vm_container.visible = not on
	body.set_layers(1, GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	if on:
		viewmodel.aiming = false

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

	# полёт: джойстик — по направлению взгляда, кнопки ВВЕРХ/ВНИЗ — по вертикали
	if flying:
		var fdir := head.global_basis * Vector3(move_input.x, 0.0, move_input.y)
		var tv := fdir * FLY_SPEED + Vector3.UP * fly_input * FLY_SPEED * 0.7
		velocity = velocity.move_toward(tv, 40.0 * delta)
		move_and_slide()
		return
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
	# камера от 3-го лица: за правым плечом, не проходит сквозь объекты
	var want := 2.6 if third_person else 0.0
	if third_person:
		var from := head.global_position
		var back := head.global_basis * Vector3(0.7, 0.25, want)
		var q := PhysicsRayQueryParameters3D.create(from, from + back)
		q.exclude = [get_rid()]
		q.collision_mask = 1
		var h := get_world_3d().direct_space_state.intersect_ray(q)
		if not h.is_empty():
			want = max(0.3, (h.position - from).length() - 0.2) / back.length() * want
	cam_dist = lerp(cam_dist, want, clamp(delta * 10.0, 0.0, 1.0))
	var k := cam_dist / 2.6
	cam.position = Vector3(0.7 * k, 0.25 * k, cam_dist)
	vm_cam.global_transform = cam.global_transform
	body.aim_pitch = pitch
	body.move_speed = clamp(Vector2(velocity.x, velocity.z).length() / WALK_SPEED * 0.75, 0.0, 1.0) if not flying else 0.0
	body.move_local = Vector2(move_input.x, -move_input.y)
	body.in_air = flying or (not is_on_floor() and velocity.y > -20.0 and abs(velocity.y) > 1.0)
	var target_fov := base_fov * (0.82 if viewmodel.aiming else 1.0)
	cam.fov = lerp(cam.fov, target_fov, clamp(delta * 10.0, 0.0, 1.0))
	var hspeed := Vector2(velocity.x, velocity.z).length() / WALK_SPEED
	viewmodel.process_weapon(delta, inv, hspeed if is_on_floor() else 0.2, look_frame / max(delta, 0.001) * 0.016)

## Смотрим ли на ящик (как подсказка «OPEN» в Rust)
func looking_at_chest():
	var h := _look_hit(2.6 + cam_dist)
	if not h.is_empty() and h.collider is Node and (h.collider as Node).is_in_group("chest"):
		return h.collider
	return null

func _look_hit(dist: float) -> Dictionary:
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist)
	q.exclude = [get_rid()]
	q.collision_mask = 3
	return get_world_3d().direct_space_state.intersect_ray(q)

## Раненый бот перед нами (для кнопки «ПОДНЯТЬ»)
func looking_at_wounded():
	for n in get_parent().get_children():
		if n is Bot and n.wounded and not n.dead and n.global_position.distance_to(global_position) < 3.0:
			return n
	return null

func _old_looking_at_chest() -> bool:
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (2.6 + cam_dist))
	q.exclude = [get_rid()]
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return not h.is_empty() and h.collider is Node and (h.collider as Node).is_in_group("chest")

## Удар в ближнем бою: что перед нами на расстоянии rng
func melee_check(rng: float) -> Dictionary:
	var from := head.global_position
	var dir := -head.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * rng)
	q.exclude = [get_rid()]
	q.collision_mask = 3
	return get_world_3d().direct_space_state.intersect_ray(q)

func melee_apply(hit: Dictionary, def: Dictionary) -> void:
	var dir := -head.global_basis.z
	_apply_hit(hit, dir, def.damage, true)

func _apply_hit(hit: Dictionary, dir: Vector3, damage: float, melee: bool) -> void:
	var col: Object = hit.collider
	if col is Node and (col as Node).has_meta("bot"):
		var bot = (col as Node).get_meta("bot")
		var res: Dictionary = bot.take_hit((col as Node).get_meta("zone"), damage, hit.position, dir, melee)
		if hud and not res.is_empty():
			hud.show_hitmarker(res.headshot, res.killed)
		return
	var is_wood: bool = col is Node and (col as Node).is_in_group("target")
	_spawn_impact(hit.position, hit.normal, col, is_wood)
	if col is RigidBody3D:
		(col as RigidBody3D).apply_impulse(dir * damage * (0.12 if melee else 0.06), hit.position - (col as RigidBody3D).global_position)
	if is_wood and hud:
		hud.show_hitmarker(false, false)

func _on_fired(def: Dictionary) -> void:
	var k_ind: String = def.get("kind", "gun")
	if k_ind == "melee":
		body.play_melee()
		return
	if k_ind in ["throw", "medical", "tool"]:
		body.play_use()
		return
	body.play_shoot()
	if third_person:
		body.muzzle_flash()
	# отдача
	var k: Vector2 = def.kick
	var ads_mul := 0.6 if viewmodel.aiming else 1.0
	recoil.x += k.x * ads_mul
	recoil.y += randf_range(-k.y, k.y) * ads_mul
	pitch = clamp(pitch + k.x * 0.25 * ads_mul, -88.0, 88.0)
	var b := cam.global_transform.basis
	var from := cam.global_position
	if k_ind == "launcher":
		var proj := "rocket" if def.get("ammo", "") in ["rocket", "high_velocity_rocket"] else "grenade"
		_spawn_projectile(from + (-b.z) * 0.6 + b.x * 0.15 - b.y * 0.1, -b.z, 40.0 if proj == "rocket" else 22.0,
			0.0 if proj == "rocket" else 9.0, 300.0 if proj == "rocket" else 140.0, 4.0, 5.0)
		return
	# лучи (у дробовика — несколько дробин, урон делится)
	var n: int = def.get("bullets", 1)
	var dmg: float = def.damage / max(n, 1) if n > 1 else def.damage
	for i in n:
		var spread_deg: float = def.spread * (0.25 if viewmodel.aiming and n == 1 else 1.0)
		spread_deg += Vector2(velocity.x, velocity.z).length() * 0.25
		var dir := -b.z
		var a := randf() * TAU
		var r := deg_to_rad(spread_deg) * sqrt(randf())
		dir = (dir + b.x * cos(a) * tan(r) + b.y * sin(a) * tan(r)).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0)
		q.exclude = [get_rid()]
		q.collision_mask = 3
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			_apply_hit(hit, dir, dmg, false)

# ---------- взрывчатка, ракеты, лечение ----------

var explode_sounds: Array = []

func throw_explosive(def: Dictionary) -> void:
	var b := cam.global_transform.basis
	var from := cam.global_position + (-b.z) * 0.5 - b.y * 0.1
	var dir := ((-b.z) + Vector3.UP * 0.25).normalized()
	_spawn_projectile(from, dir, 13.0, 9.8, def.get("damage", 80.0), def.get("radius", 4.0), def.get("fuse", 3.0), true, def.get("world", ""))

func _spawn_projectile(from: Vector3, dir: Vector3, speed: float, grav: float, damage: float, radius: float, fuse: float, bounce := false, model_path := "") -> void:
	var p := Node3D.new()
	get_parent().add_child(p)
	if model_path != "" and ResourceLoader.exists(model_path):
		var m: Node3D = load(model_path).instantiate()
		p.add_child(m)
	else:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new(); cyl.top_radius = 0.03; cyl.bottom_radius = 0.04; cyl.height = 0.35
		mi.mesh = cyl
		mi.rotation_degrees.x = 90
		p.add_child(mi)
		var trail := OmniLight3D.new(); trail.light_color = Color(1, 0.6, 0.2); trail.light_energy = 1.5; trail.omni_range = 3.0
		p.add_child(trail)
	var pr := Projectile.new()
	pr.vel = dir * speed
	pr.grav = grav
	pr.fuse = fuse
	pr.bounce = bounce
	pr.damage = damage
	pr.radius = radius
	pr.owner_player = self
	pr.exclude = [get_rid()]
	p.replace_by(pr)
	pr.global_position = from
	p.free()

func _explode(pos: Vector3, damage: float, radius: float) -> void:
	if explode_sounds.is_empty():
		for f in ["explosion.wav", "explosion.mp3"]:
			if ResourceLoader.exists("res://assets/sounds/" + f):
				explode_sounds.append(load("res://assets/sounds/" + f))
	var sp := AudioStreamPlayer3D.new()
	sp.stream = explode_sounds[randi() % explode_sounds.size()] if explode_sounds.size() > 0 else null
	sp.unit_size = 20.0
	sp.volume_db = 4.0
	get_parent().add_child(sp)
	sp.global_position = pos
	sp.play()
	sp.finished.connect(sp.queue_free)
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.6, 0.25); l.light_energy = 8.0; l.omni_range = radius * 2.5
	get_parent().add_child(l); l.global_position = pos + Vector3.UP * 0.5
	var tw := l.create_tween(); tw.tween_property(l, "light_energy", 0.0, 0.45); tw.tween_callback(l.queue_free)
	# огненный шар (текстура вспышки) + разлёт искр
	var fb := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(radius * 0.9, radius * 0.9)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = load("res://assets/textures/muzzleflash.png")
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = fm
	fb.mesh = q
	fb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(fb); fb.global_position = pos + Vector3.UP * 0.6
	var ft := fb.create_tween()
	ft.tween_property(fb, "scale", Vector3.ONE * 1.8, 0.35)
	ft.parallel().tween_property(fm, "albedo_color", Color(0, 0, 0, 0), 0.35)
	ft.tween_callback(fb.queue_free)
	var fx := CPUParticles3D.new()
	fx.one_shot = true; fx.amount = 30; fx.lifetime = 0.6; fx.explosiveness = 1.0
	fx.direction = Vector3.UP; fx.spread = 180.0; fx.initial_velocity_min = 3.0; fx.initial_velocity_max = 9.0
	fx.gravity = Vector3(0, -9, 0); fx.scale_amount_min = 0.5; fx.scale_amount_max = 1.0
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bm := BoxMesh.new(); bm.size = Vector3(0.04, 0.04, 0.04)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(1.0, 0.7, 0.3); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat; fx.mesh = bm
	get_parent().add_child(fx); fx.global_position = pos; fx.emitting = true
	fx.finished.connect(fx.queue_free)
	# урон ботам и толчок ящикам
	for n in get_parent().get_children():
		if n is Bot and not n.dead:
			var dist: float = (n.global_position + Vector3.UP - pos).length()
			if dist < radius:
				var res: Dictionary = n.take_hit("chest", damage * (1.0 - dist / radius), pos, (n.global_position - pos).normalized())
				if hud and not res.is_empty():
					hud.show_hitmarker(false, res.killed)
		elif n is RigidBody3D:
			var dv: Vector3 = n.global_position - pos
			if dv.length() < radius * 1.5:
				n.apply_impulse(dv.normalized() * (radius * 1.5 - dv.length()) * 12.0 + Vector3.UP * 20.0)
	if (global_position - pos).length() < radius and hud:
		hud.health = max(1.0, hud.health - damage * 0.2 * (1.0 - (global_position - pos).length() / radius))

func heal(amount: float) -> void:
	if hud:
		hud.health = min(100.0, hud.health + amount)

## Израсходовать один предмет из активной ячейки (граната, бинт, шприц)
func consume_active() -> void:
	if hud == null or hud.active_slot == -1:
		return
	var it = inv.get_item(hud.active_slot)
	if it == null:
		return
	it.amount -= 1
	if it.amount <= 0:
		inv.slots[hud.active_slot] = null
	inv.changed.emit()

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
