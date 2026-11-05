extends Node3D
## Ровная площадка-полигон: трава, ящики и бочки как мишени, игрок с оружием и мобильный HUD.

const HALF := 40.0   # половина размера площадки, м

var player: Player
var inv: Inventory
var hud

func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_targets()

	inv = Inventory.new()
	player = Player.new()
	player.inv = inv
	add_child(player)
	player.global_position = Vector3(0, 0.1, 12)

	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	hud = preload("res://scripts/hud.gd").new()
	ui.add_child(hud)
	player.hud = hud
	hud.bind(player, inv)
	inv.setup_default()
	player.apply_attire(inv.worn())
	hud._set_active(0)
	_spawn_bots()
	_spawn_chest()

func _spawn_chest() -> void:
	var path := "res://assets/props/large_wooden_box.gltf"
	var ab := _mesh_aabb(load(path).instantiate())
	var list := Inventory.chest_contents()
	for i in list.size():
		var body := StaticBody3D.new()
		body.add_to_group("chest")
		body.set_meta("chest", list[i])
		body.add_child(load(path).instantiate())
		var c := CollisionShape3D.new()
		var b := BoxShape3D.new(); b.size = ab.size
		c.shape = b
		c.position = ab.get_center()
		body.add_child(c)
		var l := Label3D.new()
		l.text = list[i].title
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 28
		l.pixel_size = 0.003
		l.outline_size = 10
		l.position = Vector3(0, ab.end.y + 0.35, 0)
		body.add_child(l)
		add_child(body)
		# дуга ящиков вокруг точки появления
		var a := deg_to_rad(-60.0 + i * (120.0 / max(list.size() - 1, 1)))
		body.position = Vector3(sin(a) * 6.0, 0.0, 12.0 + cos(a) * 6.0)
		body.rotation.y = a + PI

func _spawn_bots() -> void:
	var defs := [
		{"name": "Бот Вася", "pos": Vector3(-3.5, 0, -7), "attire": ["heavy_plate_helmet", "roadsign_jacket", "pants_hide", "shoes_boots", "tactical_gloves"], "weapon": "assault_rifle"},
		{"name": "Бот Петя", "pos": Vector3(3.5, 0, -11), "attire": ["hat_cap", "bandana", "jacket", "heavy_plate_legs", "shoes_boots"], "weapon": "python_revolver"},
	]
	for d in defs:
		var b := Bot.new()
		b.bot_name = d.name
		b.attire = d.attire
		b.weapon = d.weapon
		b.target = player
		add_child(b)
		b.position = d.pos

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.52, 0.74)
	sm.sky_horizon_color = Color(0.72, 0.76, 0.78)
	sm.ground_bottom_color = Color(0.24, 0.22, 0.18)
	sm.ground_horizon_color = Color(0.62, 0.64, 0.6)
	sm.sun_angle_max = 25.0
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false
	env.fog_light_color = Color(0.68, 0.72, 0.76)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.add_to_group("ground")
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(HALF * 2.0 + 40.0, 1.0, HALF * 2.0 + 40.0)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(400, 400)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/terrain_grass.png")
	mat.uv1_scale = Vector3(100, 100, 1)   # 4 м на тайл
	mat.roughness = 1.0
	mat.albedo_color = Color(0.72, 0.74, 0.68)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	pm.material = mat
	mesh.mesh = pm
	body.add_child(mesh)
	# невидимые стены по краю площадки
	for i in 4:
		var w := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var b := BoxShape3D.new(); b.size = Vector3(HALF * 2.0, 6.0, 1.0)
		c.shape = b
		w.add_child(c)
		add_child(w)
		w.rotation_degrees.y = 90.0 * i
		w.position = Vector3(0, 3, 0) + w.transform.basis.z * (HALF + 0.5)

func _prop(path: String, pos: Vector3, yaw: float, size: Vector3, center_y: float, rigid: bool) -> Node3D:
	var body: PhysicsBody3D
	if rigid:
		var rb := RigidBody3D.new()
		rb.mass = 18.0
		body = rb
	else:
		body = StaticBody3D.new()
	body.add_to_group("target")
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new(); b.size = size
	c.shape = b
	c.position.y = center_y
	body.add_child(c)
	var m: Node3D = load(path).instantiate()
	body.add_child(m)
	add_child(body)
	body.position = pos
	body.rotation_degrees.y = yaw
	return body

func _build_targets() -> void:
	var crate := "res://assets/props/crate_wooden.glb"
	var barrel := "res://assets/props/loot_barrel.glb"
	var aabb := _mesh_aabb(load(crate).instantiate())
	var baabb := _mesh_aabb(load(barrel).instantiate())
	var csize := aabb.size
	var bsize := baabb.size
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	# линии мишеней на разных дистанциях
	for row in [{"z": -15.0, "n": 4}, {"z": -28.0, "n": 5}]:
		for i in row.n:
			var x: float = (i - (row.n - 1) * 0.5) * 3.2
			var use_barrel: bool = (i % 2 == 1)
			var s: Vector3 = bsize if use_barrel else csize
			var a: AABB = baabb if use_barrel else aabb
			_prop(barrel if use_barrel else crate, Vector3(x, 0.0, row.z), rng.randf_range(-20, 20), s, a.position.y + s.y * 0.5, true)
	# пирамида из ящиков
	for lvl in 3:
		for i in 3 - lvl:
			var x := 10.0 + (i - (2 - lvl) * 0.5) * (csize.x + 0.05)
			_prop(crate, Vector3(x, lvl * csize.y + 0.01, -10.0), 0.0, csize, aabb.position.y + csize.y * 0.5, true)

func _mesh_aabb(n: Node) -> AABB:
	var res := AABB()
	var first := true
	var stack := [n]
	while stack.size() > 0:
		var x = stack.pop_back()
		if x is MeshInstance3D and x.mesh:
			var t: Transform3D = Transform3D.IDENTITY
			var p: Node = x
			while p != n and p is Node3D:
				t = (p as Node3D).transform * t
				p = p.get_parent()
			var ab: AABB = t * x.mesh.get_aabb()
			res = ab if first else res.merge(ab)
			first = false
		for ch in x.get_children():
			stack.append(ch)
	n.free()
	return res
