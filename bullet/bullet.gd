
extends RigidBody2D

export var life_timer = 1
var destroy_delay = 1;

func _ready():
	connect("body_enter", self, "onCollision")
	set_fixed_process(true)
	pass
	
func _fixed_process(delta):
	life_timer -= delta
	if life_timer < 0:
		queue_free()
		


func onCollision(var obj):
	if(obj.get("monster_tag")):
		obj.onDamage(14)
	queue_free()