extends CanvasLayer
## BARRA DE VIDA DA CHEFE, no topo da tela.
##
## - Parte vermelha: a vida atual. Parte clara atrás: o dano que acabou de levar,
##   que vai "escorrendo" até alcançar a vermelha.
## - Treme e pisca quando ela leva dano.
## - Fica apagada (cinza) quando ela está invulnerável, para o player saber
##   que naquele momento não adianta atirar.
##
## A MissEile cria e controla a barra sozinha (miss_eile.gd). Não precisa colocar na cena.

const LARGURA := 420.0
const ALTURA := 14.0

const COR_VIDA := Color(0.9, 0.18, 0.25)
const COR_DANO := Color(1.0, 0.92, 0.7)
const COR_FUNDO := Color(0.08, 0.03, 0.14, 0.9)
const COR_BORDA := Color(1.0, 0.82, 0.35)

var _max := 100.0
var _vida := 100.0
var _vida_lenta := 100.0     # a parte clara, que escorre atrás
var _espera_escorrer := 0.0
var _tremor := 0.0
var _vulneravel := true

var _raiz: Control
var _fundo: Panel
var _barra_dano: ColorRect
var _barra_vida: ColorRect
var _brilho: ColorRect
var _nome: Label
var _pos_base := Vector2.ZERO
var _nome_texto := ""


func _ready() -> void:
	layer = 15
	_raiz = Control.new()
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)

	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 16)
	_nome.add_theme_color_override("font_color", COR_BORDA)
	_nome.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.18))
	_nome.add_theme_constant_override("outline_size", 6)
	_nome.text = _nome_texto
	_raiz.add_child(_nome)

	_fundo = Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = COR_BORDA
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(4)
	estilo.shadow_color = Color(0, 0, 0, 0.5)
	estilo.shadow_size = 3
	_fundo.add_theme_stylebox_override("panel", estilo)
	_fundo.size = Vector2(LARGURA + 6, ALTURA + 6)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_fundo)

	_barra_dano = ColorRect.new()
	_barra_dano.color = COR_DANO
	_barra_vida = ColorRect.new()
	_barra_vida.color = COR_VIDA
	_brilho = ColorRect.new()   # faixa clara em cima da vida, dá volume
	_brilho.color = Color(1, 1, 1, 0.22)
	for r in [_barra_dano, _barra_vida, _brilho]:
		r.position = Vector2(3, 3)
		r.size = Vector2(LARGURA, ALTURA)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fundo.add_child(r)
	_brilho.size.y = ALTURA * 0.35

	_posicionar()
	_raiz.modulate.a = 0.0
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.6)


func configurar(nome: String, vida_max: float) -> void:
	_nome_texto = nome
	if _nome:
		_nome.text = nome
	_max = maxf(vida_max, 1.0)
	_vida = _max
	_vida_lenta = _max
	if _barra_vida:
		_atualizar_tamanhos()


## Chame sempre que a vida mudar
func atualizar(vida: float) -> void:
	if _barra_vida == null:
		return
	vida = clampf(vida, 0.0, _max)
	if vida < _vida:
		_tremor = 0.25
		_espera_escorrer = 0.35   # a parte clara espera um pouco antes de escorrer
		_barra_vida.color = Color.WHITE
		create_tween().tween_property(_barra_vida, "color", COR_VIDA, 0.15)
	_vida = vida
	_atualizar_tamanhos()


## true = dá para machucar; false = barra apagada
func vulneravel(sim: bool) -> void:
	if sim == _vulneravel or _fundo == null:
		return
	_vulneravel = sim
	var alvo := Color.WHITE if sim else Color(0.55, 0.55, 0.6)
	create_tween().tween_property(_fundo, "modulate", alvo, 0.25)


func sumir() -> void:
	var tw := create_tween()
	tw.tween_property(_raiz, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_posicionar()
	if _espera_escorrer > 0.0:
		_espera_escorrer -= delta
	elif _vida_lenta > _vida:
		_vida_lenta = maxf(_vida, _vida_lenta - _max * 0.6 * delta)
	_atualizar_tamanhos()
	if _tremor > 0.0:
		_tremor -= delta
		_fundo.position = _pos_base + Vector2(randf_range(-3, 3), randf_range(-2, 2)) * (_tremor / 0.25)
	else:
		_fundo.position = _pos_base


func _posicionar() -> void:
	var tela := get_viewport().get_visible_rect().size
	_pos_base = Vector2((tela.x - _fundo.size.x) * 0.5, 30.0)
	_nome.position = Vector2(_pos_base.x + 2, _pos_base.y - 22)


func _atualizar_tamanhos() -> void:
	_barra_vida.size.x = LARGURA * (_vida / _max)
	_brilho.size.x = _barra_vida.size.x
	_barra_dano.size.x = LARGURA * (_vida_lenta / _max)
