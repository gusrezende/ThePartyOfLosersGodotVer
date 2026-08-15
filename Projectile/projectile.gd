extends Area3D

const SPEED = 15.0
const LIFETIME = 3.0
const DAMAGE = 1

var direction := Vector3.ZERO

func _ready() -> void:
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta

func launch(dir: Vector3) -> void:
	direction = dir.normalized()

func _on_body_entered(body: Node3D) -> void:
	print("Projétil tocou em: ", body.name)
	print("Está no grupo 'enemy'? ", body.is_in_group("enemy"))
	print("Tem o método take_damage? ", body.has_method("take_damage"))

	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE)
		queue_free()
