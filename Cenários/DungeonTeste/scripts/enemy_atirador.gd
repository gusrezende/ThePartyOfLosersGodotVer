extends "res://Personagens/Enemy1/enemy_1.gd"
## Inimigo que atira: usa o mesmo corpo e animações do Enemy1, mas mantém distância
## do player e dispara projéteis nele. Quando morre, vira corpo no chão igual ao Enemy1.

const PROJETIL = preload("res://Personagens/Enemy1/projetil/prato_projetil.tscn")   # prato de comida

## Distância em que ele percebe o player e começa a atirar
@export var alcance_tiro := 11.0
## Distância que ele tenta manter do player
@export var distancia_ideal := 6.5
@export var intervalo_tiro := 1.6
@export var velocidade_atirador := 2.2
## Cor para diferenciar do inimigo comum (branco = sem cor)
@export var cor := Color(0.75, 0.85, 1.25)

var _recarga_tiro := 1.0
var _tempo_ataque := 0.0


func _ready() -> void:
	super()
	sprite.modulate = cor


func _physics_process(delta: float) -> void:
	if morto:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if player == null or not is_instance_valid(player):
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return

	var para := player.global_position - global_position
	para.y = 0
	var dist := para.length()
	var dir := para.normalized()

	if not is_hunting:
		if dist <= alcance_tiro:
			is_hunting = true
		else:
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			return

	# chega perto até o alcance, mas se afasta se o player chegar perto demais
	var mover := Vector3.ZERO
	if dist > alcance_tiro * 0.85:
		mover = dir
	elif dist < distancia_ideal * 0.6:
		mover = -dir
	velocity.x = mover.x * velocidade_atirador
	velocity.z = mover.z * velocidade_atirador

	_tempo_ataque -= delta
	if _tempo_ataque > 0.0:
		sprite.play("attack")
	elif mover != Vector3.ZERO:
		sprite.play("chasing")
	else:
		sprite.stop()

	_recarga_tiro -= delta
	if dist <= alcance_tiro and _recarga_tiro <= 0.0:
		_recarga_tiro = intervalo_tiro
		_atirar(dir)

	move_and_slide()


func _atirar(dir: Vector3) -> void:
	_tempo_ataque = 0.5
	var p := PROJETIL.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = Vector3(global_position.x, player.global_position.y, global_position.z) + dir * 0.8
	p.launch(dir)
