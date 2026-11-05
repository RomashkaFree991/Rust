extends SceneTree
# CFG: ";"-separated entries "weapon|attire1+attire2|yaw|speed|mx,my|air|pitch"
var f := 0
var chars := []
var cfgs := []
func _init():
	var r := Node3D.new(); get_root().add_child(r)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.45,0.55,0.65)
	env.environment.ambient_light_color = Color(0.7,0.7,0.7); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	r.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 25, 0); r.add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); g.mesh = pm; r.add_child(g)
	var entries := OS.get_environment("CFG").split(";", false)
	var gap := float(OS.get_environment("GAP") if OS.get_environment("GAP") else "1.3")
	for i in entries.size():
		var p := entries[i].split("|")
		var c := Character.new(); r.add_child(c)
		c.position = Vector3(-(entries.size() - 1) * gap * 0.5 + i * gap, 0, 0)
		c.rotation_degrees.y = float(p[2]) if p.size() > 2 and p[2] != "" else 0.0
		c.set_attire(p[1].split("+", false) if p.size() > 1 else [])
		c.set_weapon(p[0])
		if p.size() > 3 and p[3] != "": c.move_speed = float(p[3])
		if p.size() > 4 and p[4] != "":
			var mv := p[4].split(","); c.move_local = Vector2(float(mv[0]), float(mv[1]))
		if p.size() > 5 and p[5] == "1": c.in_air = true
		if p.size() > 6 and p[6] != "": c.aim_pitch = float(p[6])
		chars.append(c)
	var cam := Camera3D.new(); r.add_child(cam)
	var cp := OS.get_environment("CAM").split(",")
	cam.position = Vector3(float(cp[0]), float(cp[1]), float(cp[2]))
	cam.fov = float(cp[3]) if cp.size() > 3 else 40.0
	if OS.get_environment("TOP") == "1":
		cam.position = Vector3(0, float(cp[1]), 0.0)
		cam.rotation_degrees = Vector3(-90, 0, 0)
	else:
		cam.look_at(Vector3(0.0, float(cp[4]) if cp.size() > 4 else 1.1, 0.0))
func _process(_d):
	f += 1
	if f == int(OS.get_environment("FR") if OS.get_environment("FR") else "40"):
		get_root().get_texture().get_image().save_png(OS.get_environment("OUT")); quit()
	return false
