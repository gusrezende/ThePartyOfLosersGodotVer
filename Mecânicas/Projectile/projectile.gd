extends Area3D

const SPEED = 15.0
const LIFETIME = 3.0
const DAMAGE = 1
## Nome da animação a tocar. Se deixar "" (vazio), toca a animação que estiver
## selecionada no AnimatedSprite3D no Inspetor.
const ANIMACAO = "Fire Ball"

var direction := Vector3.ZERO


func _ready() -> void:
	_tocar_animacao()
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta


func launch(dir: Vector3) -> void:
	direction = dir.normalized()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE)
		queue_free()


## Acha o AnimatedSprite3D do projétil (qualquer nome) e toca a animação.
func _tocar_animacao() -> void:
	var sprites := find_children("*", "AnimatedSprite3D", true, false)
	if sprites.is_empty():
		return
	var sprite := sprites[0] as AnimatedSprite3D
	if sprite.sprite_frames == null:
		return
	var nome := ANIMACAO if ANIMACAO != "" else String(sprite.animation)
	if sprite.sprite_frames.has_animation(nome):
		sprite.play(nome)
	else:
		sprite.play()
