extends Area3D

## Tela de diálogo (zoom + caixa com opções à direita)
const CaixaDialogo = preload("res://UI/Dialogo/caixa_dialogo.gd")

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

	if CaixaDialogo.tem_conversa_aberta(get_tree()):
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

	if body.is_in_group("player"):

		jogador_perto = true

		if not npc_finalizado:
			mostrar_mensagem("[E] Falar")


func _on_body_exited(body):

	if body.is_in_group("player"):

		jogador_perto = false

		limpar_dialogo()


# ==========================================================
# CONVERSA (abre a tela de diálogo: personagens à esquerda,
# caixa com as opções à direita)
#
#   await conversa.falar("texto")               -> só uma fala
#   var n = await conversa.perguntar("texto", ["opção 1", "opção 2"])
#                                               -> n = 0, 1, 2... (opção escolhida)
#   await conversa.fechar()                     -> termina a conversa
# ==========================================================

func interagir():

	if CaixaDialogo.tem_conversa_aberta(get_tree()):
		return

	limpar_dialogo()

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var npc := _achar_npc_transformavel() as Node3D
	if npc == null:
		npc = get_parent() as Node3D

	var conversa = CaixaDialogo.abrir(self, "Pedinte", player, npc)


	# ------------------------------------------
	# PRIMEIRA CONVERSA: pede as plantas
	# ------------------------------------------

	if not missao_aceita:

		await conversa.falar("Planta... PLATA! ME DÊ 5 PLANTAS!")

		var escolha: int = await conversa.perguntar(
			"Você vai me trazer as plantas ou não vai?",
			["Tá bom, eu procuro as 5 plantas.", "Pra que você quer plantas?", "Agora não."]
		)

		if escolha == 1:
			await conversa.falar("Pra... pra minha vovozinha doente! É... isso. Vovozinha.")
			var de_novo: int = await conversa.perguntar(
				"E aí? Vai ajudar ou não?",
				["Tá bom, eu procuro.", "Agora não."]
			)
			escolha = 0 if de_novo == 0 else 2

		if escolha == 0:
			missao_aceita = true
			QuestManager.iniciar_missao()
			await conversa.falar("Hehehe... Elas estão espalhadas pela caverna. Vai logo!")
		else:
			await conversa.falar("Hmpf. Volte quando parar de enrolar.")

		await conversa.fechar()
		_mostrar_dica_se_perto()
		return


	# ------------------------------------------
	# MISSÃO AINDA NÃO TERMINOU
	# ------------------------------------------

	if not QuestManager.missao_esta_pronta():

		var quantidade = QuestManager.papeis_coletados

		var escolha: int = await conversa.perguntar(
			"Você só achou " + str(quantidade) + " de 5 plantas. Cadê o resto?!",
			["Onde eu acho as plantas?", "Já vou procurar."]
		)

		if escolha == 0:
			await conversa.falar("Por aí! Nos cantos da caverna... Procure direito!")

		await conversa.fechar()
		_mostrar_dica_se_perto()
		return


	# ------------------------------------------
	# MISSÃO TERMINADA: entregar ou não
	# ------------------------------------------

	var escolha: int = await conversa.perguntar(
		"Você... você trouxe as 5 plantas?!",
		["Aqui estão.", "Ainda não vou entregar."]
	)

	if escolha == 1:
		await conversa.falar("GRRR... Tudo bem. Eu espero. Por enquanto.")
		await conversa.fechar()
		_mostrar_dica_se_perto()
		return

	await conversa.falar("Ah! Obrigado!")
	await conversa.falar("Hehehe... hehehehe...")

	npc_finalizado = true

	# entregou os pedaços: o cogumelo some do canto da tela
	QuestManager.esconder_hud()

	await conversa.fechar()

	# Em vez de sumir, o Pedinte se transforma e vira inimigo
	if npc and npc.has_method("transformar"):
		npc.transformar()
	else:
		push_error("PEDINTE: não achei o script pedinte_npc.gd! Coloque ele no nó raiz 'Pedinte' (o CharacterBody3D) e confira se o arquivo tem 'func transformar'.")


func _mostrar_dica_se_perto():
	if jogador_perto and not npc_finalizado:
		mostrar_mensagem("[E] Falar")


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
