class_name Rig
extends Node3D
## Procedural character model + weapon + animations.
##
## The SAME arms are used in first and third person ("true first person"):
## the camera sits in the head, the head is hidden from the first-person camera,
## and both hands are placed on the weapon with two-bone IK. That is why the
## hands you see in first person always match the character model.

signal footstep

const UPPER_LEN := 0.33
const FORE_LEN := 0.32
const HEAD_LAYER := 2

const HIP_POS := Vector3(0.13, -0.01, -0.36)
const HIP_ROT := Vector3(0.0, 0.06, 0.0)
const ADS_POS := Vector3(0.0, 0.125, -0.36)
const EYE_POS := Vector3(0.0, 0.2, -0.05)

## Left-hand keyframes during reload: [time, marker]
const L_KEYS := [
	[0.0, "fore"], [0.3, "magwell"], [0.4, "magwell"], [0.55, "magdown"],
	[0.95, "pouch"], [1.05, "pouch"], [1.38, "magdown"], [1.42, "magwell"],
	[1.55, "magwell"], [1.72, "bolt"], [1.8, "bolt"], [1.9, "boltback"],
	[2.2, "fore"],
]
const RELOAD_TIME := 2.2
const MAG_DROP_T := 0.55
const MAG_IN_T := 1.42

var aim_pivot: Node3D
var fp_camera: Camera3D
var weapon_holder: Node3D
var weapon: Node3D
var mag: Node3D
var muzzle: Node3D
var muzzle_flash: Node3D
var muzzle_light: OmniLight3D
var grip_r: Node3D
var grip_l: Node3D
var magwell: Node3D
var bolt_marker: Node3D
var pouch: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var upper_l: Node3D
var fore_l: Node3D
var hand_l: Node3D
var upper_r: Node3D
var fore_r: Node3D
var hand_r: Node3D
var hand_mag: Node3D
var body_root: Node3D
var thigh_l: Node3D
var thigh_r: Node3D
var knee_l: Node3D
var knee_r: Node3D

var mat_skin: StandardMaterial3D
var mat_jacket: StandardMaterial3D
var mat_pants: StandardMaterial3D
var mat_boots: StandardMaterial3D
var mat_cloth: StandardMaterial3D
var mat_metal: StandardMaterial3D
var mat_rust: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_flash: StandardMaterial3D

var _phase := 0.0
var _time := 0.0
var _mag_base := Vector3.ZERO
var _jump_blend := 0.0
var _move_blend := 0.0


static func make_mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, layer := 1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.layers = layer
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = length
	m.radial_segments = 10
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = PI / 2.0
	parent.add_child(mi)
	return mi


