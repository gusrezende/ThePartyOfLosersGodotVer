extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	# Voltou pro menu (venceu, perdeu ou saiu): o próximo jogo começa do zero
	GameState.resetar()                                  # vida cheia de novo
	var quest := get_node_or_null("/root/QuestManager")
	if quest and quest.has_method("resetar_missao"):
		quest.resetar_missao()                           # missão das plantas do zero
	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	play_button.grab_focus()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/Cinematic/cinematic.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
