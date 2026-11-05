extends SceneTree
var f := 0
var main
func _init():
	Attachments.dbg_mode = int(OS.get_environment("DM"))
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
func _process(_d):
	f += 1
	var pl = main.player
	match f:
		20:
			pl.global_position = Vector3(0, 0.1, 6); pl.rotation.y = 0.0; pl.pitch = 0.0
			var it = main.inv.get_item(0); it["mods"] = [OS.get_environment("MOD")]; pl.equip_item(it)
		100: pl.viewmodel.toggle_aim()
		160: get_root().get_texture().get_image().save_png("/tmp/claude-0/-home-user-Rust/92f95108-dc8c-522f-9e28-a1c30e2eb27b/scratchpad/agentC/ads_%s_%s.png" % [OS.get_environment("MOD"), OS.get_environment("DM")]); quit()
	return false
