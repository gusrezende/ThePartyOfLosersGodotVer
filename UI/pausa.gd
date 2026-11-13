extends CanvasLayer
## TELA DE PAUSE (Autoload "Pausa")
##
## ESC, P ou START (controle) pausa / despausa durante o jogo.
##   - Continuar          -> volta para o jogo
##   - Reiniciar          -> recomeça a partida do começo (vida e missão do zero)
##   - Sair para o menu   -> volta para o menu principal
##
## Só abre quando tem um player na cena e nada mais está pausando o jogo
## (diálogo, sala de point and click, tela de morte, transição...).
##
## COMO ATIVAR: Projeto › Configurações do Projeto › Globais › Autoload
##   Caminho: res://UI/Pausa/pausa.gd    Nome: Pausa    -> Adicionar

## Fase onde a partida começa (Reiniciar)
const CENA_INICIAL := "res://Cenários/DungeonTeste/dungeon_teste.tscn"
## Menu principal (Sair)
const CENA_MENU := "res://UI/MainMenu/main_menu.tscn"

const COR_TEXTO := Color(1, 0.88, 0.55)
const COR_CONTORNO := Color(0.1, 0.03, 0.18)

var aberto := false

var _fundo: ColorRect
var _painel: PanelContainer
var _botoes: Array[Button] = []
var _saindo := false


func _ready() -> void:
	layer = 99                       # acima do jogo e do HUD; a transição (100) passa por cima
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false


# ---------------------------------------------------------------- MONTAGEM

func _montar() -> void:
	_fundo = ColorRect.new()
	_fundo.color = Color(0.02, 0.0, 0.05, 0.65)
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_painel = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.08, 0.03, 0.14, 0.94)
	estilo.border_color = Color(1, 0.82, 0.35)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(14)
	estilo.content_margin_left = 34
	estilo.content_margin_right = 34
	estilo.content_margin_top = 20
	estilo.content_margin_bottom = 26
	estilo.shadow_color = Color(0, 0, 0, 0.5)
	estilo.shadow_size = 8
	_painel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(_painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	_painel.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "PAUSADO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 34)
	titulo.add_theme_color_override("font_color", COR_TEXTO)
	titulo.add_theme_color_override("font_outline_color", COR_CONTORNO)
	titulo.add_theme_constant_override("outline_size", 8)
	coluna.add_child(titulo)

	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 4)
	coluna.add_child(espaco)

	_botoes = [
		_criar_botao("Continuar", coluna, fechar),
		_criar_botao("Reiniciar", coluna, _reiniciar),
		_criar_botao("Sair para o menu", coluna, _sair_para_menu),
	]
	# setas de cima/baixo dão a volta na lista
	for i in _botoes.size():
		var b := _botoes[i]
		b.focus_neighbor_top = b.get_path_to(_botoes[(i - 1 + _botoes.size()) % _botoes.size()])
		b.focus_neighbor_bottom = b.get_path_to(_botoes[(i + 1) % _botoes.size()])


func _criar_botao(texto: String, pai: Node, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(240, 46)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", COR_TEXTO)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", COR_CONTORNO)
	b.add_theme_constant_override("outline_size", 6)
	var normal := _estilo_botao(Color(0.16, 0.06, 0.32, 0.92), COR_CONTORNO)
	var selecionado := _estilo_botao(Color(0.4, 0.2, 0.68, 1.0), Color(1, 0.84, 0.45))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", selecionado)
	b.add_theme_stylebox_override("pressed", selecionado)
	b.add_theme_stylebox_override("focus", selecionado)
	b.pressed.connect(acao)
	b.mouse_entered.connect(b.grab_focus)   # mouse e teclado selecionam o mesmo botão
	pai.add_child(b)
	return b


