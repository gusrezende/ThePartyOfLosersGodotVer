extends Area3D
## GOROROBA: a bola de comida que o Gordo do Refeitório joga no player.
## Voa reto, girando, e se desfaz em respingos quando bate no player ou numa parede.

## Dano no player (o player tem 6 de vida)
@export var dano := 2
## Velocidade (metros por segundo)
@export var velocidade := 8.0
## Depois de quantos segundos ela some sozinha
@export var duracao := 4.0
## Giro do desenho, em graus por segundo
@export var giro_graus := 300.0

var direction := Vector3.ZERO
var _acabou := false
var _t := 0.0

@onready var _desenho: Sprite3D = $Desenho


func launch(dir: Vector3) -> void:
	direction = dir.normalized()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_virar_para_camera()
	get_tree().create_timer(duracao, false).timeout.connect(func():
		if not _acabou:
			_desfazer())


func _physics_process(delta: float) -> void:
	if _acabou:
		return
	var antes := global_position
	var depois := antes + direction * velocidade * delta
	# bateu numa parede no caminho? (o Area3D sozinho não percebe paredes)
	var consulta := PhysicsRayQueryParameters3D.create(antes, depois)
	consulta.collide_with_areas = false
	var excluir: Array[RID] = []
	for n in get_tree().get_nodes_in_group("gordo_refeitorio"):
		if n is CollisionObject3D:
			excluir.append(n.get_rid())   # não bate no próprio Gordo
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is CollisionObject3D:
			excluir.append(n.get_rid())   # passa pelos outros inimigos
	consulta.exclude = excluir
	var acerto := get_world_3d().direct_space_state.intersect_ray(consulta)
	if acerto.has("collider"):
		var corpo: Object = acerto["collider"]
		if corpo is Node and (corpo as Node).is_in_group("player"):
			_acertar_player(corpo as Node3D)
		else:
			global_position = acerto["position"]
			_desfazer()
		return
	global_position = depois


func _process(delta: float) -> void:
	_t += delta
	_virar_para_camera()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_acertar_player(body)


func _acertar_player(player: Node3D) -> void:
	if _acabou:
		return
	if player.has_method("take_damage"):
		player.take_damage(dano, global_position - direction)   # empurra o player para trás
	_desfazer()


## Some com respingos de comida
func _desfazer() -> void:
	if _acabou:
		return
	_acabou = true
	set_deferred("monitoring", false)
	var cena: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if cena and _desenho:
		for i in 7:
			var gota := Sprite3D.new()
			gota.texture = _desenho.texture
			gota.pixel_size = _desenho.pixel_size * randf_range(0.18, 0.32)
			gota.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			gota.shaded = false
			gota.texture_filter = _desenho.texture_filter
			cena.add_child(gota)
			gota.global_position = global_position
			var lado := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			var alvo := global_position + lado * randf_range(0.5, 1.2) + Vector3(0, randf_range(0.2, 0.6), 0)
			var tw := gota.create_tween().set_parallel(true)
			tw.tween_property(gota, "global_position", alvo, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(gota, "global_position:y", global_position.y - 0.4, 0.25).set_delay(0.3)
			tw.tween_property(gota, "modulate:a", 0.0, 0.25).set_delay(0.3)
			tw.chain().tween_callback(gota.queue_free)
	queue_free()


func _virar_para_camera() -> void:
	if _desenho == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var b := cam.global_basis.orthonormalized()
	var giro := deg_to_rad(giro_graus) * _t
	_desenho.global_basis = b * Basis(Vector3.BACK, giro)
	var pulso := 1.0 + 0.06 * sin(_t * 22.0)
	_desenho.scale = Vector3(pulso, 2.0 - pulso, 1.0)   # "balança" como gororoba mole
