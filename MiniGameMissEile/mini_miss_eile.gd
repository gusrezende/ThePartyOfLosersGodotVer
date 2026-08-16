extends TextureButton

@export var vida_maxima := 20
@export var velocidade_inicial := 450.0
@export var velocidade_maxima := 1000.0
@export var tempo_maximo := 30.0

var vida: int
var velocidade: float
var destino: Vector2

var tempo_restante: float

var combo := 0
var fase_final := false
var jogo_terminado := false

var tempo_ataque := 0.0
var intervalo_ataque := 1.5


func _ready():
	randomize()

	vida = vida_maxima
	velocidade = velocidade_inicial
	tempo_restante = tempo_maximo

	escolher_novo_destino()
	atualizar_interface()


func _process(delta):

	if jogo_terminado:
		return

	# TIMER
	tempo_restante -= delta

	if tempo_restante <= 0:
		tempo_restante = 0
		perder()
		return

	# MOVIMENTO
	position = position.move_toward(
		destino,
		velocidade * delta
	)

	if position.distance_to(destino) < 10:
		escolher_novo_destino()

	# VELOCIDADE
	var progresso = 1.0 - float(vida) / float(vida_maxima)

	velocidade = lerp(
		velocidade_inicial,
		velocidade_maxima,
		progresso
	)

	# ATAQUE
	tempo_ataque += delta

	if tempo_ataque >= intervalo_ataque:
		tempo_ataque = 0.0
		atacar()

	# INTERFACE
	atualizar_interface()


func escolher_novo_destino():

	var tamanho_tela = get_viewport_rect().size

	var margem_x := 120.0
	var margem_y := 150.0

	destino = Vector2(
		randf_range(
			margem_x,
			tamanho_tela.x - margem_x
		),
		randf_range(
			margem_y,
			tamanho_tela.y - margem_y
		)
	)


func _pressed():

	if jogo_terminado:
		return

	vida -= 1
	combo += 1

	efeito_acerto()
	atualizar_interface()

	if vida <= vida_maxima * 0.25 and not fase_final:
		iniciar_fase_final()

	if vida <= 0:
		vencer()


func efeito_acerto():

	var tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		self,
		"scale",
		Vector2(1.35, 1.35),
		0.06
	)

	tween.tween_property(
		self,
		"modulate",
		Color(1.5, 1.5, 1.5),
		0.06
	)

	tween.chain().tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.1
	)

	tween.chain().tween_property(
		self,
		"modulate",
		Color.WHITE,
		0.1
	)


func atacar():

	if fase_final:
		intervalo_ataque = 0.45
	else:
		intervalo_ataque = 1.5

	print("MISS EILE ATACOU!")


func iniciar_fase_final():

	fase_final = true

	var status = get_node_or_null("../Status")

	if status:
		status.text = "CHEGA DE BRINCADEIRA!"


func vencer():

	jogo_terminado = true

	var status = get_node_or_null("../Status")

	if status:
		status.text = "VOCÊ PEGOU A MISSEILE!"

	destino = position

	var tween = create_tween()

	tween.tween_property(
		self,
		"scale",
		Vector2(1.5, 1.5),
		0.2
	)

	tween.tween_property(
		self,
		"modulate",
		Color(1, 1, 1, 0),
		0.5
	)


func perder():

	jogo_terminado = true

	var status = get_node_or_null("../Status")

	if status:
		status.text = "TEMPO ESGOTADO!"

	var timer_label = get_node_or_null("../Timer")

	if timer_label:
		timer_label.text = "TIME: 0"


func atualizar_interface():

	var vida_barra = get_node_or_null("../Vida")
	var combo_label = get_node_or_null("../Combo")
	var timer_label = get_node_or_null("../Timer")

	if vida_barra != null:
		vida_barra.min_value = 0
		vida_barra.max_value = vida_maxima
		vida_barra.value = vida

	if combo_label != null:
		combo_label.text = "COMBO x" + str(combo)

	if timer_label != null:
		timer_label.text = "TIME: " + str(ceil(tempo_restante))
