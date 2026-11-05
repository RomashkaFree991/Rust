extends SceneTree
var f := 0
var main
var out := "/tmp/claude-0/-home-user-Rust/92f95108-dc8c-522f-9e28-a1c30e2eb27b/scratchpad/agentB2/"
var log_lines := []
func _init():
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
func snap(n): get_root().get_texture().get_image().save_png(out + n + ".png")
func aim_at(p: Vector3):
	var pl = main.player
	var to: Vector3 = p - pl.head.global_position
	pl.rotation.y = atan2(-to.x, -to.z)
	pl.pitch = rad_to_deg(atan2(to.y, Vector2(to.x, to.z).length()))
func give_active(id, extra := {}):
	var inv = main.inv
	var it = Inventory.make(id, Items.max_stack(id))
	for k in extra: it[k] = extra[k]
	inv.slots[0] = it
	inv.changed.emit()
	main.hud._set_active(-1); main.hud._set_active(0)
func projs(): return main.get_children().filter(func(n): return n is Projectile)
func L(s): print("T ", s)
func _process(_d):
	f += 1
	var pl = main.player
	var vm = pl.viewmodel
	var inv = main.inv
	var bots = main.get_children().filter(func(n): return n is Bot)
	var b0 = bots[0]
	match f:
		20: pl.global_position = Vector3(-1.5, 0.1, 0); give_active("assault_rifle"); inv.give("explosive_556_rifle_ammo", 60); inv.give("incendiary_556_rifle_ammo", 60)
		90: aim_at(b0.global_position + Vector3(0, 1.1, 0)); L("pitch0 %.2f" % pl.pitch); vm.set_trigger(true)
		100: snap("01_ak_fire")
		130: vm.set_trigger(false); L("pitch after 10 shots %.2f rec_idx %d ammo %d" % [pl.pitch, pl.recoil_index, vm.item.ammo])
		135: vm.set_ammo_type("explosive_556_rifle_ammo"); L("type %s ammo %d state %s" % [vm.def.ammo, vm.item.ammo, vm.state])
		300: L("after reload type %s ammo %d explosive left %d 556 %d" % [vm.item.get("ammo_type"), vm.item.ammo, inv.count("explosive_556_rifle_ammo"), inv.count("556_rifle_ammo")]); b0.hp = 100; b0._update_label(); aim_at(b0.global_position + Vector3(0, 1.1, 0))
		301: vm.set_trigger(true)
		304: snap("02_explosive_ammo"); vm.set_trigger(false)
		306: vm.set_ammo_type("incendiary_556_rifle_ammo")
		470: aim_at(b0.global_position + Vector3(0, 1.1, 0)); vm.set_trigger(true)
		473: vm.set_trigger(false)
		490: snap("03_incendiary"); L("burn %.1f hp %.1f" % [b0.burn_t, b0.hp])
		500: give_active("rocket_launcher"); inv.give("rocket", 3); L("rl ammo %d rockets %d" % [vm.item.ammo, inv.count("rocket")])
		580: aim_at(Vector3(0, 0.5, -20)); vm.set_trigger(true)
		582: vm.set_trigger(false); L("rl after shot ammo %d rockets %d projs %d" % [vm.item.ammo, inv.count("rocket"), projs().size()])
		590: snap("04_rocket_fly")
		620: snap("05_rocket_boom")
		630: vm.reload(inv)
		800: L("rl after reload ammo %d rockets %d state %s" % [vm.item.ammo, inv.count("rocket"), vm.state])
		805: vm.set_trigger(true)
		807: vm.set_trigger(false); L("rl 2nd shot ammo %d rockets %d" % [vm.item.ammo, inv.count("rocket")])
		850: give_active("timed_explosive_charge"); L("c4 count %d" % inv.slots[0].amount)
		920: aim_at(Vector3(2, 0.3, -6)); vm.set_trigger(true)
		922: vm.set_trigger(false)
		960: L("c4 after throw count %s projs %d stuck %s" % [str(inv.slots[0].amount if inv.slots[0] else 0), projs().size(), str(projs()[0].stuck if projs().size() else "-")]); snap("06_c4_thrown")
		1000: give_active("hunting_bow"); inv.give("arrow", 10); b0.hp = 100; b0.wounded = false; b0.ch.wounded = false; b0._update_label()
		1070: aim_at(b0.global_position + Vector3(0, 1.4, 0)); L("arrows %d" % inv.count("arrow")); vm.set_trigger(true)
		1080: L("bow state %s projs %d" % [vm.bow_state, projs().size()])
		1120: snap("07_bow_drawn"); L("bow state %s" % vm.bow_state)
		1125: vm.set_trigger(false)
		1127: L("bow released projs %d ammo %d arrows %d" % [projs().size(), vm.item.ammo, inv.count("arrow")])
		1150: snap("08_bow_shot"); L("c4 projs %d bot hp %.1f" % [projs().size(), b0.hp])
		1200: vm.set_trigger(true)
		1210: vm.set_trigger(false); L("bow quick release state %s arrows %d ammo %d" % [vm.bow_state, inv.count("arrow"), vm.item.ammo])
		1250: snap("09_c4_boom_maybe"); L("projs %d" % projs().size())
		1260: give_active("crossbow"); inv.give("arrow", 5)
		1330: vm.set_trigger(true)
		1332: vm.set_trigger(false); L("xbow ammo %d projs %d" % [vm.item.ammo, projs().size()])
		1450: L("xbow after autoreload ammo %d state %s" % [vm.item.ammo, vm.state])
		1460: give_active("pump_shotgun", {"ammo": 0}); inv.give("12_gauge_slug", 10)
		1530: vm.reload(inv)
		1800: L("pump after reload ammo %d shell_phase '%s' state %s handmade %d" % [vm.item.ammo, vm.shell_phase, vm.state, inv.count("handmade_shell")])
		1810: give_active("satchel_charge"); 
		1880: aim_at(Vector3(-2, 0.3, -5)); vm.set_trigger(true)
		1882: vm.set_trigger(false)
		1900: give_active("bandage"); main.hud.health = 50
		1970: vm.set_trigger(true)
		1972: vm.set_trigger(false)
		2100: L("health %.1f bandage left %s" % [main.hud.health, str(inv.slots[0].amount if inv.slots[0] else 0)])
		2110: give_active("grenade_launcher"); inv.give("40mm_he_grenade", 6)
		2180: aim_at(Vector3(0, 0.3, -15)); vm.set_trigger(true)
		2182: vm.set_trigger(false); L("gl ammo %d" % vm.item.ammo)
		2230: snap("10_gl")
		2300: give_active("salvaged_sword")
		2360: pl.global_position = bots[1].global_position + Vector3(0, 0.1, 1.3); aim_at(bots[1].global_position + Vector3(0, 1.2, 0)); vm.set_trigger(true)
		2400: vm.set_trigger(false); L("bot1 hp %.1f" % bots[1].hp)
		2420: quit()
	return false
