extends Node3D
## Alvo de explosão: quando o COGUMELO EXPLOSIVO explode perto deste nó, a ponte aparece.
##
## Como usar:
## - Coloque este script num nó perto de onde o cogumelo vai explodir. Pode ser a própria
##   torre ou um Node3D vazio posicionado no lugar.
## - No Inspetor, escolha qual nó é a "Ponte" e como ela aparece.

enum Animacao {
	TOMBAR,   ## a ponte está EM PÉ no editor (ex.: a torre) e tomba virando a ponte
	SURGIR,   ## a ponte está no lugar FINAL no editor, começa invisível e cresce
}

## O nó que vira a ponte (pode ser a torre). Precisa ter StaticBody3D + CollisionShape3D.
@export var ponte: Node3D
@export var animacao: Animacao = Animacao.TOMBAR
## TOMBAR: quanto a ponte gira ao cair, em graus. Ex.: (0, 0, -90) tomba para a direita.
@export var rotacao_queda := Vector3(0, 0, -90)
## Tempo da animação
@export var duracao := 1.0
## Até que distância da explosão este alvo é ativado (somado ao raio da explosão)
@export var alcance_extra := 1.5

var _ativado := false


func _ready() -> void:
	add_to_group("reage_explosao")
	if ponte == null:
		ponte = self
	if animacao == Animacao.SURGIR:
		ponte.visible = false
		_ligar_colisao(ponte, false)


## Chamado pelo cogumelo explosivo quando ele explode.
func receber_explosao(posicao: Vector3, raio: float) -> void:
	if _ativado:
		return
	if global_position.distance_to(posicao) > raio + alcance_extra:
		return
	_ativado = true
	_criar_ponte()


func _criar_ponte() -> void:
	var tw := ponte.create_tween()
	match animacao:
		Animacao.TOMBAR:
			tw.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_property(ponte, "rotation_degrees", ponte.rotation_degrees + rotacao_queda, duracao)
		Animacao.SURGIR:
			var escala_final := ponte.scale
			ponte.scale = escala_final * 0.01
			ponte.visible = true
			tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(ponte, "scale", escala_final, duracao)
			tw.tween_callback(_ligar_colisao.bind(ponte, true))


static func _ligar_colisao(raiz: Node, ligar: bool) -> void:
	for forma in raiz.find_children("*", "CollisionShape3D", true, false):
		forma.set_deferred("disabled", not ligar)
