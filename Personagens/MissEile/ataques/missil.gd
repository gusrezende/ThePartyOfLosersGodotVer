extends Node3D

const Sons = preload("res://Músicas/sons.gd")
## Míssil da MissEile: mostra o aviso no chão e uma bola branca cai do céu.
## Quando chega no chão, explode e machuca o player se ele estiver dentro do círculo.

const AVISO = preload("res://Personagens/MissEile/ataques/aviso_chao.gd")
const EXPLOSAO = preload("res://Personagens/MissEile/ataques/explosao.gd")

const ALTURA_QUEDA = 16.0
const RAIO_BOLA = 0.45

var raio := 1.8
var tempo := 1.3
var dano := 1

var _t := 0.0
var _bola: MeshInstance3D


func configurar(novo_raio: float, novo_tempo: float, novo_dano: int) -> void:
	raio = novo_raio
	tempo = novo_tempo
	dano = novo_dano


func _ready() -> void:
	var aviso := AVISO.new()
	aviso.configurar(raio, tempo)
	add_child(aviso)

	# Bola branca (aparência padrão, como os projéteis da boss)
	_bola = MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = RAIO_BOLA
	esf.height = RAIO_BOLA * 2.0
	_bola.mesh = esf
	_bola.position.y = ALTURA_QUEDA
	add_child(_bola)

	# apito + explosão: começa agora, e a explosão do som cai junto com o impacto
	Sons.tocar_missil(self, tempo)


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / tempo, 0.0, 1.0)
	# cai acelerando (devagar no começo, rápido no final)
	_bola.position.y = lerpf(ALTURA_QUEDA, RAIO_BOLA, k * k)
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
