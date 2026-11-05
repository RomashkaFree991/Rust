extends RefCounted
class_name Attachments
## Обвесы оружия — перенос gRust:
##   описания обвесов на каждом оружии: SWEP.Attachments в entities/weapons/*.lua
##   (тип, модель, кость "main", позиция/угол/масштаб, своя точка прицеливания, сетка прицела)
##   -> assets/data/attachments.json (tools/godot_conversion/gen_attachments.py);
##   эффекты: SWEP:UpdateAttachments в entities/weapons/rust_gun/shared.lua
##   (глушитель, голограф, фонарь, 8x/16x прицелы, ЛЦУ, дульный тормоз, ускоритель);
##   отрисовка на вьюмодели: SWEP:ViewModelDrawn в rust_gun/cl_init.lua.
## У предмета-оружия: item.mods — массив id обвесов (не больше слотов оружия, по одному каждого типа).

const SU := 0.01905
const VM_LAYER := 2
## Source/Blender (Z вверх) -> координаты модели glTF в Godot (Y вверх): обратная матрица
const C_INV := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
const TYPE_NAMES := {"barrel": "Ствол", "sight": "Прицел", "underbarrel": "Подствол", "magazine": "Магазин", "stock": "Приклад", "other": "Другое"}

static var _data: Dictionary = {}
static var _world: Dictionary = {}
static var _scenes := {}
static var _tex := {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/attachments.json"))
		if FileAccess.file_exists("res://assets/data/attachments_world.json"):
			_world = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/attachments_world.json"))
	return _data

## Описание обвесов оружия: {slots, attachments{id: {...}}} или {}
static func weapon_info(weapon_id: String) -> Dictionary:
	var w: Dictionary = data().weapons.get(weapon_id, {})
	if w.is_empty() or w.get("attachments", {}).is_empty():
		return {}
	return w

static func is_attachment(id: String) -> bool:
	return Items.get_def(id).get("category", "") == "Attachments"

static func slot_count(weapon_id: String) -> int:
	var w := weapon_info(weapon_id)
	return int(w.get("slots", 0)) if not w.is_empty() else 0

static func mods_of(item) -> Array:
	if item == null or not item is Dictionary:
		return []
	if not item.has("mods"):
		item["mods"] = []
	return item.mods

## Можно ли поставить обвес на оружие (подходит модель, есть место, тип не занят)
static func can_attach(item: Dictionary, att_id: String) -> bool:
	var w := weapon_info(item.get("id", ""))
	if w.is_empty() or not w.attachments.has(att_id):
		return false
	var mods := mods_of(item)
	if mods.size() >= int(w.slots) or att_id in mods:
		return false
	var t: String = w.attachments[att_id].type
	for m in mods:
		if w.attachments.has(m) and w.attachments[m].type == t:
			return false
	return true

static func attach(item: Dictionary, att_id: String) -> bool:
	if not can_attach(item, att_id):
		return false
	mods_of(item).append(att_id)
	return true

## Эффекты (как SWEP:UpdateAttachments)
static func stats(item: Dictionary) -> Dictionary:
	var st := {"silenced": false, "flashlight": false, "laser": false, "zoom_mul": 1.0, "scope": "",
		"damage_mul": 1.0, "velocity_mul": 1.0, "cone_mul": 1.0, "recoil_mul": 1.0, "rof_mul": 1.0, "ads": null}
	var w := weapon_info(item.get("id", ""))
	if w.is_empty():
		return st
	for id in mods_of(item):
		var a: Dictionary = w.attachments.get(id, {})
		if a.is_empty():
			continue
		if a.has("ads"):
			st.ads = a.ads
		match id:
			"silencer":
				st.silenced = true
				st.damage_mul *= 0.75
				st.velocity_mul *= 0.75
			"holosight":
				st.cone_mul *= 0.8
			"weapon_flashlight":
				st.flashlight = true
			"8x_zoom_scope":
				st.scope = "8x"
				st.recoil_mul *= 1.5
				st.zoom_mul = 0.2
			"16x_zoom_scope":
				st.scope = "16x"
				st.recoil_mul *= 1.5
				st.zoom_mul = 0.1
			"weapon_lasersight":
				st.laser = true
				st.cone_mul *= 0.8
			"muzzle_brake":
				st.damage_mul *= 0.8
				st.cone_mul *= 1.2
				st.velocity_mul *= 0.8
				st.recoil_mul *= 0.5
			"muzzle_boost":
				st.damage_mul *= 0.9
				st.rof_mul *= 1.1
				st.velocity_mul *= 0.9
	return st

## Описание оружия с учётом обвесов (копия Items.get_def)
static func modded_def(base: Dictionary, item: Dictionary) -> Dictionary:
	var st := stats(item)
	var d := base.duplicate()
	if d.has("damage"):
		d.damage = float(d.damage) * st.damage_mul
	if d.has("rpm"):
		d.rpm = float(d.rpm) * st.rof_mul
	if d.has("spread"):
		d.spread = float(d.spread) * st.cone_mul
	if d.has("kick"):
		d.kick = Vector2(d.kick) * st.recoil_mul
	if st.ads != null:
		d.ads = st.ads
	d["mod_stats"] = st
	return d

# ---------- модели ----------

static func _scene(model_path: String) -> PackedScene:
	var n := model_path.get_file().get_basename().to_lower()
	if not _scenes.has(n):
		var p := "res://assets/attachments/%s.gltf" % n
		_scenes[n] = load(p) if ResourceLoader.exists(p) else null
	return _scenes[n]

static func _v(a) -> Vector3:
	return Vector3(a[0], a[1], a[2]) if a is Array and a.size() >= 3 else Vector3.ZERO

## Положение обвеса относительно кости (как в ViewModelDrawn: pos + Forward*x + Right*y + Up*z,
## затем RotateAroundAxis(Up, yaw), (Right, pitch), (Forward, roll)); в координатах кости Source (метры).
static var dbg_mode := 0
static func gmod_offset(pos: Vector3, ang: Vector3) -> Transform3D:
	if dbg_mode == 1: ang.y = -ang.y
	elif dbg_mode == 2: ang = -ang
	elif dbg_mode == 3: ang.x = -ang.x
	var r := Basis()
	r = r * Basis(Vector3(0, 0, 1), deg_to_rad(ang.y))
	r = r * Basis(Vector3(0, -1, 0), deg_to_rad(ang.x))
	r = r * Basis(Vector3(1, 0, 0), deg_to_rad(ang.z))
	return Transform3D(r, Vector3(pos.x, -pos.y, pos.z) * SU)

static func _model_xf(a: Dictionary) -> Transform3D:
	var t := gmod_offset(_v(a.pos), _v(a.ang))
	var s: float = a.get("scale", 1.0)
	return t * Transform3D(C_INV.scaled(Vector3(s, s, s)), Vector3.ZERO)

static func _setup_mesh(n: Node, layer: int, cast: int) -> void:
	for m in n.find_children("*", "GeometryInstance3D", true, false):
		m.layers = layer
		m.cast_shadow = cast
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat = m.get_active_material(s)
			if mat is StandardMaterial3D:
				var nm: StandardMaterial3D = mat.duplicate()
				var rn := String(nm.resource_name).to_lower()
				nm.metallic = 0.0
				nm.roughness = 0.65
				if rn.contains("glass") or rn.contains("lense") or rn.contains("crosshair"):
					# стекло прицела — прозрачное
					nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					nm.albedo_color = Color(0.6, 0.75, 0.8, 0.15)
					nm.albedo_texture = null
				else:
					nm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					nm.albedo_color = Color(1.5, 1.5, 1.5)
				m.set_surface_override_material(s, nm)

static func _reticle(a: Dictionary, layer: int) -> Node3D:
	if not a.has("reticle_pos"):
		return null
	var col: Array = a.get("reticle_color", [1, 0, 0])
	var holo: bool = col[0] > 0.5 and col[1] < 0.5
	var tp := "res://assets/attachments/%s" % ("holosight.reticle.standard.png" if holo else "xhair_highvis.png")
	if not _tex.has(tp):
		_tex[tp] = load(tp)
	var draw_size: float = 80.0 if holo else 140.0
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var sz: float = draw_size * float(a.get("reticle_scale", 0.01)) * SU
	q.size = Vector2(sz, sz)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex[tp]
	m.albedo_color = Color(col[0], col[1], col[2])
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if holo else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.render_priority = 10
	q.material = m
	mi.mesh = q
	mi.layers = layer
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# рамка обвеса -> смещение прицельной метки -> поворот (как cam.Start3D2D: плоскость Forward/Right, нормаль Up)
	var frame := gmod_offset(_v(a.pos), _v(a.ang)) * gmod_offset(_v(a.reticle_pos), _v(a.reticle_ang))
	# квад Godot: X — вправо (Forward 3D2D), Y — вверх (-Right), нормаль Z = Up
	mi.transform = frame * Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)), Vector3.ZERO)
	return mi

