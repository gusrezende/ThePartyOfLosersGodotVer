extends Camera3D
## Câmera que segue o player com um leve atraso e NÃO mostra o que está fora do mapa.
##
## Os limites do mapa são calculados sozinhos a partir de toda a geometria fixa da cena
## (StaticBody3D: chão, paredes...). Se quiser definir na mão, ligue "usar_limites_manuais"
## no Inspetor e preencha "limite_min" / "limite_max" (X e Z do mundo).
##
## Mapas com formato irregular (caverna + corredor + sala): coloque ZONAS DE CÂMERA
## (res://Mecânicas/ZonaCamera/zona_camera.tscn). Aí a câmera usa como limite só a
## zona onde o player está, e chega mais perto quando a zona é mais estreita que a tela.

## Quanto maior, mais rápido ela alcança o player (8 = atraso bem pequeno e suave)
@export var suavidade := 8.0
## Deixa o fundo (o que sobra fora do mapa) preto em vez de cinza
@export var fundo_preto := true
## O player nunca chega mais perto da borda da tela do que isso (0.75 = 75% do caminho
## do centro até a borda). Tem prioridade sobre os limites do mapa.
@export_range(0.3, 0.95) var margem_player := 0.75
## Até que ponto da tela o FUNDO do mapa pode aparecer (0.5 = meio da tela,
## 0.0 = topo da tela). Menor = mostra menos coisa além da parede do fundo.
@export_range(0.0, 0.5) var ponto_fundo := 0.5

## Abre um "buraco" (efeito de pontinhos) na parte das paredes que fica entre a
## câmera e o player, pra dar pra ver o player atrás delas. O chão nunca some.
@export var paredes_somem := true

@export_group("Limites manuais")
@export var usar_limites_manuais := false
@export var limite_min := Vector2(-10, -10)   # (X, Z) canto de trás/esquerda
@export var limite_max := Vector2(10, 10)     # (X, Z) canto da frente/direita

var player: Node3D = null
var offset: Vector3

var _limites: Rect2           # X/Z do mapa (position = mínimo, end = máximo)
var _tem_limites := false
var _cor_fundo_antiga: Color

var _limites_mapa: Rect2      # limites do mapa inteiro (usado quando não há zona)
var _tem_limites_mapa := false
var _zonas: Array = []        # zonas de câmera da cena
var _zona_atual: Node = null
var _zoom := 1.0              # 1 = distância normal; menor = mais perto do player

var _conversa: Array = []     # player + NPC quando a tela de diálogo está aberta
var _modo_antes_conversa := Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		offset = global_position - player.global_position

	if fundo_preto:
		_cor_fundo_antiga = RenderingServer.get_default_clear_color()
		RenderingServer.set_default_clear_color(Color.BLACK)

	_calcular_limites()
	_limites_mapa = _limites
	_tem_limites_mapa = _tem_limites
	_zonas = get_tree().get_nodes_in_group("zona_camera")
	if paredes_somem and player:
		_aplicar_paredes_que_somem()
	if player:
		_atualizar_zona(0.0, true)
		global_position = _alvo_limitado()   # já começa no lugar certo, sem deslizar


func _exit_tree() -> void:
	if fundo_preto:
		RenderingServer.set_default_clear_color(_cor_fundo_antiga)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var alvo: Vector3
	var peso: float
	if not _conversa.is_empty():
		alvo = _alvo_conversa()
		peso = 1.0 - exp(-suavidade * 0.6 * delta)
		global_position = global_position.lerp(alvo, peso)
		_atualizar_paredes()
		return
	_atualizar_zona(delta, false)
	alvo = _alvo_limitado()
	# atraso suave que não depende do FPS
	peso = 1.0 - exp(-suavidade * delta)
	global_position = global_position.lerp(alvo, peso)
	_atualizar_paredes()


