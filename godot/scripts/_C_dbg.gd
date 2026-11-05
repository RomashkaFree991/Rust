extends SceneTree
var f := 0
var out := "/tmp/claude-0/-home-user-Rust/92f95108-dc8c-522f-9e28-a1c30e2eb27b/scratchpad/agentC/"
var cams := []
func _init():
	var r := Node3D.new(); get_root().add_child(r)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.45,0.55,0.65)
	env.environment.ambient_light_color = Color(0.8,0.8,0.8); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	r.add_child(env)
	var mode := int(OS.get_environment("MODE"))
	var holo_pos := Vector3.ZERO
	for i in [int(OS.get_environment("VAR"))]:
		var n: Node3D = load("res://assets/weapons/ak47u.gltf").instantiate()
		r.add_child(n)
		for m in n.find_children("*", "MeshInstance3D", true, false):
			if not String(m.name).begins_with("ak47"): m.visible = false
		var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
		var ba := BoneAttachment3D.new(); sk.add_child(ba); ba.bone_name = "main"
		var info: Dictionary = Attachments.weapon_info("assault_rifle")
		for id in ["holosight", "silencer", "weapon_lasersight"]:
			var a: Dictionary = info.attachments[id]
			var ang := Attachments._v(a.ang)
			if i == 1: ang = -ang
			if i == 2: ang = Vector3(ang.x, -ang.y, ang.z)
			var t := Attachments.gmod_offset(Attachments._v(a.pos), ang)
			var s: float = a.get("scale", 1.0)
			var node: Node3D = Attachments._scene(a.model).instantiate()
			node.transform = t * Transform3D(Attachments.C_INV.scaled(Vector3(s,s,s)), Vector3.ZERO)
			ba.add_child(node)
			if id == "holosight": node.name = "HOLO"
	var cam := Camera3D.new(); r.add_child(cam); cam.fov = 30
	cams.append(cam)
func _place():
	var cam: Camera3D = cams[0]
	var h: Node3D = get_root().find_child("HOLO", true, false)
	var hp := h.global_position
	if int(OS.get_environment("MODE")) == 0:
		cam.global_position = hp + Vector3(0.35, 0.0, 0.0); cam.look_at(hp)
	else:
		cam.global_position = hp + Vector3(0.0, 0.05, -0.35); cam.look_at(hp)
func _process(_d):
	f += 1
	if f == 5: _place()
	if f == 10: get_root().get_texture().get_image().save_png(out + "dbg_%s_%s.png" % [OS.get_environment("MODE"), OS.get_environment("VAR")]); quit()
	return false
