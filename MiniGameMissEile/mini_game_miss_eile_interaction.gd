extends Area3D

@export var tecla_interacao := KEY_E
@export var cena_minigame: PackedScene

@onready var dialogo: CanvasLayer = $CanvasLayer
@onready var sim_button: Button = $CanvasLayer/PanelContainer/VBoxContainer/SimButton
@onready var nao_button: Button = $CanvasLayer/PanelContainer/VBoxContainer/NaoButton

var jogador_perto := false


func _ready():

	dialogo.visible = false
	dialogo.process_mode = Node.PROCESS_MODE_ALWAYS  # funciona com o jogo pausado

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sim_button.pressed.connect(_on_sim_pressed)
	nao_button.pressed.connect(_fechar_dialogo)


func _unhandled_input(event):

	# Só reage ao momento em que a tecla é apertada (não ao segurar)
	if jogador_perto and not dialogo.visible:

		if event is InputEventKey and event.pressed and not event.echo and event.keycode == tecla_interacao:

			abrir_dialogo()


func _on_body_entered(body):

	if body.is_in_group("player"):

		jogador_perto = true

		print("Pressione E para interagir com MissEile")


func _on_body_exited(body):

	if body.is_in_group("player"):

		jogador_perto = false


func abrir_dialogo():

	dialogo.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	nao_button.grab_focus()  # foco começa no "Não" para não aceitar sem querer


func _fechar_dialogo():

	dialogo.visible = false
	get_tree().paused = false
	# Se o seu jogo prende o mouse, descomente:
	# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_sim_pressed():

	# GameState.pulou_boss = true  # descomente se criar o Autoload
	dialogo.visible = false  # esconde o diálogo antes do fade
	abrir_minigame()


func abrir_minigame():

	jogador_perto = false

	if cena_minigame:

		# A Transicao já despausa o jogo antes de trocar a cena
		Transicao.ir_para(cena_minigame)

	else:

		print("ERRO: Cena do minigame não foi configurada!")
		_fechar_dialogo()  # evita o jogo ficar pausado se a cena não estiver configurada
