extends CharacterBody3D
## GORDO DO REFEITÓRIO (mini chefe)
##
## Fica na frente da porta do chefe e não deixa ninguém passar.
##
## 1) Enquanto ainda tiver inimigos no refeitório, ele está "ocupado cozinhando":
##    não conversa e os tiros não fazem nada nele.
## 2) Depois que todos os inimigos do refeitório morrerem, dá para:
##    - FALAR com ele [E]: ele oferece uma sopa de plantas "do bem", feita na hora,
##      com as 5 plantas que o player está carregando.
##        • Aceitou e tem as 5 plantas -> ganha a sopa: vida cheia. Ele sai da frente da porta.
##        • Aceitou sem as plantas     -> ele pede para voltar com as plantas.
##        • Recusou                    -> ele fica OFENDIDO e vira mini chefe.
##    - ATACAR ele (tiro ou cogumelo explosivo): também fica ofendido e vira mini chefe.
## 3) Mini chefe: joga gororoba no player (dano alto) e anda para os lados na frente
##    da porta. Ao morrer, a porta fica livre.
##
## O "refeitório" é achado sozinho: é a ZONA DE CÂMERA onde o Gordo está.
## (Se não tiver zona, ele usa os inimigos num raio de "raio_arena" metros.)
##
## Animações (no AnimatedSprite3D "Sprite"):
##   "idle"    = gordo 1 e 2 (normal)
##   "raiva"   = gordo raiva 1 e 2 (depois de irritado)
##   "jogando" = gordo jogando projétil 1 e 2 (atacando)

const Sons = preload("res://Músicas/sons.gd")
const CaixaDialogo = preload("res://UI/Dialogo/caixa_dialogo.gd")
const BarraVida = preload("res://Personagens/MissEile/barra_vida_boss.gd")
const GOROROBA = preload("res://Personagens/GordoRefeitorio/gororoba.tscn")

enum Estado { OCUPADO, CALMO, CONVERSANDO, AMIGO, BRAVO, MORTO }

@export var nome := "Chefe do Refeitório"

@export_group("Mini chefe")
## Vida do mini chefe (o tiro do mago tira 1, o cogumelo explosivo tira 3)
@export var vida_maxima := 20
## Tempo entre um ataque e outro (segundos)
@export var intervalo_ataque := 1.7
## Tempo entre ataques quando ele está com menos da metade da vida
@export var intervalo_ataque_furioso := 1.1
## Abertura do leque de 3 gororobas (graus entre uma e outra)
@export var abertura_leque := 20.0
## Dano quando o player encosta nele bravo
@export var dano_encostar := 1
## Quanto ele anda para os lados (metros, para cada lado da posição inicial)
@export var passeio_lateral := 3.5
@export var velocidade := 1.3

@export_group("Arena")
## Ligado: só dá para falar com ele / atacar ele depois de matar os inimigos do refeitório.
## Desligado: dá para falar ou atacar desde o começo.
@export var esperar_arena_limpa := false
## Usado só se ele não estiver dentro de uma Zona de Câmera
@export var raio_arena := 16.0

@export_group("Barreira")
## Parede invisível ATRÁS dele, para ninguém passar por trás e chegar na porta.
## Some quando ele sai da frente (sopa) ou morre.
@export var barreira := true
## Quantos metros para trás a barreira vai (pode entrar na parede, sem problema)
@export var barreira_profundidade := 8.0
## Largura extra para cada lado, além do corpo dele e do quanto ele anda
@export var barreira_folga := 0.5

@export_group("Depois da sopa")
## Para onde ele anda (a partir de onde está) para liberar a porta
@export var sair_da_frente := Vector3(3.6, 0, 1.2)

var hp := 20
var estado := Estado.OCUPADO

var _player: Node3D
var _zona_arena: Node
var _jogador_perto := false
var _ja_conversou := false
var _casa := Vector3.ZERO
var _recarga := 1.2
var _atacando := false
var _recarga_encostar := 0.0
var _barra: CanvasLayer
var _checar := 0.0
var _barreira: StaticBody3D
var _gravidade: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var sprite: AnimatedSprite3D = $Sprite
@onready var _area: Area3D = $AreaConversa
@onready var _dica: Label3D = $Dica
@onready var _mao: Marker3D = $Mao


func _ready() -> void:
	add_to_group("gordo_refeitorio")
	hp = vida_maxima
	_casa = global_position
	_player = get_tree().get_first_node_in_group("player") as Node3D
	_area.body_entered.connect(_on_area_entrou)
	_area.body_exited.connect(_on_area_saiu)
	_dica.visible = false
	sprite.play("idle")
	# acha o refeitório: a zona de câmera onde ele está
	for z in get_tree().get_nodes_in_group("zona_camera"):
		if z.has_method("contem") and z.contem(global_position):
			_zona_arena = z
			break
	_atualizar_estado_arena()
	if barreira:
		_criar_barreira()


