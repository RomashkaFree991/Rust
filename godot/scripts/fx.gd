extends RefCounted
class_name FX
## Визуальные эффекты оружия: взрывы (как rust_big_explosion), огонь, дым, трассеры, искры.

static var _soft: Texture2D
static var _flash: Texture2D
static var _streams := {}

static func soft_tex() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft

static func flash_tex() -> Texture2D:
	if _flash == null:
		_flash = load("res://assets/textures/muzzleflash.png")
	return _flash

static func stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]

static func sound(world: Node, pos: Vector3, path: String, vol := 0.0, unit := 10.0, loop_parent: Node3D = null) -> AudioStreamPlayer3D:
	var st := stream(path)
	if st == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = vol
	p.unit_size = unit
	if loop_parent:
		loop_parent.add_child(p)
	else:
		world.add_child(p)
		p.global_position = pos
		p.finished.connect(p.queue_free)
	p.play()
	return p

static func _particles(amount: int, life: float, color: Color, tex: Texture2D, size_min: float, size_max: float, additive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	p.mesh = q
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	return p

## Огонь на объекте (возвращает узел — удалить, когда погаснет)
static func fire(parent: Node3D, offset: Vector3, size: float, with_sound := true) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.position = offset
	var p := _particles(24, 0.7, Color(1.0, 0.55, 0.15), flash_tex(), size * 0.4, size * 0.9, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.4
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.0
	n.add_child(p)
	var sm := _particles(10, 1.6, Color(0.15, 0.13, 0.12, 0.5), soft_tex(), size, size * 2.0, false)
	sm.direction = Vector3.UP
	sm.gravity = Vector3(0, 1.2, 0)
	sm.initial_velocity_min = 0.5
	sm.initial_velocity_max = 1.2
	sm.position = Vector3(0, size * 0.6, 0)
	n.add_child(sm)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 1.4
	l.omni_range = size * 6.0
	n.add_child(l)
	if with_sound:
		var snd := sound(parent, Vector3.ZERO, "res://assets/sounds/torch-burn-loop.wav", -4.0, 6.0, n)
		if snd and snd.stream is AudioStreamWAV:
			(snd.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return n

## Огонь на земле на время (зажигательная ракета/дробь)
static func ground_fire(world: Node3D, pos: Vector3, size: float, time: float) -> Node3D:
	var holder := Node3D.new()
	world.add_child(holder)
	holder.global_position = pos
	fire(holder, Vector3.ZERO, size, true)
	var t := holder.create_tween()
	t.tween_interval(time)
	t.tween_callback(holder.queue_free)
	return holder

## Дымовая завеса
static func smoke(world: Node3D, pos: Vector3, time: float, size := 3.0) -> void:
	var holder := Node3D.new()
	world.add_child(holder)
	holder.global_position = pos
	var p := _particles(40, 4.0, Color(0.75, 0.75, 0.75, 0.55), soft_tex(), size * 0.8, size * 1.6, false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.4
	p.direction = Vector3.UP
	p.spread = 60.0
	p.gravity = Vector3(0, 0.3, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	holder.add_child(p)
	sound(world, pos, "res://assets/sounds/smoke-loop.wav", -6.0, 8.0)
	var t := holder.create_tween()
	t.tween_interval(time)
	t.tween_callback(func(): p.emitting = false)
	t.tween_interval(4.5)
	t.tween_callback(holder.queue_free)

## Взрыв: вспышка, огненный шар, обломки, дым, свет
static func explosion(world: Node3D, pos: Vector3, radius: float, sound_path := "", vol := 4.0) -> void:
	if sound_path == "":
		sound_path = "res://assets/sounds/explosion.wav"
	sound(world, pos, sound_path, vol, 20.0)
	var holder := Node3D.new()
	world.add_child(holder)
	holder.global_position = pos
	var s: float = clamp(radius, 0.6, 6.0)
	# огненный шар
	var fb := _particles(int(10 + s * 4), 0.45, Color(1.0, 0.65, 0.25), flash_tex(), s * 0.5, s * 1.1, true)
	fb.one_shot = true
	fb.explosiveness = 1.0
	fb.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fb.emission_sphere_radius = s * 0.25
	fb.direction = Vector3.UP
	fb.spread = 180.0
	fb.initial_velocity_min = s * 0.8
	fb.initial_velocity_max = s * 2.0
	fb.gravity = Vector3.ZERO
	holder.add_child(fb)
	# дым
	var sm := _particles(int(8 + s * 3), 2.5, Color(0.2, 0.18, 0.16, 0.7), soft_tex(), s * 0.8, s * 1.8, false)
	sm.one_shot = true
	sm.explosiveness = 0.85
	sm.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = s * 0.3
	sm.direction = Vector3.UP
	sm.spread = 70.0
	sm.initial_velocity_min = 0.5
	sm.initial_velocity_max = s * 0.8
	sm.gravity = Vector3(0, 0.6, 0)
	holder.add_child(sm)
	# обломки / искры
	var db := CPUParticles3D.new()
	db.one_shot = true
	db.explosiveness = 1.0
	db.amount = int(12 + s * 6)
	db.lifetime = 1.0
	db.direction = Vector3.UP
	db.spread = 75.0
	db.initial_velocity_min = s * 1.5
	db.initial_velocity_max = s * 4.0
	db.gravity = Vector3(0, -9.8, 0)
	db.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.04, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	db.mesh = bm
	holder.add_child(db)
	for p in [fb, sm, db]:
		p.emitting = true
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.6, 0.25)
	l.light_energy = 6.0 + s * 2.0
	l.omni_range = s * 3.0
	l.position = Vector3.UP * 0.5
	holder.add_child(l)
	var t := holder.create_tween()
	t.tween_property(l, "light_energy", 0.0, 0.5)
	t.tween_interval(3.0)
	t.tween_callback(holder.queue_free)

## Трассер пули (короткая светящаяся линия)
static func tracer(world: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	var len := from.distance_to(to)
	if len < 1.0:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = min(len, 6.0)
	cm.radial_segments = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, 0.9)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.material = m
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	var dir := (to - from).normalized()
	var up := Vector3.UP if abs(dir.y) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI * 0.5)
	mi.global_transform = Transform3D(basis, from + dir * cm.height * 0.5)
	var t := mi.create_tween()
	var dur: float = clamp(len / 300.0, 0.05, 0.3)
	t.tween_property(mi, "global_position", to - dir * cm.height * 0.5, dur)
	t.parallel().tween_property(m, "albedo_color:a", 0.0, dur)
	t.tween_callback(mi.queue_free)