func _marker(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var m := Node3D.new()
	m.name = n
	m.position = pos
	parent.add_child(m)
	return m


func _ready() -> void:
	mat_skin = make_mat(Color(0.78, 0.6, 0.48))
	mat_jacket = make_mat(Color(0.33, 0.29, 0.2))
	mat_pants = make_mat(Color(0.22, 0.24, 0.26))
	mat_boots = make_mat(Color(0.14, 0.1, 0.07))
	mat_cloth = make_mat(Color(0.55, 0.18, 0.12))
	mat_metal = make_mat(Color(0.18, 0.18, 0.19), 0.45, 0.8)
	mat_rust = make_mat(Color(0.45, 0.23, 0.12), 0.9, 0.4)
	mat_wood = make_mat(Color(0.42, 0.27, 0.15), 0.8)
	mat_flash = StandardMaterial3D.new()
	mat_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_flash.albedo_color = Color(1.0, 0.8, 0.35)
	mat_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_flash.cull_mode = BaseMaterial3D.CULL_DISABLED
	_build_body()
	_build_upper()
	_build_weapon()
	_build_arms()


func _build_body() -> void:
	body_root = Node3D.new()
	add_child(body_root)
	# Pelvis, torso, backpack
	box(body_root, Vector3(0.34, 0.18, 0.2), Vector3(0, 1.0, 0), mat_pants)
	box(body_root, Vector3(0.4, 0.42, 0.22), Vector3(0, 1.25, 0), mat_jacket)
	box(body_root, Vector3(0.3, 0.34, 0.12), Vector3(0, 1.24, 0.17), mat_rust)
	box(body_root, Vector3(0.42, 0.05, 0.24), Vector3(0, 1.08, 0), mat_boots) # belt
	box(body_root, Vector3(0.12, 0.08, 0.06), Vector3(-0.12, 1.08, -0.14), mat_wood) # pouch
	box(body_root, Vector3(0.12, 0.08, 0.1), Vector3(0, 1.48, 0), mat_skin) # neck
	# Legs
	var legs := []
	for side in [-1.0, 1.0]:
		var hip := _marker(body_root, "Hip", Vector3(0.1 * side, 0.95, 0))
		box(hip, Vector3(0.15, 0.46, 0.16), Vector3(0, -0.23, 0), mat_pants)
		var knee := _marker(hip, "Knee", Vector3(0, -0.46, 0))
		box(knee, Vector3(0.13, 0.44, 0.14), Vector3(0, -0.22, 0), mat_pants)
		box(knee, Vector3(0.14, 0.2, 0.16), Vector3(0, -0.36, 0), mat_boots)
		box(knee, Vector3(0.13, 0.07, 0.25), Vector3(0, -0.455, -0.05), mat_boots)
		legs.append([hip, knee])
	thigh_l = legs[0][0]
	knee_l = legs[0][1]
	thigh_r = legs[1][0]
	knee_r = legs[1][1]


func _build_upper() -> void:
	# Everything that follows the aim pitch: head, shoulders, weapon, FP camera.
	aim_pivot = _marker(self, "AimPivot", Vector3(0, 1.42, 0))
	var head := Node3D.new()
	head.position = Vector3(0, 0.24, 0)
	aim_pivot.add_child(head)
	box(head, Vector3(0.22, 0.26, 0.24), Vector3.ZERO, mat_skin, HEAD_LAYER)
	box(head, Vector3(0.24, 0.12, 0.26), Vector3(0, 0.1, 0.01), mat_cloth, HEAD_LAYER) # bandana
	box(head, Vector3(0.23, 0.1, 0.06), Vector3(0, -0.06, -0.11), mat_cloth, HEAD_LAYER) # face cloth
	box(head, Vector3(0.18, 0.04, 0.02), Vector3(0, 0.02, -0.125), mat_metal, HEAD_LAYER) # eyes
	shoulder_l = _marker(aim_pivot, "ShoulderL", Vector3(-0.19, -0.02, -0.02))
	shoulder_r = _marker(aim_pivot, "ShoulderR", Vector3(0.19, -0.02, -0.02))
	box(shoulder_l, Vector3(0.14, 0.13, 0.15), Vector3.ZERO, mat_jacket)
	box(shoulder_r, Vector3(0.14, 0.13, 0.15), Vector3.ZERO, mat_jacket)
	pouch = _marker(aim_pivot, "Pouch", Vector3(-0.12, -0.36, -0.12))
	fp_camera = Camera3D.new()
	fp_camera.position = EYE_POS
	fp_camera.near = 0.02
	fp_camera.fov = 70.0
	fp_camera.cull_mask = 0xFFFFF & ~HEAD_LAYER
	aim_pivot.add_child(fp_camera)


func _build_weapon() -> void:
	weapon_holder = _marker(aim_pivot, "WeaponHolder", HIP_POS)
	weapon = _marker(weapon_holder, "Rifle", Vector3.ZERO)
	# Scrap-built rifle (original design): rusty receiver, wooden stock, pipe barrel.
	box(weapon, Vector3(0.06, 0.09, 0.32), Vector3.ZERO, mat_rust)
	box(weapon, Vector3(0.065, 0.07, 0.2), Vector3(0, -0.005, -0.25), mat_wood)
	cyl(weapon, 0.016, 0.32, Vector3(0, 0.015, -0.33), mat_metal)
	cyl(weapon, 0.024, 0.06, Vector3(0, 0.015, -0.47), mat_metal) # muzzle brake
	box(weapon, Vector3(0.05, 0.1, 0.24), Vector3(0, -0.025, 0.27), mat_wood) # stock
	box(weapon, Vector3(0.055, 0.12, 0.03), Vector3(0, -0.03, 0.4), mat_boots) # butt pad
	var pg := box(weapon, Vector3(0.04, 0.11, 0.05), Vector3(0, -0.09, 0.08), mat_wood)
	pg.rotation.x = deg_to_rad(-15)
	box(weapon, Vector3(0.012, 0.03, 0.03), Vector3(0, -0.06, 0.03), mat_metal) # trigger
	box(weapon, Vector3(0.03, 0.012, 0.36), Vector3(0, 0.05, -0.05), mat_metal) # top rail
	# rear sight: two posts with a notch so the sight line stays clear
	box(weapon, Vector3(0.012, 0.022, 0.015), Vector3(-0.014, 0.064, 0.11), mat_metal)
	box(weapon, Vector3(0.012, 0.022, 0.015), Vector3(0.014, 0.064, 0.11), mat_metal)
	box(weapon, Vector3(0.006, 0.05, 0.006), Vector3(0, 0.05, -0.42), mat_metal) # front post
	box(weapon, Vector3(0.012, 0.02, 0.04), Vector3(-0.036, 0.02, -0.05), mat_metal) # charging handle
	mag = _marker(weapon, "Mag", Vector3(0, -0.1, -0.06))
	_mag_base = mag.position
	var mag_mesh := box(mag, Vector3(0.04, 0.16, 0.07), Vector3(0, -0.03, -0.01), mat_metal)
	mag_mesh.rotation.x = deg_to_rad(12)
	grip_r = _marker(weapon, "GripR", Vector3(0.005, -0.085, 0.09))
	grip_r.rotation.x = deg_to_rad(-15)
	grip_l = _marker(weapon, "GripL", Vector3(-0.01, -0.06, -0.2))
	magwell = _marker(weapon, "MagWell", Vector3(-0.02, -0.16, -0.07))
	bolt_marker = _marker(weapon, "Bolt", Vector3(-0.06, 0.02, -0.05))
	muzzle = _marker(weapon, "Muzzle", Vector3(0, 0.015, -0.52))
	muzzle_flash = Node3D.new()
	muzzle.add_child(muzzle_flash)
	for i in 3:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.14, 0.14) if i < 2 else Vector2(0.09, 0.22)
		q.mesh = qm
		q.material_override = mat_flash
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i == 0:
			q.rotation.y = PI / 2.0
		elif i == 2:
			q.rotation.x = -PI / 2.0
			q.position.z = -0.08
			q.rotation.y = PI / 2.0
		muzzle_flash.add_child(q)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.7, 0.3)
	muzzle_light.light_energy = 3.0
	muzzle_light.omni_range = 5.0
	muzzle.add_child(muzzle_light)
	muzzle_flash.visible = false
	muzzle_light.visible = false


