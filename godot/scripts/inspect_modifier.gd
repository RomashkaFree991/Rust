extends SkeletonModifier3D
class_name InspectModifier
## Осмотр оружия поверх анимации: поворачивает само оружие (корневые кости, не ValveBiped)
## и кисти рук вокруг центра оружия, а предплечья только доворачивает к кистям.
## Так обрезанные концы рук вьюмодели остаются за кадром, как в настоящих анимациях осмотра.

var rot := Basis()          # поворот в пространстве скелета
var gun_roots: Array = []
var pivot_bone := -1
var arms: Array = []        # [[forearm, hand], ...]

func setup(sk: Skeleton3D) -> void:
	gun_roots.clear()
	arms.clear()
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if sk.get_bone_parent(i) == -1 and not n.begins_with("ValveBiped"):
			gun_roots.append(i)
	pivot_bone = sk.find_bone("main")
	if pivot_bone == -1 and gun_roots.size() > 0:
		pivot_bone = gun_roots[0]
	for side in ["R", "L"]:
		var f := sk.find_bone("ValveBiped.Bip01_%s_Forearm" % side)
		var h := sk.find_bone("ValveBiped.Bip01_%s_Hand" % side)
		if f >= 0 and h >= 0:
			arms.append([f, h])

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or pivot_bone < 0 or rot.is_equal_approx(Basis()):
		return
	var p := sk.get_bone_global_pose(pivot_bone).origin
	var xf := Transform3D(rot, p - rot * p)
	var targets := {}
	for a in arms:
		targets[a[1]] = xf * sk.get_bone_global_pose(a[1])
	for b in gun_roots:
		sk.set_bone_global_pose(b, xf * sk.get_bone_global_pose(b))
	for a in arms:
		var fg := sk.get_bone_global_pose(a[0])
		var to: Vector3 = (targets[a[1]] as Transform3D).origin - fg.origin
		if to.length() > 0.0001:
			var q := Quaternion(fg.basis.x.normalized(), to.normalized())
			sk.set_bone_global_pose(a[0], Transform3D(Basis(q) * fg.basis, fg.origin))
		sk.set_bone_global_pose(a[1], targets[a[1]])
