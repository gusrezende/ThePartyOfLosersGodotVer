extends CharacterBody3D

const Sons = preload("res://Músicas/sons.gd")

## Ciclo da MissEile:
## 1. SHOOTING  -> parada no lugar dela, atira quando o player está perto (animação "idle")
## 2. CHARGING  -> depois de um tempo, mostra no chão a área da explosão (animação "attack")
## 3. Explode   -> machuca quem ficou dentro do círculo
## 4. TRANSFORMING / CHASING -> se transforma e voa até o player (animações "transformation" e "flying")
## 5. RETURNING -> volta para o lugar dela e começa a chuva de mísseis nas áreas
##                longe dela, obrigando o player a se aproximar de novo

enum State { SHOOTING, CHARGING, TRANSFORMING, CHASING, RETURNING, DEAD }

const MAX_HP = 100
const DETECT_RADIUS = 9.0
const FLY_HEIGHT = 1.5
const CHASE_SPEED = 6.0
const RETURN_SPEED = 4.0
const CHASE_DURATION = 3.0
const SHOT_INTERVAL = 0.5
const SHOT_SPREAD_DEGREES = 8.0
const CONTACT_DAMAGE = 3
const CONTACT_COOLDOWN = 1.0

# --- Explosão ---
const TEMPO_ATE_EXPLOSAO = 6.0      # segundos atirando antes de preparar a explosão
const TEMPO_AVISO_EXPLOSAO = 1.6    # quanto tempo o aviso fica no chão antes de explodir
const RAIO_EXPLOSAO = 6.0
const DANO_EXPLOSAO = 2

# --- Chuva de mísseis (quando ela volta) ---
const DURACAO_CHUVA = 7.0           # quanto tempo dura a chuva depois que ela começa a voltar
const INTERVALO_ONDA = 1.1          # tempo entre cada leva de mísseis
const MISSEIS_POR_ONDA = 4
const RAIO_SEGURO = 7.0             # em volta dela NÃO cai míssil (é pra onde o player deve ir)
const RAIO_MISSIL = 1.8
const TEMPO_AVISO_MISSIL = 1.3
const DANO_MISSIL = 1
const MIRAR_NO_PLAYER = true        # uma das bolas de cada leva cai em cima do player se ele estiver longe

# true = ela toma dano também quando está parada atirando (incentiva o player a chegar perto)
# false = só toma dano enquanto persegue/volta (como era antes)
const VULNERAVEL_PARADA = true

const BOSS_PROJECTILE_SCENE = preload("res://Personagens/MissEile/projectile/boss_projectile.tscn")
const AVISO_CHAO = preload("res://Personagens/MissEile/ataques/aviso_chao.gd")
const EXPLOSAO = preload("res://Personagens/MissEile/ataques/explosao.gd")
const MISSIL = preload("res://Personagens/MissEile/ataques/missil.gd")
const TelaVitoria = preload("res://Cenários/BossMissEile/tela_vitoria.gd")

# Limites da arena (X e Z) onde os mísseis podem cair. Pode ser um retângulo um pouco
# maior que a arena: os mísseis só caem onde tem chão. Se mudar a arena, ajuste no Inspetor.
@export var arena_min := Vector2(-10.5, -5.0)
@export var arena_max := Vector2(10.5, 13.8)

var hp := MAX_HP
var state: int = State.SHOOTING
var player: Node3D = null
var home_position: Vector3
var shot_timer := 0.0
var chase_timer := 0.0
var contact_timer := 0.0
var can_take_damage := false
var shooting_elapsed := 0.0
var charge_timer := 0.0
var chuva_restante := 0.0
var onda_timer := 0.0
var _casa_ajustada := false   # a altura da "casa" é acertada pelo chão no 1º quadro de física

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D


func _ready() -> void:
	# ela VOA: sem lógica de chão/rampa do CharacterBody (não fica presa em degraus e bordas)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	home_position = global_position
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	enter_shooting()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	if not _casa_ajustada:
		_ajustar_casa()
	_atualizar_som_voo()

	match state:
		State.SHOOTING:
			process_shooting(delta)
		State.CHARGING:
			process_charging(delta)
		State.CHASING:
			process_chasing(delta)
		State.RETURNING:
			process_returning(delta)
		State.TRANSFORMING:
			pass
		State.DEAD:
			return

	process_chuva(delta)


# ---------------------------------------------------------------- ATIRANDO

func process_shooting(delta: float) -> void:
	shooting_elapsed += delta
	var distance = global_position.distance_to(player.global_position)

	if distance <= DETECT_RADIUS:
		shot_timer -= delta
		if shot_timer <= 0:
			shot_timer = SHOT_INTERVAL
			shoot_at_player()

	if shooting_elapsed >= TEMPO_ATE_EXPLOSAO:
		enter_charging()


