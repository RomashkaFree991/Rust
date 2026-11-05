extends SceneTree
var f := 0
func _init():
	var r := Node3D.new(); get_root().add_child(r)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.45,0.55,0.65)
	env.environment.ambient_light_color = Color(0.8,0.8,0.8); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	r.add_child(env)
	var w := OS.get_environment("W")
	# 3 копии: вид вдоль X, Y, Z (камера смотрит вдоль -Z); оси: красный X, зелёный Y, синий Z
	var rots = [Vector3(0, -90, 0), Vector3(90, 0, 0), Vector3(0, 0, 0)]
	for i in 3:
		var holder := Node3D.new(); r.add_child(holder)
		holder.position = Vector3(-1.2 + i * 1.2, 0, 0)
		holder.rotation_degrees = rots[i]
		var n: Node3D = load(w).instantiate(); holder.add_child(n)
		for a in 3:
			var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
			var sz := Vector3(0.01, 0.01, 0.01); sz[a] = 0.5; bm.size = sz
			var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = [Color.RED, Color.GREEN, Color.BLUE][a]; bm.material = m; mi.mesh = bm
			var off := Vector3.ZERO; off[a] = 0.25; mi.position = off
			holder.add_child(mi)
	var cam := Camera3D.new(); r.add_child(cam); cam.position = Vector3(0, 0.1, 3.0); cam.fov = 50
func _process(_d):
	f += 1
	if f == 5: get_root().get_texture().get_image().save_png(OS.get_environment("OUT")); quit()
	return false
