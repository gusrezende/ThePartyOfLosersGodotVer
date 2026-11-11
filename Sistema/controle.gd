extends Node
## AUTOLOAD: suporte a CONTROLE (Xbox, PlayStation, Switch Pro, genéricos).
##
## Ele "traduz" os botões do controle para as teclas e cliques que o jogo já usa,
## então nenhum outro script precisou mudar.
##
##   Analógico esquerdo / direcional ... andar (e navegar nos menus e diálogos)
##   Analógico direito ................. mirar (a mira gira em volta do mago)
##   RT / RB / X (□ no PlayStation) .... atirar / jogar o cogumelo
##   A (✕ no PlayStation) .............. interagir (falar, entrar, pegar)
##                                       e confirmar nos menus e diálogos
##   B (○ no PlayStation) .............. voltar / sair da conversa / sair da sala
##   Start ............................. pular a cinemática / confirmar no menu
##   Select / Back ..................... tela cheia (igual ao F11)
##
## Na sala de point and click:
##   analógico direito move a mãozinha, A clica, analógico esquerdo olha para os lados,
##   B volta.
##
## Se o player mexer o mouse, tudo volta ao normal (teclado + mouse).

## Distância da mira até o mago, em pixels da tela do jogo (854 x 480)
@export var distancia_mira := 120.0
## Velocidade da mãozinha na sala de point and click (pixels por segundo)
@export var velocidade_cursor := 520.0
## Zona morta dos analógicos (0 a 1)
@export var zona_morta := 0.25

var usando_controle := false

var _mira_dir := Vector2.RIGHT          # última direção de mira
var _gatilho_apertado := false
var _teclas_seguradas := {}             # tecla -> true (para soltar depois)
var _clique_segurado := false
var _pan := 0                           # -1 esquerda, 0 parado, 1 direita (sala)
var _vertical := 0                      # -1 cima, 0, 1 baixo (navegação)
var _eixos := {}                        # eixo -> valor (último valor recebido do controle)
var _tempo_desde_warp := 1.0            # ignora o "mouse fantasma" logo depois de mover o cursor


## Mostra na tela quando um controle conecta/desconecta
@export var avisar_na_tela := true

var _aviso: Label
var _tempo_aviso := 0.0
var _primeiro_evento := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_adicionar_movimento_no_controle()
	_criar_aviso()
	Input.joy_connection_changed.connect(_conexao_mudou)

	# DIAGNÓSTICO: aparece no painel Output da Godot
	var lista := Input.get_connected_joypads()
	print("[Controle] script ligado. Controles encontrados: ", lista.size())
	for id in lista:
		print("[Controle]   #", id, ": ", Input.get_joy_name(id), "  (guid ", Input.get_joy_guid(id), ")")
		_avisar("Controle conectado: " + Input.get_joy_name(id))
	if lista.is_empty():
		print("[Controle]   nenhum controle. Confira se ele está ligado/conectado ANTES de apertar F5,")
		print("[Controle]   ou conecte agora: vai aparecer uma mensagem aqui quando a Godot reconhecer.")


func _conexao_mudou(id: int, conectado: bool) -> void:
	var nome := Input.get_joy_name(id)
	print("[Controle] controle #", id, (" CONECTADO: " if conectado else " desconectado: "), nome)
	_avisar(("Controle conectado: " if conectado else "Controle desconectado: ") + nome)


func _criar_aviso() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 126
	add_child(camada)
	_aviso = Label.new()
	_aviso.position = Vector2(12, 440)
	_aviso.add_theme_font_size_override("font_size", 16)
	_aviso.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	_aviso.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.18))
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.visible = false
	camada.add_child(_aviso)


func _avisar(texto: String) -> void:
	if not avisar_na_tela or _aviso == null:
		return
	_aviso.text = texto
	_aviso.visible = true
	_aviso.modulate.a = 1.0
	_tempo_aviso = 3.0


# ---------------------------------------------------------------- MAPEAMENTO

