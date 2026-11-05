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

	# отдача по таблице (подъём ствола) и возврат визуального толчка
	if viewmodel.has_weapon():
		var rt = viewmodel.def.get("recoil", [])
		_recoil_step(delta, float(viewmodel.def.get("rpm", 300.0)), rt.size() if rt is Array else 0)
	else:
		_clock += delta
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
	_apply_recoil(def)
	var item: Dictionary = viewmodel.item
	var ammo_id: String = item.get("ammo_type", def.get("ammo", ""))
	var fx: Dictionary = Items.ammo_fx(ammo_id)
	var b := cam.global_transform.basis
	var from := cam.global_position
	var muzzle_pos := from + (-b.z) * 0.6 + b.x * 0.15 - b.y * 0.1
	if fx.get("proj", "") in ["rocket", "grenade", "arrow"]:
		var pr := Projectile.new()
		pr.mode = fx.proj
		pr.ammo_id = ammo_id
		var spd: float = fx.get("speed", 30.0)
		var dmg_mul: float = fx.get("dmg", 1.0)
		var dir := -b.z
		match fx.proj:
			"rocket":
				pr.grav = 1.5
				pr.damage = fx.get("damage", 300.0)
				pr.radius = fx.get("radius", 4.0)
				pr.impact = true
				_add_proj_mesh(pr, "rocket")
			"grenade":
				pr.grav = 9.8
				pr.damage = fx.get("damage", def.damage)
				pr.radius = fx.get("radius", 2.5)
				pr.impact = true
				_add_proj_mesh(pr, "grenade")
			"arrow":
				pr.grav = 9.8
				pr.damage = def.damage * dmg_mul
				if bool(def.get("crossbow", false)):
					spd *= 1.4
				_add_proj_mesh(pr, "arrow")
				dir = (dir + Vector3.UP * 0.02).normalized()
		pr.vel = dir * spd
		pr.owner_player = self
		pr.exclude = [get_rid()]
		get_parent().add_child(pr)
		pr.global_position = muzzle_pos if fx.proj != "arrow" else from + (-b.z) * 0.4
		pr.look_at(pr.global_position + dir, Vector3.UP)
		return
	# лучи (у дробовика — несколько дробин, урон делится); тип патрона меняет урон/разброс/эффекты
	var n: int = int(fx.get("pellets", def.get("bullets", 1)))
	var total: float = def.damage * fx.get("dmg", 1.0)
	var dmg: float = total / n if n > 1 else total
	var spread_mul: float = fx.get("spread", 1.0)
	var tcol: Color = fx.get("tracer", Color(1.0, 0.9, 0.6))
	for i in n:
		var spread_deg: float = def.spread * spread_mul * (0.25 if viewmodel.aiming and n == 1 else 1.0)
		spread_deg += Vector2(velocity.x, velocity.z).length() * 0.25
		var dir := -b.z
		var a := randf() * TAU
		var r := deg_to_rad(spread_deg) * sqrt(randf())
		dir = (dir + b.x * cos(a) * tan(r) + b.y * sin(a) * tan(r)).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0)
		q.exclude = [get_rid()]
		q.collision_mask = 3
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var end: Vector3 = hit.position if not hit.is_empty() else from + dir * 120.0
		if i == 0 or randf() < 0.3:
			FX.tracer(get_parent(), muzzle_pos, end, tcol)
		if hit.is_empty():
			continue
		_apply_hit(hit, dir, dmg, false)
		_ammo_effects(fx, hit)

## Эффекты пули при попадании: зажигательная — огонь/поджог, разрывная — маленький взрыв
func _ammo_effects(fx: Dictionary, hit: Dictionary) -> void:
	var col: Object = hit.collider
	if fx.get("fire", false):
		if col is Node and (col as Node).has_meta("bot"):
			(col as Node).get_meta("bot").ignite(6.0, 4.0)
		else:
			FX.ground_fire(get_parent(), hit.position, 0.25, 2.5)
	if fx.has("explode"):
		var r: float = fx.explode
		FX.explosion(get_parent(), hit.position + hit.normal * 0.05, r, "res://assets/sounds/explosive-ammo.wav", -4.0)

# ---------- отдача по таблице gRust (rust_gun/cl_init.lua: Recoil / UpdateRecoil) ----------

