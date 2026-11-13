extends CanvasLayer

const Sons = preload("res://Músicas/sons.gd")

# true = estrela (estilo Mario 64), false = círculo
@export var usar_estrela := true

const SHADER_CODE := """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0; // 0 = aberto, 1 = fechado
uniform vec2 centro = vec2(0.5, 0.5);
uniform vec2 tamanho_tela = vec2(1920.0, 1080.0);
uniform bool estrela = true;

float sd_estrela(vec2 p, float r, float n, float m) {
	float an = 3.141593 / n;
	float en = 3.141593 / m;
	vec2 acs = vec2(cos(an), sin(an));
	vec2 ecs = vec2(cos(en), sin(en));
	float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
	p = length(p) * vec2(cos(bn), abs(sin(bn)));
	p -= r * acs;
	p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
	return length(p) * sign(p.x);
}

void fragment() {
	vec2 p = (UV - centro) * vec2(tamanho_tela.x / tamanho_tela.y, 1.0);
	// tamanho exato para a estrela, aberta, cobrir até o canto mais longe da tela
	// (assim ela aparece desde o comecinho da animação, sem "pular" parte dela)
	vec2 asp = vec2(tamanho_tela.x / tamanho_tela.y, 1.0);
	float longe = 0.0;
	longe = max(longe, length((vec2(0.0, 0.0) - centro) * asp));
	longe = max(longe, length((vec2(1.0, 0.0) - centro) * asp));
	longe = max(longe, length((vec2(0.0, 1.0) - centro) * asp));
	longe = max(longe, length((vec2(1.0, 1.0) - centro) * asp));
	float raio_max = estrela ? longe / 0.45 : longe * 1.02;   // 0.45 = "cintura" da estrela
	float raio = mix(raio_max, 0.0, progress);
	float d;
	if (estrela) {
		float a = progress * 2.5;               // a estrela gira enquanto fecha
		mat2 rot = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
		d = sd_estrela(rot * p, raio, 5.0, 3.0);
	} else {
		d = length(p) - raio;
	}
	float alpha = smoothstep(-0.003, 0.003, d);
	if (progress > 0.995) alpha = 1.0;
	if (progress < 0.005) alpha = 0.0;      // aberta: não sobra nada na tela
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _ocupado := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("progress", 0.0)

	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.visible = false
	add_child(_rect)


func _centro_do_player() -> Vector2:
	# Posição do player na tela (0..1). Se não achar, usa o centro.
	var vp := get_viewport()
	var cam := vp.get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if cam and player and not cam.is_position_behind(player.global_position):
		var pos := cam.unproject_position(player.global_position + Vector3(0, 1, 0))
		var tam := vp.get_visible_rect().size
		return Vector2(pos.x / tam.x, pos.y / tam.y)
	return Vector2(0.5, 0.5)


func _preparar() -> void:
	_rect.visible = true
	_mat.set_shader_parameter("centro", _centro_do_player())
	_mat.set_shader_parameter("tamanho_tela", get_viewport().get_visible_rect().size)
	_mat.set_shader_parameter("estrela", usar_estrela)


func _animar(alvo: float, duracao: float, easing: Tween.EaseType) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(easing)
	tween.tween_property(_mat, "shader_parameter/progress", alvo, duracao)
	await tween.finished
	if alvo <= 0.0:
		_rect.visible = false   # terminou de abrir: esconde de vez a camada preta


func ir_para(destino, duracao := 0.8) -> void:
	if _ocupado:
		return
	_ocupado = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	_preparar()
	Sons.tocar_transicao(self)                       # som da estrela + música para na hora
	await _animar(1.0, duracao, Tween.EASE_IN)      # fecha em volta do player

	get_tree().paused = false
	if destino is PackedScene:
		get_tree().change_scene_to_packed(destino)
	else:
		get_tree().change_scene_to_file(destino)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout      # segura a tela preta, como no N64
	Sons.retomar_musica(self)                        # começa a música da cena nova

	_preparar()                                      # recalcula o centro na cena nova
	await _animar(0.0, duracao, Tween.EASE_OUT)      # reabre em volta do player

	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ocupado = false
