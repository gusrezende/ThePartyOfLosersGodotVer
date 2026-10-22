extends Area3D

const CENA_BOSS := "res://BossMissEile/bossMissEile.tscn"

var _usada := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _usada or not body.is_in_group("player"):
		return
	_usada = true
	Transicao.ir_para(CENA_BOSS, 1.0)