func _build_arms() -> void:
	upper_l = _segment(UPPER_LEN, 0.1, mat_jacket)
	fore_l = _segment(FORE_LEN, 0.08, mat_jacket)
	upper_r = _segment(UPPER_LEN, 0.1, mat_jacket)
	fore_r = _segment(FORE_LEN, 0.08, mat_jacket)
	hand_l = _hand()
	hand_r = _hand()
	hand_mag = Node3D.new()
	hand_l.add_child(hand_mag)
	var hm := box(hand_mag, Vector3(0.04, 0.16, 0.07), Vector3(0.0, 0.02, -0.02), mat_metal)
	hm.rotation.x = deg_to_rad(12)
	hand_mag.visible = false


func _segment(length: float, width: float, mat: Material) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	box(n, Vector3(width, width, length + 0.03), Vector3(0, 0, -length / 2.0), mat)
	# glove cuff at the end of the forearm
	if length == FORE_LEN:
		box(n, Vector3(width + 0.015, width + 0.015, 0.05), Vector3(0, 0, -length + 0.03), mat_boots)
	return n


func _hand() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	box(n, Vector3(0.075, 0.09, 0.1), Vector3.ZERO, mat_skin)
	box(n, Vector3(0.03, 0.03, 0.06), Vector3(0.03, 0.03, -0.04), mat_skin) # thumb
	return n