# ---------------------------------------------------------------- BARREIRA

## Cria a parede invisível atrás dele (fica parada, mesmo quando ele anda para os lados)
func _criar_barreira() -> void:
	var corpo := $CollisionShape3D as CollisionShape3D
	var caixa := corpo.shape as BoxShape3D if corpo else null
	var largura := (caixa.size.x if caixa else 4.4) + passeio_lateral * 2.0 + barreira_folga * 2.0
	var costas := (corpo.position.z - caixa.size.z * 0.5) if caixa else -2.3   # onde fica as costas dele
	var forma := BoxShape3D.new()
	forma.size = Vector3(largura, 4.0, barreira_profundidade)
	var cs := CollisionShape3D.new()
	cs.shape = forma
	_barreira = StaticBody3D.new()
	_barreira.name = "BarreiraAtras"
	_barreira.top_level = true
	_barreira.collision_layer = 1
	_barreira.add_child(cs)
	add_child(_barreira)
	# começa um pouquinho dentro do corpo dele, para não sobrar fresta
	_barreira.global_transform = global_transform * Transform3D(Basis.IDENTITY,
		Vector3(0, 2.0, costas + 0.3 - barreira_profundidade * 0.5))
	add_collision_exception_with(_barreira)   # ele mesmo não bate nela


func _remover_barreira() -> void:
	if _barreira and is_instance_valid(_barreira):
		_barreira.queue_free()
	_barreira = null


# ---------------------------------------------------------------- ARENA

## true se ainda tem inimigo vivo no refeitório
func _tem_inimigos_na_arena() -> bool:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not (e is Node3D) or not is_instance_valid(e):
			continue
		if e.get("morto") == true:
			continue
		var p: Vector3 = (e as Node3D).global_position
		if _zona_arena and is_instance_valid(_zona_arena):
			if _zona_arena.contem(p):
				return true
		elif p.distance_to(global_position) <= raio_arena:
			return true
	return false


func _atualizar_estado_arena() -> void:
	if estado != Estado.OCUPADO:
		return
	if not esperar_arena_limpa or not _tem_inimigos_na_arena():
		estado = Estado.CALMO
		add_to_group("enemy")   # agora os tiros acertam ele (e deixam ele bravo)
		_atualizar_dica()


# ---------------------------------------------------------------- LOOP

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravidade * delta
	else:
		velocity.y = 0.0
	velocity.x = 0.0
	velocity.z = 0.0

	if estado == Estado.OCUPADO:
		_checar -= delta
		if _checar <= 0.0:
			_checar = 0.25
			_atualizar_estado_arena()
	elif estado == Estado.BRAVO:
		_lutar(delta)

	move_and_slide()


