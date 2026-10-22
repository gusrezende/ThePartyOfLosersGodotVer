extends CanvasLayer

const MENU := "res://MainMenu/main_menu.tscn"  # confira o caminho real do seu menu

const MSG_VITORIA := "Parabéns! Você derrotou a inocente, delicada e charmosa MissEile, como pôde? Enfim! Você ganhou +1 de habilidade"
const MSG_FIM := "Fim da demo.\nObrigado por jogar!"

var _label: Label
var _botao: Button
var _fase := 0
var _mensagem := MSG_VITORIA


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.8)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 40)
	centro.add_child(caixa)

	_label = Label.new()
	_label.text = _mensagem
	_label.custom_minimum_size = Vector2(900, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 36)
	caixa.add_child(_label)

	_botao = Button.new()
	_botao.text = "Continuar"
	_botao.custom_minimum_size = Vector2(260, 64)
	_botao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_botao.add_theme_font_size_override("font_size", 30)
	_botao.pressed.connect(_on_botao_pressed)
	caixa.add_child(_botao)


func mostrar(mensagem: String = MSG_VITORIA) -> void:
	_mensagem = mensagem
	if _label:
		_label.text = mensagem
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_botao.grab_focus()


func _on_botao_pressed() -> void:
	if _fase == 0:
		_fase = 1
		_label.text = MSG_FIM
		_botao.text = "Voltar ao menu"
		_botao.grab_focus()
	else:
		Transicao.ir_para(MENU)
