extends SceneTree
var f := 0
var main
var out := "/tmp/claude-0/-home-user-Rust/92f95108-dc8c-522f-9e28-a1c30e2eb27b/scratchpad/agentC/"
func _init():
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
func snap(n): get_root().get_texture().get_image().save_png(out + n + ".png")
func _process(_d):
	f += 1
	var hud = main.hud
	var pl = main.player
	var inv = main.inv
	var ui = hud.inv_ui
	match f:
		20:
			pl.global_position = Vector3(0, 0.1, 6); pl.rotation.y = 0.0; pl.pitch = 0.0
			inv.slots[Inventory.MAIN_START + 12] = Inventory.make("holosight")
			inv.slots[Inventory.MAIN_START + 13] = Inventory.make("silencer")
			inv.slots[Inventory.MAIN_START + 14] = Inventory.make("8x_zoom_scope")
			inv.slots[Inventory.MAIN_START + 15] = Inventory.make("weapon_lasersight")
			inv.slots[Inventory.MAIN_START + 16] = Inventory.make("hv_556_rifle_ammo", 64)
			inv.changed.emit()
		30: hud.toggle_inventory()
		40:
			ui.sel = 0; ui.refresh()
			ui.sel = -1
			ui._attach_from(Inventory.MAIN_START + 12)
			ui._attach_from(Inventory.MAIN_START + 13)
			ui._attach_from(Inventory.MAIN_START + 15)
			ui.refresh()
		60: snap("C1_inventory"); print("mods ", inv.get_item(0).get("mods"))
		61: hud.toggle_inventory()
		140: snap("C2_hip")
		141: pl.viewmodel.toggle_aim()
		200: snap("C3_ads_holo")
		201: pl.viewmodel.set_trigger(true)
		204: snap("C4_fire_silenced"); pl.viewmodel.set_trigger(false)
		210: pl.viewmodel.toggle_aim(); pl.set_third_person(true); pl.rotation.y = deg_to_rad(160)
		280: snap("C5_third")
		281: pl.set_third_person(false); pl.rotation.y = 0.0
		290:
			var it = inv.get_item(0)
			it.mods = ["8x_zoom_scope", "muzzle_brake"]
			pl.equip_item(it)
		380: pl.viewmodel.toggle_aim()
		440: snap("C6_8x_scope")
		441: pl.viewmodel.toggle_aim()
		500: snap("C7_8x_hip")
		501: quit()
	return false
