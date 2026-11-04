extends SceneTree
var f := 0
var chars := []
func _init():
	var r := Node3D.new(); get_root().add_child(r)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.4,0.5,0.6)
	env.environment.ambient_light_color = Color(0.6,0.6,0.6); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	r.add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-40, 20, 0); r.add_child(l)
	var setups = [["ak47u", 0.0, 0.0], ["python", 0.0, 0.0], ["rock", 0.0, 0.0], ["", 0.0, 1.0], ["ak47u", 30.0, 1.0]]
	for i in setups.size():
		var c := Character.new(); r.add_child(c)
		c.position = Vector3(-2.4 + i * 1.2, 0, 0)
		c.rotation_degrees.y = float(OS.get_environment("YAW") if OS.get_environment("YAW") else "0")
		c.set_attire(["jacket", "pants_hide", "shoes_boots", "hat_cap"])
		c.set_weapon(setups[i][0]); c.aim_pitch = setups[i][1]; c.move_speed = setups[i][2]
		chars.append(c)
	var cam := Camera3D.new(); r.add_child(cam); cam.position = Vector3(0, 1.1, 5.0); cam.fov = 45
func _process(_d):
	f += 1
	if f == 20:
		get_root().get_texture().get_image().save_png(OS.get_environment("OUT")); quit()
	return false
