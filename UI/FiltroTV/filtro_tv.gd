extends CanvasLayer
## AUTOLOAD: filtro de TV de tubo por cima do jogo INTEIRO (menu, cinemática, fases...).
##
## F2 liga/desliga o filtro.
## Para ajustar cada efeito (curvatura, linhas, chiado...), abra o arquivo
## filtro_tv.gdshader nesta pasta: cada efeito tem um número no começo do arquivo.

## Começa ligado?
@export var ligado := true

var _tela: ColorRect


func _ready() -> void:
	layer = 127   # por cima de tudo (só a mira fica acima, para ela seguir o mouse certinho)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tela = ColorRect.new()
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE   # não atrapalha cliques
	var mat := ShaderMaterial.new()
	mat.shader = load(get_script().resource_path.get_base_dir().path_join("filtro_tv.gdshader"))
	_tela.material = mat
	add_child(_tela)
	visible = ligado


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		alternar()


## Liga/desliga o filtro
func alternar() -> void:
	ligado = not ligado
	visible = ligado
