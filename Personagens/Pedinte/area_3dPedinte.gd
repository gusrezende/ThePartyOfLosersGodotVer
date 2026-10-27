extends Area3D

@export var tecla_interacao := KEY_E

var jogador_perto := false
var missao_aceita := false
var npc_finalizado := false
var pode_interagir := true

var dialogo: Label3D


func _ready():

	monitoring = true

	# Procura o Dialogo em qualquer lugar
	# dentro do Pedinte.
	dialogo = get_parent().find_child("Dialogo", true, false) as Label3D

	# Conecta os sinais
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	# Começa sem diálogo
	if dialogo != null:
		dialogo.text = ""
		dialogo.visible = false
	else:
		print("ERRO: Não encontrei um Label3D chamado 'Dialogo' dentro do Pedinte.")


func _input(event):

	if npc_finalizado:
		return

	if not jogador_perto:
		return

	if not pode_interagir:
		return

	# Verifica se E foi pressionado
	if event is InputEventKey:

		if event.keycode == tecla_interacao:
			
			if event.pressed and not event.echo:

				pode_interagir = false

				print("E APERTADO PERTO DO NPC!")

				interagir()

				await get_tree().create_timer(0.4).timeout

				pode_interagir = true


func _on_body_entered(body):

	if body.is_in_group("player") or body is CharacterBody3D:

		jogador_perto = true

		print("PLAYER ENTROU NA ÁREA DO NPC")


func _on_body_exited(body):

	if body.is_in_group("player") or body is CharacterBody3D:

		jogador_perto = false

		print("PLAYER SAIU DA ÁREA DO NPC")


func interagir():

	print("INTERAGINDO COM O NPC!")


	# ==========================================
	# PRIMEIRA INTERAÇÃO
	# ==========================================

	if not missao_aceita:

		missao_aceita = true

		QuestManager.iniciar_missao()

		mostrar_mensagem(
			"Planta... PLATA! ME DÊ 5 PLANTAS!"
		)

		return


	# ==========================================
	# MISSÃO AINDA NÃO TERMINOU
	# ==========================================

	if not QuestManager.missao_esta_pronta():

		var quantidade = QuestManager.papeis_coletados

		mostrar_mensagem(
			"Você já encontrou "
			+ str(quantidade)
			+ " de 5 folhas."
		)

		return


	# ==========================================
	# MISSÃO TERMINADA
	# ==========================================

	mostrar_mensagem("Ah! Obrigado!")

	npc_finalizado = true

	# entregou os pedaços: o cogumelo some do canto da tela
	QuestManager.esconder_hud()

	await get_tree().create_timer(1.5).timeout

	limpar_dialogo()

	# Em vez de sumir, o Pedinte se transforma e vira inimigo
	var npc := _achar_npc_transformavel()
	if npc:
		npc.transformar()
	else:
		push_error("PEDINTE: não achei o script pedinte_npc.gd! Coloque ele no nó raiz 'Pedinte' (o CharacterBody3D) e confira se o arquivo tem 'func transformar'.")


func mostrar_mensagem(texto: String):

	if dialogo == null:

		print("ERRO: O Dialogo não foi encontrado!")

		return

	dialogo.text = texto
	dialogo.visible = true

	print("NPC DISSE: ", texto)


func limpar_dialogo():

	if dialogo != null:

		dialogo.text = ""
		dialogo.visible = false


## Procura o nó do Pedinte que tem o script pedinte_npc.gd
## (normalmente é o pai deste Area3D, mas procura também acima e nos irmãos).
func _achar_npc_transformavel() -> Node:
	var no: Node = get_parent()
	while no != null and no != get_tree().root:
		if no.has_method("transformar"):
			return no
		no = no.get_parent()
	for irmao in get_parent().find_children("*", "", true, false):
		if irmao.has_method("transformar"):
			return irmao
	return null