func shoot_at_player() -> void:
	var base_direction = (player.global_position - global_position)
	base_direction.y = 0
	base_direction = base_direction.normalized()

	var random_angle = deg_to_rad(randf_range(-SHOT_SPREAD_DEGREES, SHOT_SPREAD_DEGREES))
	var shot_direction = base_direction.rotated(Vector3.UP, random_angle)

	var projectile = BOSS_PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = Vector3(global_position.x, player.global_position.y, global_position.z)
	projectile.launch(shot_direction)


func enter_shooting() -> void:
	state = State.SHOOTING
	can_take_damage = VULNERAVEL_PARADA
	velocity = Vector3.ZERO
	global_position = home_position + Vector3(0, FLY_HEIGHT, 0)
	sprite.modulate = Color.WHITE
	sprite.play("idle")
	shooting_elapsed = 0.0
	shot_timer = SHOT_INTERVAL


# ---------------------------------------------------------------- EXPLOSÃO

func enter_charging() -> void:
	state = State.CHARGING
	can_take_damage = VULNERAVEL_PARADA
	charge_timer = TEMPO_AVISO_EXPLOSAO
	sprite.play("attack")

	var aviso := AVISO_CHAO.new()
	aviso.configurar(RAIO_EXPLOSAO, TEMPO_AVISO_EXPLOSAO)
	get_tree().current_scene.add_child(aviso)
	aviso.global_position = _ponto_no_chao(global_position.x, global_position.z)


func process_charging(delta: float) -> void:
	charge_timer -= delta
	# fica piscando em vermelho enquanto carrega
	var k := 1.0 - charge_timer / TEMPO_AVISO_EXPLOSAO
	var pisca := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * lerpf(10.0, 35.0, k))
	sprite.modulate = Color(1.0, 1.0 - 0.6 * pisca, 1.0 - 0.6 * pisca)

	if charge_timer <= 0:
		explodir()


func explodir() -> void:
	sprite.modulate = Color.WHITE
	Sons.tocar(self, Sons.EXPLOSAO)
	var centro := _ponto_no_chao(global_position.x, global_position.z)

	var ex := EXPLOSAO.new()
	ex.configurar(RAIO_EXPLOSAO, Color(1.0, 0.45, 0.1), 0.5)
	get_tree().current_scene.add_child(ex)
	ex.global_position = centro

	if _distancia_plana(player.global_position, centro) <= RAIO_EXPLOSAO:
		if player.has_method("take_damage"):
			player.take_damage(DANO_EXPLOSAO, centro)

	# o player se afastou (ou foi arremessado): ela vai atrás dele
	enter_transforming()


# ---------------------------------------------------------------- PERSEGUIÇÃO

func enter_transforming() -> void:
	state = State.TRANSFORMING
	can_take_damage = false
	transform_and_chase()


func transform_and_chase() -> void:
	sprite.play("transformation")
	await sprite.animation_finished
	if state != State.TRANSFORMING or player == null or not is_instance_valid(player):
		return
	# voa na altura dela (acima do chão), e não na altura do player:
	# ela é mais alta que o mago, e na altura dele a colisão dela raspava no chão e travava
	global_position.y = home_position.y + FLY_HEIGHT
	chase_timer = CHASE_DURATION
	contact_timer = 0.0
	can_take_damage = true
	state = State.CHASING
	sprite.play("flying")


func process_chasing(delta: float) -> void:
	chase_timer -= delta
	contact_timer -= delta

	var to_player = player.global_position - global_position
	to_player.y = 0
	var direction = to_player.normalized()

	velocity = direction * CHASE_SPEED
	# mantém a altura de voo
	velocity.y = (home_position.y + FLY_HEIGHT - global_position.y) * 8.0
	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider == player and contact_timer <= 0:
			contact_timer = CONTACT_COOLDOWN
			if player.has_method("take_damage"):
				player.take_damage(CONTACT_DAMAGE, global_position)

	if chase_timer <= 0:
		enter_returning()


# ---------------------------------------------------------------- VOLTANDO + MÍSSEIS

func enter_returning() -> void:
	state = State.RETURNING
	# começa a chuva de mísseis nas áreas longe dela
	chuva_restante = DURACAO_CHUVA
	onda_timer = 0.3


func process_returning(_delta: float) -> void:
	var target = home_position + Vector3(0, FLY_HEIGHT, 0)
	var to_target = target - global_position
	var distance = to_target.length()

	if distance < 0.5:
		enter_shooting()
		return

	velocity = to_target.normalized() * RETURN_SPEED
	move_and_slide()


