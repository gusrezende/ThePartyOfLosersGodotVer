extends CanvasLayer
## HUD da missão do Pedinte: no canto inferior direito da tela, o cogumelo vai se
## montando a cada pedaço coletado. No último pedaço, ele faz um "efeito borracha"
## (encolhe e estica) e solta brilhinhos.
##
## Quem controla este HUD é o QuestManager (autoload). Não precisa colocar em cena nenhuma.

const TOTAL := 5

## Largura do cogumelo na tela (a tela do jogo tem 854 x 480)
const LARGURA := 150.0
## Distância da borda da tela
const MARGEM := Vector2(28, 18)

var _texturas: Array[Texture2D] = []
var _imagem: TextureRect
var _brilhos: CPUParticles2D
var _brilhos_lentos: CPUParticles2D
var _tw: Tween
var _quantidade := 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	# as imagens ficam na MESMA pasta deste script (seja qual for)
	var pasta: String = get_script().resource_path.get_base_dir()
	for i in range(1, TOTAL + 1):
		var caminho := pasta.path_join("cogumelo_morto_%d.png" % i)
		var tex: Texture2D = null
		if ResourceLoader.exists(caminho):
			tex = load(caminho)
		if tex == null:
			push_error("HUD do cogumelo: não achei a imagem '%s'. Coloque as 5 imagens cogumelo_morto_1..5.png na mesma pasta do hud_cogumelo.gd." % caminho)
			set_process(false)
			return
		_texturas.append(tex)

	var proporcao := float(_texturas[0].get_height()) / float(_texturas[0].get_width())
	var tamanho := Vector2(LARGURA, LARGURA * proporcao)

	_imagem = TextureRect.new()
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# preso no canto inferior direito
	_imagem.anchor_left = 1.0
	_imagem.anchor_right = 1.0
	_imagem.anchor_top = 1.0
	_imagem.anchor_bottom = 1.0
	_imagem.offset_left = -tamanho.x - MARGEM.x
	_imagem.offset_right = -MARGEM.x
	_imagem.offset_top = -tamanho.y - MARGEM.y
	_imagem.offset_bottom = -MARGEM.y
	_imagem.pivot_offset = tamanho * 0.5   # anima a partir do centro
	_imagem.visible = false
	add_child(_imagem)

	_brilhos = _criar_brilhos(true)
	_brilhos.position = tamanho * 0.5
	_imagem.add_child(_brilhos)

	_brilhos_lentos = _criar_brilhos(false)
	_brilhos_lentos.position = tamanho * 0.5
	_imagem.add_child(_brilhos_lentos)


## Mostra o cogumelo com "quantidade" pedaços (0 = esconde).
func mostrar_progresso(quantidade: int) -> void:
	if _imagem == null:
		return   # imagens não foram encontradas (veja o erro no Output)
	quantidade = clampi(quantidade, 0, TOTAL)
	var subiu := quantidade > _quantidade
	_quantidade = quantidade

	if quantidade == 0:
		_imagem.visible = false
		return

	_imagem.texture = _texturas[quantidade - 1]
	_imagem.modulate = Color.WHITE
	_imagem.visible = true

	if not subiu:
		return
	if quantidade >= TOTAL:
		_efeito_completo()
	else:
		_efeito_pedaco()


## Some suavemente (chamado quando o player entrega os pedaços ao Pedinte).
func esconder() -> void:
	if _imagem == null or not _imagem.visible:
		return
	_parar_tween()
	_brilhos_lentos.emitting = false
	_tw = create_tween()
	_tw.tween_property(_imagem, "modulate:a", 0.0, 0.6)
	_tw.tween_callback(func(): _imagem.visible = false)


# ---------------------------------------------------------------- EFEITOS

## Pedaço novo: um "pulinho"
func _efeito_pedaco() -> void:
	_parar_tween()
	_imagem.scale = Vector2(1.25, 1.25)
	_tw = create_tween()
	_tw.tween_property(_imagem, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Cogumelo completo: encolhe, estica como borracha e solta brilhinhos
func _efeito_completo() -> void:
	_parar_tween()
	_imagem.scale = Vector2.ONE
	_tw = create_tween()
	# encolhe (achatando um pouco, como borracha sendo apertada)
	_tw.tween_property(_imagem, "scale", Vector2(0.55, 0.45), 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# solta os brilhinhos no momento em que "estoura"
	_tw.tween_callback(func():
		_brilhos.restart()
		_brilhos.emitting = true
		_brilhos_lentos.emitting = true)
	# estica bem além do normal, como borracha soltando...
	_tw.tween_property(_imagem, "scale", Vector2(1.3, 1.2), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# ...e volta pro tamanho normal balançando (efeito elástico)
	_tw.tween_property(_imagem, "scale", Vector2.ONE, 0.8) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _parar_tween() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()


## Partículas de brilho em forma de estrelinha.
## estouro = true: uma explosão de brilhos de uma vez. false: brilhos fracos contínuos.
func _criar_brilhos(estouro: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _textura_estrela()
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = LARGURA * 0.3
	p.direction = Vector2.UP
	p.gravity = Vector2(0, 40)
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0

	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.2))
	curva.add_point(Vector2(0.25, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curva

	var cores := Gradient.new()
	cores.set_color(0, Color(1.0, 1.0, 0.85, 1.0))
	cores.set_color(1, Color(1.0, 0.85, 0.3, 0.0))
	p.color_ramp = cores

	if estouro:
		p.amount = 40
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 1.0
		p.spread = 180.0
		p.initial_velocity_min = 70.0
		p.initial_velocity_max = 190.0
		p.scale_amount_min = 0.8
		p.scale_amount_max = 1.6
	else:
		p.amount = 8
		p.lifetime = 1.2
		p.spread = 180.0
		p.initial_velocity_min = 5.0
		p.initial_velocity_max = 20.0
		p.gravity = Vector2(0, -15)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 0.9
	return p


## Desenha uma estrelinha de 4 pontas (branca, as partículas dão a cor)
static func _textura_estrela() -> Texture2D:
	var tam := 32
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var c := (tam - 1) * 0.5
	for y in tam:
		for x in tam:
			var dx := absf(x - c) / c
			var dy := absf(y - c) / c
			# losango fino nos eixos + brilho redondo no meio
			var raio := 0.12 / maxf(dx * dy * 6.0 + 0.12, 0.0001)
			var dist := sqrt(dx * dx + dy * dy)
			var a := clampf(raio - dist, 0.0, 1.0)
			a = maxf(a, clampf(1.0 - dist * 3.0, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
