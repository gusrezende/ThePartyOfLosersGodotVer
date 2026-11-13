extends CanvasLayer
## TELA DE MORTE do mago: animação em 3 quadros quando o player morre.
##
##   1) o mago de olhos fechados, na luz (zoom lento)
##   2) CORTE: a caveira aparece (tremida + clarão), a luz fecha
##   3) "IT'S OVER"
##   depois a fase recomeça e a tela preta some.
##
## Qualquer tecla / clique / botão do controle pula para o fim.
##
## Uso (no player, quando a vida chega a 0):
##     const TelaMorte = preload("res://UI/TelaMorte/tela_morte.gd")
##     TelaMorte.mostrar(get_tree())

const QUADRO_1 := preload("res://UI/TelaMorte/morte_1.png")
const QUADRO_2 := preload("res://UI/TelaMorte/morte_2.png")
const QUADRO_3 := preload("res://UI/TelaMorte/morte_3.png")
const Sons = preload("res://Músicas/sons.gd")

## Quanto tempo cada quadro fica na tela (segundos)
const TEMPO_1 := 1.6
const TEMPO_2 := 1.5
const TEMPO_3 := 2.0

var _fundo: ColorRect
var _imagem: TextureRect
var _clarao: ColorRect
var _pular := false
var _pode_pular := false
var _pulso := 0.0


## Começa a animação de morte (não faz nada se já estiver rodando)
static func mostrar(arvore: SceneTree) -> void:
	if arvore.root.get_node_or_null("TelaMorte"):
		return
	var tela = load("res://UI/TelaMorte/tela_morte.gd").new()
	tela.name = "TelaMorte"
	arvore.root.add_child(tela)   # fica na raiz: continua viva quando a fase recarrega


func _ready() -> void:
	layer = 95                    # por cima do jogo e do HUD, embaixo da transição
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	_fundo = ColorRect.new()
	_fundo.color = Color.BLACK
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fundo)

	_imagem = TextureRect.new()
	_imagem.set_anchors_preset(Control.PRESET_FULL_RECT)
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_imagem)

	_clarao = ColorRect.new()
	_clarao.color = Color(1, 1, 1, 0)
	_clarao.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clarao)

	_animar()


func _input(event: InputEvent) -> void:
	if not _pode_pular:
		return
	var apertou: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if apertou:
		_pular = true
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# a imagem fica sempre centralizada, mesmo com zoom
	if _imagem:
		_imagem.pivot_offset = _imagem.size * 0.5


func _mostrar_mira(sim: bool) -> void:
	var mira := get_node_or_null("/root/Mira") as CanvasLayer
	if mira:
		mira.visible = sim


func _exit_tree() -> void:
	_mostrar_mira(true)


func _animar() -> void:
	_mostrar_mira(false)   # esconde a mira durante a animação
	# a música para na hora
	var musica := get_node_or_null("/root/Musica")
	if musica and musica.has_method("parar_agora"):
		musica.parar_agora()

	# ---- escurece o jogo
	_fundo.modulate.a = 0.0
	_imagem.modulate.a = 0.0
	await _tween(_fundo, "modulate:a", 1.0, 0.35)

	# ---- QUADRO 1: mago de olhos fechados, zoom bem devagar
	_imagem.texture = QUADRO_1
	_imagem.scale = Vector2.ONE
	_tween(_imagem, "modulate:a", 1.0, 0.4)
	var zoom := _criar_tween()
	zoom.tween_property(_imagem, "scale", Vector2.ONE * 1.06, TEMPO_1 + 0.3)
	get_tree().create_timer(0.4, true, false, true).timeout.connect(func(): _pode_pular = true)
	await _esperar(TEMPO_1)

	# ---- QUADRO 2: CORTE seco para a caveira, com clarão e tremida
	if not _pular:
		zoom.kill()
		_imagem.texture = QUADRO_2
		_imagem.modulate.a = 1.0
		_imagem.scale = Vector2.ONE * 1.12
		_clarao.color.a = 0.85
		_tween(_clarao, "color:a", 0.0, 0.25)
		var som := Sons.tocar(self, Sons.HIT, 4.0)
		if som:
			som.pitch_scale = 0.45   # pancada grave
			som.process_mode = Node.PROCESS_MODE_ALWAYS
		_tween(_imagem, "scale", Vector2.ONE, 0.35, Tween.TRANS_BACK)
		await _tremer(0.45, 14.0)
		await _esperar(TEMPO_2 - 0.45)

	# ---- QUADRO 3: "IT'S OVER"
	_imagem.position = Vector2.ZERO
	_imagem.modulate.a = 0.0
	_imagem.texture = QUADRO_3
	_imagem.scale = Vector2.ONE * 0.92
	_tween(_imagem, "scale", Vector2.ONE, 0.5, Tween.TRANS_BACK)
	await _tween(_imagem, "modulate:a", 1.0, 0.25)
	if not _pular:
		await _esperar(TEMPO_3)
	else:
		await _esperar_real(0.6)

	# ---- recomeça a fase por baixo da tela preta
	_pode_pular = false
	await _tween(_imagem, "modulate:a", 0.0, 0.3)
	get_tree().paused = false
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame
	Sons.retomar_musica(self)
	await _tween(_fundo, "modulate:a", 0.0, 0.5)
	queue_free()


# ---------------------------------------------------------------- ajudantes

func _criar_tween() -> Tween:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)   # roda com o jogo pausado
	return tw


func _tween(no: Object, propriedade: String, valor, tempo: float, trans := Tween.TRANS_QUAD) -> Signal:
	var tw := _criar_tween()
	tw.set_trans(trans).set_ease(Tween.EASE_OUT)
	tw.tween_property(no, propriedade, valor, tempo)
	return tw.finished


## Espera "tempo" segundos, mas sai antes se o jogador pular
func _esperar(tempo: float) -> void:
	var t := 0.0
	while t < tempo and not _pular:
		await get_tree().process_frame
		t += get_process_delta_time()


func _esperar_real(tempo: float) -> void:
	await get_tree().create_timer(tempo, true, false, true).timeout


func _tremer(duracao: float, forca: float) -> void:
	var t := 0.0
	while t < duracao and not _pular:
		var k := 1.0 - t / duracao
		_imagem.position = Vector2(randf_range(-forca, forca), randf_range(-forca, forca)) * k
		await get_tree().process_frame
		t += get_process_delta_time()
	_imagem.position = Vector2.ZERO
