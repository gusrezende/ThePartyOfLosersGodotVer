extends CanvasLayer
## AUTOLOAD: troca o mouse do jogo pela MIRA animada.
##
## A mira é desenhada em "cor negativa": cada pixel dela mostra o inverso da cor
## que está atrás (fundo claro = mira escura, fundo escuro = mira clara),
## então ela sempre se destaca, em qualquer lugar do mapa.
##
## O ponto do clique é o CENTRO da mira.
## Na tela de point and click a mira some e volta a mãozinha daquela sala.
##
## As imagens da animação são mira_1.png ... mira_N.png, na mesma pasta deste script.

## Quadros por segundo da animação
@export var velocidade_animacao := 10.0
## Tamanho da mira (1 = tamanho original da imagem, 31 px; 2 = 62 px).
## Prefira números inteiros (1, 2, 3): com 1.5 as linhas da pixel art ficam tortas.
@export var escala := 2.0

const SHADER_NEGATIVO := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	float forma = texture(TEXTURE, UV).a;
	vec3 fundo = texture(tela, SCREEN_UV).rgb;
	vec3 negativo = vec3(1.0) - fundo;
	// em fundos cinza-médio o negativo também fica cinza: empurra para preto/branco
	float luz = dot(negativo, vec3(0.299, 0.587, 0.114));
	negativo = mix(negativo, vec3(step(0.5, luz)), 0.35);
	COLOR = vec4(negativo, forma);
}
"""

var _quadros: Array[Texture2D] = []
var _sprite: Sprite2D
var _tempo := 0.0
var _aparecendo := true


func _ready() -> void:
	layer = 128   # acima de tudo (até da transição em estrela)
	process_mode = Node.PROCESS_MODE_ALWAYS

	var pasta: String = get_script().resource_path.get_base_dir()
	var i := 1
	while ResourceLoader.exists(pasta.path_join("mira_%d.png" % i)):
		_quadros.append(load(pasta.path_join("mira_%d.png" % i)))
		i += 1
	if _quadros.is_empty():
		push_error("Mira: não achei as imagens mira_1.png, mira_2.png... na pasta " + pasta)
		set_process(false)
		return

	var shader := Shader.new()
	shader.code = SHADER_NEGATIVO
	var mat := ShaderMaterial.new()
	mat.shader = shader

	_sprite = Sprite2D.new()
	_sprite.texture = _quadros[0]
	_sprite.material = mat
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art nítida
	_sprite.scale = Vector2.ONE * escala
	add_child(_sprite)
	_atualizar_posicao()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _sprite:
		_atualizar_posicao()


func _process(delta: float) -> void:
	# animação
	_tempo += delta * velocidade_animacao
	_sprite.texture = _quadros[int(_tempo) % _quadros.size()]
	_atualizar_posicao()

	# some na tela de point and click (lá o cursor é a mãozinha) e quando o
	# mouse está "preso" (MOUSE_MODE_CAPTURED)
	var deve_aparecer := not _tem_point_and_click() \
		and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
		and Input.mouse_mode != Input.MOUSE_MODE_CONFINED_HIDDEN
	if deve_aparecer:
		# esconde a setinha do sistema (outros scripts às vezes deixam ela visível)
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		elif Input.mouse_mode == Input.MOUSE_MODE_CONFINED:
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	elif _aparecendo and _tem_point_and_click():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # mostra a mãozinha
	_aparecendo = deve_aparecer
	_sprite.visible = deve_aparecer


func _atualizar_posicao() -> void:
	_sprite.position = get_viewport().get_mouse_position().round()


func _tem_point_and_click() -> bool:
	for tela in get_tree().get_nodes_in_group("tela_point_click"):
		if tela.visible:
			return true
	return false
