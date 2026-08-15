extends Area3D

const SPEED = 15.0
const LIFETIME = 3.0  # segundos até desaparecer sozinho

var direction := Vector3.ZERO

func _ready() -> void:
	# Destrói o projétil sozinho depois de alguns segundos, caso não acerte nada
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta

func launch(dir: Vector3) -> void:
	direction = dir.normalized()

func _on_body_entered(body: Node3D) -> void:
	# Aqui depois você pode aplicar dano, tocar efeito, etc.
	queue_free()
