
extends Button

# member variables here, example:
# var a=2
# var b="textvar"

func _ready():
	# Called every time the node is added to the scene.
	# Initialization here
	pass

func _input_event(event):
	accept_event()
	self.get_tree().set_input_as_handled()
	print("UI:" , event)