## Onde a câmera deveria estar: atrás do player, mas sem passar dos limites do mapa.
func _alvo_limitado() -> Vector3:
	var alvo := player.global_position + offset * _zoom
	if not _tem_limites:
		return alvo

	# altura da câmera em relação ao chão onde o player está
	var chao_y := player.global_position.y - 1.0
	var h := alvo.y - chao_y
	if h <= 0.1:
		return alvo

	var tam := get_viewport().get_visible_rect().size
	# pontos da tela que não podem mostrar nada fora do mapa:
	# laterais (no meio da tela e embaixo), base da tela e o centro.
	# No fundo do mapa a câmera pode ir até o player ficar no centro da tela:
	# lá normalmente tem parede, então o que aparece em cima é a própria parede.
	var esq_meio := _no_chao(Vector2(0, tam.y * 0.5), h)
	var dir_meio := _no_chao(Vector2(tam.x, tam.y * 0.5), h)
	var esq_baixo := _no_chao(Vector2(0, tam.y), h)
	var dir_baixo := _no_chao(Vector2(tam.x, tam.y), h)
	var centro := _no_chao(Vector2(tam.x * 0.5, tam.y * ponto_fundo), h)

	var min_dx := minf(esq_meio.x, esq_baixo.x)
	var max_dx := maxf(dir_meio.x, dir_baixo.x)
	var perto_dz := maxf(esq_baixo.y, dir_baixo.y)   # base da tela (lado da câmera)
	var longe_dz := centro.y                          # centro da tela (lado do fundo)

	var livre := alvo   # onde ela ficaria sem limites (player no centro)
	alvo.x = _limitar(alvo.x, _limites.position.x - min_dx, _limites.end.x - max_dx)
	alvo.z = _limitar(alvo.z, _limites.position.y - longe_dz, _limites.end.y - perto_dz)

	# prioridade: o player nunca pode sumir da tela
	alvo = _garantir_player_visivel(alvo, livre)
	return alvo


## Se o limite do mapa empurrou o player pra muito perto da borda da tela,
## aproxima a câmera do player só o necessário.
func _garantir_player_visivel(alvo: Vector3, livre: Vector3) -> Vector3:
	var tam := get_viewport().get_visible_rect().size
	var tan_v := tan(deg_to_rad(fov) * 0.5)
	var tan_h := tan_v * tam.x / maxf(tam.y, 1.0)
	var frente := -global_basis.z
	var cima := global_basis.y
	var alvo_p := player.global_position

	# eixo Z (cima/baixo da tela): busca binária entre a posição limitada e a livre
	if not _player_cabe_vertical(Vector3(alvo.x, alvo.y, alvo.z), alvo_p, frente, cima, tan_v):
		var a := 0.0
		var b := 1.0
		for i in 14:
			var m := (a + b) * 0.5
			var z := lerpf(alvo.z, livre.z, m)
			if _player_cabe_vertical(Vector3(alvo.x, alvo.y, z), alvo_p, frente, cima, tan_v):
				b = m
			else:
				a = m
		alvo.z = lerpf(alvo.z, livre.z, b)

	# eixo X (esquerda/direita da tela)
	var rel := alvo_p - alvo
	var prof := maxf(rel.dot(frente), 0.1)
	var max_x := prof * tan_h * margem_player
	alvo.x = clampf(alvo.x, alvo_p.x - max_x, alvo_p.x + max_x)
	return alvo


func _player_cabe_vertical(cam: Vector3, p: Vector3, frente: Vector3, cima: Vector3, tan_v: float) -> bool:
	var rel := p - cam
	var prof := rel.dot(frente)
	if prof <= 0.1:
		return false
	return absf(rel.dot(cima)) <= prof * tan_v * margem_player


# ---------------------------------------------------------------- TELA DE DIÁLOGO

## Chamado pela caixa de diálogo: dá zoom nos personagens e deixa eles
## do lado esquerdo da tela (o lado direito fica livre para a caixa).
func focar_conversa(personagens: Array) -> void:
	_conversa = personagens.filter(func(n): return n != null and is_instance_valid(n))
	_modo_antes_conversa = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS   # o jogo fica pausado, a câmera não


func soltar_conversa() -> void:
	_conversa.clear()
	process_mode = _modo_antes_conversa


## Fração da largura da tela onde fica o centro dos personagens (0 = esquerda, 1 = direita)
const CONVERSA_POSICAO_X := 0.28
## Quanto da tela (largura) os personagens podem ocupar
const CONVERSA_LARGURA := 0.5


func _alvo_conversa() -> Vector3:
	# caixa (no mundo) que envolve os desenhos dos personagens
	var caixa := AABB()
	var achou := false
	for n in _conversa:
		if not is_instance_valid(n):
			continue
		var c := _caixa_visual(n)
		caixa = c if not achou else caixa.merge(c)
		achou = true
	if not achou:
		return global_position
	var meio := caixa.get_center()
	var tam := get_viewport().get_visible_rect().size
	var tan_v := tan(deg_to_rad(fov * 0.5))
	var tan_h := tan_v * tam.x / tam.y
	var frente := -global_basis.z
	var direita := global_basis.x
	var cima := global_basis.y
	# tamanho da caixa "vista pela câmera" (largura e altura na tela)
	var largura := 0.0
	var altura := 0.0
	for i in 8:
		var canto := caixa.get_endpoint(i) - meio
		largura = maxf(largura, absf(canto.dot(direita)) * 2.0)
		altura = maxf(altura, absf(canto.dot(cima)) * 2.0)
	# distância para os dois caberem na parte esquerda, com uma folga
	var dist := maxf((largura + 1.2) / (CONVERSA_LARGURA * 2.0 * tan_h),
		(altura + 0.8) / (2.0 * tan_v * 0.78))
	dist = clampf(dist, 3.5, offset.length() * 1.2)
	# empurra a câmera pra direita: os personagens aparecem do lado esquerdo
	var deslocar := (1.0 - CONVERSA_POSICAO_X * 2.0) * dist * tan_h
	return meio - frente * dist + direita * deslocar


