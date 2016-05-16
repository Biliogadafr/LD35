
extends Node2D


func _ready():
	set_fixed_process(true)
	
	var screen_size = OS.get_screen_size()
	var window_size = OS.get_window_size()
	OS.set_window_position(screen_size*0.5 - window_size*0.5)
	
	pass
	
func _fixed_process(delta):
	if(Input.is_action_pressed("transform") || Input.is_action_pressed("shoot")):
		get_tree().change_scene("res://arena.scn")

