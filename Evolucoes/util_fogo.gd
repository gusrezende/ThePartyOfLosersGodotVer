extends RefCounted
## Funções compartilhadas pelas evoluções de fogo (visual + checagem de inimigos).

const COR_NUCLEO := Color(1.0, 0.93, 0.5)
const COR_FOGO := Color(1.0, 0.45, 0.08)


## true se dá pra causar dano nesse inimigo agora
static func inimigo_valido(e: Node) -> bool:
	if not is_instance_valid(e) or e.is_queued_for_deletion():
		return false
	if not (e is Node3D) or not e.has_method("take_damage"):
		return false
	if e.get("morto") == true:   # Enemy1 tocando a animação de morte
		return false
	return true


static func distancia_plana(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func material_brilho(cor: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(cor.r, cor.g, cor.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Bola de fogo: núcleo amarelo + aura laranja + chamas + luz
static func criar_bola_fogo(raio: float, com_luz := true) -> Node3D:
	var raiz := Node3D.new()

	var nucleo := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = raio * 0.6
	esf.height = raio * 1.2
	nucleo.mesh = esf
	nucleo.material_override = material_brilho(COR_NUCLEO)
	nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(nucleo)

	var aura := MeshInstance3D.new()
	var esf2 := SphereMesh.new()
	esf2.radius = raio
	esf2.height = raio * 2.0
	aura.mesh = esf2
	aura.material_override = material_brilho(COR_FOGO, 0.55)
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(aura)

	raiz.add_child(criar_chamas(raio))

	if com_luz:
		var luz := OmniLight3D.new()
		luz.light_color = COR_FOGO
		luz.omni_range = raio * 7.0
		luz.light_energy = 1.2
		raiz.add_child(luz)
	return raiz


## Partículas de chama subindo
static func criar_chamas(raio: float, qtd := 18) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = qtd
	p.lifetime = 0.45
	p.local_coords = false

	var m := SphereMesh.new()
	m.radius = raio * 0.45
	m.height = raio * 0.9
	m.radial_segments = 8
	m.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m

	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = raio * 0.5
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 2.0, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0

	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.1))
	p.scale_amount_curve = curva

	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.5, 1.0))
	g.set_color(1, Color(0.9, 0.15, 0.0, 0.0))
	g.add_point(0.4, Color(1.0, 0.5, 0.1, 0.9))
	p.color_ramp = g
	return p