## Caixa que envolve os desenhos (sprites/modelos) de um personagem
func _caixa_visual(n: Node3D) -> AABB:
	var caixa := AABB(n.global_position, Vector3(0.5, 1.5, 0.5))
	var achou := false
	for v in n.find_children("*", "GeometryInstance3D", true, false):
		var gi := v as GeometryInstance3D
		if not gi.is_visible_in_tree() or gi is Label3D:
			continue
		var b := gi.global_transform * gi.get_aabb()
		caixa = b if not achou else caixa.merge(b)
		achou = true
	return caixa


# ---------------------------------------------------------------- ZONAS DE CÂMERA

## Descobre em qual zona o player está e ajusta os limites e a aproximação.
func _atualizar_zona(delta: float, na_hora: bool) -> void:
	if _zonas.is_empty():
		return
	var pos := player.global_position
	var melhor: Node = null
	for z in _zonas:
		if not is_instance_valid(z) or not z.contem(pos):
			continue
		if melhor == null or z.prioridade > melhor.prioridade \
				or (z.prioridade == melhor.prioridade and z == _zona_atual):
			melhor = z
	if melhor != null:
		_zona_atual = melhor
	# fora de todas as zonas: continua usando a última (ou o mapa inteiro)
	if _zona_atual != null and is_instance_valid(_zona_atual):
		_limites = _zona_atual.retangulo()
		_tem_limites = true
	else:
		_limites = _limites_mapa
		_tem_limites = _tem_limites_mapa

	var zoom_alvo := _zoom_da_zona()
	if na_hora:
		_zoom = zoom_alvo
	else:
		_zoom = lerpf(_zoom, zoom_alvo, 1.0 - exp(-suavidade * 0.5 * delta))


## Quanto a câmera precisa se aproximar para a tela caber dentro da zona.
func _zoom_da_zona() -> float:
	if _zona_atual == null or not is_instance_valid(_zona_atual) or not _zona_atual.aproximar_se_estreito:
		return 1.0
	if offset.y <= 0.1:
		return 1.0
	var tam := get_viewport().get_visible_rect().size
	# tamanho do chão visível para cada 1 m de altura da câmera
	var esq := _no_chao(Vector2(0, tam.y * 0.5), 1.0)
	var dir := _no_chao(Vector2(tam.x, tam.y * 0.5), 1.0)
	var largura_por_m := dir.x - esq.x
	if largura_por_m <= 0.01:
		return 1.0
	# a altura da câmera acima do chão é (offset.y * zoom + 1)
	var altura_cabe: float = _zona_atual.retangulo().size.x / largura_por_m
	var z: float = (altura_cabe - 1.0) / offset.y
	return clampf(z, _zona_atual.zoom_minimo, 1.0)


## Distância (X, Z) da câmera até o ponto do chão que aparece nesse pixel da tela.
func _no_chao(pixel: Vector2, h: float) -> Vector2:
	var d := project_ray_normal(pixel)
	if d.y > -0.05:
		d.y = -0.05   # raio quase horizontal: evita distância infinita
	var t := h / -d.y
	return Vector2(d.x * t, d.z * t)


## Se o mapa for menor que a tela nesse eixo, a câmera fica centralizada nele.
func _limitar(valor: float, minimo: float, maximo: float) -> float:
	if minimo > maximo:
		return (minimo + maximo) * 0.5
	return clampf(valor, minimo, maximo)


func _calcular_limites() -> void:
	if usar_limites_manuais:
		_limites = Rect2(limite_min, limite_max - limite_min)
		_tem_limites = true
		return

	var caixa := AABB()
	var achou := false
	var raiz := get_tree().current_scene if get_tree().current_scene else get_parent()
	for corpo in raiz.find_children("*", "StaticBody3D", true, false):
		for forma in corpo.find_children("*", "CollisionShape3D", false, false):
			var cs := forma as CollisionShape3D
			if cs.shape == null or cs.disabled:
				continue
			var malha := cs.shape.get_debug_mesh()
			if malha == null:
				continue
			var b := cs.global_transform * malha.get_aabb()
			caixa = b if not achou else caixa.merge(b)
			achou = true

	if achou:
		_limites = Rect2(caixa.position.x, caixa.position.z, caixa.size.x, caixa.size.z)
		_tem_limites = true