## Coloca analógico esquerdo + direcional nas ações de andar do projeto
func _adicionar_movimento_no_controle() -> void:
	var mapa := {
		"move_left": [[JOY_AXIS_LEFT_X, -1.0], JOY_BUTTON_DPAD_LEFT],
		"move_right": [[JOY_AXIS_LEFT_X, 1.0], JOY_BUTTON_DPAD_RIGHT],
		"move_forward": [[JOY_AXIS_LEFT_Y, -1.0], JOY_BUTTON_DPAD_UP],
		"move_back": [[JOY_AXIS_LEFT_Y, 1.0], JOY_BUTTON_DPAD_DOWN],
	}
	for acao in mapa:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao, 0.2)
		var eixo := InputEventJoypadMotion.new()
		eixo.axis = mapa[acao][0][0]
		eixo.axis_value = mapa[acao][0][1]
		InputMap.action_add_event(acao, eixo)
		var botao := InputEventJoypadButton.new()
		botao.button_index = mapa[acao][1]
		InputMap.action_add_event(acao, botao)


# ---------------------------------------------------------------- ENTRADA

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not _evento_nosso(event):
		# mexeu o mouse de verdade: volta ao normal (teclado + mouse).
		# Logo depois de a gente mover o cursor, o sistema pode mandar um movimento
		# "fantasma": esse é ignorado.
		if _tempo_desde_warp > 0.15 and event.relative.length() > 6.0:
			usando_controle = false
		return
	if event is InputEventMouseButton and not _evento_nosso(event):
		usando_controle = false
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return

	if _primeiro_evento and (event is InputEventJoypadButton or absf(event.axis_value) > zona_morta):
		_primeiro_evento = false
		print("[Controle] primeiro botão/analógico recebido do controle #", event.device, " (", Input.get_joy_name(event.device), "): ", event.as_text())

	if event is InputEventJoypadMotion:
		_eixos[event.axis] = event.axis_value
		# analógico parado no meio (ou com "drift") não liga o modo controle
		var forte: bool = absf(event.axis_value) > zona_morta
		if forte:
			usando_controle = true
	else:
		usando_controle = true
	# o controle vira teclas/cliques; o evento original não segue adiante
	# (assim nada é apertado duas vezes)
	get_viewport().set_input_as_handled()

	if event is InputEventJoypadButton:
		_botao(event.button_index, event.pressed)
	elif event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_TRIGGER_RIGHT:
			var apertado: bool = event.axis_value > 0.5
			if apertado != _gatilho_apertado:
				_gatilho_apertado = apertado
				_clique(apertado)


func _botao(b: int, apertado: bool) -> void:
	var dialogo := _dialogo_aberto()
	var sala := _sala_aberta()
	match b:
		JOY_BUTTON_A:
			if sala:
				_clique(apertado)
			elif dialogo:
				_tecla(KEY_E, apertado)
			else:
				_focar_algum_botao()
				_tecla(KEY_E, apertado)
				_tecla(KEY_ENTER, apertado)
		JOY_BUTTON_B:
			_tecla(KEY_ESCAPE, apertado)
		JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER:
			if not dialogo:
				_clique(apertado)
		JOY_BUTTON_START:
			if apertado and not _pular_cinematica():
				_focar_algum_botao()
				_tecla(KEY_ENTER, true)
				_tecla(KEY_ENTER, false)
		JOY_BUTTON_BACK:
			if apertado:
				_tecla(KEY_F11, true)
				_tecla(KEY_F11, false)
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			# o andar já vem pelas ações; aqui só a navegação de menus/diálogos
			var tecla: Key = {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
				JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT}[b]
			if apertado:
				_focar_algum_botao()
			if sala and (tecla == KEY_LEFT or tecla == KEY_RIGHT):
				_tecla(tecla, apertado)          # olhar para os lados
			elif dialogo or not _tem_player():
				_tecla(tecla, apertado)          # navegar nas opções / menus