var recoil_index := 0
var recoil_last := -100.0
var recoil_ang := Vector2.ZERO     # (тангаж вверх, поворот вправо) градусы в секунду на время lerp
var recoil_left := 0.0
var recoil_decr_next := 0.0
var _clock := 0.0

func _apply_recoil(def: Dictionary) -> void:
	var table: Array = def.get("recoil", []) if def.get("recoil") != null else []
	var ads_mul := 0.6 if viewmodel.aiming else 1.0
	if table.is_empty():
		var k: Vector2 = def.get("kick", Vector2(1, 0.4))
		recoil.x += k.x * ads_mul
		recoil.y += randf_range(-k.y, k.y) * ads_mul
		pitch = clamp(pitch + k.x * 0.25 * ads_mul, -88.0, 88.0)
		return
	recoil_index = (recoil_index % table.size()) + 1
	recoil_last = _clock
	var amt: float = float(def.get("recoil_amount", 1.0)) if def.get("recoil_amount") != null else 1.0
	var lt: float = float(def.get("recoil_lerp", 0.1)) if def.get("recoil_lerp") != null else 0.1
	var e: Array = table[recoil_index - 1]
	# Source: Angle(pitch, yaw) — отрицательный pitch = вверх, положительный yaw = влево.
	# Суммарный сдвиг за выстрел = RecoilTable[i] * RecoilAmount * RecoilLerpTime (распределён по lerpTime)
	recoil_ang = Vector2(-float(e[0]), -float(e[1])) * amt * ads_mul
	recoil_left = lt
	recoil_lerp_t = lt
	# визуальный толчок камеры
	recoil.x += 0.6 * ads_mul

var recoil_lerp_t := 0.1

func _recoil_step(delta: float, rpm: float, table_size: int) -> void:
	_clock += delta
	if recoil_left > 0.0:
		var dt: float = min(delta, recoil_left)
		recoil_left -= dt
		pitch = clamp(pitch + recoil_ang.x * dt, -88.0, 88.0)
		rotate_y(deg_to_rad(-recoil_ang.y * dt))
	# индекс таблицы откатывается, когда не стреляем (как NextRecoilDecrement)
	if recoil_index > 0 and _clock > recoil_last + (60.0 / max(rpm, 1.0)) * 2.0 and _clock > recoil_decr_next:
		recoil_index = max(recoil_index - 1, 0)
		recoil_decr_next = _clock + 0.1

func _add_proj_mesh(pr: Node3D, kind: String) -> void:
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	match kind:
		"rocket":
			var c := CylinderMesh.new(); c.top_radius = 0.035; c.bottom_radius = 0.045; c.height = 0.5
			m.albedo_color = Color(0.35, 0.33, 0.28)
			c.material = m
			mi.mesh = c
		"grenade":
			var sp := CylinderMesh.new(); sp.top_radius = 0.02; sp.bottom_radius = 0.02; sp.height = 0.09
			m.albedo_color = Color(0.5, 0.45, 0.25)
			sp.material = m
			mi.mesh = sp
		"arrow":
			var c2 := CylinderMesh.new(); c2.top_radius = 0.004; c2.bottom_radius = 0.004; c2.height = 0.7
			m.albedo_color = Color(0.55, 0.4, 0.25)
			c2.material = m
			mi.mesh = c2
			var tip := MeshInstance3D.new()
			var cone := CylinderMesh.new(); cone.top_radius = 0.0; cone.bottom_radius = 0.012; cone.height = 0.05
			var tm := StandardMaterial3D.new(); tm.albedo_color = Color(0.3, 0.3, 0.32)
			cone.material = tm
			tip.mesh = cone
			tip.position = Vector3(0, 0.37, 0)
			mi.add_child(tip)
	mi.rotation_degrees.x = -90.0     # ось цилиндра (Y) -> вперёд (-Z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pr.add_child(mi)

# ---------- взрывчатка, ракеты, стрелы, лечение ----------