## Обвесы на модели от первого лица. Вызывается из ViewModel.equip() сразу после создания модели.
static func attach_viewmodel(vm, model: Node3D, item: Dictionary, skel: Skeleton3D) -> void:
	var old = vm.get_node_or_null("AttRuntime")
	if old:
		old.queue_free()
	if vm.player and vm.player.body:
		vm.player.body.set_meta("weapon_item", item)
	var w := weapon_info(item.get("id", ""))
	if w.is_empty() or skel == null:
		return
	var mods := mods_of(item)
	vm.def = modded_def(vm.def, item)
	var st: Dictionary = vm.def.mod_stats
	if st.silenced and not w.get("silenced_files", []).is_empty():
		vm.shoot_streams.clear()
		for p in w.silenced_files:
			vm.shoot_streams.append(load(p))
	var holder: Node3D = null
	for id in mods:
		var a: Dictionary = w.attachments.get(id, {})
		var sc := _scene(a.get("model", ""))
		if a.is_empty() or sc == null:
			continue
		var bi := skel.find_bone(a.get("bone", "main"))
		if bi < 0:
			continue
		if holder == null:
			var ba := BoneAttachment3D.new()
			ba.name = "AttMods"
			skel.add_child(ba)
			ba.bone_name = skel.get_bone_name(bi)
			holder = ba
		var n: Node3D = sc.instantiate()
		n.transform = _model_xf(a)
		holder.add_child(n)
		_setup_mesh(n, VM_LAYER, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var r := _reticle(a, VM_LAYER)
		if r:
			holder.add_child(r)
		if id == "silencer" or id == "muzzle_brake" or id == "muzzle_boost":
			n.set_meta("barrel", true)
	var rt := AttachmentsRuntime.new()
	rt.name = "AttRuntime"
	rt.vm = vm
	rt.st = st
	vm.add_child(rt)

## Обвесы на модели в мире (3-е лицо). Вызывается из Character.set_weapon().
static func attach_world(ch, weapon_node: Node3D, weapon_id: String, item: Dictionary = {}) -> void:
	if weapon_node == null:
		return
	if item.is_empty() and ch.has_meta("weapon_item"):
		var mi: Dictionary = ch.get_meta("weapon_item")
		if mi.get("id", "") == weapon_id:
			item = mi
	var w := weapon_info(weapon_id)
	data()
	var al: Array = _world.get(weapon_id, [])
	if w.is_empty() or item.is_empty() or al.size() < 12:
		return
	var align := Transform3D(Basis(Vector3(al[0], al[1], al[2]), Vector3(al[3], al[4], al[5]), Vector3(al[6], al[7], al[8])), Vector3(al[9], al[10], al[11]))
	for id in mods_of(item):
		var a: Dictionary = w.attachments.get(id, {})
		var sc := _scene(a.get("model", ""))
		if a.is_empty() or sc == null:
			continue
		var n: Node3D = sc.instantiate()
		n.transform = align * _model_xf(a)
		weapon_node.add_child(n)
		_setup_mesh(n, ch.layer_mask, ch.cast_mode)
