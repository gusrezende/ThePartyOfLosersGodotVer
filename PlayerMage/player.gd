extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
const PROJECTILE_SCENE = preload("res://Projectile/projectile.tscn")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0, input_dir.y)
	if direction.length() > 0:
		direction = direction.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		update_walk_animation(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		sprite.play("IdleDown")
	move_and_slide()

func update_walk_animation(direction: Vector3) -> void:
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("1 - clique detectado")
		shoot()

func shoot() -> void:
	print("2 - entrou no shoot()")
	var target_point = get_mouse_world_position()
	print("3 - target_point = ", target_point)
	if target_point == null:
		print("saiu: target_point é null")
		return

	var shoot_direction = (target_point - global_position)
	shoot_direction.y = 0
	print("4 - shoot_direction antes de normalizar = ", shoot_direction)

	if shoot_direction.length() == 0:
		print("saiu: direção é zero, cancelando tiro")
		return

	shoot_direction = shoot_direction.normalized()
	print("5 - shoot_direction normalizado = ", shoot_direction)

	var projectile = PROJECTILE_SCENE.instantiate()
	print("6 - projétil instanciado")
	get_tree().current_scene.add_child(projectile)
	print("7 - projétil adicionado à cena")
	projectile.global_position = global_position + Vector3(0, 0, 0)
	projectile.launch(shoot_direction)
	print("8 - launch chamado, tudo certo")

func get_mouse_world_position() -> Variant:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		print("erro: nenhuma câmera ativa encontrada")
		return null
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var ground_plane = Plane(Vector3.UP, global_position.y)
	var intersection = ground_plane.intersects_ray(ray_origin, ray_direction)
	return intersection