## Бросок взрывчатки (rust_explosive Throw: скорость 1000 ед/с ≈ 19 м/с, fuse = SWEP.Delay, stick = SWEP.Stick)
func throw_explosive(def: Dictionary) -> void:
	var b := cam.global_transform.basis
	var from := cam.global_position + (-b.z) * 0.4 - b.y * 0.05
	var dir := ((-b.z) + Vector3.UP * 0.12).normalized()
	var pr := Projectile.new()
	pr.mode = "bomb"
	pr.vel = dir * 19.0 + velocity * 0.5
	pr.grav = 9.8
	pr.fuse = float(def.get("fuse", 3.0))
	pr.damage = float(def.get("damage", 80.0))
	pr.radius = float(def.get("radius", 4.0))
	pr.stick = def.get("stick", false) == true
	pr.owner_player = self
	pr.exclude = [get_rid()]
	var sid: String = def.get("swep", "")
	match sid:
		"rust_c4":
			pr.beep_sound = "res://assets/sounds/c4-beep-loop.wav"
			pr.explode_sound = "res://assets/sounds/c4-%d.wav" % (1 + randi() % 4)
		"rust_satchel":
			pr.explode_sound = "res://assets/sounds/satchel-charge-%d.wav" % (1 + randi() % 3)
		"rust_f1grenade":
			pr.explode_sound = "res://assets/sounds/f1-grenade-%d.wav" % (1 + randi() % 2)
		_:
			pr.explode_sound = "res://assets/sounds/beancan-grenade-%d.wav" % (1 + randi() % 2)
	if sid in ["rust_beancan", "rust_satchel"]:
		FX.sound(get_parent(), from, "res://assets/sounds/beancan-grenade-fuse.wav", -6.0, 6.0, pr)
	var wp: String = def.get("world", "")
	if wp != "" and ResourceLoader.exists(wp):
		var m: Node3D = load(wp).instantiate()
		pr.add_child(m)
	else:
		_add_proj_mesh(pr, "grenade")
	get_parent().add_child(pr)
	pr.global_position = from
	FX.sound(get_parent(), from, "res://assets/sounds/throw-item-small.mp3", -4.0, 6.0)

## Попадание стрелы
func projectile_hit(pr: Projectile, hit: Dictionary) -> void:
	var dir: Vector3 = pr.vel.normalized()
	_apply_hit(hit, dir, pr.damage, false)
	var fx := Items.ammo_fx(pr.ammo_id)
	_ammo_effects(fx, hit)

## Взрыв снаряда
func projectile_explode(pr: Projectile) -> void:
	var pos := pr.global_position
	var fx := Items.ammo_fx(pr.ammo_id)
	if fx.get("smoke", false):
		FX.smoke(get_parent(), pos, 12.0, 3.0)
		FX.sound(get_parent(), pos, "res://assets/sounds/explosive-ammo.wav", -6.0, 10.0)
		_explode(pos, pr.damage, pr.radius, "", false)
		return
	var snd := pr.explode_sound
	if snd == "":
		if pr.mode == "rocket":
			snd = ("res://assets/sounds/rocket-hv-%d.wav" % (1 + randi() % 1)) if pr.ammo_id == "high_velocity_rocket" else "res://assets/sounds/rocket-%d.wav" % (1 + randi() % 2)
		else:
			snd = "res://assets/sounds/beancan-grenade-%d.wav" % (1 + randi() % 2)
	_explode(pos, pr.damage, pr.radius, snd)
	if fx.get("fire", false):
		FX.ground_fire(get_parent(), pos, 0.8, 8.0)
		for n in get_parent().get_children():
			if n is Bot and not n.dead and (n.global_position - pos).length() < pr.radius * 1.2:
				n.ignite(8.0, 6.0)

## Урон по площади (gRust.BlastDamage) + эффекты
func _explode(pos: Vector3, damage: float, radius: float, sound_path := "", effects := true) -> void:
	if effects:
		FX.explosion(get_parent(), pos, radius, sound_path, 4.0)
	if damage <= 0.0:
		return
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
	var pd := (global_position + Vector3.UP - pos).length()
	if pd < radius and hud:
		hud.health = max(1.0, hud.health - damage * 0.2 * (1.0 - pd / radius))
	# тряска камеры (util.ScreenShake)
	var shake: float = clamp(1.0 - (global_position - pos).length() / (radius * 4.0), 0.0, 1.0)
	recoil += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 4.0 * shake

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
