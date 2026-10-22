extends Node3D
## Evolução 3: Fogo Amigo — um mascote de fogo que corre pelo mapa
## caçando o inimigo mais próximo. Sem inimigos, fica correndo em volta do player.

const UTIL = preload("res://Evolucoes/util_fogo.gd")
const SPRITE = preload("res://Evolucoes/assets/fogo_amigo.png")

const VELOCIDADE = 6.5
const VELOCIDADE_PASSEIO = 4.0
const RAIO_BUSCA = 16.0         # até onde ele enxerga inimigos
const ALCANCE_ATAQUE = 0.9
const DANO = 4
const RECARGA_ATAQUE = 0.4
const RAIO_PASSEIO = 4.0        # quando não tem inimigo, corre nessa área em volta do player
const DISTANCIA_MAX = 22.0      # se ficar longe demais do player, volta pra perto dele
const ALTURA = -1.0             # altura em relação ao centro do player (= chão)
const ALTURA_SPRITE = 1.7       # tamanho do mascote na tela (em metros)

var player: Node3D

var _t := 0.0
var _recarga := 0.0
var _destino_passeio := Vector3.ZERO
var _tempo_passeio := 0.0
var _corpo: Sprite3D


func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	_criar_visual()
	_novo_destino_passeio()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return

	_t += delta
	_recarga -= delta

	if UTIL.distancia_plana(global_position, player.global_position) > DISTANCIA_MAX:
		global_position = player.global_position + Vector3(1, ALTURA, 1)

	var alvo := _inimigo_mais_proximo()
	var destino: Vector3
	var vel: float
	if alvo:
		destino = alvo.global_position
		vel = VELOCIDADE
	else:
		_tempo_passeio -= delta
		if _tempo_passeio <= 0.0 or UTIL.distancia_plana(global_position, _destino_passeio) < 0.4:
			_novo_destino_passeio()
		destino = _destino_passeio
		vel = VELOCIDADE_PASSEIO

	var para := destino - global_position
	para.y = 0
	var andando := para.length() > 0.3
	if andando:
		var passo := minf(vel * delta, para.length())
		global_position += para.normalized() * passo
		# vira o "rosto" pro lado que está correndo
		if absf(para.x) > 0.05:
			_corpo.flip_h = para.x < 0

	# acompanha a altura do player (chão)
	global_position.y = lerpf(global_position.y, player.global_position.y + ALTURA, 10.0 * delta)

	# pulinhos enquanto corre
	var pulo := absf(sin(_t * (14.0 if andando else 5.0))) * (0.3 if andando else 0.1)
	_corpo.position.y = ALTURA_SPRITE * 0.5 + pulo
	var estica := 1.0 + pulo * 0.6
	_corpo.scale = Vector3(1.0 / sqrt(estica), estica, 1.0 / sqrt(estica))

	if alvo and _recarga <= 0.0 and UTIL.distancia_plana(global_position, alvo.global_position) <= ALCANCE_ATAQUE:
		_recarga = RECARGA_ATAQUE
		alvo.take_damage(DANO)
		_corpo.scale = Vector3.ONE * 1.5


func _inimigo_mais_proximo() -> Node3D:
	var melhor: Node3D = null
	var melhor_d := RAIO_BUSCA
	for e in get_tree().get_nodes_in_group("enemy"):
		if not UTIL.inimigo_valido(e):
			continue
		if e.get("can_take_damage") == false:   # ex.: MissEile invulnerável
			continue
		var d := UTIL.distancia_plana(global_position, e.global_position)
		if d < melhor_d:
			melhor_d = d
			melhor = e
	return melhor


func _novo_destino_passeio() -> void:
	_tempo_passeio = randf_range(0.8, 1.8)
	if player == null:
		return
	var a := randf() * TAU
	var r := randf_range(1.5, RAIO_PASSEIO)
	_destino_passeio = player.global_position + Vector3(cos(a) * r, 0, sin(a) * r)


func _criar_visual() -> void:
	_corpo = Sprite3D.new()
	_corpo.texture = SPRITE
	_corpo.pixel_size = ALTURA_SPRITE / float(SPRITE.get_height())
	_corpo.billboard = BaseMaterial3D.BILLBOARD_ENABLED   # sempre virado pra câmera
	_corpo.shaded = false
	_corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corpo.position.y = ALTURA_SPRITE * 0.5
	add_child(_corpo)

	# brilho laranja no chão em volta dele
	var luz := OmniLight3D.new()
	luz.light_color = UTIL.COR_FOGO
	luz.omni_range = 3.5
	luz.light_energy = 1.5
	luz.position.y = 0.6
	add_child(luz)
