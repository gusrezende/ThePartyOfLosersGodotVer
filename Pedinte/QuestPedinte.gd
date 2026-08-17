extends Area3D

@export var tecla_interacao := KEY_E

var jogador_perto := false
var conversa_iniciada := false
var missao_aceita := false
var npc_finalizado := false

@onready var dialogo = $"../Dialogo"


func _ready():

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	dialogo.text = ""


func _process(_delta):

	if jogador_perto and not npc_finalizado:

		if Input.is_key_pressed(tecla_interacao):

			interagir()

			# Evita ativar várias vezes enquanto segura E
			await get_tree().create_timer(0.3).timeout


func _on_body_entered(body):

	if body.is_in_group("player"):

		jogador_perto = true

		if not npc_finalizado:

			mostrar_mensagem("Pressione E para falar")


func _on_body_exited(body):

	if body.is_in_group("player"):

		jogador_perto = false

		if not npc_finalizado:

			dialogo.text = ""


func interagir():

	# ==========================================
	# PRIMEIRA CONVERSA
	# ==========================================

	if not missao_aceita:

		missao_aceita = true

		QuestManager.iniciar_missao()

		mostrar_mensagem(
			"Ei! Você consegue me ajudar a encontrar 5 folhas de papel?"
		)

		return


	# ==========================================
	# MISSÃO AINDA NÃO TERMINOU
	# ==========================================

	if not QuestManager.missao_esta_pronta():

		var quantidade = QuestManager.papeis_coletados

		mostrar_mensagem(
			"Você já encontrou " +
			str(quantidade) +
			" de 5 folhas."
		)

		return


	# ==========================================
	# MISSÃO TERMINADA
	# ==========================================

	mostrar_mensagem("Ah! Obrigado!")

	await get_tree().create_timer(2.0).timeout

	npc_finalizado = true

	dialogo.text = ""

	# Faz o NPC desaparecer
	get_parent().queue_free()


func mostrar_mensagem(texto: String):

	dialogo.text = texto
