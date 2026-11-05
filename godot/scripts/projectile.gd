extends Node3D
class_name Projectile
## Ракета / граната / брошенная взрывчатка: летит с гравитацией, отскакивает (если bounce), взрывается по таймеру или при ударе.
var vel := Vector3.ZERO
var grav := 9.8
var fuse := 3.0
var bounce := false
var t := 0.0
var owner_player
var damage := 80.0
var radius := 4.0
var exclude: Array = []

func _physics_process(delta: float) -> void:
	t += delta
	vel += Vector3.DOWN * grav * delta
	var nxt := global_position + vel * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, nxt)
	q.exclude = exclude
	q.collision_mask = 3
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		if bounce:
			vel = vel.bounce(h.normal) * 0.35
			global_position = h.position + h.normal * 0.05
		else:
			global_position = h.position
			t = fuse
	else:
		global_position = nxt
		if vel.length() > 0.5 and not bounce:
			look_at(global_position + vel, Vector3.UP if abs(vel.normalized().y) < 0.99 else Vector3.FORWARD)
	if t >= fuse:
		set_physics_process(false)
		if owner_player:
			owner_player._explode(global_position, damage, radius)
		queue_free()
