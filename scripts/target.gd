class_name ShootTarget
extends StaticBody3D
## Pop-up target: falls back when hit, rises again after 2 seconds.

var board: Node3D
var _down := false


func _ready() -> void:
	board = Node3D.new()
	add_child(board)
	var wood := Rig.make_mat(Color(0.5, 0.36, 0.2))
	var red := Rig.make_mat(Color(0.75, 0.15, 0.1))
	var white := Rig.make_mat(Color(0.9, 0.88, 0.8))
	Rig.box(board, Vector3(0.08, 1.0, 0.08), Vector3(0, 0.5, 0.03), wood)
	Rig.box(board, Vector3(0.6, 0.8, 0.04), Vector3(0, 1.3, 0), wood)
	Rig.box(board, Vector3(0.4, 0.4, 0.05), Vector3(0, 1.35, 0), white)
	Rig.box(board, Vector3(0.18, 0.18, 0.06), Vector3(0, 1.35, 0), red)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.6, 0.8, 0.1)
	cs.shape = sh
	cs.position = Vector3(0, 1.3, 0)
	add_child(cs)


func hit(_point: Vector3) -> void:
	if _down:
		return
	_down = true
	var tw := create_tween()
	tw.tween_property(board, "rotation:x", -PI / 2.0, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.0)
	tw.tween_property(board, "rotation:x", 0.0, 0.4)
	tw.tween_callback(func() -> void: _down = false)
