extends Area3D
## Projétil que voa reto: usado pela MissEile (bola de fogo) e pelos cogumelos
## atiradores (prato de comida, em prato_projetil.tscn).
## O desenho (nó "Fogo", pode ser Sprite3D ou AnimatedSprite3D) fica sempre virado
## para a câmera. Ele pode apontar para a direção do voo (seguir_direcao) ou só
## girar no lugar (desenhos redondos, como o prato e a bola de fogo nova).

const SPEED = 12.0
const LIFETIME = 4.0
const DAMAGE = 1

## Ângulo (em graus) para onde aponta a "traseira" no desenho original
## (0 = direita, 90 = cima). Bola de fogo: o rabo aponta para cima-direita (45°).
## Prato: as linhas de velocidade apontam para baixo-esquerda (212°).
@export var angulo_rabo_desenho := 45.0
## Quanto o desenho pulsa/balança (0 = parado)
@export var tremulacao := 1.0
## true = quando voa para a ESQUERDA da tela, o desenho é espelhado em vez de
## girar (assim o prato nunca fica de cabeça pra baixo). Use em desenhos que têm
## "lado de cima" (prato); a bola de fogo pode girar livre.
@export var espelhar_para_esquerda := false
## true = o desenho aponta para onde voa; false = só gira no lugar
@export var seguir_direcao := true
## Giro contínuo do desenho, em graus por segundo (0 = não gira)
@export var girar_graus_por_segundo := 0.0

var direction := Vector3.ZERO

@onready var _fogo: SpriteBase3D = $Fogo
var _t := randf() * 10.0
var _escala_base := Vector3.ONE


func _ready() -> void:
	_escala_base = _fogo.scale
	if _fogo is AnimatedSprite3D:
		(_fogo as AnimatedSprite3D).play()
	_virar_para_camera()
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta


func _process(delta: float) -> void:
	_t += delta
	_virar_para_camera()
	# tremulação do fogo
	var pulso := 1.0 + (0.07 * sin(_t * 28.0) + 0.03 * sin(_t * 47.0)) * tremulacao
	_fogo.scale = _escala_base * pulso


func _virar_para_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var b := cam.global_basis.orthonormalized()
	var giro := deg_to_rad(girar_graus_por_segundo) * _t
	if seguir_direcao and direction.length_squared() > 0.0001:
		# direção do voo como aparece na tela
		var na_tela := atan2(direction.dot(b.y), direction.dot(b.x))
		var rabo := angulo_rabo_desenho
		var para_esquerda := espelhar_para_esquerda and cos(na_tela) < 0.0
		_fogo.flip_h = para_esquerda
		if para_esquerda:
			rabo = 180.0 - angulo_rabo_desenho   # no desenho espelhado o rabo vai pro outro lado
		# a traseira aponta para o lado contrário ao voo
		giro += na_tela + PI - deg_to_rad(rabo)
	giro += deg_to_rad(4.0) * sin(_t * 17.0) * tremulacao   # balancinho
	_fogo.global_basis = b * Basis(Vector3.BACK, giro)


func launch(dir: Vector3) -> void:
	direction = dir.normalized()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(DAMAGE)
		queue_free()
