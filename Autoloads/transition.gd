extends Node

@onready var effect: ColorRect = %Effect
var is_transitioning := false

func transition_to(scene_path:String) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	var tween := create_tween()
	tween.tween_property(effect.material,"shader_parameter/progress",1.0,1.0)
	
	await tween.finished
	get_tree().change_scene_to_file(scene_path)


	tween = create_tween()
	tween.tween_property(effect.material,"shader_parameter/progress",0.0,1.0)
	await tween.finished
	is_transitioning = false
