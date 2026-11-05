extends SceneTree
# Рендер вьюмоделей: MODELS=a,b,c  ACT=ACT_VM_DRAW  T=end|0.3  OUT=dir PFX=prefix
var f := 0
var rt: Node3D
var cam: Camera3D
var models: PackedStringArray
var i := 0
var cur: Node3D
var wj: Dictionary
func _init():
	wj = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/weapons.json"))
	models = OS.get_environment("MODELS").split(",")
	rt = Node3D.new(); get_root().add_child(rt)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.4,0.5,0.6)
	env.environment.ambient_light_color = Color(0.7,0.7,0.7); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	rt.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-50, 30, 0); rt.add_child(l)
	cam = Camera3D.new(); cam.fov = 56; cam.near = 0.01; rt.add_child(cam)
	if OS.get_environment("BACK") != "":
		cam.position = Vector3(0.15, 0.25, 0.9); cam.rotation_degrees = Vector3(-12, 8, 0)
	_load()
func _load():
	if cur: cur.free()
	var m := models[i]
	cur = load("res://assets/weapons/%s.gltf" % m).instantiate()
	if OS.get_environment("BACK") != "": rt.add_child(cur)
	else: cam.add_child(cur)
	cur.rotation_degrees.y = 90
	for mi in cur.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if OS.get_environment("ONLY") == "" and (n.begins_with("Hoodie") or n.begins_with("Burlap") or n.begins_with("Roadsign")):
			mi.visible = false
		var only := OS.get_environment("ONLY")
		if only != "" and not n.begins_with(only):
			mi.visible = false
	cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(float(OS.get_environment("FOV") if OS.get_environment("FOV") != "" else "60")) * 0.5) * 0.75))
	var ap: AnimationPlayer = cur.find_child("AnimationPlayer", true, false)
	var act := OS.get_environment("ACT")
	var seq := ""
	var seqs: Dictionary = wj.get(m, {}).get("seqs", {})
	for s in seqs:
		if seqs[s].activity == act and seq == "": seq = s
	if seq == "":
		for s in seqs:
			if seqs[s].activity == "ACT_VM_DRAW" and seq == "": seq = s
	if ap and seq != "":
		var an: String = seqs[seq].anim
		ap.play(an)
		var t := OS.get_environment("T")
		var L := ap.current_animation_length
		ap.seek(L - 0.01 if t == "end" else min(float(t), L - 0.01), true); ap.pause()
func _process(_d):
	f += 1
	if f % 4 == 0:
		get_root().get_texture().get_image().save_png(OS.get_environment("OUT") + "/" + OS.get_environment("PFX") + models[i] + ".png")
		i += 1
		if i >= models.size(): quit(); return false
		_load()
	return false