func _process(delta: float) -> void:
	_tempo_desde_warp += delta
	if _tempo_aviso > 0.0:
		_tempo_aviso -= delta
		_aviso.modulate.a = clampf(_tempo_aviso / 0.5, 0.0, 1.0)
		if _tempo_aviso <= 0.0:
			_aviso.visible = false
	if not usando_controle:
		_soltar_tudo_se_preciso()
		return

	var esq := _analogico(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var dir := _analogico(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)

	if _sala_aberta():
		# mãozinha com o analógico direito, olhar para os lados com o esquerdo
		if dir != Vector2.ZERO:
			_mover_mouse(get_viewport().get_mouse_position() + dir * velocidade_cursor * delta)
		_atualizar_pan(esq.x)
		return
	_atualizar_pan(0.0)

	# navegação nos menus e diálogos com o analógico esquerdo
	if _dialogo_aberto() or not _tem_player():
		_atualizar_vertical(esq.y)
		return
	_atualizar_vertical(0.0)

	# mira em volta do mago: analógico direito; parado = para onde ele anda
	if dir != Vector2.ZERO:
		_mira_dir = dir.normalized()
	elif esq != Vector2.ZERO:
		_mira_dir = _mira_dir.slerp(esq.normalized(), 1.0 - exp(-10.0 * delta))
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var cam := get_viewport().get_camera_3d()
	if player and cam and not cam.is_position_behind(player.global_position):
		var centro := cam.unproject_position(player.global_position + Vector3(0, 0.8, 0))
		_mover_mouse(centro + _mira_dir * distancia_mira)


# ---------------------------------------------------------------- AUXILIARES

func _analogico(eixo_x: JoyAxis, eixo_y: JoyAxis) -> Vector2:
	var v := Vector2(_eixos.get(eixo_x, 0.0), _eixos.get(eixo_y, 0.0))
	if v.length() < zona_morta:
		return Vector2.ZERO
	return v.normalized() * inverse_lerp(zona_morta, 1.0, minf(v.length(), 1.0))


func _tecla(tecla: Key, apertado: bool) -> void:
	if apertado == _teclas_seguradas.has(tecla):
		return
	var e := InputEventKey.new()
	e.keycode = tecla
	e.physical_keycode = tecla
	e.pressed = apertado
	e.set_meta("controle", true)
	if apertado:
		_teclas_seguradas[tecla] = true
	else:
		_teclas_seguradas.erase(tecla)
	Input.parse_input_event(e)


func _clique(apertado: bool) -> void:
	if apertado == _clique_segurado:
		return
	_clique_segurado = apertado
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = apertado
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if apertado else 0
	e.position = get_viewport().get_mouse_position()
	e.global_position = e.position
	e.set_meta("controle", true)
	Input.parse_input_event(e)


func _mover_mouse(pos: Vector2) -> void:
	var tela := get_viewport().get_visible_rect().size
	pos = pos.clamp(Vector2.ZERO, tela - Vector2.ONE)
	var antes := get_viewport().get_mouse_position()
	get_viewport().warp_mouse(pos)
	_tempo_desde_warp = 0.0
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = pos - antes
	e.set_meta("controle", true)
	Input.parse_input_event(e)


func _evento_nosso(event: InputEvent) -> bool:
	return event.has_meta("controle")


func _atualizar_pan(x: float) -> void:
	var novo := 0 if absf(x) < 0.3 else int(signf(x))
	if novo == _pan:
		return
	if _pan != 0:
		_tecla(KEY_RIGHT if _pan > 0 else KEY_LEFT, false)
	if novo != 0:
		_tecla(KEY_RIGHT if novo > 0 else KEY_LEFT, true)
	_pan = novo


func _atualizar_vertical(y: float) -> void:
	var novo := 0 if absf(y) < 0.5 else int(signf(y))
	if novo == _vertical:
		return
	_vertical = novo
	if novo != 0:
		_focar_algum_botao()
		var t := KEY_DOWN if novo > 0 else KEY_UP
		_tecla(t, true)
		_tecla(t, false)


func _soltar_tudo_se_preciso() -> void:
	for t in _teclas_seguradas.keys():
		_tecla(t, false)
	if _clique_segurado:
		_clique(false)
	_pan = 0
	_vertical = 0


func _dialogo_aberto() -> bool:
	return not get_tree().get_nodes_in_group("caixa_dialogo").is_empty()


func _sala_aberta() -> bool:
	for s in get_tree().get_nodes_in_group("tela_point_click"):
		if s.visible:
			return true
	return false


func _tem_player() -> bool:
	return get_tree().get_first_node_in_group("player") != null


## Nos menus: se nenhum botão está selecionado, seleciona o primeiro visível
func _focar_algum_botao() -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	var cena := get_tree().current_scene
	if cena == null:
		return
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		var botao := b as BaseButton
		if botao.is_visible_in_tree() and not botao.disabled and botao.focus_mode != Control.FOCUS_NONE:
			botao.grab_focus()
			return


## Start na cinemática: aperta o botão de pular
func _pular_cinematica() -> bool:
	var cena := get_tree().current_scene
	if cena == null:
		return false
	var pular := cena.find_child("SkipButton", true, false) as BaseButton
	if pular and pular.is_visible_in_tree():
		pular.pressed.emit()
		return true
	return false
