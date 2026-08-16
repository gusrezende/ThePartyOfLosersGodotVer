extends CanvasLayer

@onready var heart1: TextureProgressBar = $HeartsContainer/Heart1
@onready var heart2: TextureProgressBar = $HeartsContainer/Heart2
@onready var heart3: TextureProgressBar = $HeartsContainer/Heart3

var hearts: Array[TextureProgressBar] = []


func _ready() -> void:
	hearts = [heart1, heart2, heart3]

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		player.hp_changed.connect(_on_hp_changed)
		_on_hp_changed(player.hp, player.MAX_HP)


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	var hp_per_heart = ceil(max_hp / float(hearts.size()))

	for i in hearts.size():
		var heart_min = i * hp_per_heart
		var heart_hp = clamp(current_hp - heart_min, 0, hp_per_heart)
		hearts[i].value = (heart_hp / hp_per_heart) * 100.0
