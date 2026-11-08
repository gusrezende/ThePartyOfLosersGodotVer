extends CanvasLayer
## TELA DE DIÁLOGO: a câmera dá zoom no player + NPC (que ficam do lado esquerdo)
## e a caixa de diálogo aparece do lado direito, com o texto e as opções.
##
## Como usar (exemplo no area_3dPedinte.gd):
##
##     var conversa = CaixaDialogo.abrir(self, "Pedinte", player, npc)
##     await conversa.falar("Olá, viajante!")
##     var escolha: int = await conversa.perguntar("Me ajuda?", ["Sim", "Não"])
##     if escolha == 0:
##         await conversa.falar("Obrigado!")
##     await conversa.fechar()
##
## Enquanto a conversa está aberta o jogo fica PAUSADO (inimigos, tiros, tudo para).
##
## Controles: E / Enter / Espaço / clique = avançar ou escolher
##            W S ou setas = mudar a opção  |  1, 2, 3... = escolher direto
##            ESC = fechar a conversa (escolhe a última opção, que deve ser a de "sair")

const CENA := "res://UI/Dialogo/caixa_dialogo.tscn"

## Letras por segundo do efeito de "digitando"
@export var velocidade_texto := 45.0

@export_group("Cores dos botões")
@export var cor_botao := Color(0.2, 0.12, 0.32, 0.95)
@export var cor_botao_selecionado := Color(0.45, 0.27, 0.7, 1.0)
@export var cor_borda_selecionado := Color(1.0, 0.82, 0.35)

signal _confirmou
signal _escolheu(indice: int)

@onready var _painel: Control = %Painel
@onready var _nome: Label = %Nome
@onready var _texto: RichTextLabel = %Texto
@onready var _continuar: Label = %Continuar
@onready var _opcoes: VBoxContainer = %Opcoes
@onready var _faixa_cima: ColorRect = %FaixaCima
@onready var _faixa_baixo: ColorRect = %FaixaBaixo

var _player: Node3D
var _npc: Node3D
var _camera: Node
var _estava_pausado := false
var _modos_antigos := {}          # nó -> process_mode antigo
var _digitando := false
var _esperando_confirmar := false
var _botoes: Array[Button] = []
var _bloqueio := 0.0              # ignora teclas logo ao abrir (o mesmo E que abriu)
var _painel_x := 0.0
var _fechando := false


## Abre a conversa. "quem_chama" é qualquer nó da cena (ex.: o Area3D do NPC).
static func abrir(quem_chama: Node, nome_npc: String, player: Node3D, npc: Node3D):
	var caixa = load(CENA).instantiate()
	quem_chama.get_tree().root.add_child(caixa)
	caixa._comecar(nome_npc, player, npc)
	return caixa


## true se tem alguma conversa aberta agora
static func tem_conversa_aberta(arvore: SceneTree) -> bool:
	return not arvore.get_nodes_in_group("caixa_dialogo").is_empty()


func _ready() -> void:
	add_to_group("caixa_dialogo")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_texto.text = ""
	_continuar.visible = false
	_opcoes.visible = false


func _comecar(nome_npc: String, player: Node3D, npc: Node3D) -> void:
	_player = player
	_npc = npc
	_nome.text = nome_npc
	_bloqueio = 0.2

	# pausa o jogo
	_estava_pausado = get_tree().paused
	get_tree().paused = true
	# ...mas deixa os desenhos do player e do NPC animando
	for alvo in [player, npc]:
		if alvo == null:
			continue
		for s in alvo.find_children("*", "AnimatedSprite3D", true, false):
			_modos_antigos[s] = s.process_mode
			s.process_mode = Node.PROCESS_MODE_ALWAYS
	if player and player.has_node("AnimatedSprite3D"):
		var spr := player.get_node("AnimatedSprite3D") as AnimatedSprite3D
		if spr.sprite_frames and spr.sprite_frames.has_animation("IdleDown"):
			spr.play("IdleDown")

	# zoom da câmera
	_camera = get_viewport().get_camera_3d()
	if _camera and _camera.has_method("focar_conversa"):
		_camera.focar_conversa([player, npc])

	# animação de entrada: faixas pretas de cinema + caixa deslizando da direita
	await get_tree().process_frame
	_painel_x = _painel.position.x
	_painel.position.x = _painel_x + 420.0
	_painel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_painel, "position:x", _painel_x, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_painel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_faixa_cima, "offset_bottom", 26.0, 0.3)
	tw.tween_property(_faixa_baixo, "offset_top", -26.0, 0.3)


# ---------------------------------------------------------------- API

## Mostra uma fala. Espera o player apertar E / clicar para continuar.
func falar(texto: String) -> void:
	_limpar_opcoes()
	await _digitar(texto)
	_continuar.visible = true
	_esperando_confirmar = true
	await _confirmou
	_esperando_confirmar = false
	_continuar.visible = false


