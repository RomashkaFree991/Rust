extends SceneTree
var f := 0
func _init():
	var r := Node3D.new(); get_root().add_child(r)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.45,0.55,0.65)
	env.environment.ambient_light_color = Color(0.6,0.6,0.6); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	r.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, 30, 0); r.add_child(l)
	var setups = [["", []], ["m92", ["tshirt_long", "pants_hide", "shoes_boots", "metal_mask"]], ["ak47u", ["jacket", "pants_hide", "shoes_boots", "bandana"]], ["ak47u", ["roadsign_jacket", "heavy_plate_legs", "heavy_plate_helmet"]]]
	var yaws = [0.0, 45.0, 60.0, 90.0]
	for i in setups.size():
		var c := Character.new(); r.add_child(c)
		c.position = Vector3(-2.7 + i * 1.8, 0, 0)
		c.rotation_degrees.y = yaws[i] + float(OS.get_environment("YAW") if OS.get_environment("YAW") else "0")
		c.set_attire(setups[i][1]); c.set_weapon(setups[i][0])
	var cam := Camera3D.new(); r.add_child(cam); cam.position = Vector3(0, 1.2, 6.5); cam.fov = 40
func _process(_d):
	f += 1
	if f == 20: get_root().get_texture().get_image().save_png(OS.get_environment("OUT")); quit()
	return false
