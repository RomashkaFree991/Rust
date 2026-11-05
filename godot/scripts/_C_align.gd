extends SceneTree
## Вычисляет для каждого оружия с обвесами преобразование «кость main вьюмодели c_ -> модель w_» (подгонка облаков точек).
const ARM := ["hand_mesh", "Hoodie_vm", "TacticalGloves_vm", "BurlapGloves_vm", "RoadsignGloves_vm"]

func pts(root: Node3D, skip_arms: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var nm := String(m.name)
		var skip := false
		for a in ARM:
			if nm.begins_with(a): skip = true
		if skip_arms and skip: continue
		var xf: Transform3D = root.global_transform.affine_inverse() * m.global_transform
		for s in m.mesh.get_surface_count():
			for v in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	return out

func sub(p: PackedVector3Array, n: int) -> PackedVector3Array:
	var o := PackedVector3Array()
	var step: int = max(1, p.size() / n)
	for i in range(0, p.size(), step): o.append(p[i])
	return o

func pca(p: PackedVector3Array) -> Array:
	var c := Vector3.ZERO
	for v in p: c += v
	c /= p.size()
	var m := [[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0]]
	for v in p:
		var d := v - c
		for i in 3:
			for j in 3:
				m[i][j] += d[i] * d[j]
	# степенной метод с дефляцией
	var axes := []
	for k in 3:
		var x := Vector3(1, 0.3, 0.1) if k == 0 else (Vector3(0.2, 1, 0.3) if k == 1 else Vector3(0.1, 0.2, 1))
		for it in 200:
			var y := Vector3(m[0][0]*x.x+m[0][1]*x.y+m[0][2]*x.z, m[1][0]*x.x+m[1][1]*x.y+m[1][2]*x.z, m[2][0]*x.x+m[2][1]*x.y+m[2][2]*x.z)
			for a in axes: y -= a * y.dot(a)
			x = y.normalized()
		axes.append(x)
	return [c, axes]

func score(a: PackedVector3Array, b: PackedVector3Array, t: Transform3D) -> float:
	var s := 0.0
	for v in a:
		var w := t * v
		var best := 1e9
		for u in b:
			best = min(best, w.distance_squared_to(u))
		s += best
	return sqrt(s / a.size())

func icp(a: PackedVector3Array, b: PackedVector3Array, t: Transform3D) -> Transform3D:
	for it in 8:
		# соответствия
		var src := []
		var dst := []
		for v in a:
			var w := t * v
			var best := 1e9
			var bu := Vector3.ZERO
			for u in b:
				var d := w.distance_squared_to(u)
				if d < best: best = d; bu = u
			src.append(w); dst.append(bu)
		# Кабш через кватернионную оптимизацию (Хорн) — упрощённо: малый шаг по градиенту
		var cs := Vector3.ZERO; var cd := Vector3.ZERO
		for i in src.size(): cs += src[i]; cd += dst[i]
		cs /= src.size(); cd /= dst.size()
		var h := [[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0]]
		for i in src.size():
			var x: Vector3 = src[i] - cs
			var y: Vector3 = dst[i] - cd
			for r in 3:
				for c in 3:
					h[r][c] += x[r] * y[c]
		var n := [
			[h[0][0]+h[1][1]+h[2][2], h[1][2]-h[2][1], h[2][0]-h[0][2], h[0][1]-h[1][0]],
			[h[1][2]-h[2][1], h[0][0]-h[1][1]-h[2][2], h[0][1]+h[1][0], h[2][0]+h[0][2]],
			[h[2][0]-h[0][2], h[0][1]+h[1][0], -h[0][0]+h[1][1]-h[2][2], h[1][2]+h[2][1]],
			[h[0][1]-h[1][0], h[2][0]+h[0][2], h[1][2]+h[2][1], -h[0][0]-h[1][1]+h[2][2]]]
		var q := [1.0, 0.0, 0.0, 0.0]
		var shift := 0.0
		for r in 4: shift += abs(n[r][0]) + abs(n[r][1]) + abs(n[r][2]) + abs(n[r][3])
		for k in 100:
			var nq := [0.0, 0.0, 0.0, 0.0]
			for r in 4:
				for c in 4:
					nq[r] += (n[r][c] + (shift if r == c else 0.0)) * q[c]
			var l := sqrt(nq[0]*nq[0]+nq[1]*nq[1]+nq[2]*nq[2]+nq[3]*nq[3])
			for r in 4: q[r] = nq[r] / l
		var rot := Basis(Quaternion(q[1], q[2], q[3], q[0]).normalized())
		var step := Transform3D(rot, cd - rot * cs)
		t = step * t
	return t

func _init():
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/attachments.json"))
	var res := {}
	for id in data.weapons:
		var d := Items.get_def(id)
		if d.is_empty() or not d.has("scene") or not d.has("world"): continue
		var c: Node3D = load(d.scene).instantiate(); get_root().add_child(c)
		var w: Node3D = load(d.world).instantiate(); get_root().add_child(w)
		var sk: Skeleton3D = c.find_child("Skeleton3D", true, false)
		var bi := sk.find_bone("main")
		if bi < 0:
			print("NO MAIN ", id); c.free(); w.free(); continue
		var gm: Transform3D = (c.global_transform.affine_inverse() * sk.global_transform) * sk.get_bone_global_rest(bi)
		var pa := pts(c, true)
		var a := PackedVector3Array()
		for v in pa: a.append(gm.affine_inverse() * v)
		var b := pts(w, false)
		var a1 := sub(a, 250); var b1 := sub(b, 600)
		var A: Array = pca(a1); var B: Array = pca(b1)
		var best_t := Transform3D(); var best_s := 1e9
		for sx in [1, -1]:
			for sy in [1, -1]:
				var ax: Array = A[1]; var bx: Array = B[1]
				var ba := Basis(ax[0], ax[1], (ax[0] as Vector3).cross(ax[1]))
				var bb := Basis(bx[0] * sx, bx[1] * sy, ((bx[0] as Vector3) * sx).cross(bx[1] * sy))
				var rot := bb * ba.inverse()
				var t := Transform3D(rot, (B[0] as Vector3) - rot * (A[0] as Vector3))
				t = icp(a1, b1, t)
				var sc := score(a1, b1, t)
				if sc < best_s: best_s = sc; best_t = t
		print(id, " rms ", snapped(best_s, 0.0001))
		var t := best_t
		res[id] = [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z, best_s]
		c.free(); w.free()
	var f := FileAccess.open("res://assets/data/attachments_world.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " "))
	f.close()
	quit()
