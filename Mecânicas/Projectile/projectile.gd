extends Area3D

const Sons = preload("res://Músicas/sons.gd")

const SPEED = 15.0
const DAMAGE = 1
## ALCANCE do tiro, em metros: depois dessa distância a bola some
const ALCANCE = 9.0
## Nome da animação a tocar. Se deixar "" (vazio), toca a animação que estiver
## selecionada no AnimatedSprite3D no Inspetor.
const ANIMACAO = "Fire Ball"

var direction := Vector3.ZERO
var _percorrido := 0.0
var _sumindo := false


func _ready() -> void:
	_tocar_animacao()


func _physics_process(delta: float) -> void:
	var antes := global_position
	var depois := antes + direction * SPEED * delta
	# Bateu numa parede no caminho? Some sem fazer som (e não atravessa a parede
	# para acertar inimigos do outro lado). O Area3D sozinho não percebe paredes.
	var consulta := PhysicsRayQueryParameters3D.create(antes, depois)
	consulta.collide_with_areas = false
	var excluir: Array[RID] = []
	for p in get_tree().get_nodes_in_group("player"):
		if p is CollisionObject3D:
			excluir.append(p.get_rid())
	consulta.exclude = excluir
	var acerto := get_world_3d().direct_space_state.intersect_ray(consulta)
	if acerto.has("collider"):
		var corpo: Object = acerto["collider"]
		if corpo is Node and (corpo as Node).is_in_group("enemy"):
			_on_body_entered(corpo as Node3D)   # inimigo: dano + som de hit
		else:
			_destruir_na_parede(acerto["position"], acerto["normal"])   # parede: se desfaz
		return
	global_position = depois
	_percorrido += SPEED * delta
	if _percorrido >= ALCANCE and not _sumindo:
		_sumir_no_ar()


func launch(dir: Vector3) -> void:
	direction = dir.normalized()


var _acertou := false


func _on_body_entered(body: Node3D) -> void:
	if _acertou:
		return
	if body.is_in_group("enemy"):
		_acertou = true
		Sons.tocar(self, Sons.HIT)
		if body.has_method("take_damage"):
			var vida_antes = body.get("hp")
			body.take_damage(DAMAGE)
			# só treme se o dano pegou (a MissEile às vezes está invulnerável)
			if vida_antes == null or body.get("hp") != vida_antes:
				tremer(body)
		queue_free()


# ---------------------------------------------------------------- TREMIDA
## Força da tremida, em metros (para os lados)
const TREMIDA_FORCA = 0.12
## Quanto tempo a tremida dura, em segundos
const TREMIDA_TEMPO = 0.25

## Faz o desenho do inimigo tremer para os lados por um instante.
## Mexe só no desenho (o "offset" do sprite), então não atrapalha o movimento nem a colisão.
static func tremer(corpo: Node) -> void:
	if corpo == null or not is_instance_valid(corpo):
		return
	for s in corpo.find_children("*", "SpriteBase3D", true, false):
		var sprite := s as SpriteBase3D
		# se já estava tremendo, para a tremida anterior e volta ao lugar certo
		if sprite.has_meta("tremida"):
			var antiga: Tween = sprite.get_meta("tremida")
			if antiga and antiga.is_valid():
				antiga.kill()
			sprite.offset = sprite.get_meta("offset_original")
		else:
			sprite.set_meta("offset_original", sprite.offset)
		var base: Vector2 = sprite.get_meta("offset_original")
		var forca := TREMIDA_FORCA / maxf(sprite.pixel_size, 0.0001)   # metros -> pixels do desenho
		var passos := 6
		var tw := sprite.create_tween()
		for i in passos:
			var lado := 1.0 if i % 2 == 0 else -1.0
			var k := 1.0 - float(i) / passos   # vai diminuindo
			tw.tween_property(sprite, "offset", base + Vector2(lado * forca * k, randf_range(-0.3, 0.3) * forca * k), TREMIDA_TEMPO / passos)
		tw.tween_property(sprite, "offset", base, TREMIDA_TEMPO / passos)
		tw.tween_callback(func():
			if is_instance_valid(sprite):
				sprite.remove_meta("tremida"))
		sprite.set_meta("tremida", tw)


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


## A bola de fogo se desfaz na parede: clarão + faíscas (sem som de hit).
func _destruir_na_parede(ponto: Vector3, normal: Vector3) -> void:
	set_physics_process(false)
	# a parede tem colisão dos dois lados: garante que a "frente" aponta para quem atirou
	if normal == Vector3.ZERO or normal.dot(direction) > 0.0:
		normal = -direction
	var efeito := Faiscas.new()
	efeito.normal = normal
	get_tree().current_scene.add_child(efeito)
	efeito.global_position = ponto + normal * 0.2
	queue_free()


## Clarão + faíscas laranjas que voam para fora da parede e somem. Se apaga sozinho.
class Faiscas extends Node3D:
	var normal := Vector3.UP
	const DURACAO := 0.4
	var _t := 0.0
	var _pedacos: Array[MeshInstance3D] = []
	var _vel: Array[Vector3] = []
	var _clarao: MeshInstance3D
	var _mat_clarao: StandardMaterial3D

	func _ready() -> void:
		var lado := normal.cross(Vector3.UP)
		if lado.length() < 0.1:
			lado = Vector3.RIGHT
		lado = lado.normalized()
		for i in 10:
			var m := MeshInstance3D.new()
			var esf := SphereMesh.new()
			esf.radius = randf_range(0.05, 0.1)
			esf.height = esf.radius * 2.0
			esf.radial_segments = 6
			esf.rings = 3
			m.mesh = esf
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1.0, randf_range(0.45, 0.95), randf_range(0.1, 0.35))
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(m)
			_pedacos.append(m)
			var v := normal * randf_range(2.0, 5.0) + lado * randf_range(-3.5, 3.5) + Vector3.UP * randf_range(0.5, 3.5)
			_vel.append(v)
		_clarao = MeshInstance3D.new()
		var bola := SphereMesh.new()
		bola.radius = 0.5
		bola.height = 1.0
		_clarao.mesh = bola
		_mat_clarao = StandardMaterial3D.new()
		_mat_clarao.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_clarao.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_clarao.albedo_color = Color(1.0, 0.85, 0.4, 0.8)
		_clarao.material_override = _mat_clarao
		_clarao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_clarao)

	func _process(delta: float) -> void:
		_t += delta
		var k := clampf(_t / DURACAO, 0.0, 1.0)
		for i in _pedacos.size():
			_vel[i].y -= 14.0 * delta
			_pedacos[i].position += _vel[i] * delta
			_pedacos[i].scale = Vector3.ONE * (1.0 - k)
		var r := lerpf(0.2, 0.55, 1.0 - pow(1.0 - k, 3.0))
		_clarao.scale = Vector3.ONE * r
		_mat_clarao.albedo_color.a = 0.6 * (1.0 - k)
		if _t >= DURACAO:
			queue_free()


## Chegou no alcance máximo: encolhe rapidinho e some
func _sumir_no_ar() -> void:
	_sumindo = true
	set_physics_process(false)
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.12)
	tw.tween_callback(queue_free)
