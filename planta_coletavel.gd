extends Area3D

var jogador_perto := false
var coletado := false


func _ready():

	monitoring = true

	if body_entered.is_connected(_on_body_entered) == false:
		body_entered.connect(_on_body_entered)

	if body_exited.is_connected(_on_body_exited) == false:
		body_exited.connect(_on_body_exited)


func _process(_delta):

	if coletado:
		return

	# Se o jogador estiver perto e apertar E,
	# também pode pegar o papel.
	if jogador_perto:

		if Input.is_key_pressed(KEY_E):

			coletar()

			await get_tree().create_timer(0.4).timeout


func _on_body_entered(body):

	if not body is CharacterBody3D:
		return

	jogador_perto = true

	# O papel é coletado automaticamente
	# quando o jogador encosta nele.
	coletar()


func _on_body_exited(body):

	if body is CharacterBody3D:

		jogador_perto = false


func coletar():

	if coletado:
		return

	# A missão precisa estar ativa.
	if not QuestManager.missao_ativa:
		return

	# Não pode coletar depois de completar.
	if QuestManager.missao_concluida:
		return

	coletado = true

	# Adiciona 1 papel à missão.
	QuestManager.coletar_papel()

	print(
		"PAPEL COLETADO! ",
		QuestManager.papeis_coletados,
		"/",
		QuestManager.total_papeis
	)

	# Remove o papel do mapa.
	queue_free()
