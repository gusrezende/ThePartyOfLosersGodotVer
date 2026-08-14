extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

func _physics_process(delta: float) -> void:
	# Gravidade
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Captura input nos dois eixos (gera as 8 direções)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0, input_dir.y)

	if direction.length() > 0:
		direction = direction.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED

		update_animation(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		sprite.stop()

	move_and_slide()


func update_animation(direction: Vector3) -> void:
	if abs(direction.x) > abs(direction.z):
		if direction.x > 0:
			sprite.play("WalkingRight")
		else:
			sprite.play("WalkingLeft")
	else:
		if direction.z > 0:
			sprite.play("WalkingDown")
		else:
			sprite.play("WalkingUp")