func process_chuva(delta: float) -> void:
	if chuva_restante <= 0:
		return
	chuva_restante -= delta
	onda_timer -= delta
	if onda_timer <= 0:
		onda_timer = INTERVALO_ONDA
		soltar_onda_de_misseis()


func soltar_onda_de_misseis() -> void:
	var pontos: Array[Vector2] = []

	# uma bola cai em cima do player se ele estiver longe dela
	if MIRAR_NO_PLAYER and _distancia_plana(player.global_position, home_position) > RAIO_SEGURO:
		pontos.append(Vector2(player.global_position.x, player.global_position.z))

	while pontos.size() < MISSEIS_POR_ONDA:
		var p := _ponto_longe_da_boss()
		if p == Vector2.INF:
			break
		pontos.append(p)

	for p in pontos:
		var missil := MISSIL.new()
		missil.configurar(RAIO_MISSIL, TEMPO_AVISO_MISSIL, DANO_MISSIL)
		get_tree().current_scene.add_child(missil)
		missil.global_position = _ponto_no_chao(p.x, p.y)


func _ponto_longe_da_boss() -> Vector2:
	var casa := Vector2(home_position.x, home_position.z)
	for i in 30:
		var p := Vector2(randf_range(arena_min.x, arena_max.x), randf_range(arena_min.y, arena_max.y))
		if p.distance_to(casa) <= RAIO_SEGURO + RAIO_MISSIL * 0.5:
			continue
		# só cai onde tem chão de verdade (a arena não é um retângulo)
		if absf(_ponto_no_chao(p.x, p.y).y - home_position.y) > 1.0:
			continue
		return p
	return Vector2.INF


# ---------------------------------------------------------------- DANO / MORTE

func take_damage(amount: int) -> void:
	if not can_take_damage or state == State.DEAD:
		return
	hp -= amount
	print("MissEile tomou dano, HP restante: ", hp)
	if state != State.CHARGING:
		sprite.modulate = Color(1.0, 0.5, 0.5)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		die()


func die() -> void:
	state = State.DEAD
	can_take_damage = false
	chuva_restante = 0.0
	velocity = Vector3.ZERO
	_mostrar_vitoria()
	queue_free()


func _mostrar_vitoria() -> void:
	var tela = TelaVitoria.new()
	get_tree().current_scene.add_child(tela)
	tela.mostrar()


# ---------------------------------------------------------------- AUXILIARES

func _distancia_plana(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Som de "míssil voando": toca enquanto ela voa atrás do player e para quando ela para.
var _som_voo: AudioStreamPlayer
var _tw_som_voo: Tween

func _atualizar_som_voo() -> void:
	var voando := state == State.CHASING
	if voando and (_som_voo == null or not is_instance_valid(_som_voo)):
		if _tw_som_voo and _tw_som_voo.is_valid():
			_tw_som_voo.kill()
		var som: AudioStream = Sons.MISSIL_VOANDO
		if "loop" in som:
			som.loop = true
		_som_voo = AudioStreamPlayer.new()
		_som_voo.stream = som
		_som_voo.volume_db = Sons.volume_de(som)
		add_child(_som_voo)
		_som_voo.play(0.4)   # pula o silêncio do começo do arquivo
	elif not voando and _som_voo and is_instance_valid(_som_voo) and not _som_voo.has_meta("parando"):
		# some suavemente
		var s := _som_voo
		s.set_meta("parando", true)
		_som_voo = null
		_tw_som_voo = create_tween()
		_tw_som_voo.tween_property(s, "volume_db", -40.0, 0.35)
		_tw_som_voo.tween_callback(s.queue_free)


## A posição inicial dela pode estar alta ou baixa demais em relação ao chão do mapa.
## Aqui a "casa" é colocada exatamente em cima do chão que está embaixo dela.
func _ajustar_casa() -> void:
	_casa_ajustada = true
	var chao := _ponto_no_chao(home_position.x, home_position.z)
	if absf(chao.y - home_position.y) < 30.0:
		home_position.y = chao.y
	if state == State.SHOOTING:
		global_position = home_position + Vector3(0, FLY_HEIGHT, 0)


## Acha a altura do chão no ponto (x, z). Se não achar, usa o pé do player.
func _ponto_no_chao(x: float, z: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 40.0, z), Vector3(x, -40.0, z))
	var excluir: Array[RID] = [get_rid()]
	if player is CollisionObject3D:
		excluir.append((player as CollisionObject3D).get_rid())
	query.exclude = excluir
	var hit := space.intersect_ray(query)
	if hit.has("position"):
		return hit["position"]
	return Vector3(x, player.global_position.y - 1.0, z)
