extends Node

## O HUD do cogumelo (hud_cogumelo.gd) é procurado sozinho no projeto,
## então pode ficar em qualquer pasta.
const NOME_HUD := "hud_cogumelo.gd"

var missao_ativa := false
var papeis_coletados := 0
var total_papeis := 5
var missao_concluida := false

## HUD do cogumelo que vai se montando (canto inferior direito)
var hud_cogumelo: CanvasLayer


func _ready():

	var caminho := _procurar_arquivo("res://", NOME_HUD)
	if caminho == "":
		push_error("QuestManager: não achei o arquivo '%s' em nenhuma pasta do projeto." % NOME_HUD)
		hud_cogumelo = CanvasLayer.new()   # HUD vazio, só para o jogo não travar
	else:
		hud_cogumelo = load(caminho).new()
	add_child(hud_cogumelo)


## Procura um arquivo pelo nome em todas as pastas do projeto.
func _procurar_arquivo(pasta: String, nome: String) -> String:
	var dir := DirAccess.open(pasta)
	if dir == null:
		return ""
	for arquivo in dir.get_files():
		# no jogo exportado o arquivo pode aparecer como .remap
		if arquivo == nome or arquivo == nome + ".remap" or arquivo == nome.get_basename() + ".gdc":
			return pasta.path_join(nome)
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue   # pula .godot, .git...
		var achou := _procurar_arquivo(pasta.path_join(sub), nome)
		if achou != "":
			return achou
	return ""


func iniciar_missao():

	missao_ativa = true
	papeis_coletados = 0
	missao_concluida = false

	_hud("mostrar_progresso", 0)

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

	_hud("mostrar_progresso", min(papeis_coletados, total_papeis))

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


## Volta a missão do zero (chamado quando o player morre).
## O Pedinte volta a pedir as plantas e o cogumelo some do canto da tela.
func resetar_missao():

	missao_ativa = false
	papeis_coletados = 0
	missao_concluida = false

	_hud("mostrar_progresso", 0)

	print("MISSÃO REINICIADA (o player morreu)")


## Esconde o cogumelo do canto da tela (quando os pedaços são entregues)
func esconder_hud():

	_hud("esconder")


## Chama uma função do HUD só se ele existir
func _hud(funcao: String, valor = null) -> void:
	if hud_cogumelo and hud_cogumelo.has_method(funcao):
		if valor == null:
			hud_cogumelo.call(funcao)
		else:
			hud_cogumelo.call(funcao, valor)
