
extends RigidBody2D

var monster_tag = true #to identify this object

const player_class = preload("res://player/player.gd") # Check if we see player
const bullet_class = preload("res://bullet/bullet.gd") # Check if we see player

export var health = 100
export var speed = 100.0
export var attack = 10.0
export var attack_speed = 2.0

var rot_speed = 1.0
var death_timeout = 1.0

var attack_cooldown = 0

var random_target_timer = 0
var random_target_pos = Vector2(0,0)

func _init():
	set_meta("network", true)

func _ready():
	set_fixed_process(true)
	connect("body_enter", self, "onCollision")
	#print(get_filename())
	#animations = get_node("AnimationPlayer")
	pass

var preparing_attack = false

func _fixed_process(delta):
	if(health < 0):
		set_angular_velocity(0)
		death_timeout -= delta
		if(death_timeout < 0):
			queue_free()
		return
	
	
	#animations
	var anim = get_node("Sprites/AnimationPlayer")
	var current_anim = anim.get_current_animation()
	if(!anim.is_playing()):
		anim.play("Run")
	
	var target_pos
	if(get_tree().get_current_scene().has_node("Player")):
		var player = get_tree().get_current_scene().get_node("Player")
		target_pos = player.get_global_pos()
	else:
		random_target_timer-=delta
		if(random_target_timer <= 0):
			random_target_pos.x = get_global_pos().x+(randf()-0.5)*speed
			random_target_pos.y = get_global_pos().y+(randf()-0.5)*speed
			random_target_timer = 2
		target_pos = random_target_pos
		
	
	var direction = target_pos - get_global_pos()
	if(direction.length()<10):
		set_linear_velocity(Vector2(0,0))
	else:
		direction = direction.normalized()
		direction*=delta*speed*100
		
	
		set_rot(Vector2(0,-1).angle_to( direction ))
		#if(abs(Vector2(0,-1).angle_to( direction )-get_rot()) > 0.05):
		#	if( (get_rot() - Vector2(0,-1).angle_to( direction ) ) > 0):
		#		set_angular_velocity(rot_speed)
		#	else:
		#		set_angular_velocity(-rot_speed)
		#else:
		#	set_angular_velocity(0)
		set_linear_velocity(direction)
	
	var colliding_bodies = get_colliding_bodies();

	for body in colliding_bodies:
		if body extends player_class:
			preparing_attack = true
			if(attack_cooldown < 0):
				var anim = get_node("Sprites/AnimationPlayer")
				anim.play("Attack")
				body.onDamage(attack)
				attack_cooldown = 1.0/attack_speed
				preparing_attack = false
				
	if(preparing_attack):
		attack_cooldown -= delta
			
func onDamage(damage):
	health -= damage
	if(health<0):
		get_node("Death").set_emitting(true)
		get_node("Sprites").set_hidden(true)
		set_collision_mask(0)
		set_layer_mask(0)
		set_angular_velocity(0)
		#queue_free()

func onCollision(var collider):
	pass
	
func get_state():
	var state = {
		pos = get_global_pos(),
		rot = get_rot(),
		rand_target = random_target_pos
	}
	if(random_target_timer<=0):
		state.rand_target=null
	return state

func set_state(state):
	set_global_pos(state.pos)
	set_rot(state.rot)
	if(state.rand_target!=null):
		random_target_pos = state.rand_target
		random_target_timer = 2