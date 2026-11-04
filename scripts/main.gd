extends Node3D
## Builds the test level, input map, HUD, touch controls and the player.

const HINT := "WASD - ходьба, Shift - бег, Space - прыжок, мышь - обзор\nЛКМ - огонь, ПКМ - прицел, R - перезарядка, V - 1/3 лицо\nF1 - сенсорное управление, Esc - отпустить мышь"


func _ready() -> void:
	_setup_input()
	_build_environment()
	_build_level()

	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Hud.new()
	layer.add_child(hud)
	var touch := TouchControls.new()
	layer.add_child(touch)
	touch.visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	hud.hint = "" if touch.visible else HINT

	var player := Player.new()
	player.name = "Player"
	player.touch = touch
	player.hud = hud
	add_child(player)
	player.position = Vector3(0, 0.2, 8)


func _setup_input() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("move_forward", KEY_UP)
	_key("move_back", KEY_DOWN)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_RIGHT)
	_key("jump", KEY_SPACE)
	_key("sprint", KEY_SHIFT)
	_key("reload", KEY_R)
	_key("toggle_view", KEY_V)
	_key("toggle_touch", KEY_F1)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _key(action: String, key: Key) -> void:
	_ensure(action)
	var e := InputEventKey.new()
	e.physical_keycode = key
	InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func _build_environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.45, 0.62)
	sky_mat.sky_horizon_color = Color(0.78, 0.68, 0.55)
	sky_mat.ground_horizon_color = Color(0.5, 0.45, 0.38)
	sky_mat.ground_bottom_color = Color(0.2, 0.18, 0.15)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.65, 0.58)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(35), 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _static_box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation = rot
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	Rig.box(sb, size, Vector3.ZERO, mat)
	add_child(sb)
	return sb


func _rigid_box(size: Vector3, pos: Vector3, mat: Material, mass := 8.0) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.position = pos
	rb.mass = mass
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	rb.add_child(cs)
	Rig.box(rb, size, Vector3.ZERO, mat)
	add_child(rb)
	return rb


func _barrel(pos: Vector3, mat: Material) -> void:
	var rb := RigidBody3D.new()
	rb.position = pos
	rb.mass = 15.0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.3
	sh.height = 0.9
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 0.9
	mi.mesh = cm
	mi.material_override = mat
	rb.add_child(mi)
	add_child(rb)


func _build_level() -> void:
	# ground with noise texture
	var ground_mat := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	var grad := Gradient.new()
	grad.set_color(0, Color(0.3, 0.33, 0.2))
	grad.set_color(1, Color(0.45, 0.4, 0.28))
	tex.color_ramp = grad
	ground_mat.albedo_texture = tex
	ground_mat.uv1_scale = Vector3(40, 40, 40)
	ground_mat.roughness = 1.0
	_static_box(Vector3(200, 1, 200), Vector3(0, -0.5, 0), ground_mat)

	var rock := Rig.make_mat(Color(0.36, 0.35, 0.33), 0.95)
	var metal := Rig.make_mat(Color(0.5, 0.3, 0.18), 0.8, 0.5)
	var wood := Rig.make_mat(Color(0.55, 0.4, 0.22))
	var concrete := Rig.make_mat(Color(0.42, 0.42, 0.4))
	var barrel_mat := Rig.make_mat(Color(0.55, 0.15, 0.1), 0.7, 0.4)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 40:
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		if p.length() < 12.0:
			continue
		var s := Vector3(rng.randf_range(1, 4), rng.randf_range(0.6, 3), rng.randf_range(1, 4))
		p.y = s.y * 0.35
		_static_box(s, p, rock, Vector3(rng.randf_range(-0.3, 0.3), rng.randf(), rng.randf_range(-0.3, 0.3)))

	# scrap shack
	_static_box(Vector3(6, 3, 0.15), Vector3(-8, 1.5, -6), metal)
	_static_box(Vector3(0.15, 3, 5), Vector3(-11, 1.5, -3.5), metal)
	_static_box(Vector3(0.15, 3, 5), Vector3(-5, 1.5, -3.5), metal)
	_static_box(Vector3(6.4, 0.15, 5.4), Vector3(-8, 3.05, -3.6), metal, Vector3(0.08, 0, 0))

	# ramp + platforms for jumping
	_static_box(Vector3(2.5, 0.3, 6), Vector3(8, 1.0, -2), concrete, Vector3(deg_to_rad(20), 0, 0))
	_static_box(Vector3(4, 2, 4), Vector3(8, 1.0, -7), concrete)
	_static_box(Vector3(2, 0.4, 2), Vector3(4.5, 2.6, -7), concrete)
	_static_box(Vector3(2, 0.4, 2), Vector3(1.5, 3.3, -7), concrete)
	for i in 5:
		_static_box(Vector3(1.2, 0.3 + i * 0.35, 1.2), Vector3(-3 + i * 1.4, (0.3 + i * 0.35) / 2.0, 3), concrete)

	# crates and barrels (physics)
	for i in 6:
		_rigid_box(Vector3(0.8, 0.8, 0.8), Vector3(3 + (i % 3) * 0.85, 0.4 + floorf(i / 3.0) * 0.82, 4), wood)
	for i in 4:
		_barrel(Vector3(-4 + i * 0.7, 0.45, 6), barrel_mat)

	# shooting range
	for i in 6:
		var t := ShootTarget.new()
		t.position = Vector3(-7.5 + i * 3.0, 0, -18 - (i % 2) * 4.0)
		add_child(t)