const SHADER_PAREDE := """
shader_type spatial;
render_mode CULL_MODE;

uniform sampler2D textura : source_color, FILTRO, repeat_enable;
uniform bool tem_textura = true;
uniform vec4 cor : source_color = vec4(1.0);
uniform vec3 uv_escala = vec3(1.0);
uniform vec3 uv_desloc = vec3(0.0);
uniform float aspereza = 1.0;

uniform vec3 jogador_pos;      // centro do player
uniform float pe_y;            // altura do pé do player
uniform float raio = 2.3;      // tamanho do "buraco" na parede

varying vec3 pos_mundo;

void vertex() {
	UV = UV * uv_escala.xy + uv_desloc.xy;
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 para_jog = jogador_pos - cam;
	float dist_jog = length(para_jog);
	vec3 dir = para_jog / dist_jog;
	vec3 v = pos_mundo - cam;
	float ao_longo = dot(v, dir);
	float lateral = length(v - dir * ao_longo);
	// só some o que está ACIMA do pé, ENTRE a câmera e o player e perto da linha de visão
	if (pos_mundo.y > pe_y + 0.3 && ao_longo > 0.0 && ao_longo < dist_jog - 0.7) {
		float quanto = 1.0 - smoothstep(raio * 0.55, raio, lateral);
		if (quanto > bayer4(FRAGCOORD.xy)) {
			discard;
		}
	}
	vec4 c = cor;
	if (tem_textura) {
		c *= texture(textura, UV);
	}
	ALBEDO = c.rgb;
	ROUGHNESS = aspereza;
}
"""

var _mats_parede: Array[ShaderMaterial] = []


## Troca o material das paredes por um que "abre um buraco" na frente do player.
## Só afeta a parte da parede acima do pé do player: o chão nunca some.
func _aplicar_paredes_que_somem() -> void:
	var altura_pe := player.global_position.y - 0.5
	var raiz := get_tree().current_scene if get_tree().current_scene else get_parent()
	var cache := {}   # material original -> material novo (reaproveita)

	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		var malha := mi as MeshInstance3D
		if malha.mesh == null or not _faz_parte_do_mapa(malha):
			continue
		var caixa := malha.global_transform * malha.get_aabb()
		if caixa.end.y <= altura_pe + 1.0:
			continue   # peça baixa (chão, degrau): não precisa
		for i in malha.mesh.get_surface_count():
			var mat := malha.get_active_material(i)
			if not (mat is StandardMaterial3D):
				continue
			var std := mat as StandardMaterial3D
			if std.uv1_triplanar or std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			if not cache.has(std):
				cache[std] = _criar_material_parede(std)
			malha.set_surface_override_material(i, cache[std])


func _criar_material_parede(std: StandardMaterial3D) -> ShaderMaterial:
	var codigo := SHADER_PAREDE
	var cull := "cull_back"
	if std.cull_mode == BaseMaterial3D.CULL_DISABLED:
		cull = "cull_disabled"
	elif std.cull_mode == BaseMaterial3D.CULL_FRONT:
		cull = "cull_front"
	codigo = codigo.replace("CULL_MODE", cull)
	var filtro := "filter_linear_mipmap"
	if std.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST or std.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS:
		filtro = "filter_nearest_mipmap"
	codigo = codigo.replace("FILTRO", filtro)

	var shader := Shader.new()
	shader.code = codigo
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("textura", std.albedo_texture)
	m.set_shader_parameter("tem_textura", std.albedo_texture != null)
	m.set_shader_parameter("cor", std.albedo_color)
	m.set_shader_parameter("uv_escala", std.uv1_scale)
	m.set_shader_parameter("uv_desloc", std.uv1_offset)
	m.set_shader_parameter("aspereza", std.roughness)
	_mats_parede.append(m)
	return m


func _atualizar_paredes() -> void:
	if _mats_parede.is_empty():
		return
	var pos := player.global_position
	for m in _mats_parede:
		m.set_shader_parameter("jogador_pos", pos)
		m.set_shader_parameter("pe_y", pos.y - 1.0)


## true se a malha é cenário (está ligada a um StaticBody3D: pai ou filho)
func _faz_parte_do_mapa(malha: MeshInstance3D) -> bool:
	if malha.get_parent() is StaticBody3D:
		return true
	for filho in malha.get_children():
		if filho is StaticBody3D:
			return true
	return false
