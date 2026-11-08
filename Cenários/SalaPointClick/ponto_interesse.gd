@tool
extends Control
## PONTO DE INTERESSE da tela de point and click: um retângulo invisível
## em cima de alguma coisa do desenho (estante, baú, quadro...).
##
## Passando o mouse por cima: ele brilha e mostra o nome.
## Clicando: mostra a mensagem embaixo da tela e avisa a sala pelo sinal
## "objeto_clicado(nome)" (use isso para fazer puzzles: pegar itens, abrir baú...).
##
## Para criar um novo: duplique um dos que já existem (Ctrl+D), mova e mude o tamanho
## no editor. No editor eles aparecem com um contorno amarelo tracejado.

## Nome que aparece ao passar o mouse
@export var nome := "Objeto"
## Texto que aparece ao clicar
@export_multiline var mensagem := "Não tem nada de especial aqui."

var destacado := false:
	set(valor):
		if destacado != valor:
			destacado = valor
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # quem cuida do mouse é a sala
	queue_redraw()


func contem_ponto(ponto_tela: Vector2) -> bool:
	return get_global_rect().has_point(ponto_tela)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if Engine.is_editor_hint():
		# só no editor: mostra onde está a área clicável
		draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), Color(1, 0.85, 0.2), 2.0, 8.0)
		draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, Color(1, 0.85, 0.2), 2.0, 8.0)
		draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), Color(1, 0.85, 0.2), 2.0, 8.0)
		draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, Color(1, 0.85, 0.2), 2.0, 8.0)
		return
	if destacado:
		var brilho := StyleBoxFlat.new()
		brilho.bg_color = Color(1, 0.9, 0.5, 0.10)
		brilho.border_color = Color(1, 0.85, 0.35, 0.85)
		brilho.set_border_width_all(2)
		brilho.set_corner_radius_all(10)
		brilho.shadow_color = Color(1, 0.8, 0.3, 0.35)
		brilho.shadow_size = 10
		draw_style_box(brilho, r)
