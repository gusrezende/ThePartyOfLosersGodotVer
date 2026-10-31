extends Area3D
## Zona embaixo do mapa: se o player cair num buraco, ele volta para o último
## chão seguro em que estava e perde vida. Inimigos que caem somem.

@export var dano := 1
## Altura abaixo da qual conta como queda (o chão do mapa fica em ~0)
@export var altura_queda := -4.0

var _player: CharacterBody3D
var _ultimo_seguro := Vector3.ZERO
var _tempo := 0.0
var _espera := 0.0   # evita contar a mesma queda duas vezes


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player:
		_ultimo_seguro = _player.global_position


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_tempo -= delta
	_espera -= delta
	# guarda a posição quando o player está firme no chão (e longe da beirada)
	if _tempo <= 0.0 and _player.is_on_floor() and _chao_firme_em_volta(_player.global_position):
		_ultimo_seguro = _player.global_position
		_tempo = 0.25
	# garantia: caiu muito, mesmo sem encostar na área
	if _player.global_position.y < altura_queda:
		_devolver_player()


func _on_body_entered(body: Node3D) -> void:
	if body == _player:
		_devolver_player()
	elif body.is_in_group("enemy"):
		body.queue_free()


func _devolver_player() -> void:
	if _espera > 0.0:
		return
	_espera = 0.5
	_player.velocity = Vector3.ZERO
	_player.global_position = _ultimo_seguro + Vector3(0, 0.5, 0)
	if _player.has_method("take_damage"):
		_player.take_damage(dano)


## true se tem chão um pouco à frente/atrás/dos lados (não está na beirada do buraco)
func _chao_firme_em_volta(pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for d in [Vector3(1.2, 0, 0), Vector3(-1.2, 0, 0), Vector3(0, 0, 1.2), Vector3(0, 0, -1.2)]:
		var q := PhysicsRayQueryParameters3D.create(pos + d + Vector3(0, 1, 0), pos + d + Vector3(0, -3, 0))
		q.exclude = [_player.get_rid()]
		if space.intersect_ray(q).is_empty():
			return false
	return true
