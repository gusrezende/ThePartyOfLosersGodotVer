extends CanvasLayer

const Sons = preload("res://Músicas/sons.gd")
## TELA DE POINT AND CLICK de uma sala.
##
## Abre POR CIMA da dungeon (que fica pausada), então ao voltar está tudo do jeito
## que estava: plantas coletadas, missão, ponte, inimigos...
##
## - Segure o botão esquerdo e arraste para olhar para os lados
##   (também: A / D, setas ou a rodinha do mouse).
## - Clique nas coisas (os "PontoInteresse") para ver as mensagens.
## - Botão "Voltar" (ou ESC) volta para a dungeon.
##
## O cursor vira a mãozinha e faz a animação de apertar a cada clique.
##
## Para trocar o desenho da sala: troque a textura do nó "Cenario/Fundo"
## (qualquer imagem mais larga que a tela; ela é ajustada à altura da tela)
## e reposicione os PontoInteresse em cima dos objetos.

## Avisa quando um objeto é clicado (use para puzzles)
signal objeto_clicado(nome: String)
## Avisa quando o player sai da sala
signal saiu

@export_group("Cursor")
@export var cursor_normal: Texture2D = preload("res://Cenários/SalaPointClick/cursor_mao.png")
@export var cursor_apertando: Texture2D = preload("res://Cenários/SalaPointClick/cursor_mao_apertando.png")
## Ponta do dedo em cada imagem (em pixels da imagem original)
@export var ponta_dedo_normal := Vector2(44, 6)
@export var ponta_dedo_apertando := Vector2(46, 15)
## Tamanho do cursor na tela, em pixels
@export var tamanho_cursor := 96

@export_group("Movimento")
## Velocidade com A/D ou setas (pixels por segundo)
@export var velocidade_teclado := 650.0
## Quanto o cenário continua deslizando depois de soltar o mouse (0 = nada)
@export_range(0.0, 0.98) var inercia := 0.9

@onready var _cenario: Control = %Cenario
@onready var _fundo: TextureRect = %Fundo
@onready var _voltar: Button = %Voltar
@onready var _seta_esq: Label = %SetaEsquerda
@onready var _seta_dir: Label = %SetaDireita
@onready var _dica: Label = %Dica
@onready var _nome_objeto: Label = %NomeObjeto
@onready var _mensagem: PanelContainer = %Mensagem
@onready var _mensagem_texto: Label = %MensagemTexto

var _deslocamento := 0.0      # posição X do cenário (0 = encostado na esquerda)
var _minimo := 0.0            # deslocamento máximo para a direita (negativo)
var _arrastando := false
var _apertado := false
var _distancia_arrasto := 0.0
var _velocidade := 0.0
var _cursores := {}           # "normal"/"apertando" -> [textura, ponta]
var _tempo_apertado := 0.0
var _estava_pausado := false
var _saindo := false
var _ativo := false
var _tempo_mensagem := 0.0
var _usou_arrasto := false


func _ready() -> void:
	add_to_group("tela_point_click")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_mensagem.visible = false
	_nome_objeto.visible = false
	_voltar.pressed.connect(sair)
	_preparar_cursores()
	_entrar()


# ---------------------------------------------------------------- ENTRAR / SAIR

func _entrar() -> void:
	_estava_pausado = get_tree().paused
	get_tree().paused = true
	var tr := _transicao()
	Sons.tocar(self, Sons.TRANSICAO)
	if tr:
		tr._preparar()
		await tr._animar(1.0, 0.5, Tween.EASE_IN)
	visible = true
	_ajustar_tamanho()
	# começa olhando o meio da sala
	_deslocamento = _minimo * 0.5
	_aplicar_posicao()
	_usar_cursor("normal")
	if tr:
		await get_tree().create_timer(0.15).timeout
		await tr._animar(0.0, 0.5, Tween.EASE_OUT)
	_ativo = true


func sair() -> void:
	if _saindo:
		return
	_saindo = true
	_ativo = false
	var tr := _transicao()
	Sons.tocar(self, Sons.TRANSICAO)
	if tr:
		tr._preparar()
		await tr._animar(1.0, 0.5, Tween.EASE_IN)
	Input.set_custom_mouse_cursor(null)
	visible = false
	saiu.emit()
	get_tree().paused = _estava_pausado
	if tr:
		await get_tree().create_timer(0.15).timeout
		tr._preparar()
		await tr._animar(0.0, 0.5, Tween.EASE_OUT)
	queue_free()


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)   # garante que o cursor volta ao normal


func _transicao() -> Node:
	var tr := get_tree().root.get_node_or_null("Transicao")
	if tr and tr.has_method("_animar") and tr.has_method("_preparar"):
		return tr
	return null


# ---------------------------------------------------------------- CURSOR

func _preparar_cursores() -> void:
	for nome in ["normal", "apertando"]:
		var tex: Texture2D = cursor_normal if nome == "normal" else cursor_apertando
		var ponta: Vector2 = ponta_dedo_normal if nome == "normal" else ponta_dedo_apertando
		if tex == null:
			continue
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var escala := float(tamanho_cursor) / float(maxi(img.get_width(), img.get_height()))
		img.resize(maxi(1, roundi(img.get_width() * escala)), maxi(1, roundi(img.get_height() * escala)), Image.INTERPOLATE_LANCZOS)
		_cursores[nome] = [ImageTexture.create_from_image(img), (ponta * escala).round()]