## Called every frame by the player.
## p: pitch, ads(0..1), speed, forward_sign, on_floor, recoil(0..1), reload_t (-1 = none),
##    sprint(0..1), vertical_speed
func update_pose(delta: float, p: Dictionary) -> void:
	_time += delta
	var pitch: float = p.pitch
	var speed: float = p.speed
	var on_floor: bool = p.on_floor
	var ads: float = p.ads
	var recoil: float = p.recoil
	var reload_t: float = p.reload_t
	var sprint: float = p.sprint

	aim_pivot.rotation.x = pitch

	# ---------- legs / body ----------
	var target_jump := 0.0 if on_floor else 1.0
	_jump_blend = move_toward(_jump_blend, target_jump, delta * 6.0)
	var move_amt := clampf(speed / 5.0, 0.0, 1.3) if on_floor else 0.0
	_move_blend = move_toward(_move_blend, move_amt, delta * 6.0)
	if on_floor and speed > 0.2:
		var prev := _phase
		_phase += delta * (4.0 + speed * 1.3) * float(p.forward_sign)
		if signf(sin(prev)) != signf(sin(_phase)):
			footstep.emit()
	var amp := 0.65 * _move_blend
	var s := sin(_phase)
	var walk_tl := s * amp
	var walk_tr := -s * amp
	var walk_kl := -maxf(0.0, cos(_phase)) * amp * 1.4
	var walk_kr := -maxf(0.0, -cos(_phase)) * amp * 1.4
	thigh_l.rotation.x = lerpf(walk_tl, 0.7, _jump_blend)
	thigh_r.rotation.x = lerpf(walk_tr, 0.25, _jump_blend)
	knee_l.rotation.x = lerpf(walk_kl, -1.1, _jump_blend)
	knee_r.rotation.x = lerpf(walk_kr, -0.5, _jump_blend)
	var bob := -absf(sin(_phase)) * 0.035 * _move_blend
	position.y = bob - 0.05 * _jump_blend
	body_root.rotation.x = -0.08 * _move_blend * sprint

	# ---------- weapon pose ----------
	var pos := HIP_POS.lerp(ADS_POS, ads)
	var rot := HIP_ROT * (1.0 - ads)
	var sway_amt := 1.0 - ads * 0.85
	pos.x += sin(_phase * 0.5) * 0.012 * _move_blend * sway_amt
	pos.y += (sin(_time * 1.6) * 0.004 - absf(cos(_phase)) * 0.012 * _move_blend) * sway_amt
	pos.z += recoil * 0.06
	rot.x += recoil * 0.07
	pos.y -= 0.05 * _jump_blend * sway_amt
	# sprint: rifle lowered and canted
	pos += Vector3(-0.04, -0.05, 0.03) * sprint
	rot += Vector3(-0.5, 0.6, 0.2) * sprint
	if reload_t >= 0.0:
		var e := smoothstep(0.0, 0.3, reload_t) * (1.0 - smoothstep(1.95, RELOAD_TIME, reload_t))
		pos += Vector3(-0.07, 0.05, -0.1) * e
		rot += Vector3(0.1, 0.3, -1.0) * e
		if reload_t > 1.85 and reload_t < 2.0:
			pos.z += sin((reload_t - 1.85) / 0.15 * PI) * 0.02
	weapon_holder.position = pos
	weapon_holder.rotation = rot

	# ---------- magazine ----------
	if reload_t < 0.0:
		mag.visible = true
		mag.position = _mag_base
		hand_mag.visible = false
	else:
		mag.visible = reload_t < MAG_DROP_T or reload_t >= MAG_IN_T
		var off := 0.0
		if reload_t > 0.4 and reload_t < MAG_DROP_T:
			off = -0.12 * smoothstep(0.4, MAG_DROP_T, reload_t)
		elif reload_t >= MAG_IN_T and reload_t < MAG_IN_T + 0.1:
			off = -0.05 * (1.0 - smoothstep(MAG_IN_T, MAG_IN_T + 0.1, reload_t))
		mag.position = _mag_base + Vector3(0, off, 0)
		hand_mag.visible = reload_t > 0.95 and reload_t < MAG_IN_T

	# ---------- arms IK ----------
	var lt: Transform3D = grip_l.global_transform
	if reload_t >= 0.0:
		lt = Transform3D(grip_l.global_basis, _left_reload_target(reload_t))
	var pb := aim_pivot.global_basis
	_solve_arm(upper_r, fore_r, hand_r, shoulder_r.global_position, grip_r.global_transform,
			shoulder_r.global_position + pb * Vector3(0.5, -0.7, 0.1))
	_solve_arm(upper_l, fore_l, hand_l, shoulder_l.global_position, lt,
			shoulder_l.global_position + pb * Vector3(-0.3, -0.8, 0.0))


