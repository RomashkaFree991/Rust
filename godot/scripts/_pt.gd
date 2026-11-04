extends SceneTree
var f := 0
func _init():
	var r := Node3D.new(); get_root().add_child(r)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.4,0.5,0.6)
	env.environment.ambient_light_color = Color(0.6,0.6,0.6); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	r.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, 20, 0); r.add_child(l)
	var items := OS.get_environment("WEAR").split(",", false)
	for i in 2:
		var p: Node3D = load("res://assets/player/player.gltf").instantiate()
		r.add_child(p); p.position.x = -0.6 + i * 1.2
		if i == 0: _dump(p, 0)
		var sk: Skeleton3D = p.find_child("Skeleton3D", true, false)
		for m in sk.get_children():
			if m is MeshInstance3D:
				m.visible = String(m.name).begins_with(OS.get_environment("SHOW").split(",") as Array if false else "") and (String(m.name) in OS.get_environment("SHOW").split(","))
		if i == 1:
			for it in items:
				var c: Node3D = load("res://assets/player/%s.gltf" % it).instantiate()
				var cs: Skeleton3D = c.find_child("Skeleton3D", true, false)
				for m in cs.get_children():
					if m is MeshInstance3D:
						cs.remove_child(m); sk.add_child(m); m.skeleton = NodePath("..")
	var cam := Camera3D.new(); r.add_child(cam); cam.position = Vector3(0, 1.0, 3.2); cam.fov = 45
func _dump(n, d):
	if n is MeshInstance3D or n is Skeleton3D: print("  ".repeat(d), n.name, " ", n.get_class())
	for c in n.get_children(): _dump(c, d+1)
func _process(_d):
	f += 1
	if f == 5:
		get_root().get_texture().get_image().save_png(OS.get_environment("OUT")); quit()
	return false