func _usar_cursor(nome: String) -> void:
	if not _cursores.has(nome):
		return
	var c: Array = _cursores[nome]
	Input.set_custom_mouse_cursor(c[0], Input.CURSOR_ARROW, c[1])
	Input.set_custom_mouse_cursor(c[0], Input.CURSOR_POINTING_HAND, c[1])


# ---------------------------------------------------------------- ENTRADA

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# animação de apertar: vale para qualquer clique (até no botão Voltar)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_apertado = true
			_tempo_apertado = 0.0
			_usar_cursor("apertando")
		else:
			_apertado = false


func _unhandled_input(event: InputEvent) -> void:
	if not _ativo:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_arrastando = true
					_distancia_arrasto = 0.0
					_velocidade = 0.0
				elif _arrastando:
					_arrastando = false
					if _distancia_arrasto < 8.0:
						_clicar(event.position)
			MOUSE_BUTTON_WHEEL_UP:
				_mover(70.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_mover(-70.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _arrastando:
		_distancia_arrasto += absf(event.relative.x)
		_mover(event.relative.x)
		# guarda a velocidade para a inércia
		_velocidade = lerpf(_velocidade, event.relative.x / maxf(get_process_delta_time(), 0.001), 0.5)
		if _distancia_arrasto > 30.0 and not _usou_arrasto:
			_usou_arrasto = true
			create_tween().tween_property(_dica, "modulate:a", 0.0, 0.6)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		sair()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	# volta do cursor "apertando" para o normal (fica pelo menos 0,12 s apertado)
	_tempo_apertado += delta
	if not _apertado and _tempo_apertado > 0.12:
		_usar_cursor("normal")
		_tempo_apertado = -INF   # já voltou; não fica chamando toda hora

	if not _ativo:
		return

	# teclado
	var eixo := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		eixo += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		eixo -= 1.0
	if eixo != 0.0:
		_mover(eixo * velocidade_teclado * delta)
		_velocidade = 0.0

	# inércia depois de soltar o arrasto
	if not _arrastando and absf(_velocidade) > 5.0:
		_mover(_velocidade * delta)
		_velocidade *= pow(1.0 - inercia, delta * 3.0) if inercia < 1.0 else 1.0
	elif not _arrastando:
		_velocidade = 0.0

	_atualizar_setas()
	_atualizar_hover()

	if _mensagem.visible:
		_tempo_mensagem -= delta
		if _tempo_mensagem <= 0.0:
			_esconder_mensagem()


# ---------------------------------------------------------------- CENÁRIO

func _ajustar_tamanho() -> void:
	var tela := get_viewport().get_visible_rect().size
	var tex_tam := _fundo.size
	# o cenário inteiro é escalado para ter a altura da tela
	var escala := tela.y / tex_tam.y
	_cenario.scale = Vector2.ONE * escala
	_minimo = minf(0.0, tela.x - tex_tam.x * escala)


func _mover(dx: float) -> void:
	_deslocamento = clampf(_deslocamento + dx, _minimo, 0.0)
	if _deslocamento == 0.0 or _deslocamento == _minimo:
		_velocidade = 0.0
	_aplicar_posicao()


func _aplicar_posicao() -> void:
	_cenario.position.x = roundf(_deslocamento)


func _atualizar_setas() -> void:
	var piscar := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.005)
	_seta_esq.modulate.a = piscar if _deslocamento < -2.0 else 0.0
	_seta_dir.modulate.a = piscar if _deslocamento > _minimo + 2.0 else 0.0


func _pontos() -> Array:
	return _cenario.get_children().filter(func(n): return n.has_method("contem_ponto"))


func _ponto_em(posicao: Vector2) -> Node:
	for p in _pontos():
		if p.contem_ponto(posicao):
			return p
	return null


func _atualizar_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	var sobre: Node = null if (_arrastando and _distancia_arrasto > 8.0) else _ponto_em(mouse)
	for p in _pontos():
		p.destacado = (p == sobre)
	_nome_objeto.visible = sobre != null
	if sobre:
		_nome_objeto.text = sobre.nome
		var tela := get_viewport().get_visible_rect().size
		var pos := mouse + Vector2(18, -30)
		pos.x = clampf(pos.x, 4.0, tela.x - _nome_objeto.size.x - 4.0)
		pos.y = maxf(pos.y, 4.0)
		_nome_objeto.position = pos


func _clicar(posicao: Vector2) -> void:
	var p := _ponto_em(posicao)
	if p == null:
		_esconder_mensagem()
		return
	mostrar_mensagem(p.mensagem)
	objeto_clicado.emit(p.nome)


## Mostra uma mensagem embaixo da tela (some sozinha depois de alguns segundos)
func mostrar_mensagem(texto: String) -> void:
	_mensagem_texto.text = texto
	_mensagem.visible = true
	_tempo_mensagem = 2.5 + texto.length() * 0.04
	_mensagem.modulate.a = 0.0
	create_tween().tween_property(_mensagem, "modulate:a", 1.0, 0.15)


func _esconder_mensagem() -> void:
	_mensagem.visible = false
