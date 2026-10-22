extends Node3D
## Evolução 2: Rajadão — um laser de fogo na direção do mouse.
## Botão DIREITO do mouse (ou tecla E) dispara. Tem recarga.

const UTIL = preload("res://Evolucoes/util_fogo.gd")

const DURACAO = 1.2         # quanto tempo o laser fica ligado
const RECARGA = 2.5         # tempo até poder usar de novo (conta depois que o laser apaga)
const ALCANCE = 11.0        # comprimento do laser
const LARGURA = 0.9         # quão "grosso" é o acerto
const DANO = 1              # dano por tick
const TICK = 0.12           # de quanto em quanto tempo o laser causa dano
const INICIO = 0.4          # distância do player onde o laser começa

var _player: Node3D
var _ativo := 0.0
var _recarga := 0.0
var _tick := 0.0
var _dir := Vector3.FORWARD

var _feixe: Node3D
var _nucleo: MeshInstance3D
var _aura: MeshInstance3D
var _chamas_ponta: CPUParticles3D
var _barra: ProgressBar
var _rotulo: Label


func _ready() -> void:
	_player = get_parent() as Node3D
	_criar_feixe()
	_criar_hud()


func _unhandled_input(event: InputEvent) -> void:
	var apertou := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		apertou = true
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		apertou = true
	if apertou:
		disparar()


func disparar() -> void:
	if _ativo > 0.0 or _recarga > 0.0:
		return
	_ativo = DURACAO
	_tick = 0.0
	_atualizar_direcao()
	_feixe.visible = true
	_feixe.scale = Vector3(1, 1, 0.05)
	_chamas_ponta.emitting = true


func _physics_process(delta: float) -> void:
	if _ativo > 0.0:
		_ativo -= delta
		_atualizar_direcao()
		_animar_feixe()
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			_causar_dano()
		if _ativo <= 0.0:
			_feixe.visible = false
			_chamas_ponta.emitting = false
			_recarga = RECARGA
	elif _recarga > 0.0:
		_recarga = maxf(_recarga - delta, 0.0)
	_atualizar_hud()


func _atualizar_direcao() -> void:
	if _player.has_method("get_mouse_world_position"):
		var alvo = _player.get_mouse_world_position()
		if alvo != null:
			var d: Vector3 = alvo - _player.global_position
			d.y = 0
			if d.length() > 0.1:
				_dir = d.normalized()
	_feixe.basis = Basis.looking_at(_dir, Vector3.UP)
	_chamas_ponta.global_position = _player.global_position + _dir * ALCANCE + Vector3(0, 0.1, 0)


func _animar_feixe() -> void:
	var t := Time.get_ticks_msec() * 0.001
	# cresce rápido no começo e afina no final
	var crescer := clampf((DURACAO - _ativo) / 0.12, 0.05, 1.0)
	var afinar := clampf(_ativo / 0.2, 0.0, 1.0)
	var tremor := 1.0 + sin(t * 45.0) * 0.12 + sin(t * 23.0) * 0.08
	var grossura := tremor * afinar
	_feixe.scale = Vector3(grossura, grossura, crescer)


func _causar_dano() -> void:
	var origem := _player.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if not UTIL.inimigo_valido(e):
			continue
		var v: Vector3 = e.global_position - origem
		v.y = 0
		var ao_longo := v.dot(_dir)
		if ao_longo < 0.0 or ao_longo > ALCANCE + 0.5:
			continue
		var lateral := (v - _dir * ao_longo).length()
		if lateral <= LARGURA:
			e.take_damage(DANO)


# ---------------------------------------------------------------- VISUAL

func _criar_feixe() -> void:
	_feixe = Node3D.new()
	_feixe.position = Vector3(0, 0.1, 0)
	_feixe.visible = false
	add_child(_feixe)

	var comprimento := ALCANCE - INICIO
	# Cilindros ficam em pé (eixo Y); giramos pra apontar pra frente (-Z)
	_aura = _cilindro(0.42, comprimento, UTIL.material_brilho(UTIL.COR_FOGO, 0.6))
	_aura.rotation_degrees = Vector3(-90, 0, 0)
	_aura.position = Vector3(0, 0, -(INICIO + comprimento * 0.5))
	_feixe.add_child(_aura)

	_nucleo = _cilindro(0.17, comprimento, UTIL.material_brilho(UTIL.COR_NUCLEO))
	_nucleo.rotation_degrees = Vector3(-90, 0, 0)
	_nucleo.position = _aura.position
	_feixe.add_child(_nucleo)

	var boca := UTIL.criar_bola_fogo(0.45)
	boca.position = Vector3(0, 0, -INICIO)
	_feixe.add_child(boca)

	_chamas_ponta = UTIL.criar_chamas(0.5, 30)
	_chamas_ponta.emitting = false
	_chamas_ponta.initial_velocity_min = 1.0
	_chamas_ponta.initial_velocity_max = 2.5
	_chamas_ponta.spread = 70.0
	add_child(_chamas_ponta)


func _cilindro(raio: float, altura: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = raio
	c.bottom_radius = raio
	c.height = altura
	c.radial_segments = 16
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _criar_hud() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 5
	add_child(camada)

	var caixa := VBoxContainer.new()
	caixa.anchor_top = 1.0
	caixa.anchor_bottom = 1.0
	caixa.offset_left = 12
	caixa.offset_right = 190
	caixa.offset_top = -52
	caixa.offset_bottom = -10
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(caixa)

	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 13)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 4)
	caixa.add_child(_rotulo)

	_barra = ProgressBar.new()
	_barra.custom_minimum_size = Vector2(178, 12)
	_barra.show_percentage = false
	_barra.max_value = 1.0
	_barra.step = 0.0
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.1, 0.05, 0.05, 0.8)
	fundo.set_corner_radius_all(3)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = UTIL.COR_FOGO
	cheio.set_corner_radius_all(3)
	_barra.add_theme_stylebox_override("background", fundo)
	_barra.add_theme_stylebox_override("fill", cheio)
	caixa.add_child(_barra)
	_atualizar_hud()


func _atualizar_hud() -> void:
	if _ativo > 0.0:
		_rotulo.text = "RAJADÃO!!!"
		_barra.value = _ativo / DURACAO
	elif _recarga > 0.0:
		_rotulo.text = "Rajadão recarregando..."
		_barra.value = 1.0 - _recarga / RECARGA
	else:
		_rotulo.text = "Rajadão pronto [botão direito / E]"
		_barra.value = 1.0
