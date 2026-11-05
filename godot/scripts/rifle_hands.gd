extends SkeletonModifier3D
## Выполняется после AnimationTree: прикрепляет оружие к руке, для автомата ставит кисти IK.
var character

func _process_modification() -> void:
	if character:
		character.post_animation()