## Mostra uma fala com opções. Devolve o número da opção escolhida (0 = primeira).
func perguntar(texto: String, opcoes: Array) -> int:
	_limpar_opcoes()
	await _digitar(texto)
	for i in opcoes.size():
		var b := _criar_botao("%d. %s" % [i + 1, opcoes[i]])
		b.pressed.connect(func(): _escolher(i))
		_opcoes.add_child(b)
		_botoes.append(b)
	_opcoes.visible = true
	# navegação com setas entre os botões
	for i in _botoes.size():
		var b := _botoes[i]
		b.focus_neighbor_top = b.get_path_to(_botoes[(i - 1 + _botoes.size()) % _botoes.size()])
		b.focus_neighbor_bottom = b.get_path_to(_botoes[(i + 1) % _botoes.size()])
	if not _botoes.is_empty():
		_botoes[0].grab_focus()
	var escolha: int = await _escolheu
	_limpar_opcoes()
	return escolha


## Fecha a conversa: a câmera volta e o jogo continua.
func fechar() -> void:
	if _fechando:
		return
	_fechando = true
	_limpar_opcoes()
	if _camera and is_instance_valid(_camera) and _camera.has_method("soltar_conversa"):
		_camera.soltar_conversa()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_painel, "position:x", _painel_x + 420.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_painel, "modulate:a", 0.0, 0.25)
	tw.tween_property(_faixa_cima, "offset_bottom", 0.0, 0.25)
	tw.tween_property(_faixa_baixo, "offset_top", 0.0, 0.25)
	await tw.finished
	for s in _modos_antigos:
		if is_instance_valid(s):
			s.process_mode = _modos_antigos[s]
	get_tree().paused = _estava_pausado
	queue_free()


# ---------------------------------------------------------------- ENTRADA

func _process(delta: float) -> void:
	_bloqueio -= delta
	# setinha "continuar" piscando
	if _continuar.visible:
		_continuar.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)


func _input(event: InputEvent) -> void:
	if _fechando or _bloqueio > 0.0:
		get_viewport().set_input_as_handled()
		return
	var confirmar := false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				confirmar = true
			KEY_W, KEY_UP:
				_mover_foco(-1)
			KEY_S, KEY_DOWN:
				_mover_foco(1)
			KEY_ESCAPE:
				if not _botoes.is_empty():
					_escolher(_botoes.size() - 1)
				elif _esperando_confirmar:
					_confirmou.emit()
			_:
				var n: int = event.keycode - KEY_1
				if n >= 0 and n < _botoes.size():
					_escolher(n)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# clique nos botões é tratado pelo próprio botão
		if _botoes.is_empty():
			confirmar = true
			get_viewport().set_input_as_handled()
	if not confirmar:
		return
	if _digitando:
		_texto.visible_ratio = 1.0   # mostra o texto inteiro de uma vez
	elif _esperando_confirmar:
		_confirmou.emit()
	elif not _botoes.is_empty():
		var focado := get_viewport().gui_get_focus_owner()
		var i := _botoes.find(focado)
		_escolher(maxi(i, 0))


func _mover_foco(direcao: int) -> void:
	if _botoes.is_empty():
		return
	var i := _botoes.find(get_viewport().gui_get_focus_owner())
	i = (maxi(i, 0) + direcao + _botoes.size()) % _botoes.size()
	_botoes[i].grab_focus()


func _escolher(indice: int) -> void:
	if _botoes.is_empty():
		return
	_escolheu.emit(indice)


# ---------------------------------------------------------------- AUXILIARES

func _digitar(texto: String) -> void:
	_texto.text = texto
	_texto.visible_characters = 0
	var total := _texto.get_total_character_count()
	if total == 0:
		return
	_digitando = true
	var tw := create_tween()
	tw.tween_property(_texto, "visible_characters", total, total / velocidade_texto)
	while _digitando and _texto.visible_ratio < 1.0:
		await get_tree().process_frame
	tw.kill()
	_texto.visible_ratio = 1.0
	_digitando = false


func _limpar_opcoes() -> void:
	for b in _botoes:
		b.queue_free()
	_botoes.clear()
	_opcoes.visible = false


func _criar_botao(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.92, 0.9, 1.0))
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := _estilo(cor_botao, Color(0, 0, 0, 0))
	var sel := _estilo(cor_botao_selecionado, cor_borda_selecionado)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", sel)
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("focus", sel)
	# passar o mouse por cima também seleciona (para o E escolher a mesma)
	b.mouse_entered.connect(b.grab_focus)
	return b


func _estilo(fundo: Color, borda: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.set_corner_radius_all(6)
	s.set_border_width_all(2)
	s.border_color = borda
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s
