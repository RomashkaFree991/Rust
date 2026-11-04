extends SceneTree
var f := 0
var main
var out := "/tmp/claude-0/-home-user-Rust/92f95108-dc8c-522f-9e28-a1c30e2eb27b/scratchpad/shots/"
func _init():
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
func _process(_d):
	f += 1
	var vm = main.player.viewmodel
	if f == 30 and OS.get_environment("SLOT") != "0": main.hud._tap_hotbar(int(OS.get_environment("SLOT")))
	if f == 160: vm.inspect()
	if f == 220: get_root().get_texture().get_image().save_png(out + "v_a.png")
	if f == 320: get_root().get_texture().get_image().save_png(out + "v_b.png")
	if f == 321: quit()
	return false
