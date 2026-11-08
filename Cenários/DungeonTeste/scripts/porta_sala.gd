extends Area3D
## Porta para uma sala.
## - "tela_point_and_click" preenchida: apertar E abre a tela de point and click
##   POR CIMA da dungeon (a dungeon fica pausada e nada se perde ao voltar).
## - "cena_destino" preenchida: apertar E troca de cena (vai para outra fase).
## - As duas vazias: mostra que a sala está em construção.

## Cena da tela de point and click (ex.: res://Cenários/SalaPointClick/sala_point_click.tscn)
@export_file("*.tscn") var tela_point_and_click := ""
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
	_texto.position = Vector3(0, 1.4, 0)
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
	if cena_destino == "" and tela_point_and_click == "":
		_texto.text = "%s\n(em construção)" % nome_sala
	else:
		_texto.text = "%s\n[E] entrar" % nome_sala


func _unhandled_input(event: InputEvent) -> void:
	if not _perto or (cena_destino == "" and tela_point_and_click == ""):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == tecla:
		get_viewport().set_input_as_handled()
		if tela_point_and_click != "":
			if get_tree().get_nodes_in_group("tela_point_click").is_empty():
				get_tree().root.add_child(load(tela_point_and_click).instantiate())
		else:
			Transicao.ir_para(cena_destino)
