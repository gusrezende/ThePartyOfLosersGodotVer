extends Control

@onready var miss_eile = $MissEile

var velocidade := 300.0
var direcao := Vector2(1, 0)
var tempo_mudanca := 0.0


func _ready():
	randomizar_direcao()


func _process(delta):
	tempo_mudanca -= delta

	if tempo_mudanca <= 0:
		randomizar_direcao()
		tempo_mudanca = randf_range(0.5, 1.5)

	miss_eile.position += direcao * velocidade * delta

	verificar_bordas()


func randomizar_direcao():
	direcao = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()


func verificar_bordas():
	var tamanho_tela = size
	var tamanho_miss_eile = miss_eile.size

	if miss_eile.position.x <= 0:
		miss_eile.position.x = 0
		direcao.x *= -1

	if miss_eile.position.x + tamanho_miss_eile.x >= tamanho_tela.x:
		miss_eile.position.x = tamanho_tela.x - tamanho_miss_eile.x
		direcao.x *= -1

	if miss_eile.position.y <= 0:
		miss_eile.position.y = 0
		direcao.y *= -1

	if miss_eile.position.y + tamanho_miss_eile.y >= tamanho_tela.y:
		miss_eile.position.y = tamanho_tela.y - tamanho_miss_eile.y
		direcao.y *= -1

func _on_miss_eile_pressed() -> void:
	pass # Replace with function body.
