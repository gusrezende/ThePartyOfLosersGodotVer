extends CharacterBody3D

const Sons = preload("res://Músicas/sons.gd")

const SPEED = 2.5
const MAX_HP = 10
const ATTACK_RANGE = 1.5
const ATTACK_DAMAGE = 1
const ATTACK_COOLDOWN = 1.0
const DETECTION_RADIUS = 6.0

var hp := MAX_HP
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player: Node3D = null
var attack_timer := 0.0
var is_hunting := false
var morto := false

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

func _ready() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	sprite.animation = "chasing"
	sprite.frame = 0
	sprite.stop()

func _physics_process(delta: float) -> void:
	if morto:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if player == null:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	var to_player = player.global_position - global_position
	to_player.y = 0
	var distance = to_player.length()

	if not is_hunting:
		if distance <= DETECTION_RADIUS:
			is_hunting = true
		else:
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			return

	if distance > ATTACK_RANGE:
		var direction = to_player.normalized()
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		sprite.play("chasing")
	else:
		velocity.x = 0
		velocity.z = 0
		sprite.play("attack")
		attack_timer -= delta
		if attack_timer <= 0:
			attack_timer = ATTACK_COOLDOWN
			if player.has_method("take_damage"):
				player.take_damage(ATTACK_DAMAGE)

	move_and_slide()

func take_damage(amount: int) -> void:
	if morto:
		return
	hp -= amount
	print("Enemy tomou dano, HP restante: ", hp)
	if hp <= 0:
		morrer()

func morrer() -> void:
	morto = true
	Sons.tocar(self, Sons.COGUMELO_MORRE)
	set_physics_process(false)
	velocity = Vector3.ZERO

	# o corpo não conta mais como inimigo, não bloqueia o player e não para os tiros
	remove_from_group("enemy")
	for forma in find_children("*", "CollisionShape3D", true, false):
		forma.set_deferred("disabled", true)

	# toca a morte uma vez só e fica parado no último quadro (o corpo fica no mapa)
	sprite.sprite_frames.set_animation_loop("death", false)
	sprite.play("death")
	await sprite.animation_finished
	sprite.stop()
	sprite.frame = sprite.sprite_frames.get_frame_count("death") - 1
