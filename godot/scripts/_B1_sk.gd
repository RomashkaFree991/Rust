extends SceneTree
func _init():
	for m in ["c4", "ak47u"]:
		var n: Node3D = load("res://assets/weapons/%s.gltf" % m).instantiate()
		var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
		var out := []
		for i in sk.get_bone_count():
			var nm := sk.get_bone_name(i)
			if nm.contains("L_") and (nm.contains("Wrist") or nm.contains("Ulna") or nm.contains("Forearm") or nm.contains("Hand") or nm.contains("Upper") or nm.contains("Clav")):
				out.append("%s<-%s %s" % [nm.replace("ValveBiped.Bip01_",""), sk.get_bone_name(sk.get_bone_parent(i)).replace("ValveBiped.Bip01_",""), sk.get_bone_global_rest(i).origin.snapped(Vector3.ONE*0.001)])
		print(m, " ", out)
		n.free()
	quit()
