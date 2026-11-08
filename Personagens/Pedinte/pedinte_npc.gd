extends CharacterBody3D
## Pedinte: quando o player ENTREGA as 5 plantas (fala com ele), ele se transforma
## (Idle 2) e depois de um tempinho vira inimigo, persegue e ataca o player.
## Quem chama a transformação é o area_3dPedinte.gd, na hora da entrega.
##
## Coloque este script no nó RAIZ do Pedinte (o CharacterBody3D).

@export_group("Animações")
@export var anim_parado := "Idle"
@export var anim_transformando := "Idle 2"
@export var anim_andando := "walking"
@export var anim_morte := "death"
## Depois da morte, fica tocando esta em loop (o corpo fica no mapa)
@export var anim_morto_loop := "death2"

@export_group("Transformação")
## Quanto tempo ele fica no "Idle 2" antes de atacar
@export var tempo_transformacao := 1.5
@export var fala_transformacao := "HAHAHA! Agora você vai ver!"

@export_group("Inimigo")
@export var vida := 15
@export var velocidade := 3.0
@export var alcance_ataque := 1.8
@export var dano := 1
@export var intervalo_ataque := 1.0

enum Estado { NPC, TRANSFORMANDO, INIMIGO, MORTO }
var estado: int = Estado.NPC

var player: Node3D
var _recarga := 0.0
var _sprite: AnimatedSprite3D
var _area_dialogo: Node
var _dialogo: Label3D
var _gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	var sprites := find_children("*", "AnimatedSprite3D", true, false)
	if sprites.size() > 0:
		_sprite = sprites[0]
	_dialogo = find_child("Dialogo", true, false) as Label3D
	for filho in get_children():
		if filho is Area3D and filho.get("npc_finalizado") != null:
			_area_dialogo = filho
	_garantir_colisao()
	_tocar(anim_parado)


func _physics_process(delta: float) -> void:
	if estado == Estado.MORTO:
		return   # morto: fica parado onde caiu (sem gravidade, não afunda no chão)
	if estado != Estado.INIMIGO:
		# Enquanto é NPC (e transformando), ele NÃO usa física: fica exatamente onde
		# você colocou no editor. Sem isso, se ele encosta um pouco no chão, numa pedra
		# ou no player, a física "desgruda" ele e ele sobe/escorrega (parece que voa).
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= _gravidade * delta
	else:
		velocity.y = 0.0

	if estado == Estado.INIMIGO and player and is_instance_valid(player):
		_perseguir(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()


# ---------------------------------------------------------------- TRANSFORMAÇÃO

## Chamado pelo diálogo quando o player entrega as plantas.
func transformar() -> void:
	if estado != Estado.NPC:
		return
	estado = Estado.TRANSFORMANDO
	# desliga a conversa normal do NPC
	if _area_dialogo:
		_area_dialogo.set("npc_finalizado", true)
	_falar(fala_transformacao)
	_tocar(anim_transformando)

	await get_tree().create_timer(tempo_transformacao).timeout
	if estado != Estado.TRANSFORMANDO:
		return
	_falar("")
	_assentar_no_chao()
	estado = Estado.INIMIGO
	add_to_group("enemy")   # agora os tiros e o cogumelo machucam ele
	_tocar(anim_andando)


# ---------------------------------------------------------------- INIMIGO

func _perseguir(delta: float) -> void:
	_recarga -= delta
	var para := player.global_position - global_position
	para.y = 0.0
	var dist := para.length()
	if dist > alcance_ataque:
		var dir := para.normalized()
		velocity.x = dir.x * velocidade
		velocity.z = dir.z * velocidade
		if _sprite and absf(dir.x) > 0.1:
			_sprite.flip_h = dir.x < 0.0
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _recarga <= 0.0:
			_recarga = intervalo_ataque
			if player.has_method("take_damage"):
				player.take_damage(dano, global_position)


func take_damage(quantidade: int) -> void:
	if estado != Estado.INIMIGO:
		return   # antes de virar inimigo, não toma dano
	vida -= quantidade
	if _sprite:
		_sprite.modulate = Color(1, 0.4, 0.4)
		var tw := create_tween()
		tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if vida <= 0:
		_morrer()


func _morrer() -> void:
	estado = Estado.MORTO
	remove_from_group("enemy")
	velocity = Vector3.ZERO
	for forma in find_children("*", "CollisionShape3D", false, false):
		forma.set_deferred("disabled", true)
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var frames := _sprite.sprite_frames
	# 1) "death" toca uma vez
	if frames.has_animation(anim_morte):
		frames.set_animation_loop(anim_morte, false)
		_sprite.play(anim_morte)
		await _sprite.animation_finished
	# 2) depois fica em loop no "death2" (ele não some)
	if frames.has_animation(anim_morto_loop):
		frames.set_animation_loop(anim_morto_loop, true)
		_sprite.play(anim_morto_loop)


# ---------------------------------------------------------------- AUXILIARES

func _tocar(nome: String) -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(nome):
		_sprite.play(nome)


func _falar(texto: String) -> void:
	if _dialogo:
		_dialogo.text = texto
		_dialogo.visible = texto != ""


## Antes de começar a andar: coloca os pés dele em cima do chão que está embaixo,
## para não começar enterrado (e ser jogado pra cima).
func _assentar_no_chao() -> void:
	var de := global_position + Vector3(0, 2.0, 0)
	var ate := global_position + Vector3(0, -3.0, 0)
	var consulta := PhysicsRayQueryParameters3D.create(de, ate)
	consulta.exclude = [get_rid()]
	if player is CollisionObject3D:
		consulta.exclude.append((player as CollisionObject3D).get_rid())
	var acerto := get_world_3d().direct_space_state.intersect_ray(consulta)
	if acerto.has("position"):
		global_position.y = acerto["position"].y + 0.02
	velocity = Vector3.ZERO


## O Pedinte precisa de uma colisão no corpo pra andar no chão e levar tiro.
## Se você não colocou uma, cria uma cápsula do tamanho do sprite.
func _garantir_colisao() -> void:
	for filho in get_children():
		if filho is CollisionShape3D:
			return
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.7
	capsula.height = 3.0
	forma.shape = capsula
	forma.position = Vector3(0, 1.5, 0)
	add_child(forma)
