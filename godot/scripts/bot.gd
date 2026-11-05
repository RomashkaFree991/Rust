extends Node3D
class_name Bot
## Бот-мишень: стоит на месте, смотрит на игрока, держит оружие.
## Хитбоксы на костях: голова / тело / руки / ноги. Урон с учётом зоны и брони, звуки попаданий,
## крик при смерти, падение и возрождение.

signal killed(bot: Bot)

const ZONES := {
	# зона: [кость, тип формы, радиус, длина, смещение вдоль кости, множитель урона]
	"head": ["Head1", "sphere", 0.115, 0.0, 0.09, 2.0],
	"chest": ["Spine2", "capsule", 0.17, 0.52, 0.12, 1.0],
	"stomach": ["Pelvis", "capsule", 0.16, 0.36, 0.06, 0.9],
	"l_upperarm": ["L_UpperArm", "capsule", 0.06, 0.3, 0.13, 0.6],
	"r_upperarm": ["R_UpperArm", "capsule", 0.06, 0.3, 0.13, 0.6],
	"l_forearm": ["L_Forearm", "capsule", 0.05, 0.3, 0.13, 0.5],
	"r_forearm": ["R_Forearm", "capsule", 0.05, 0.3, 0.13, 0.5],
	"l_thigh": ["L_Thigh", "capsule", 0.085, 0.45, 0.2, 0.6],
	"r_thigh": ["R_Thigh", "capsule", 0.085, 0.45, 0.2, 0.6],
	"l_calf": ["L_Calf", "capsule", 0.07, 0.42, 0.2, 0.5],
	"r_calf": ["R_Calf", "capsule", 0.07, 0.42, 0.2, 0.5],
}
const ZONE_SLOT := {"head": ["head", "face"], "chest": ["torso"], "stomach": ["torso"], "l_upperarm": ["torso"],
	"r_upperarm": ["torso"], "l_forearm": ["torso", "hands"], "r_forearm": ["torso", "hands"],
	"l_thigh": ["legs"], "r_thigh": ["legs"], "l_calf": ["legs", "feet"], "r_calf": ["legs", "feet"]}

var ch: Character
var bot_name := "Бот"
var hp := 100.0
var dead := false
var attire: Array = []
var weapon := ""
var target: Node3D
var bodies := {}
var label: Label3D
var bar_mat: ShaderMaterial
var snd_head: AudioStream
var snd_body: AudioStream
var snd_flesh: Array = []
var snd_pain: Array = []
var snd_death: Array = []
var hit_flash := 0.0
var wounded := false
var wounded_t := 0.0

func _ready() -> void:
	ch = Character.new()
	add_child(ch)
	ch.set_attire(attire)
	ch.set_weapon(weapon)
	for z in ZONES:
		var d: Array = ZONES[z]
		var b := StaticBody3D.new()
		b.set_meta("bot", self)
		b.set_meta("zone", z)
		b.collision_layer = 2
		var cs := CollisionShape3D.new()
		var sc := Character.SCALE
		if d[1] == "sphere":
			var sp := SphereShape3D.new(); sp.radius = d[2] * sc
			cs.shape = sp
		else:
			var cp := CapsuleShape3D.new(); cp.radius = d[2] * sc; cp.height = max(d[3] * sc, cp.radius * 2.0 + 0.01)
			cs.shape = cp
			cs.rotation_degrees.z = 90.0   # ось капсулы (Y) вдоль кости (X)
		cs.position = Vector3(d[4] * sc, 0, 0)
		b.add_child(cs)
		add_child(b)
		bodies[z] = b
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.004
	label.outline_size = 10
	label.no_depth_test = true
	label.position = Vector3(0, 2.14, 0)
	add_child(label)
	# полоска здоровья
	var bar := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.7, 0.07)
	bar_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;
