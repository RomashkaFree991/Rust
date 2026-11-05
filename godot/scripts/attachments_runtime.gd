extends Node
class_name AttachmentsRuntime
## Работа обвесов во время игры (как rust_gun/cl_init.lua):
## глушитель — без вспышки; 8x/16x — приближение камеры и прицельная сетка во весь экран
## (DrawZoomCrosshair), вьюмодель скрыта; ЛЦУ — красная точка; фонарь — луч света.

var vm
var st: Dictionary = {}
var scope_layer: CanvasLayer
var scope_rect: TextureRect
var bars: Array = []
var dot: MeshInstance3D
var light: SpotLight3D

func _ready() -> void:
	if st.get("scope", "") != "":
		scope_layer = CanvasLayer.new()
		scope_layer.layer = 3
		add_child(scope_layer)
		for i in 2:
			var b := ColorRect.new()
			b.color = Color.BLACK
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			scope_layer.add_child(b)
			bars.append(b)
		scope_rect = TextureRect.new()
		scope_rect.texture = load("res://assets/attachments/scope_%s.png" % st.scope)
		scope_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scope_layer.add_child(scope_rect)
		scope_layer.visible = false
	if st.get("laser", false):
		dot = MeshInstance3D.new()
		var s := SphereMesh.new(); s.radius = 0.025; s.height = 0.05
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 0.1, 0.1)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = false
		s.material = m
		dot.mesh = s
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.top_level = true
		add_child(dot)
	if st.get("flashlight", false) and vm.player:
		light = SpotLight3D.new()
		light.spot_range = 35.0
		light.spot_angle = 28.0
		light.light_energy = 3.0
		light.shadow_enabled = false
		vm.player.cam.add_child(light)
		light.position = Vector3(0.15, -0.15, 0)

func _exit_tree() -> void:
	if light and is_instance_valid(light):
		light.queue_free()
	if vm and is_instance_valid(vm.model):
		vm.model.visible = true

func _process(_delta: float) -> void:
	if vm == null or not is_instance_valid(vm):
		return
	if st.get("silenced", false):
		vm.flash_mesh.visible = false
		vm.flash_light.light_energy = 0.0
	var p = vm.player
	if p == null:
		return
	# прицел 8x / 16x
	if scope_layer:
		var on: bool = vm.aiming and vm.ads_t > 0.85 and not p.third_person
		scope_layer.visible = on
		if vm.model:
			vm.model.visible = not on
		if on:
			var vs: Vector2 = get_viewport().get_visible_rect().size
			var side: float = (vs.x - vs.y) * 0.5
			scope_rect.position = Vector2(side, 0)
			scope_rect.size = Vector2(vs.y, vs.y)
			bars[0].position = Vector2.ZERO; bars[0].size = Vector2(side, vs.y)
			bars[1].position = Vector2(vs.x - side, 0); bars[1].size = Vector2(side, vs.y)
			p.cam.fov = p.base_fov * float(st.zoom_mul) * 1.3
	# ЛЦУ: точка там, куда смотрит ствол
	if dot:
		var from: Vector3 = p.cam.global_position
		var dir: Vector3 = -p.cam.global_basis.z
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 120.0)
		q.exclude = [p.get_rid()]
		q.collision_mask = 3
		var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
		dot.visible = not h.is_empty()
		if not h.is_empty():
			dot.global_position = h.position + h.normal * 0.01
