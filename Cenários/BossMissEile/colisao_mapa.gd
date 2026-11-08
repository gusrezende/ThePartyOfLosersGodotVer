extends Node3D
## Colocado no modelo 3D do mapa (.glb): cria a colisão (chão e paredes)
## a partir das próprias malhas do modelo, quando a fase começa.
##
## - Funciona mesmo se o modelo estiver girado ou esticado (escala diferente em X/Y/Z):
##   a colisão é criada já no tamanho final, num StaticBody3D sem escala.
## - É "dos dois lados" (backface_collision), então ninguém atravessa nada por dentro.
## - PAREDES INVISÍVEIS: o mapa da arena é uma plataforma com barrancos nas bordas.
##   Este script acha a borda do chão sozinho e levanta uma parede invisível em volta,
##   seguindo o formato da arena. Assim ninguém cai (nem o player, nem a MissEile).
## - Se você mudar o modelo no Blender e reexportar, tudo acompanha sozinho.

## Camada de colisão do mapa (camada 1, a mesma do chão de antes)
@export_flags_3d_physics var camada := 1
## Cria as paredes invisíveis na borda do chão
@export var paredes_invisiveis := true
## Altura das paredes invisíveis (em metros, a partir do chão)
@export var altura_paredes := 5.0
## Até quantos metros abaixo do ponto mais alto do mapa ainda conta como "chão"
@export var profundidade_chao := 0.5
## Mostra as paredes invisíveis em vermelho (só para conferir; deixe desligado no jogo)
@export var mostrar_paredes := false


func _ready() -> void:
	var faces := PackedVector3Array()
	for mi in find_children("*", "MeshInstance3D", true, false):
		var malha := mi as MeshInstance3D
		if malha.mesh == null:
			continue
		var t := malha.global_transform
		for v in malha.mesh.get_faces():
			faces.append(t * v)   # já no tamanho e na posição finais
	if faces.is_empty():
		push_warning("colisao_mapa: nenhuma malha encontrada em " + name)
		return

	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoDoMapa"
	corpo.collision_layer = camada
	corpo.top_level = true            # não herda a escala esticada do modelo
	add_child(corpo)
	corpo.global_transform = Transform3D.IDENTITY

	corpo.add_child(_forma(faces))

	if paredes_invisiveis:
		var paredes := _paredes_na_borda(faces)
		if not paredes.is_empty():
			var cs := _forma(paredes)
			cs.name = "ParedesInvisiveis"
			corpo.add_child(cs)
			if mostrar_paredes:
				_desenhar(paredes)


func _forma(faces: PackedVector3Array) -> CollisionShape3D:
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(faces)
	forma.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = forma
	return cs


## Acha as bordas do chão (lados de triângulos de chão que não encostam em outro
## triângulo de chão) e levanta uma parede em cada uma.
func _paredes_na_borda(faces: PackedVector3Array) -> PackedVector3Array:
	var topo := -INF
	for v in faces:
		topo = maxf(topo, v.y)

	var uso := {}        # chave da aresta -> quantos triângulos de chão usam
	var pontas := {}     # chave da aresta -> [a, b]
	_chao_tris.clear()
	_grade.clear()
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < 1e-10:
			continue
		normal = normal.normalized()
		# chão = virado para cima e perto do ponto mais alto do mapa
		if absf(normal.y) < 0.7 or (a.y + b.y + c.y) / 3.0 < topo - profundidade_chao:
			continue
		_guardar_chao(a, b, c)
		for par in [[a, b], [b, c], [c, a]]:
			var k := _chave(par[0], par[1])
			uso[k] = uso.get(k, 0) + 1
			pontas[k] = par

	var paredes := PackedVector3Array()
	var alto := Vector3(0, altura_paredes, 0)
	var baixo := Vector3(0, -0.5, 0)   # entra um pouco no chão para não sobrar fresta
	for k in uso:
		if uso[k] != 1:
			continue
		var p: Array = pontas[k]
		var a: Vector3 = p[0]
		var b: Vector3 = p[1]
		# só é borda de verdade se de um dos lados NÃO tem chão.
		# (o modelo pode ter "emendas": dois pedaços de chão encostados que não
		#  dividem os mesmos vértices; ali não pode ter parede)
		if _tem_chao_dos_dois_lados(a, b):
			continue
		paredes.append_array([a + baixo, b + baixo, b + alto, a + baixo, b + alto, a + alto])
	return paredes


func _tem_chao_dos_dois_lados(a: Vector3, b: Vector3) -> bool:
	var dir := b - a
	dir.y = 0
	if dir.length_squared() < 1e-6:
		return false
	var lado := Vector3(-dir.z, 0, dir.x).normalized() * 0.35
	for t in [0.25, 0.5, 0.75]:
		var meio: Vector3 = a.lerp(b, t)
		if not (_chao_em(meio + lado) and _chao_em(meio - lado)):
			return false
	return true


# ---- triângulos de chão guardados numa grade de 1 m (para achar rápido)
var _chao_tris: Array = []
var _grade := {}


func _guardar_chao(a: Vector3, b: Vector3, c: Vector3) -> void:
	var i := _chao_tris.size()
	_chao_tris.append([a, b, c])
	for gx in range(floori(minf(a.x, minf(b.x, c.x))), floori(maxf(a.x, maxf(b.x, c.x))) + 1):
		for gz in range(floori(minf(a.z, minf(b.z, c.z))), floori(maxf(a.z, maxf(b.z, c.z))) + 1):
			var k := Vector2i(gx, gz)
			if not _grade.has(k):
				_grade[k] = []
			_grade[k].append(i)


## Tem triângulo de chão embaixo deste ponto (olhando de cima, na mesma altura)?
func _chao_em(ponto: Vector3) -> bool:
	var k := Vector2i(floori(ponto.x), floori(ponto.z))
	if not _grade.has(k):
		return false
	var p := Vector2(ponto.x, ponto.z)
	for i in _grade[k]:
		var tri: Array = _chao_tris[i]
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		if Geometry2D.point_is_inside_triangle(p, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)) \
				and absf((a.y + b.y + c.y) / 3.0 - ponto.y) < 1.0:
			return true
	return false


func _chave(a: Vector3, b: Vector3) -> String:
	var ka := "%.3f,%.3f,%.3f" % [a.x, a.y, a.z]
	var kb := "%.3f,%.3f,%.3f" % [b.x, b.y, b.z]
	return ka + "|" + kb if ka < kb else kb + "|" + ka


func _desenhar(faces: PackedVector3Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in faces:
		st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.mesh.surface_set_material(0, mat)
	mi.top_level = true
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
