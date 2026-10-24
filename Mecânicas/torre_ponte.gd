extends Node3D
## Torre que vira ponte: quando o COGUMELO EXPLOSIVO explode nela, a torre tomba,
## se despedaça e uma tábua de madeira cai no lugar, virando a ponte.
##
## Como usar: arraste este script para o nó da torre (o que tem o modelo + StaticBody3D).
## O cogumelo explosivo precisa das 4 linhas que avisam o grupo "reage_explosao".

## Para que lado a torre tomba, em graus (eixos do mundo).
## (0, 0, -90) = cai para a direita (+X) | (0, 0, 90) = para a esquerda (-X)
## (90, 0, 0)  = cai para frente (+Z)   | (-90, 0, 0) = para trás (-Z)
@export var rotacao_queda := Vector3(0, 0, -90)
## Tempo da queda
@export var duracao_queda := 0.9
## Até que distância da torre a explosão ativa a queda (somado ao raio da explosão)
@export var alcance_extra := 1.0

@export_group("Tábua")
## Opcional: um nó de tábua que você já montou na cena (com StaticBody3D + colisão).
## Se ficar vazio, a tábua é criada sozinha onde a torre caiu, com a madeira da torre.
@export var tabua: Node3D
## Largura da tábua criada automaticamente
@export var largura_tabua := 1.6
## Grossura da tábua criada automaticamente
@export var espessura_tabua := 0.25
## Material da tábua criada automaticamente (vazio = usa o material da torre)
@export var material_tabua: Material

@export_group("Destroços")
@export var quantidade_lascas := 18
@export var cor_lascas := Color(0.45, 0.28, 0.14)

var _ativado := false


func _ready() -> void:
	add_to_group("reage_explosao")
	if tabua:
		tabua.visible = false
		_ligar_colisao(tabua, false)


## Chamado pelo cogumelo explosivo quando ele explode.
func receber_explosao(posicao: Vector3, raio: float) -> void:
	if _ativado:
		return
	var caixa := _caixa_global()
	var ponto_mais_perto := posicao.clamp(caixa.position, caixa.end)
	if ponto_mais_perto.distance_to(posicao) > raio + alcance_extra:
		return
	_ativado = true
	_cair_e_quebrar()


# ---------------------------------------------------------------- SEQUÊNCIA

func _cair_e_quebrar() -> void:
	var caixa := _caixa_global()
	# gira pela BASE da torre (centro de baixo), não pela origem do nó
	var pivo := Vector3(caixa.get_center().x, caixa.position.y, caixa.get_center().z)
	var chao_y := _altura_do_chao(pivo, caixa.end.y)
	var inicial := global_transform
	var giro := Basis.from_euler(rotacao_queda * PI / 180.0)
	var giro_quat := Quaternion(giro)

	# 1) tomba acelerando (como algo pesado caindo)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var b := Basis(Quaternion.IDENTITY.slerp(giro_quat, k))
		var t := Transform3D(b, Vector3.ZERO)
		global_transform = Transform3D.IDENTITY.translated(pivo) * t * Transform3D.IDENTITY.translated(-pivo) * inicial
	, 0.0, 1.0, duracao_queda).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	# 2) quebra: lascas + poeira, a torre some
	var caida := _caixa_global()
	var mat := _material_da_torre()
	_soltar_destrocos(caida, mat)
	visible = false
	_ligar_colisao(self, false)

	await get_tree().create_timer(0.35).timeout

	# 3) a tábua cai no lugar
	if tabua:
		_mostrar_tabua_pronta()
	else:
		_criar_tabua(caida, chao_y, mat)


func _mostrar_tabua_pronta() -> void:
	var final := tabua.position
	tabua.position = final + Vector3(0, 2.0, 0)
	tabua.visible = true
	var tw := tabua.create_tween()
	tw.tween_property(tabua, "position", final, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_ligar_colisao.bind(tabua, true))


func _criar_tabua(caida: AABB, chao_y: float, mat: Material) -> void:
	# a tábua cobre o lugar onde a torre caiu, no sentido mais comprido
	var comprimento := maxf(caida.size.x, caida.size.z)
	var no_eixo_x := caida.size.x >= caida.size.z
	var tam := Vector3(comprimento, espessura_tabua, largura_tabua) if no_eixo_x \
		else Vector3(largura_tabua, espessura_tabua, comprimento)

	var corpo := StaticBody3D.new()
	corpo.name = "TabuaPonte"
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tam
	forma.shape = caixa
	corpo.add_child(forma)
	var malha := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tam
	malha.mesh = box
	malha.material_override = material_tabua if material_tabua else mat
	corpo.add_child(malha)

	get_parent().add_child(corpo)
	# topo da tábua 8 cm acima do chão: aparece e o player sobe sem tropeçar
	var final := Vector3(caida.get_center().x, chao_y + 0.08 - espessura_tabua * 0.5, caida.get_center().z)
	corpo.global_position = final + Vector3(0, 2.0, 0)
	forma.disabled = true

	var tw := corpo.create_tween()
	tw.tween_property(corpo, "global_position", final, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): forma.disabled = false)


# ---------------------------------------------------------------- DESTROÇOS

