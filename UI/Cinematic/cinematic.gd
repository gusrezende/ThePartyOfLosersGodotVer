extends Control

@onready var video: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_button: Button = $SkipButton

var _acabou := false

func _ready() -> void:
	video.finished.connect(_terminar)
	skip_button.pressed.connect(_terminar)
	video.play()

func _terminar() -> void:
	if _acabou:
		return
	_acabou = true
	video.stop()
	get_tree().change_scene_to_file("res://Cenários/DungeonTeste/dungeon_teste.tscn")  # confira o caminho real
