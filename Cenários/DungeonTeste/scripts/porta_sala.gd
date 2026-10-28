extends Area3D
## Porta para uma sala (ex.: as salas de point-and-click).
## Se "cena_destino" estiver preenchida, apertar E perto da porta leva para a sala.
## Se estiver vazia, mostra que a sala está em construção.

@export_file("*.tscn") var cena_destino := ""
@export var nome_sala := "Sala"
@export var tecla := KEY_E

var _perto := false
var _texto: Label3D


func _ready() -> void:
	body_entered.connect(_on_entrou)
	body_exited.connect(_on_saiu)
	_texto = Label3D.new()
	_texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_texto.pixel_size = 0.012
	_texto.outline_size = 8
	_texto.position = Vector3(0, 3.0, 0)
	_texto.visible = false
	add_child(_texto)


func _on_entrou(corpo: Node3D) -> void:
	if corpo.is_in_group("player"):
		_perto = true
		_atualizar()


func _on_saiu(corpo: Node3D) -> void:
	if corpo.is_in_group("player"):
		_perto = false
		_atualizar()


func _atualizar() -> void:
	_texto.visible = _perto
	if cena_destino == "":
		_texto.text = "%s\n(em construção)" % nome_sala
	else:
		_texto.text = "%s\n[E] entrar" % nome_sala


func _unhandled_input(event: InputEvent) -> void:
	if not _perto or cena_destino == "":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == tecla:
		Transicao.ir_para(cena_destino)