func _lutar(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# anda devagar para os lados, acompanhando o player, sem sair da frente da porta
	var alvo_x := clampf(_player.global_position.x, _casa.x - passeio_lateral, _casa.x + passeio_lateral)
	var dx := alvo_x - global_position.x
	if absf(dx) > 0.3 and not _atacando:
		velocity.x = signf(dx) * velocidade
	# volta para a linha da porta se foi empurrado
	velocity.z = clampf((_casa.z - global_position.z) * 3.0, -velocidade, velocidade)

	# dano por encostar
	_recarga_encostar -= delta
	var d := _player.global_position - global_position
	d.y = 0.0
	if _recarga_encostar <= 0.0 and absf(d.x) < 2.5 and absf(d.z) < 1.5:
		_recarga_encostar = 1.0
		if _player.has_method("take_damage"):
			_player.take_damage(dano_encostar, global_position)

	# ataque
	_recarga -= delta
	if _recarga <= 0.0 and not _atacando:
		var furioso := hp <= vida_maxima / 2
		_recarga = intervalo_ataque_furioso if furioso else intervalo_ataque
		_atacar(furioso)


func _atacar(furioso: bool) -> void:
	_atacando = true
	sprite.play("jogando")
	sprite.frame = 0
	sprite.pause()
	await get_tree().create_timer(0.35, false).timeout     # prepara o arremesso
	if estado != Estado.BRAVO:
		_atacando = false
		return
	sprite.frame = 1                                        # solta a gororoba
	var dir := _direcao_player()
	# alterna: uma gororoba mirada / leque de 3 (furioso: leque sempre)
	if furioso or randf() < 0.45:
		for ang in [-abertura_leque, 0.0, abertura_leque]:
			_jogar(dir.rotated(Vector3.UP, deg_to_rad(ang)))
	else:
		_jogar(dir)
	Sons.tocar(self, Sons.COMIDA)
	await get_tree().create_timer(0.3, false).timeout
	if estado == Estado.BRAVO:
		sprite.play("raiva")
	_atacando = false


func _direcao_player() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		return Vector3.BACK
	var d := _player.global_position - _mao.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.BACK


func _jogar(dir: Vector3) -> void:
	var g := GOROROBA.instantiate()
	_cena().add_child(g)
	var altura := _player.global_position.y if _player and is_instance_valid(_player) else _mao.global_position.y
	g.global_position = Vector3(_mao.global_position.x, altura, _mao.global_position.z) + dir * 0.6
	g.launch(dir)


## Onde colocar coisas novas (gororoba, barra de vida...)
func _cena() -> Node:
	var cena := get_tree().current_scene
	return cena if cena else get_parent()


# ---------------------------------------------------------------- DANO

func take_damage(amount: int) -> void:
	match estado:
		Estado.CALMO:
			hp -= amount
			_piscar()
			_ficar_bravo("EI!! VOCÊ ME ATACOU?! AGORA VAI COMER GOROROBA!")
		Estado.BRAVO:
			hp -= amount
			_piscar()
			if _barra and is_instance_valid(_barra):
				_barra.atualizar(hp)
			if hp <= 0:
				_morrer()
		_:
			pass   # ocupado / amigo / morto: não leva dano


func _piscar() -> void:
	sprite.modulate = Color(1.0, 0.5, 0.5)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _ficar_bravo(grito: String) -> void:
	if estado == Estado.BRAVO or estado == Estado.MORTO:
		return
	estado = Estado.BRAVO
	add_to_group("enemy")
	_recarga = 1.0
	sprite.play("raiva")
	_mostrar_dica(grito)
	get_tree().create_timer(2.5, false).timeout.connect(func():
		if estado == Estado.BRAVO:
			_dica.visible = false)
	_barra = BarraVida.new()
	_barra.configurar(nome, vida_maxima)
	_cena().add_child(_barra)
	_barra.atualizar(hp)


func _morrer() -> void:
	estado = Estado.MORTO
	_remover_barreira()
	remove_from_group("enemy")
	_dica.visible = false
	if _barra and is_instance_valid(_barra):
		_barra.sumir()
	for f in find_children("*", "CollisionShape3D", true, false):
		f.set_deferred("disabled", true)
	var som := Sons.tocar(self, Sons.COGUMELO_MORRE)
	if som:
		som.pitch_scale = 0.7   # voz mais grossa
	sprite.play("raiva")
	sprite.pause()
	# pisca e afunda no chão
	var tw := create_tween()
	for i in 4:
		tw.tween_property(sprite, "modulate", Color(3, 3, 3), 0.07)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.07)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.8)
	tw.parallel().tween_property(sprite, "position:y", sprite.position.y - 1.2, 0.8)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- CONVERSA

func _on_area_entrou(body: Node3D) -> void:
	if body.is_in_group("player"):
		_jogador_perto = true
		_atualizar_dica()


func _on_area_saiu(body: Node3D) -> void:
	if body.is_in_group("player"):
		_jogador_perto = false
		_atualizar_dica()


func _atualizar_dica() -> void:
	if estado == Estado.BRAVO or estado == Estado.MORTO:
		return
	if not _jogador_perto:
		_dica.visible = false
		return
	match estado:
		Estado.OCUPADO:
			_mostrar_dica("Tô ocupado cozinhando!\n(derrote os inimigos do refeitório)")
		Estado.CALMO:
			_mostrar_dica("[E] Falar")
		Estado.AMIGO:
			_mostrar_dica("Bom apetite, freguês!")
		_:
			_dica.visible = false


func _mostrar_dica(texto: String) -> void:
	_dica.text = texto
	_dica.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if estado != Estado.CALMO or not _jogador_perto:
		return
	if CaixaDialogo.tem_conversa_aberta(get_tree()):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_conversar()


