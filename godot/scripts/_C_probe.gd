extends SceneTree
func _init():
	var n: Node3D = load("res://assets/weapons/ak47u.gltf").instantiate()
	get_root().add_child(n)
	var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
	var bi := sk.find_bone("main")
	var g := sk.get_bone_global_rest(bi)
	print("main G ", g)
	var mz: Node3D = n.find_child("muzzle", true, false)
	print("muzzle path ", mz.get_path(), " parent ", mz.get_parent().get_class())
	var rel: Transform3D = (sk.global_transform * g).affine_inverse() * mz.global_transform
	print("muzzle in main ", rel.origin / 0.01905, " basis ", rel.basis)
	quit()
