
extends Position2D

var monster_class1 = preload("res://monsters/monster_light.scn")
var monster_class2 = preload("res://monsters/monster_med.scn")
var monster_class3 = preload("res://monsters/monster_heavy.scn")

var wait_time = 4.0;
var wait_time_decrease = 0.1;

func _ready():
	get_node("Timer").set_wait_time(wait_time * randf() * 10)
	pass

func _on_Timer_timeout():
	var player = get_tree().get_current_scene().get_node("Player")
	if(player.health < 0):
		return
	
	var monster 
	var rand_val = randf()
	if(rand_val < 0.6):
		monster= monster_class1.instance()
	elif(rand_val < 0.9):
		monster= monster_class2.instance()
	else:
		monster= monster_class3.instance()
	get_tree().get_current_scene().add_child(monster)
	monster.set_global_pos(get_global_pos())
	if(wait_time_decrease<3.7):
		wait_time_decrease+=0.4;
	get_node("Timer").set_wait_time((wait_time-wait_time_decrease) * randf() * 10)
	pass 