func _soltar_destrocos(caixa: AABB, mat: Material) -> void:
	var efeito := Destrocos.new()
	efeito.caixa = caixa
	efeito.quantidade = quantidade_lascas
	efeito.cor = cor_lascas
	efeito.material_madeira = mat
	get_parent().add_child(efeito)


## Lascas de madeira voando + nuvem de poeira. Se apaga sozinho.
class Destrocos extends Node3D:
	var caixa: AABB
	var quantidade := 18
	var cor := Color(0.45, 0.28, 0.14)
	var material_madeira: Material
	var _lascas: Array[MeshInstance3D] = []
	var _vel: Array[Vector3] = []
	var _giro: Array[Vector3] = []
	var _poeira: MeshInstance3D
	var _mat_poeira: StandardMaterial3D
	var _t := 0.0
	const DURACAO := 1.3

	func _ready() -> void:
		var mat_lasca := StandardMaterial3D.new()
		mat_lasca.albedo_color = cor
		for i in quantidade:
			var l := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(randf_range(0.15, 0.5), randf_range(0.08, 0.15), randf_range(0.1, 0.25))
			l.mesh = b
			l.material_override = material_madeira if (material_madeira and randf() < 0.5) else mat_lasca
			add_child(l)
			l.global_position = Vector3(
				randf_range(caixa.position.x, caixa.end.x),
				randf_range(caixa.position.y, caixa.end.y) + 0.3,
				randf_range(caixa.position.z, caixa.end.z))
			l.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
			var fora := (l.global_position - caixa.get_center())
			fora.y = 0
			_vel.append(fora.normalized() * randf_range(1.5, 4.0) + Vector3(0, randf_range(3.0, 6.0), 0))
			_giro.append(Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)))
			_lascas.append(l)

		_mat_poeira = StandardMaterial3D.new()
		_mat_poeira.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_poeira.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_poeira.albedo_color = Color(0.75, 0.7, 0.65, 0.5)
		_poeira = MeshInstance3D.new()
		var esf := SphereMesh.new()
		esf.radius = 1.0
		esf.height = 2.0
		_poeira.mesh = esf
		_poeira.material_override = _mat_poeira
		_poeira.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_poeira)
		_poeira.global_position = Vector3(caixa.get_center().x, caixa.position.y + 0.3, caixa.get_center().z)

	func _process(delta: float) -> void:
		_t += delta
		var k := clampf(_t / DURACAO, 0.0, 1.0)
		for i in _lascas.size():
			_vel[i].y -= 14.0 * delta
			var l := _lascas[i]
			l.global_position += _vel[i] * delta
			if l.global_position.y < caixa.position.y + 0.05:   # bate no chão e para
				l.global_position.y = caixa.position.y + 0.05
				_vel[i] *= 0.4
				_vel[i].y = absf(_vel[i].y) * 0.3
			l.rotation += _giro[i] * delta
			if k > 0.6:
				l.scale = Vector3.ONE * (1.0 - (k - 0.6) / 0.4)
		var r := lerpf(0.5, maxf(caixa.size.x, caixa.size.z) * 0.6, 1.0 - pow(1.0 - k, 3.0))
		_poeira.scale = Vector3(r, r * 0.45, r)
		_mat_poeira.albedo_color.a = 0.5 * (1.0 - k)
		if _t >= DURACAO:
			queue_free()


# ---------------------------------------------------------------- AUXILIARES

## Altura do chão onde a torre está apoiada (ignora a própria torre)
func _altura_do_chao(base: Vector3, topo_y: float) -> float:
	var excluir: Array[RID] = []
	var eu: Node = self
	if eu is CollisionObject3D:
		excluir.append((eu as CollisionObject3D).get_rid())
	for corpo in find_children("*", "CollisionObject3D", true, false):
		excluir.append((corpo as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(Vector3(base.x, topo_y, base.z), base + Vector3(0, -5, 0))
	query.exclude = excluir
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("position"):
		return hit["position"].y
	return base.y


## Caixa (no mundo) que envolve todo o visual da torre
func _caixa_global() -> AABB:
	var caixa := AABB()
	var achou := false
	var visuais: Array = find_children("*", "VisualInstance3D", true, false)
	var eu: Node = self
	if eu is VisualInstance3D:
		visuais.append(eu)
	for v in visuais:
		if v is GPUParticles3D or v is CPUParticles3D or v is Light3D:
			continue
		var b: AABB = (v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb()
		caixa = b if not achou else caixa.merge(b)
		achou = true
	if not achou:
		caixa = AABB(global_position - Vector3(0.5, 0, 0.5), Vector3(1, 3, 1))
	return caixa


func _material_da_torre() -> Material:
	var malhas: Array = find_children("*", "MeshInstance3D", true, false)
	var eu: Node = self
	if eu is MeshInstance3D:
		malhas.insert(0, eu)
	for m in malhas:
		var mi := m as MeshInstance3D
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			var mat := mi.get_active_material(0)
			if mat:
				return mat
	var padrao := StandardMaterial3D.new()
	padrao.albedo_color = Color(0.5, 0.32, 0.17)
	return padrao


static func _ligar_colisao(raiz: Node, ligar: bool) -> void:
	for forma in raiz.find_children("*", "CollisionShape3D", true, false):
		forma.set_deferred("disabled", not ligar)
