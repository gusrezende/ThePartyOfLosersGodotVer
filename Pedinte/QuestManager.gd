extends Node

var missao_ativa := false
var papeis_coletados := 0
var total_papeis := 5
var missao_concluida := false


func iniciar_missao():

	missao_ativa = true
	papeis_coletados = 0
	missao_concluida = false

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
