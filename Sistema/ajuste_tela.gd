extends Node
## AUTOLOAD: garante que a janela do jogo CABE na tela do computador.
##
## O projeto abre a janela em 1920 x 1080. Em monitores Full HD (com a barra de
## tarefas e a barra de título da janela) ou em notebooks com tela menor / zoom do
## Windows em 125% ou 150%, essa janela fica maior que a tela e a parte de baixo e
## da direita somem (é aí que a cinemática aparece cortada, legenda e botão "Pular").
##
## Este script diminui a janela, mantendo o formato 16:9, até caber na área livre da
## tela, e centraliza. Se já couber, não faz nada.
##
## O jogo começa em TELA CHEIA (pra desligar, troque COMECAR_TELA_CHEIA para false).
## F11 liga/desliga a tela cheia a qualquer momento.

## O jogo já abre em tela cheia
const COMECAR_TELA_CHEIA := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# espera a janela aparecer de verdade antes de medir
	await get_tree().process_frame
	if get_window().is_embedded():
		print_rich("[color=yellow]AjusteTela: o jogo está rodando DENTRO do editor (aba Game). ",
			"Aí a Godot não deixa o jogo ficar em tela cheia. Para testar a tela cheia, ",
			"desligue \"Embed Game on Next Play\" no menu ⋮ da aba Game, ou rode o jogo exportado.[/color]")
	if COMECAR_TELA_CHEIA and _pode_mudar_janela():
		get_window().mode = Window.MODE_FULLSCREEN
	else:
		ajustar_janela()


# _input (e não _unhandled_input): assim nenhum botão ou menu "rouba" o F11
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		alternar_tela_cheia()
		get_viewport().set_input_as_handled()


## false quando o jogo roda dentro do editor (aba "Game"), na web ou no celular:
## nesses casos quem manda na janela não é o jogo.
func _pode_mudar_janela() -> bool:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return not get_window().is_embedded()


func ajustar_janela() -> void:
	if not _pode_mudar_janela():
		return
	var janela := get_window()
	if janela.mode != Window.MODE_WINDOWED:
		return

	var tela := DisplayServer.window_get_current_screen()
	var livre := DisplayServer.screen_get_usable_rect(tela)   # tela sem a barra de tarefas
	# tamanho das bordas e da barra de título da janela
	var bordas := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var cabe := Vector2(livre.size - bordas) * 0.95   # deixa uma folguinha

	var atual := Vector2(janela.size)
	if atual.x <= cabe.x and atual.y <= cabe.y:
		return   # já cabe

	var fator := minf(cabe.x / atual.x, cabe.y / atual.y)
	var novo := Vector2i((atual * fator).floor())
	janela.size = novo
	# centraliza na área livre
	janela.position = livre.position + (livre.size - novo - bordas) / 2 + Vector2i(0, bordas.y)


func alternar_tela_cheia() -> void:
	if not _pode_mudar_janela():
		print("AjusteTela: F11 ignorado, o jogo está dentro do editor (aba Game).")
		return
	var janela := get_window()
	if janela.mode == Window.MODE_FULLSCREEN or janela.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		janela.mode = Window.MODE_WINDOWED
		await get_tree().process_frame
		ajustar_janela()
	else:
		janela.mode = Window.MODE_FULLSCREEN
