extends CharacterBody2D


var speed = 10
var velocityHistory = []

func _ready(): 
	if not is_multiplayer_authority(): return

func get_input():
	if not is_multiplayer_authority(): return
	var input_dir = Input.get_vector("steerLeft", "steerRight", "accelerate", "break")
	velocity = velocity + ( input_dir * speed)

func _physics_process(delta):
	if  not is_multiplayer_authority(): return
	
	get_input()
	
	var collision = move_and_collide(velocity * delta, false, 0.08, false)
	if collision:
		var collider = collision.get_collider()
		if collider.is_class("CharacterBody2D"):
			velocity = velocity.slide(collision.get_normal()) * 0.8 + (velocity.bounce(collision.get_normal()) / 5)
		else:
			velocity = (velocity.slide(collision.get_normal()) + (velocity.bounce(collision.get_normal()) / 5) ) / 2
			
func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
