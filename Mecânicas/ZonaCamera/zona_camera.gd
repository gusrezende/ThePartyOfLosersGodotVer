extends Area3D
## ZONA DE CÂMERA: diz para a câmera até onde ela pode mostrar.
##
## Enquanto o player está dentro desta caixa, a câmera não mostra nada fora dela
## (só olhando de cima: conta o X e o Z, a altura não importa).
## Se a zona for mais estreita que a tela (um corredor, por exemplo), a câmera chega
## mais perto do player para não mostrar o lado de fora.
##
## Como usar:
##   1. Arraste "zona_camera.tscn" para a cena da fase.
##   2. Mude o tamanho pelo CollisionShape3D (pelas bolinhas vermelhas no editor
##      ou em Shape > Size) e posicione cobrindo o pedaço do mapa.
##   3. Faça as zonas se sobreporem um pouco nas passagens (porta, entrada do corredor).
## Se a cena não tiver nenhuma zona, a câmera usa o mapa inteiro, como antes.

## Quando o player está em duas zonas ao mesmo tempo, vale a de prioridade maior.
## Empate: continua na zona em que ele já estava.
@export var prioridade := 0
## Deixa a câmera chegar mais perto quando a zona é menor que a tela.
@export var aproximar_se_estreito := true
## O máximo que ela pode se aproximar (0.6 = fica a 60% da distância normal).
@export_range(0.3, 1.0) var zoom_minimo := 0.6


func _enter_tree() -> void:
	# entra no grupo antes de qualquer _ready, para a câmera achar a zona logo no início
	add_to_group("zona_camera")


func _ready() -> void:
	# a zona só serve para a câmera: não detecta nem bloqueia nada
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0


## Retângulo da zona no mundo: position = (X mínimo, Z mínimo), size = (largura X, largura Z)
func retangulo() -> Rect2:
	var caixa := AABB()
	var achou := false
	for filho in get_children():
		var cs := filho as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var malha := cs.shape.get_debug_mesh()
		if malha == null:
			continue
		var b := cs.global_transform * malha.get_aabb()
		caixa = b if not achou else caixa.merge(b)
		achou = true
	if not achou:
		return Rect2(global_position.x - 5, global_position.z - 5, 10, 10)
	return Rect2(caixa.position.x, caixa.position.z, caixa.size.x, caixa.size.z)


## true se o ponto (do mundo) está dentro da zona, olhando de cima
func contem(ponto: Vector3) -> bool:
	return retangulo().has_point(Vector2(ponto.x, ponto.z))