func _conversar() -> void:
	estado = Estado.CONVERSANDO
	_dica.visible = false
	var conversa = CaixaDialogo.abrir(self, nome, _player, self)

	if not _ja_conversou:
		_ja_conversou = true
		await conversa.falar("Ô, freguês! Chegou bem na hora do rango!")
		await conversa.falar("Limpou o refeitório pra mim, é? Gostei de você.")

	var escolha: int = await conversa.perguntar(
		"Tô fazendo uma sopinha de plantas... do BEM, sabe? Feita na hora! Aceita uma?",
		["Aceito a sopa!", "Não quero essa gororoba.", "Agora não."]
	)

	match escolha:
		0:
			var tenho := _plantas_que_o_player_tem()
			if tenho >= _total_plantas():
				await conversa.falar("Opa! Só preciso dessas %d plantinhas que você tá segurando aí..." % _total_plantas())
				_pegar_plantas()
				await conversa.falar("*mexe o caldeirão* ... *prova* ... Prontinho! Sopa do bem, quentinha!")
				_curar_player()
				await conversa.falar("Isso aí cura até alma penada. Pode passar, freguês!")
				await conversa.fechar()
				_virar_amigo()
				return
			elif tenho > 0:
				await conversa.falar("Só %d planta%s? Pra sopa do bem eu preciso de %d! Volta quando tiver todas." % [tenho, "" if tenho == 1 else "s", _total_plantas()])
			else:
				await conversa.falar("Sem planta não tem sopa, freguês. Me traz %d plantas que eu faço uma na hora!" % _total_plantas())
			await conversa.fechar()
			estado = Estado.CALMO
			_atualizar_dica()
		1:
			await conversa.falar("GOROROBA?!")
			await conversa.falar("Ninguém fala assim da MINHA comida!")
			await conversa.falar("Então prova ela... NA CARA!")
			await conversa.fechar()
			estado = Estado.CALMO   # (para o _ficar_bravo funcionar)
			_ficar_bravo("OFENDIDO!!")
		_:
			await conversa.falar("Tá bom... a sopa não vai a lugar nenhum. Nem eu.")
			await conversa.fechar()
			estado = Estado.CALMO
			_atualizar_dica()


# ---------------------------------------------------------------- PLANTAS / SOPA

func _total_plantas() -> int:
	var q := get_node_or_null("/root/QuestManager")
	return int(q.total_papeis) if q else 5


## Quantas plantas o player está carregando agora
func _plantas_que_o_player_tem() -> int:
	var q := get_node_or_null("/root/QuestManager")
	if q == null or not q.missao_ativa:
		return 0
	# se já entregou as plantas para o Pedinte, não tem mais nenhuma
	var cena := get_tree().current_scene
	if cena:
		for n in cena.find_children("*", "", true, false):
			if n.get("npc_finalizado") == true:
				return 0
	return int(q.papeis_coletados)


## O Gordo fica com as plantas (o Pedinte não vai mais receber essas)
func _pegar_plantas() -> void:
	var q := get_node_or_null("/root/QuestManager")
	if q == null:
		return
	q.papeis_coletados = 0
	q.missao_concluida = false
	if q.has_method("esconder_hud"):
		q.esconder_hud()


## Sopa do bem: vida cheia
func _curar_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var maximo: int = _player.get("MAX_HP") if _player.get("MAX_HP") != null else 6
	_player.set("hp", maximo)
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.player_hp = maximo
	if _player.has_signal("hp_changed"):
		_player.emit_signal("hp_changed", maximo, maximo)
	Sons.tocar(self, Sons.COGUMELO)
	# brilho verde no player + "+" subindo
	var desenho := _player.get_node_or_null("AnimatedSprite3D") as SpriteBase3D
	if desenho:
		desenho.modulate = Color(0.5, 1.6, 0.5)
		create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) \
			.tween_property(desenho, "modulate", Color.WHITE, 0.8)
	var mais := Label3D.new()
	mais.text = "+ VIDA CHEIA"
	mais.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mais.no_depth_test = true
	mais.font_size = 64
	mais.outline_size = 14
	mais.modulate = Color(0.55, 1.0, 0.45)
	mais.outline_modulate = Color(0.08, 0.2, 0.05)
	mais.process_mode = Node.PROCESS_MODE_ALWAYS
	_cena().add_child(mais)
	mais.global_position = _player.global_position + Vector3(0, 2.0, 0)
	var tw := mais.create_tween().set_parallel(true)
	tw.tween_property(mais, "global_position:y", mais.global_position.y + 1.2, 1.4)
	tw.tween_property(mais, "modulate:a", 0.0, 0.6).set_delay(0.8)
	tw.chain().tween_callback(mais.queue_free)


## Depois da sopa: fica amigo e sai da frente da porta
func _virar_amigo() -> void:
	estado = Estado.AMIGO
	_remover_barreira()
	remove_from_group("enemy")
	sprite.play("idle")
	var tw := create_tween()
	tw.tween_property(self, "global_position", global_position + sair_da_frente, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# balancinho enquanto anda
	var tw2 := create_tween().set_loops(4)
	tw2.tween_property(sprite, "position:y", sprite.position.y + 0.12, 0.17)
	tw2.tween_property(sprite, "position:y", sprite.position.y, 0.17)
	await tw.finished
	_casa = global_position
	_atualizar_dica()
