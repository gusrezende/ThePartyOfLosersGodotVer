extends Node3D
## Marca no chão mostrando onde um ataque vai acertar.
## O preenchimento vermelho cresce e fica completo no momento do impacto.

var raio := 3.0
var duracao := 1.5
var cor := Color(1.0, 0.15, 0.1)

var _t := 0.0
var _preenchimento: MeshInstance3D
var _mat_anel: StandardMaterial3D


func configurar(novo_raio: float, nova_duracao: float, nova_cor := Color(1.0, 0.15, 0.1)) -> void:
	raio = novo_raio
	duracao = nova_duracao
	cor = nova_cor


func _ready() -> void:
	var fundo := _disco(raio, _material(Color(cor.r, cor.g, cor.b, 0.18)))
	fundo.position.y = 0.03
	add_child(fundo)

	var mat_preench := _material(Color(cor.r, cor.g, cor.b, 0.42))
	mat_preench.render_priority = 1
	_preenchimento = _disco(raio, mat_preench)
	_preenchimento.position.y = 0.04
	_preenchimento.scale = Vector3(0.001, 1.0, 0.001)
	add_child(_preenchimento)

	_mat_anel = _material(Color(cor.r, cor.g, cor.b, 0.9))
	_mat_anel.render_priority = 2
	var anel := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = maxf(raio - 0.18, 0.05)
	toro.outer_radius = raio
	toro.rings = 48
	anel.mesh = toro
	anel.material_override = _mat_anel
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anel.scale = Vector3(1.0, 0.15, 1.0)
	anel.position.y = 0.05
	add_child(anel)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / duracao, 0.0, 1.0)
	var s := maxf(k, 0.001)
	_preenchimento.scale = Vector3(s, 1.0, s)
	# pisca cada vez mais rápido conforme o impacto se aproxima
	var pisca := 0.5 + 0.5 * sin(_t * lerpf(8.0, 30.0, k))
	_mat_anel.albedo_color.a = lerpf(0.45, 1.0, pisca)
	if _t >= duracao:
		queue_free()


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m


func _disco(r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.02
	c.radial_segments = 48
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
