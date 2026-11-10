extends Node3D

const Sons = preload("res://Músicas/sons.gd")
## Míssil da MissEile: mostra o aviso no chão e uma mini MissEile cai do céu,
## de cabeça pra baixo, com a animação de voo dela.
## Quando chega no chão, explode e machuca o player se ele estiver dentro do círculo.

const AVISO = preload("res://Personagens/MissEile/ataques/aviso_chao.gd")
const EXPLOSAO = preload("res://Personagens/MissEile/ataques/explosao.gd")

const ALTURA_QUEDA = 16.0

## Quadros da animação "flying" da MissEile
const QUADROS_VOO := [
	preload("res://Personagens/MissEile/newAssets/flying/1000280557.png"),
	preload("res://Personagens/MissEile/newAssets/flying/1000280558.png"),
	preload("res://Personagens/MissEile/newAssets/flying/1000280559.png"),
]
## Velocidade da animação (quadros por segundo; a MissEile grande usa 10)
const FPS_VOO := 10.0
## Altura da mini MissEile, em metros
const ALTURA_MINI := 1.4

## Altura do centro dela quando a ponta do chapéu encosta no chão
var _altura_no_chao := ALTURA_MINI * 0.5

var raio := 1.8
var tempo := 1.3
var dano := 1

var _t := 0.0
var _bola: Node3D
var _sprite: AnimatedSprite3D
var _balanco := randf() * TAU   # cada uma balança de um jeito


func configurar(novo_raio: float, novo_tempo: float, novo_dano: int) -> void:
	raio = novo_raio
	tempo = novo_tempo
	dano = novo_dano


func _ready() -> void:
	var aviso := AVISO.new()
	aviso.configurar(raio, tempo)
	add_child(aviso)

	# Mini MissEile de cabeça pra baixo, com a animação de voo
	_bola = Node3D.new()
	_bola.position.y = ALTURA_QUEDA
	add_child(_bola)
	var frames := SpriteFrames.new()
	frames.add_animation(&"flying")
	frames.set_animation_speed(&"flying", FPS_VOO)
	frames.set_animation_loop(&"flying", true)
	for q in QUADROS_VOO:
		frames.add_frame(&"flying", q)
	_sprite = AnimatedSprite3D.new()
	_sprite.sprite_frames = frames
	_sprite.flip_v = true                                   # de cabeça pra baixo
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED    # sempre virada para a câmera
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex: Texture2D = QUADROS_VOO[0]
	_sprite.pixel_size = ALTURA_MINI / float(tex.get_height())
	_sprite.frame = randi() % QUADROS_VOO.size()
	_bola.add_child(_sprite)
	_sprite.play(&"flying")
	# a ponta do chapéu fica um pouco acima da borda da imagem
	_altura_no_chao = ALTURA_MINI * 0.5 - 35.0 * _sprite.pixel_size

	# apito + explosão: começa agora, e a explosão do som cai junto com o impacto
	Sons.tocar_missil(self, tempo)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / tempo, 0.0, 1.0)
	# cai acelerando (devagar no começo, rápido no final)
	_bola.position.y = lerpf(ALTURA_QUEDA, _altura_no_chao, k * k)
	# balança de leve de um lado pro outro enquanto cai
	_bola.position.x = sin(_t * 9.0 + _balanco) * 0.12
	if _t >= tempo:
		_impacto()


func _impacto() -> void:
	set_physics_process(false)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and is_instance_valid(player):
		var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
		if d <= raio and absf(player.global_position.y - global_position.y) < 3.0:
			if player.has_method("take_damage"):
				player.take_damage(dano, global_position)

	var ex := EXPLOSAO.new()
	ex.configurar(raio, Color(1.0, 0.85, 0.6), 0.35)
	get_parent().add_child(ex)
	ex.global_position = global_position
	queue_free()
