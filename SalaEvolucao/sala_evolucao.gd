extends Node3D
## Sala de evolução: o player testa a evolução escolhida contra ondas de inimigos.
## No final, pode voltar ao menu ou testar outra evolução.

const ENEMY_SCENE = preload("res://Enemy1/enemy_1.tscn")
const EVOLUCOES = preload("res://Evolucoes/evolucoes.gd")
const TelaEvolucao = preload("res://BossMissEile/tela_evolucao.gd")
const MENU := "res://MainMenu/main_menu.tscn"

const ONDAS := [3, 5, 7, 9, 12]       # quantos inimigos em cada onda
const PAUSA_ENTRE_ONDAS := 2.5
const DISTANCIA_MIN_SPAWN := 6.0      # inimigos não nascem colados no player

# Área onde os inimigos podem nascer (X e Z), dentro das paredes
@export var area_min := Vector2(-11.0, -8.0)
@export var area_max := Vector2(11.0, 8.0)

var _onda := -1
var _espera := 1.5
var _terminou := false
var _player: Node3D
var _aviso_onda: Label
var _dica: Label
var _camada_ui: CanvasLayer


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_criar_ui()
	var nome: String = EVOLUCOES.NOMES.get(GameState.evolucao, "Nenhuma")
	var dica: String = EVOLUCOES.DICAS.get(GameState.evolucao, "")
	_dica.text = "Evolução: %s\n%s" % [nome, dica]
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(_dica, "modulate:a", 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if _terminou:
		return
	if _inimigos_vivos() > 0:
		return
	_espera -= delta
	if _espera > 0.0:
		return
	_espera = PAUSA_ENTRE_ONDAS
	_onda += 1
	if _onda >= ONDAS.size():
		_fim()
	else:
		_soltar_onda(ONDAS[_onda])


func _inimigos_vivos() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.get("morto") != true:
			n += 1
	return n


func _soltar_onda(qtd: int) -> void:
	_mostrar_aviso("Onda %d / %d" % [_onda + 1, ONDAS.size()])
	for i in qtd:
		var inimigo := ENEMY_SCENE.instantiate()
		inimigo.add_to_group("enemy")
		add_child(inimigo)
		inimigo.global_position = _ponto_spawn()
		inimigo.set("is_hunting", true)   # já vem caçando o player


func _ponto_spawn() -> Vector3:
	var p := Vector3.ZERO
	for i in 30:
		p = Vector3(randf_range(area_min.x, area_max.x), 1.0, randf_range(area_min.y, area_max.y))
		if _player == null or Vector2(p.x - _player.global_position.x, p.z - _player.global_position.z).length() >= DISTANCIA_MIN_SPAWN:
			break
	return p


# ---------------------------------------------------------------- UI

func _criar_ui() -> void:
	_camada_ui = CanvasLayer.new()
	_camada_ui.layer = 10
	add_child(_camada_ui)

	_dica = Label.new()
	_dica.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_dica.offset_left = -300
	_dica.offset_right = 300
	_dica.offset_top = 12
	_dica.offset_bottom = 70
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.add_theme_font_size_override("font_size", 16)
	_dica.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	_dica.add_theme_color_override("font_outline_color", Color.BLACK)
	_dica.add_theme_constant_override("outline_size", 5)
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada_ui.add_child(_dica)

	_aviso_onda = Label.new()
	_aviso_onda.set_anchors_preset(Control.PRESET_CENTER)
	_aviso_onda.offset_left = -200
	_aviso_onda.offset_right = 200
	_aviso_onda.offset_top = -130
	_aviso_onda.offset_bottom = -90
	_aviso_onda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso_onda.add_theme_font_size_override("font_size", 30)
	_aviso_onda.add_theme_color_override("font_color", Color(1.0, 0.55, 0.12))
	_aviso_onda.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso_onda.add_theme_constant_override("outline_size", 6)
	_aviso_onda.modulate.a = 0.0
	_aviso_onda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada_ui.add_child(_aviso_onda)


func _mostrar_aviso(texto: String) -> void:
	_aviso_onda.text = texto
	_aviso_onda.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(_aviso_onda, "modulate:a", 0.0, 0.6)


func _fim() -> void:
	_terminou = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var tela := CanvasLayer.new()
	tela.layer = 80
	tela.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tela)

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.8)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	tela.add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	tela.add_child(centro)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 14)
	centro.add_child(caixa)

	var texto := Label.new()
	texto.text = "Sala concluída!\nFim da demo.\nObrigado por jogar!"
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 26)
	caixa.add_child(texto)

	var outra := Button.new()
	outra.text = "Testar outra evolução"
	outra.custom_minimum_size = Vector2(260, 44)
	outra.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outra.add_theme_font_size_override("font_size", 18)
	outra.pressed.connect(func():
		tela.queue_free()
		GameState.player_hp = -1   # volta com vida cheia
		var escolha = TelaEvolucao.new()
		add_child(escolha)
		escolha.mostrar()
	)
	caixa.add_child(outra)

	var menu := Button.new()
	menu.text = "Voltar ao menu"
	menu.custom_minimum_size = Vector2(260, 44)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.add_theme_font_size_override("font_size", 18)
	menu.pressed.connect(func():
		GameState.resetar()
		Transicao.ir_para(MENU)
	)
	caixa.add_child(menu)
	outra.grab_focus()
