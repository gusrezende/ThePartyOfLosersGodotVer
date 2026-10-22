extends Node3D
## Efeito visual de explosão (só visual, o dano é calculado por quem cria).

var raio := 3.0
var cor := Color(1.0, 0.5, 0.1)
var duracao := 0.45

var _t := 0.0
var _esfera: MeshInstance3D
var _onda: MeshInstance3D
var _mat_esfera: StandardMaterial3D
var _mat_onda: StandardMaterial3D
var _luz: OmniLight3D


func configurar(novo_raio: float, nova_cor := Color(1.0, 0.5, 0.1), nova_duracao := 0.45) -> void:
	raio = novo_raio
	cor = nova_cor
	duracao = nova_duracao


func _ready() -> void:
	_mat_esfera = _material(Color(cor.r, cor.g, cor.b, 0.8))
	_esfera = MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 1.0
	esf.height = 2.0
	_esfera.mesh = esf
	_esfera.material_override = _mat_esfera
	_esfera.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_esfera)

	_mat_onda = _material(Color(1.0, 0.95, 0.8, 0.9))
	_onda = MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.85
	toro.outer_radius = 1.0
	toro.rings = 48
	_onda.mesh = toro
	_onda.material_override = _mat_onda
	_onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_onda.position.y = 0.08
	add_child(_onda)

	_luz = OmniLight3D.new()
	_luz.light_color = cor
	_luz.omni_range = raio * 2.5
	_luz.light_energy = 4.0
	_luz.position.y = 1.0
	add_child(_luz)
	_atualizar(0.0)


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / duracao, 0.0, 1.0)
	_atualizar(k)
	if _t >= duracao:
		queue_free()


func _atualizar(k: float) -> void:
	var cresc := 1.0 - pow(1.0 - k, 3.0)  # ease-out
	var r_esf := lerpf(raio * 0.25, raio * 0.75, cresc)
	_esfera.scale = Vector3(r_esf, r_esf * 0.6, r_esf)
	_mat_esfera.albedo_color.a = 0.8 * (1.0 - k)
	var r_onda := lerpf(raio * 0.3, raio * 1.05, cresc)
	_onda.scale = Vector3(r_onda, 0.2, r_onda)
	_mat_onda.albedo_color.a = 0.9 * (1.0 - k)
	_luz.light_energy = 4.0 * (1.0 - k)


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m
