extends Node

const HUD_COGUMELO = preload("res:///Personagens/Pedinte/UI/QuestCogumelo/hud_cogumelo.gd")
	
var missao_ativa := false
var papeis_coletados := 0
var total_papeis := 5
var missao_concluida := false

## HUD do cogumelo que vai se montando (canto inferior direito)
var hud_cogumelo: CanvasLayer


func _ready():

	hud_cogumelo = HUD_COGUMELO.new()
	add_child(hud_cogumelo)


func iniciar_missao():

	missao_ativa = true
	papeis_coletados = 0
	missao_concluida = false

	hud_cogumelo.mostrar_progresso(0)

	print("================================")
	print("MISSÃO INICIADA!")
	print("Encontre 5 folhas de papel.")
	print("================================")


func coletar_papel():

	if not missao_ativa:
		return

	if missao_concluida:
		return

	papeis_coletados += 1

	hud_cogumelo.mostrar_progresso(min(papeis_coletados, total_papeis))

	print(
		"Papel coletado: ",
		papeis_coletados,
		"/",
		total_papeis
	)

	if papeis_coletados >= total_papeis:

		papeis_coletados = total_papeis
		missao_concluida = true

		print("================================")
		print("TODOS OS PAPEIS FORAM COLETADOS!")
		print("================================")


func missao_esta_pronta() -> bool:

	return missao_concluida


## Esconde o cogumelo do canto da tela (quando os pedaços são entregues)
func esconder_hud():

	hud_cogumelo.esconder()
