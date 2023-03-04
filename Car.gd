extends CharacterBody2D


# Called when the node enters the scene tree for the first time.



var speed = 10

func _ready(): 
	if not is_multiplayer_authority(): return

func get_input():
	if not is_multiplayer_authority(): return
	var input_dir = Input.get_vector("steerLeft", "steerRight", "accelerate", "break")
	velocity = velocity + ( input_dir * speed)

func _physics_process(delta):
	if  not is_multiplayer_authority(): return
	
	get_input()
	#move_and_slide()
	var collision = move_and_collide(velocity * delta)
	if collision:
		var collider = collision.get_collider()
		if collider.is_class("CharacterBody2D"):
			velocity = velocity.bounce(collision.get_normal())
		else:
			move_and_slide()	#
func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	

