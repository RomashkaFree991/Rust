extends SceneTree
func _init():
	for w in ["w_rocketlauncher","w_bow","w_compoundbow","w_crossbow","w_ak47u","w_m92","w_c4","w_f1","w_syringe_v2","w_salvaged_sword","w_rock"]:
		var n: Node3D = load("res://assets/weapons/%s.gltf" % w).instantiate()
		get_root().add_child(n)
		var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
		for i in sk.get_bone_count():
			var r := sk.get_bone_global_rest(i)
			print(w, " bone ", sk.get_bone_name(i), " par ", sk.get_bone_parent(i), " o ", r.origin.snapped(Vector3.ONE*0.001), " x ", r.basis.x.normalized().snapped(Vector3.ONE*0.01), " y ", r.basis.y.normalized().snapped(Vector3.ONE*0.01))
		for m in n.find_children("*", "MeshInstance3D", true, false):
			print(w, " mesh ", m.name, " skin ", m.skin != null, " aabb ", m.get_aabb())
		n.free()
	quit()