uniform float fill = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 b = step(vec2(0.02, 0.12), UV) * step(UV, vec2(0.98, 0.88));
	float inner = b.x * b.y;
	vec3 hp = mix(vec3(0.9, 0.2, 0.15), vec3(0.35, 0.85, 0.3), fill);
	ALBEDO = inner > 0.5 ? (UV.x < 0.02 + fill * 0.96 ? hp : vec3(0.12)) : vec3(0.0);
	ALPHA = 0.85;
}"""
	bar_mat.shader = sh
	q.material = bar_mat
	bar.mesh = q
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.position = Vector3(0, 2.02, 0)
	add_child(bar)
	snd_head = load("res://assets/sounds/headshot.wav")
	snd_body = load("res://assets/sounds/hitmarker.wav")
	for i in range(1, 4):
		snd_flesh.append(load("res://assets/sounds/flesh_bullet_impact-%d.mp3" % i))
		snd_death.append(load("res://assets/sounds/scream%d.wav" % i))
	snd_pain = [load("res://assets/sounds/pl_fallpain1.wav"), load("res://assets/sounds/pl_fallpain3.wav")]
	_update_label()

func _update_label() -> void:
	label.text = ("%s   РАНЕН" % bot_name) if wounded else ("%s   %d HP" % [bot_name, int(ceil(hp))])
	label.modulate = Color(1, 1, 1) if hp > 0 else Color(1, 0.4, 0.3)
	if bar_mat:
		bar_mat.set_shader_parameter("fill", clamp(hp / 100.0, 0.0, 1.0))

func _physics_process(delta: float) -> void:
	if ch == null or ch.sk == null:
		return
	if not dead and not wounded and target:
		var to := target.global_position - global_position
		var want := atan2(to.x, to.z)
		rotation.y = lerp_angle(rotation.y, want, clamp(delta * 2.0, 0.0, 1.0))
		ch.look_target = target.global_position + Vector3(0, 1.5, 0)
		var dist := Vector2(to.x, to.z).length()
		ch.aim_pitch = rad_to_deg(atan2(1.5 - 1.45, max(dist, 0.1)))
	# хитбоксы следуют за костями
	for z in bodies:
		var t := ch.bone_global(ZONES[z][0])
		bodies[z].global_transform = Transform3D(t.basis.orthonormalized(), t.origin)
	if hit_flash > 0.0:
		hit_flash -= delta
	if wounded:
		wounded_t -= delta
		if wounded_t <= 0.0:
			_die(Vector3.FORWARD)
			_update_label()

func _play3d(stream: AudioStream, pos: Vector3, vol := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = vol
	p.unit_size = 8.0
	get_parent().add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)

func _play2d(stream: AudioStream, vol := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func protection(zone: String) -> float:
	var p := 0.0
	for id in attire:
		var d := Items.get_def(id)
		if d.get("slot") in ZONE_SLOT.get(zone, []):
			p += d.get("prot", 0.0)
	return clamp(p, 0.0, 0.8)

## Попадание: возвращает {"damage", "zone", "killed", "headshot"}
func take_hit(zone: String, base_damage: float, pos: Vector3, dir: Vector3, melee := false) -> Dictionary:
	if dead:
		return {}
	var mul: float = ZONES[zone][5]
	var dmg: float = base_damage * mul * (1.0 - protection(zone))
	if wounded:
		# добивание раненого
		_spawn_damage_text(pos, dmg, zone == "head")
		_play3d(snd_flesh[randi() % snd_flesh.size()], pos, 2.0)
		_die(dir)
		_update_label()
		return {"damage": dmg, "zone": zone, "killed": true, "headshot": zone == "head"}
	hp -= dmg
	var head := zone == "head"
	_play3d(snd_flesh[randi() % snd_flesh.size()], pos, 2.0)
	_play2d(snd_head if head else snd_body, 0.0 if head else -4.0)
	_spawn_damage_text(pos, dmg, head)
	# толчок от попадания
	position += Vector3(dir.x, 0, dir.z).normalized() * 0.03
	var died := hp <= 0.0
	if died and (head or base_damage >= 150.0):
		_die(dir)             # в голову или взрывом — сразу насмерть
	elif died:
		_wound()              # как в Rust: падает раненым, можно поднять или добить
		died = false
	else:
		ch.play_hit()
	if not died and randf() < 0.35:
		_play3d(snd_pain[randi() % snd_pain.size()], global_position + Vector3(0, 1.6, 0))
	_update_label()
	return {"damage": dmg, "zone": zone, "killed": died, "headshot": head, "wounded": wounded}

func _spawn_damage_text(pos: Vector3, dmg: float, head: bool) -> void:
	var l := Label3D.new()
	l.text = ("%d" % roundi(dmg)) + (" ГОЛОВА" if head else "")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64 if head else 48
	l.pixel_size = 0.004
	l.outline_size = 12
	l.modulate = Color(1, 0.3, 0.2) if head else Color(1, 1, 1)
	get_parent().add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.15, 0.15), 0.1, 0)
	var t := l.create_tween()
	t.tween_property(l, "global_position", l.global_position + Vector3(0, 0.6, 0), 0.9)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	t.tween_callback(l.queue_free)

func _wound() -> void:
	wounded = true
	wounded_t = 30.0
	hp = 0.0
	ch.wounded = true
	_play3d(snd_pain[randi() % snd_pain.size()], global_position + Vector3(0, 1.0, 0), 3.0)

## Поднять раненого (кнопка «ПОДНЯТЬ» рядом с ним)
func revive() -> void:
	if not wounded or dead:
		return
	wounded = false
	ch.wounded = false
	hp = 35.0
	_play2d(load("res://assets/sounds/notify.wav"), -4.0)
	_update_label()

func _die(dir: Vector3) -> void:
	ch.dead_lying = wounded
	wounded = false
	ch.wounded = false
	dead = true
	hp = 0.0
	ch.dead = true
	_play3d(snd_death[randi() % snd_death.size()], global_position + Vector3(0, 1.6, 0), 3.0)
	for b in bodies.values():
		b.collision_layer = 0
	# анимация смерти, через 4 секунды встать
	var start := transform
	var t := create_tween()
	t.tween_interval(4.0)
	t.tween_callback(_respawn.bind(start))
	killed.emit(self)

func _respawn(start: Transform3D) -> void:
	transform = start
	dead = false
	ch.dead = false
	ch.dead_lying = false
	hp = 100.0
	for b in bodies.values():
		b.collision_layer = 2
	_update_label()