func _marker_pos(n: String) -> Vector3:
	var wb := weapon.global_basis
	match n:
		"fore":
			return grip_l.global_position
		"magwell":
			return magwell.global_position
		"magdown":
			return magwell.global_position - wb.y * 0.12
		"bolt":
			return bolt_marker.global_position
		"boltback":
			return bolt_marker.global_position + wb.z * 0.07
		"pouch":
			return pouch.global_position
	return grip_l.global_position


func _left_reload_target(t: float) -> Vector3:
	for i in range(L_KEYS.size() - 1):
		var a: Array = L_KEYS[i]
		var b: Array = L_KEYS[i + 1]
		if t >= a[0] and t <= b[0]:
			var k := smoothstep(float(a[0]), float(b[0]), t)
			return _marker_pos(a[1]).lerp(_marker_pos(b[1]), k)
	return _marker_pos("fore")


func _solve_arm(upper: Node3D, fore: Node3D, hand: Node3D, s: Vector3, target_xf: Transform3D, pole: Vector3) -> void:
	var a := UPPER_LEN
	var b := FORE_LEN
	var d := target_xf.origin - s
	var dist := clampf(d.length(), 0.05, a + b - 0.001)
	var dir := d.normalized()
	var t := s + dir * dist
	var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var ang := acos(cos_a)
	var pd := pole - s
	pd = (pd - dir * pd.dot(dir))
	if pd.length_squared() < 0.0001:
		pd = Vector3.DOWN
	pd = pd.normalized()
	var elbow := s + dir * (cos(ang) * a) + pd * (sin(ang) * a)
	_place(upper, s, elbow, pd)
	_place(fore, elbow, t, pd)
	hand.global_transform = Transform3D(target_xf.basis, t)


func _place(n: Node3D, from: Vector3, to: Vector3, up_hint: Vector3) -> void:
	var dir := (to - from).normalized()
	var up := -up_hint
	if absf(dir.dot(up)) > 0.98:
		up = Vector3.UP if absf(dir.y) < 0.9 else Vector3.FORWARD
	n.look_at_from_position(from, to, up)


func show_flash(on: bool) -> void:
	muzzle_flash.visible = on
	muzzle_light.visible = on
	if on:
		muzzle_flash.rotation.z = randf() * TAU
		var sc := randf_range(0.8, 1.3)
		muzzle_flash.scale = Vector3(sc, sc, sc)
