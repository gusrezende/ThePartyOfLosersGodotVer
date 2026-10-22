extends CanvasLayer
## Tela que aparece quando a MissEile morre: o player escolhe 1 de 3 evoluções.
## Depois da escolha, a transição em estrela leva para a sala de evolução.

const SALA := "res://SalaEvolucao/sala_evolucao.tscn"

const COR_FUNDO := Color(0.06, 0.02, 0.03, 0.88)
const COR_CARTA := Color(0.16, 0.07, 0.06)
const COR_BORDA := Color(0.55, 0.22, 0.08)
const COR_DESTAQUE := Color(1.0, 0.55, 0.12)

const OPCOES := [
	{
		"id": "orbes",
		"nome": "Orbes de Fogo",
		"desc": "3 bolas de fogo giram em volta de você e queimam quem encostar.",
	},
	{
		"id": "rajadao",
		"nome": "Rajadão",
		"desc": "Um laser de fogo que atravessa tudo na direção do mouse.\n[Botão direito]",
	},
	{
		"id": "fogo_amigo",
		"nome": "Fogo Amigo",
		"desc": "Um mascote de fogo que corre pelo mapa caçando os inimigos.",
	},
]

var _botoes: Array[Button] = []
var _escolheu := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	centro.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "Você derrotou a MissEile!"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", COR_DESTAQUE)
	titulo.add_theme_color_override("font_outline_color", Color(0.25, 0.05, 0.0))
	titulo.add_theme_constant_override("outline_size", 6)
	coluna.add_child(titulo)

	var sub := Label.new()
	sub.text = "A inocente, delicada e charmosa MissEile... como pôde?\nEnfim! Escolha sua evolução:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.95, 0.85, 0.75))
	coluna.add_child(sub)

	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 10)
	coluna.add_child(espaco)

	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 18)
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_child(linha)

	for opcao in OPCOES:
		var b := _criar_carta(opcao)
		linha.add_child(b)
		_botoes.append(b)


func mostrar() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _botoes.size() > 0:
		_botoes[0].grab_focus()


func _escolher(id: String) -> void:
	if _escolheu:
		return
	_escolheu = true
	GameState.evolucao = id
	for b in _botoes:
		b.disabled = true
	Transicao.ir_para(SALA, 0.9)   # transição em formato de estrela


# ---------------------------------------------------------------- CARTAS

func _criar_carta(opcao: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(230, 270)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _estilo(COR_CARTA, COR_BORDA, 2))
	b.add_theme_stylebox_override("hover", _estilo(COR_CARTA.lightened(0.12), COR_DESTAQUE, 3))
	b.add_theme_stylebox_override("focus", _estilo(Color(0, 0, 0, 0), COR_DESTAQUE, 3))
	b.add_theme_stylebox_override("pressed", _estilo(COR_CARTA.lightened(0.25), Color(1, 0.9, 0.5), 3))
	b.add_theme_stylebox_override("disabled", _estilo(COR_CARTA.darkened(0.3), COR_BORDA.darkened(0.3), 2))
	b.pressed.connect(_escolher.bind(opcao["id"]))

	var conteudo := VBoxContainer.new()
	conteudo.set_anchors_preset(Control.PRESET_FULL_RECT)
	conteudo.offset_left = 12
	conteudo.offset_right = -12
	conteudo.offset_top = 12
	conteudo.offset_bottom = -12
	conteudo.add_theme_constant_override("separation", 8)
	conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(conteudo)

	var icone := IconeEvolucao.new()
	icone.tipo = opcao["id"]
	icone.custom_minimum_size = Vector2(0, 120)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.add_child(icone)

	var nome := Label.new()
	nome.text = opcao["nome"]
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 20)
	nome.add_theme_color_override("font_color", COR_DESTAQUE)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.add_child(nome)

	var desc := Label.new()
	desc.text = opcao["desc"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.92, 0.85, 0.78))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.add_child(desc)

	return b


func _estilo(fundo: Color, borda: Color, largura: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura)
	s.set_corner_radius_all(8)
	return s


## Desenho animado simples de cada evolução, feito só com formas.
class IconeEvolucao extends Control:
	var tipo := ""
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var laranja := Color(1.0, 0.45, 0.08)
		var amarelo := Color(1.0, 0.93, 0.5)
		var mago := Color(0.55, 0.45, 0.9)
		match tipo:
			"orbes":
				var tex: Texture2D = load("res://Evolucoes/assets/orbe_fogo.png")
				var alt := 48.0
				var tam := Vector2(alt * tex.get_width() / float(tex.get_height()), alt)
				var bolas := []
				for i in 3:
					var a := _t * 3.0 + TAU * i / 3.0
					bolas.append({"p": c + Vector2(cos(a), sin(a) * 0.6) * 46, "s": sin(a)})
				# as de trás primeiro, depois o mago, depois as da frente
				bolas.sort_custom(func(x, y): return x["s"] < y["s"])
				for b in bolas:
					if b["s"] >= 0.0:
						continue
					draw_texture_rect(tex, Rect2(b["p"] - tam * 0.5, tam), false)
				draw_circle(c, 14, mago)
				for b in bolas:
					if b["s"] < 0.0:
						continue
					draw_texture_rect(tex, Rect2(b["p"] - tam * 0.5, tam), false)
			"rajadao":
				var origem := c + Vector2(-80, 0)
				draw_circle(origem, 14, mago)
				var tremor := 1.0 + sin(_t * 40.0) * 0.15
				var fim := c + Vector2(90, 0)
				draw_line(origem + Vector2(12, 0), fim, Color(laranja, 0.7), 22 * tremor)
				draw_line(origem + Vector2(12, 0), fim, amarelo, 8 * tremor)
				draw_circle(fim, 12 * tremor, Color(laranja, 0.8))
			"fogo_amigo":
				var tex: Texture2D = load("res://Evolucoes/assets/fogo_amigo.png")
				var x := sin(_t * 2.0) * 45
				var pulo := absf(sin(_t * 10.0)) * 10
				var alt := 105.0
				var larg := alt * tex.get_width() / float(tex.get_height())
				var esticar := 1.0 + pulo * 0.012
				var tam := Vector2(larg / sqrt(esticar), alt * esticar)
				var pos := c + Vector2(x, alt * 0.5 - pulo) - Vector2(tam.x * 0.5, tam.y)
				var virado := cos(_t * 2.0) < 0
				if virado:
					draw_set_transform(Vector2(pos.x * 2 + tam.x, 0), 0, Vector2(-1, 1))
				draw_texture_rect(tex, Rect2(pos, tam), false)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
