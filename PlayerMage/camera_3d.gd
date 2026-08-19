extends Camera3D

const FOLLOW_SPEED = 4.0  # quanto maior, mais rápido ela alcança o player

var player: Node3D = null
var offset: Vector3


func _ready() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		offset = global_position - player.global_position


func _process(delta: float) -> void:
	if player == null:
		return

	var target_position = player.global_position + offset
	global_position = global_position.lerp(target_position, FOLLOW_SPEED * delta)
