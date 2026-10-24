extends Node

var player_hp := -1   # -1 = ainda não definido (começa com a vida máxima)
var pulou_boss := false

func resetar() -> void:
	player_hp = -1
	pulou_boss = false
