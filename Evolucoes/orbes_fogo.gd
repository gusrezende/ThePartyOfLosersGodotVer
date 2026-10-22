extends Node3D
## Evolução 1: 3 bolas de fogo girando em volta do player.
## Qualquer inimigo que encostar numa bola toma dano.

const UTIL = preload("res://Evolucoes/util_fogo.gd")
const SPRITE = preload("res://Evolucoes/assets/orbe_fogo.png")

const QUANTIDADE = 3
const RAIO_ORBITA = 1.7       # distância das bolas até o player
const VELOCIDADE = 3.2        # radianos por segundo
const ALTURA_SPRITE = 1.3     # tamanho de cada bola na tela (em metros)
const ALCANCE_HIT = 0.9       # distância bola-inimigo pra contar como acerto
const DANO = 2
const RECARGA_POR_INIMIGO = 0.45  # o mesmo inimigo só toma dano de novo depois disso
const ALTURA = 0.1

var _angulo := 0.0
var _t := 0.0
var _bolas: Array[Node3D] = []
var _recarga := {}   # id do inimigo -> tempo restante


func _ready() -> void:
	for i in QUANTIDADE:
		var bola := _criar_bola(i == 0)  # só uma luz pra não pesar
		add_child(bola)
		_bolas.append(bola)
	_posicionar()


func _physics_process(delta: float) -> void:
	_t += delta
	_angulo = wrapf(_angulo + VELOCIDADE * delta, 0.0, TAU)
	_posicionar()

	for id in _recarga.keys():
		_recarga[id] -= delta
		if _recarga[id] <= 0.0:
			_recarga.erase(id)

	for e in get_tree().get_nodes_in_group("enemy"):
		if not UTIL.inimigo_valido(e):
			continue
		var id: int = e.get_instance_id()
		if _recarga.has(id):
			continue
		for bola in _bolas:
			if UTIL.distancia_plana(bola.global_position, e.global_position) <= ALCANCE_HIT:
				e.take_damage(DANO)
				_recarga[id] = RECARGA_POR_INIMIGO
				_pulsar(bola)
				break


func _posicionar() -> void:
	for i in _bolas.size():
		var a := _angulo + TAU * i / float(_bolas.size())
		var sobe := sin(_t * 4.0 + i * 2.0) * 0.12
		_bolas[i].position = Vector3(cos(a) * RAIO_ORBITA, ALTURA + sobe, sin(a) * RAIO_ORBITA)


func _criar_bola(com_luz: bool) -> Node3D:
	var raiz := Node3D.new()
	var sprite := Sprite3D.new()
	sprite.texture = SPRITE
	sprite.pixel_size = ALTURA_SPRITE / float(SPRITE.get_height())
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED   # sempre virado pra câmera
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# o centro da bola preta fica na parte de baixo da imagem; sobe o sprite pra
	# que a bola (e não a chama) fique na altura certa
	sprite.position.y = ALTURA_SPRITE * 0.18
	raiz.add_child(sprite)
	if com_luz:
		var luz := OmniLight3D.new()
		luz.light_color = UTIL.COR_FOGO
		luz.omni_range = 4.0
		luz.light_energy = 1.2
		raiz.add_child(luz)
	return raiz


func _pulsar(bola: Node3D) -> void:
	bola.scale = Vector3.ONE * 1.6
	var tween := create_tween()
	tween.tween_property(bola, "scale", Vector3.ONE, 0.2)
