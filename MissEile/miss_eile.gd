extends CharacterBody3D

enum State { SHOOTING, TRANSFORMING, CHASING, RETURNING }

const MAX_HP = 15
const DETECT_RADIUS = 9.0
const RETREAT_RADIUS = 9.0
const FLY_HEIGHT = 1.5
const CHASE_SPEED = 6.0
const RETURN_SPEED = 4.0
const CHASE_DURATION = 3.0
const SHOT_INTERVAL = 0.5
const SHOT_SPREAD_DEGREES = 8.0
const CONTACT_DAMAGE = 3
const CONTACT_COOLDOWN = 1.0
const MIN_SHOOTING_TIME = 1.5

const BOSS_PROJECTILE_SCENE = preload("res://MissEile/projectile/boss_projectile.tscn")

var hp := MAX_HP
var state: int = State.SHOOTING
var player: Node3D = null
var home_position: Vector3
var shot_timer := 0.0
var chase_timer := 0.0
var contact_timer := 0.0
var can_take_damage := false
var shooting_elapsed := 0.0

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D


func _ready() -> void:
	home_position = global_position
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	enter_shooting()


func _physics_process(delta: float) -> void:
	if player == null:
		return

	match state:
		State.SHOOTING:
			process_shooting(delta)
		State.CHASING:
			process_chasing(delta)
		State.RETURNING:
			process_returning(delta)
		State.TRANSFORMING:
			pass


func process_shooting(delta: float) -> void:
	shooting_elapsed += delta
	var distance = global_position.distance_to(player.global_position)

	if distance <= DETECT_RADIUS:
		shot_timer -= delta
		if shot_timer <= 0:
			shot_timer = SHOT_INTERVAL
			shoot_at_player()

	if distance > RETREAT_RADIUS and shooting_elapsed >= MIN_SHOOTING_TIME:
		enter_transforming()


func shoot_at_player() -> void:
	var base_direction = (player.global_position - global_position)
	base_direction.y = 0
	base_direction = base_direction.normalized()

	var random_angle = deg_to_rad(randf_range(-SHOT_SPREAD_DEGREES, SHOT_SPREAD_DEGREES))
	var shot_direction = base_direction.rotated(Vector3.UP, random_angle)

	var projectile = BOSS_PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = Vector3(global_position.x, player.global_position.y, global_position.z)
	projectile.launch(shot_direction)


func enter_shooting() -> void:
	state = State.SHOOTING
	can_take_damage = false
	global_position = home_position + Vector3(0, FLY_HEIGHT, 0)
	sprite.play("idle")
	shooting_elapsed = 0.0


func enter_transforming() -> void:
	state = State.TRANSFORMING
	can_take_damage = false
	transform_and_chase()


func transform_and_chase() -> void:
	sprite.play("transformation")
	await sprite.animation_finished
	global_position.y = player.global_position.y
	chase_timer = CHASE_DURATION
	can_take_damage = true
	state = State.CHASING
	sprite.play("flying")


func process_chasing(delta: float) -> void:
	chase_timer -= delta
	contact_timer -= delta

	var to_player = player.global_position - global_position
	to_player.y = 0
	var direction = to_player.normalized()

	velocity = direction * CHASE_SPEED
	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider == player and contact_timer <= 0:
			contact_timer = CONTACT_COOLDOWN
			if player.has_method("take_damage"):
				player.take_damage(CONTACT_DAMAGE)

	if chase_timer <= 0:
		enter_returning()


func enter_returning() -> void:
	state = State.RETURNING


func process_returning(delta: float) -> void:
	var target = home_position + Vector3(0, FLY_HEIGHT, 0)
	var to_target = target - global_position
	var distance = to_target.length()

	if distance < 0.5:
		enter_shooting()
		return

	velocity = to_target.normalized() * RETURN_SPEED
	move_and_slide()


func take_damage(amount: int) -> void:
	if not can_take_damage:
		return
	hp -= amount
	print("MissEile tomou dano, HP restante: ", hp)
	if hp <= 0:
		queue_free()