func _estilo_botao(fundo: Color, borda: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(3)
	s.set_corner_radius_all(12)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


# ---------------------------------------------------------------- ABRIR / FECHAR

## Dá para pausar agora?
func _pode_pausar() -> bool:
	if _saindo or get_tree().paused:
		return false   # outra coisa já pausou (diálogo, point and click, morte...)
	var cena := get_tree().current_scene
	if cena == null or get_tree().get_first_node_in_group("player") == null:
		return false   # menu, cinemática...
	if get_tree().root.get_node_or_null("TelaMorte"):
		return false
	var tr := get_node_or_null("/root/Transicao")
	if tr and tr.get("_ocupado") == true:
		return false
	return true


func abrir() -> void:
	if aberto or not _pode_pausar():
		return
	aberto = true
	get_tree().paused = true
	visible = true
	_abaixar_musica(true)
	_painel.pivot_offset = _painel.size * 0.5
	_painel.scale = Vector2.ONE * 0.9
	_painel.modulate.a = 0.0
	_fundo.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_fundo, "modulate:a", 1.0, 0.15)
	tw.tween_property(_painel, "modulate:a", 1.0, 0.15)
	tw.tween_property(_painel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_botoes[0].grab_focus()


func fechar() -> void:
	if not aberto:
		return
	aberto = false
	visible = false
	_abaixar_musica(false)
	get_tree().paused = false


func _reiniciar() -> void:
	_ir_para(CENA_INICIAL)


func _sair_para_menu() -> void:
	_ir_para(CENA_MENU)


func _ir_para(cena: String) -> void:
	if _saindo:
		return
	_saindo = true
	aberto = false
	visible = false
	_abaixar_musica(false)
	# partida do zero: vida cheia e missão das plantas recomeçando
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("resetar"):
		gs.resetar()
	var q := get_node_or_null("/root/QuestManager")
	if q and q.has_method("resetar_missao"):
		q.resetar_missao()
	var tr := get_node_or_null("/root/Transicao")
	if tr and tr.has_method("ir_para"):
		await tr.ir_para(cena)          # fecha a estrela (o jogo continua pausado) e troca de cena
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file(cena)
	get_tree().paused = false
	_saindo = false


func _abaixar_musica(sim: bool) -> void:
	var musica := get_node_or_null("/root/Musica")
	if musica and musica.has_method("abaixar"):
		musica.abaixar(sim)


# ---------------------------------------------------------------- ENTRADA

func _input(event: InputEvent) -> void:
	# abrir / fechar: ESC, P ou START
	var alternar := false
	if event is InputEventKey and event.pressed and not event.echo:
		alternar = event.keycode == KEY_ESCAPE or event.keycode == KEY_P
	elif event is InputEventJoypadButton and event.pressed:
		alternar = event.button_index == JOY_BUTTON_START \
			or (aberto and event.button_index == JOY_BUTTON_B)

	if not aberto:
		if alternar and _pode_pausar():
			abrir()
			get_viewport().set_input_as_handled()
		return

	# ---- menu aberto: este menu cuida de tudo (o jogo não recebe nada)
	if alternar:
		fechar()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				_mover_foco(-1)
			JOY_BUTTON_DPAD_DOWN:
				_mover_foco(1)
			JOY_BUTTON_A:
				_apertar_foco()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_Y and absf(event.axis_value) > 0.6 and not _eixo_preso:
			_eixo_preso = true
			_mover_foco(1 if event.axis_value > 0 else -1)
		elif event.axis == JOY_AXIS_LEFT_Y and absf(event.axis_value) < 0.3:
			_eixo_preso = false
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				_mover_foco(-1)
			KEY_DOWN, KEY_S:
				_mover_foco(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				_apertar_foco()
		get_viewport().set_input_as_handled()


var _eixo_preso := false


func _indice_foco() -> int:
	var f := get_viewport().gui_get_focus_owner()
	var i := _botoes.find(f)
	return i if i >= 0 else 0


func _mover_foco(passo: int) -> void:
	var i := (_indice_foco() + passo + _botoes.size()) % _botoes.size()
	_botoes[i].grab_focus()


func _apertar_foco() -> void:
	_botoes[_indice_foco()].pressed.emit()
