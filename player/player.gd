
extends RigidBody2D

var bullet = preload("res://bullet/bullet.scn") # bullet scn to make instance and shoot

var animations
var health = 100
var death_timeout = 1.0
var lastPos = Vector2(0,0)
var speed = 250.0
var shoots_per_sec = 15
var shoot_timeout = 0.05

var attack_per_sec = 2.5
var attack_timeout = 0.0

var bullet_impulse = 3000
const MODE_SHOOTER  = 0
const MODE_WARRIOR = 1
var mode = MODE_SHOOTER
var transform_cooldown = 1
var transform_timeout = transform_cooldown

var attack_switch = 0
var time = 0.0
var yeah_played = false
var music_id

func _ready():
	print("Hello :3. I'm main character of this game! My name is... player? And I'm child of RigidBody2d ...? 0_0'  Anyway! Don't let me die!")
	set_process_input(true)
	set_fixed_process(true)
	#animations = get_node("AnimationPlayer")
	connect("body_enter", self, "onCollision")
	var sample = get_node("SamplePlayer")
	music_id = sample.play("RigidBody")
	sample.set_volume(music_id, 0.5)
	pass
	
func _fixed_process(delta):

	#gandle cooldowns
	shoot_timeout -= delta
	transform_timeout -= delta
	attack_timeout -= delta
	#get_tree().get_root().get_child( get_tree().get_root().get_child_count() -1 ).get_node("CanvasLayer/health").set_text(" Health: " + str(health))
	
	get_node("ui/health").set_value(health)

	if health <= 0 :
		death_timeout -= delta
		get_node("ui/Score").set_text("Time: " + str(time) + "  ... Press space to restart.")
		var death_spark = get_node("Death")
		if(!death_spark.is_emitting()):
			death_spark.set_emitting(true)
		if death_timeout < 0:
			if(Input.is_action_pressed("transform") || Input.is_action_pressed("shoot")):
				get_tree().change_scene("res://arena.scn")
		return
	else:
		time+=delta
	#aiming
	#var global_aim_pos = get_node("Camera2D").get_canvas_transform().xform_inv(lastPos)
	#get camera transformation to convert screen coordinates to world coordinates
	var transform = get_viewport().get_canvas_transform()
	#convert mouse pos to world pos
	var global_aim_pos = transform.affine_inverse() * lastPos
	#moving
	var move_left = Input.is_action_pressed("move_left")
	var move_right = Input.is_action_pressed("move_right")
	var move_up = Input.is_action_pressed("move_up")
	var move_down = Input.is_action_pressed("move_down")
	var direction = Vector2(move_right-move_left, move_down - move_up)
	direction = direction.normalized()
	direction*=delta*speed*100
	set_linear_velocity(direction)
	
	#animations
	var anim
	if(mode == MODE_SHOOTER):
		anim = get_node("Sprites/AnimationPlayer")
	else:
		anim = get_node("SpritesW/AnimationPlayer")
	var current_anim = anim.get_current_animation()
	if(direction.length()!=0):
		if(!anim.is_playing()):
			anim.play("Run")
	else:
		if(current_anim == "Run" && anim.is_playing()):
			anim.stop()
			
	var aim_angle = get_global_pos().angle_to_point( global_aim_pos )	
	set_rot( aim_angle )
	var shoot = Input.is_action_pressed("shoot")
	if(shoot):
		if(mode == MODE_SHOOTER):
			if(shoot_timeout < 0):
				shoot_timeout = 1.0/shoots_per_sec
				shoot(aim_angle)
		else:
			if(attack_timeout < 0):
				attack_timeout = 1.0/attack_per_sec
				attack(aim_angle)
			
	var transform = Input.is_action_pressed("transform")
	if(transform):
		if(transform_timeout<0):
			get_node("ParticleTransform").set_emitting(true)
			transform_timeout = transform_cooldown
			if(mode == MODE_SHOOTER):
				mode = MODE_WARRIOR
				get_node("Sprites").set_hidden(true)
				get_node("SpritesW").set_hidden(false)
				var sample = get_node("SamplePlayer")
				var sound_id
				if(!yeah_played):
					sound_id = sample.play("yeah")
					yeah_played = true
				elif(randf()>0.5):
					sound_id = sample.play("ou")
				else:
					sound_id = sample.play("um")
				sample.set_pitch_scale(sound_id, 0.8)
				sample.set_volume(sound_id, 0.7)
			else:
				mode = MODE_SHOOTER
				get_node("Sprites").set_hidden(false)
				get_node("SpritesW").set_hidden(true)
			
func shoot(aim_angle):
	var bulletInst = bullet.instance()
	get_tree().get_root().get_child( get_tree().get_root().get_child_count() -1 ).add_child(bulletInst)
	var shootDir = Vector2(0,-1).rotated(aim_angle)
	var shootPos = get_global_pos()
	shootPos += shootDir * 20
	bulletInst.set_global_pos(shootPos)
	bulletInst.get_node(".").apply_impulse(Vector2(0,0), shootDir * bullet_impulse)
	bulletInst.set_rot(aim_angle)
	var sample = get_node("SamplePlayer")
	var sound_id = sample.play("shot")
	sample.set_pitch_scale(sound_id, (randf()-0.5)*0.1+1)
	sample.set_volume(sound_id, (randf()-0.5)*0.2 + 0.5)

func attack(attack):
	var attack = get_node("DirectAttack")
	var colliding_bodies = attack.get_overlapping_bodies()
	for body in colliding_bodies:
		if(body.get("monster_tag")):
			body.onDamage(45)
			print("whoa!")
			get_node("Attack").set_emitting(true)
			var sample = get_node("SamplePlayer")
			var sound_id = sample.play("kick")
			sample.set_pitch_scale(sound_id, (randf()-0.5)*0.1+1)
			sample.set_volume(sound_id, (randf()-0.5)*0.2 + 0.5)
	var anim = get_node("SpritesW/AnimationPlayer")
	var current_anim = anim.get_current_animation()
	
	if(attack_switch==0):
		#if( !(current_anim == "Attack1" || current_anim == "Attack2")  || !anim.is_playing()):
			#anim.set_pause_mode(
		anim.play("Attack1")
		attack_switch = 1
		attack_timeout = attack_timeout/2
	else:
		#if( !(current_anim == "Attack1" || current_anim == "Attack2" )  || !anim.is_playing()):
			#anim.set_pause_mode(
		anim.play("Attack2")
		attack_switch = 0
	pass

func onDamage(damage):
	get_node("Bite").set_emitting(true)
	if(mode == MODE_SHOOTER):
		health -= damage
	else:
		health -= damage * 0.25

func _input(ev):
	if(ev.type == InputEvent.MOUSE_MOTION):
		lastPos = ev.pos