extends Area3D

const SPEED = 10.0
const LIFETIME = 5.0
const EXPLOSION_RADIUS = 3.0
const EXPLOSION_DAMAGE = 3

var direction := Vector3.ZERO
var has_exploded := false


func _ready() -> void:
	await get_tree().create_timer(LIFETIME).timeout
	explode()


func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta


func launch(dir: Vector3) -> void:
	direction = dir.normalized()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return  # ignora quem jogou o cogumelo
	explode()


func explode() -> void:
	if has_exploded:
		return
	has_exploded = true

	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= EXPLOSION_RADIUS:
			if enemy.has_method("take_damage"):
				enemy.take_damage(EXPLOSION_DAMAGE)

	queue_free()
