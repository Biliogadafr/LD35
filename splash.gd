
extends Node2D

var monster_class = preload("res://monsters/monster_light.scn")

func _ready():
	set_fixed_process(true)
	set_process_input(true)
	var screen_size = OS.get_screen_size()
	var window_size = OS.get_window_size()
	OS.set_window_position(screen_size*0.5 - window_size*0.5)
	pass
	
func _fixed_process(delta):
	if(Input.is_action_pressed("transform")):
		get_tree().change_scene("res://arena.scn")

func _input(event):
	#print("NODE:", event)
	if(event.type == InputEvent.MOUSE_BUTTON):

		if(event.button_index == 1 && event.is_pressed()):
			var monster = monster_class.instance()
			get_tree().get_current_scene().add_child(monster)
			monster.set_global_pos(Vector2(event.x, event.y))
			get_node("/root/network").replicate_object(monster)


func _on_Start_pressed():
	print("Starting server")
	get_node("/root/network").start_server()
	

func _on_Connect_pressed():
	get_node("/root/network").connect_to_server(get_node("PanelContainer/Panel/LineEdit").get_text())