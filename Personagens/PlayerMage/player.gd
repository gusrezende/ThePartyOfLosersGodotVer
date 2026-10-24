extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MAX_HP = 6
const KNOCKBACK_FORCE = 6.0
const KNOCKBACK_DURATION = 0.2
const FLASH_DURATION = 0.3

signal hp_changed(current_hp, max_hp)

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var hp := MAX_HP
var knockback_velocity := Vector3.ZERO
var knockback_timer := 0.0
var is_holding_mushroom := false

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var held_mushroom: Node3D = $HeldMushroom

const PROJECTILE_SCENE = preload("res://Mecânicas/projectile/projectile.tscn")
const MUSHROOM_PROJECTILE_SCENE = preload("res://Mecânicas/MashroomProjectile/mashroom_projectile.tscn")


func _ready() -> void:
	if GameState.player_hp >= 0:
		hp = clampi(GameState.player_hp, 1, MAX_HP)  # veio de outra cena: mantém a vida
	else:
		GameState.player_hp = hp                     # primeira vez: guarda a vida inicial
	hp_changed.emit(hp, MAX_HP)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if knockback_timer > 0:
		knockback_timer -= delta
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		move_and_slide()
		return

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
		if is_holding_mushroom:
			throw_mushroom()
		else:
			shoot()


func shoot() -> void:
	var target_point = get_mouse_world_position()
	if target_point == null:
		return

	var shoot_direction = (target_point - global_position)
	shoot_direction.y = 0
	if shoot_direction.length() == 0:
		return
	shoot_direction = shoot_direction.normalized()

	var projectile = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.launch(shoot_direction)


func pick_up_mushroom() -> void:
	if is_holding_mushroom:
		return
	is_holding_mushroom = true
	held_mushroom.visible = true


func throw_mushroom() -> void:
	var target_point = get_mouse_world_position()
	if target_point == null:
		return

	var throw_direction = (target_point - global_position)
	throw_direction.y = 0
	if throw_direction.length() == 0:
		return
	throw_direction = throw_direction.normalized()

	var mushroom = MUSHROOM_PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(mushroom)
	mushroom.global_position = global_position
	mushroom.launch(throw_direction)

	is_holding_mushroom = false
	held_mushroom.visible = false


func get_mouse_world_position() -> Variant:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return null

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	var ground_plane = Plane(Vector3.UP, global_position.y)
	var intersection = ground_plane.intersects_ray(ray_origin, ray_direction)

	return intersection


func take_damage(amount: int, source_position = null) -> void:
	hp -= amount
	hp = max(hp, 0)
	GameState.player_hp = hp  # guarda a vida para a próxima cena
	hp_changed.emit(hp, MAX_HP)
	print("Player tomou dano, HP restante: ", hp)

	if source_position != null:
		apply_knockback(source_position)
	flash_red()

	if hp <= 0:
		print("Player morreu!")
		GameState.player_hp = -1  # ao recarregar a cena, volta com a vida cheia
		get_tree().call_deferred("reload_current_scene")


func apply_knockback(source_position: Vector3) -> void:
	var direction = global_position - source_position
	direction.y = 0
	if direction.length() == 0:
		return
	direction = direction.normalized()
	knockback_velocity = direction * KNOCKBACK_FORCE
	knockback_timer = KNOCKBACK_DURATION


func flash_red() -> void:
	sprite.modulate = Color(1, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), FLASH_DURATION)
