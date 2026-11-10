extends RefCounted
## EFEITOS SONOROS do jogo, todos num lugar só.
##
## Para tocar um efeito de qualquer script:
##     const Sons = preload("res://Músicas/sons.gd")
##     Sons.tocar(self, Sons.EXPLOSAO)
##
## Para trocar um som: substitua o arquivo na pasta Músicas/Efeitos (mesmo nome)
## ou mude o caminho aqui embaixo.

const MISSIL := preload("res://Músicas/Efeitos/missil.mp3")                  # bombinhas que caem do céu (chefe)
const MISSIL_VOANDO := preload("res://Músicas/Efeitos/missil_voando.mp3")    # MissEile voando atrás do player
const TRANSICAO := preload("res://Músicas/Efeitos/transicao.mp3")            # transição da estrela
const COGUMELO := preload("res://Músicas/Efeitos/cogumelo.mp3")              # pegou o cogumelo amarelo
const JOGANDO_COGUMELO := preload("res://Músicas/Efeitos/jogando_cogumelo.mp3")  # jogou o cogumelo
const NPC := preload("res://Músicas/Efeitos/npc_interacao.mp3")              # conversa com NPC
const EXPLOSAO := preload("res://Músicas/Efeitos/explosao.mp3")              # explosões

## VOLUME GERAL de todos os efeitos (dB). Vale para todos de uma vez, além do volume
## de cada um abaixo. -6 = metade da força, -12 = um quarto, 0 = sem mudança.
const VOLUME_GERAL := -8.0

## Volume de cada efeito (dB). 0 = volume do arquivo. Ajuste aqui se algum ficar alto/baixo.
const VOLUMES := {
	MISSIL: -5.0,
	MISSIL_VOANDO: -6.0,
	TRANSICAO: -3.0,
	COGUMELO: 0.0,
	JOGANDO_COGUMELO: 0.0,
	NPC: 6.0,          # o arquivo é bem baixinho
	EXPLOSAO: -2.0,
}

## Quantas cópias do MESMO som podem tocar ao mesmo tempo (evita estourar o volume).
## Os mísseis não têm limite prático: cada bombinha tem o seu som.
const MAXIMO_IGUAIS := 3
const MAXIMO_POR_SOM := {
	MISSIL: 32,
}

## Em que segundo do arquivo missil.mp3 o apito acaba e começa a EXPLOSÃO.
## O som do míssil é tocado já sincronizado: a explosão do som acontece
## exatamente quando a bombinha encosta no chão.
const MOMENTO_EXPLOSAO_MISSIL := 1.55

static var _tocando := {}


## Toca um efeito uma vez. "quem" é qualquer nó da cena (normalmente self).
## a_partir_de: começa o som desse segundo do arquivo (pula o começo).
## pausavel: true = o som pausa junto com o jogo (para continuar sincronizado).
static func tocar(quem: Node, som: AudioStream, volume_extra := 0.0, a_partir_de := 0.0, pausavel := false) -> AudioStreamPlayer:
	if quem == null or som == null or not quem.is_inside_tree():
		return null
	var chave := som.resource_path
	if _tocando.get(chave, 0) >= MAXIMO_POR_SOM.get(som, MAXIMO_IGUAIS):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = som
	p.volume_db = volume_de(som) + volume_extra
	# normalmente toca mesmo com o jogo pausado; os "pausáveis" param junto com o jogo
	p.process_mode = Node.PROCESS_MODE_PAUSABLE if pausavel else Node.PROCESS_MODE_ALWAYS
	quem.get_tree().root.add_child(p)
	p.play(maxf(a_partir_de, 0.0))
	_tocando[chave] = _tocando.get(chave, 0) + 1
	p.finished.connect(func():
		_tocando[chave] = maxi(0, _tocando.get(chave, 1) - 1)
		p.queue_free())
	return p


## Abaixa (true) ou volta ao normal (false) a música de fundo.
static func abaixar_musica(quem: Node, abaixar: bool) -> void:
	if quem == null or not quem.is_inside_tree():
		return
	var musica := quem.get_tree().root.get_node_or_null("Musica")
	if musica and musica.has_method("abaixar"):
		musica.abaixar(abaixar)


## Som do míssil sincronizado com a queda: chame quando a bombinha COMEÇA a cair,
## passando quanto tempo ela leva até o chão. A explosão do som cai junto com o impacto.
static func tocar_missil(quem: Node, tempo_queda: float) -> void:
	var adianto := MOMENTO_EXPLOSAO_MISSIL - tempo_queda
	if adianto >= 0.0:
		# a queda é mais curta que o apito: começa o som um pouco "para frente"
		tocar(quem, MISSIL, 0.0, adianto, true)
	else:
		# a queda é mais longa que o apito: espera um pouco antes de tocar
		var arvore := quem.get_tree()
		var t := arvore.create_timer(-adianto, false)
		t.timeout.connect(func(): tocar(arvore.root, MISSIL, 0.0, 0.0, true))


## Som da transição da estrela: toca o efeito e PARA A MÚSICA NA HORA.
## Depois da transição, chame retomar_musica() (a transicao.gd já faz isso).
static func tocar_transicao(quem: Node) -> void:
	tocar(quem, TRANSICAO)
	if quem and quem.is_inside_tree():
		var musica := quem.get_tree().root.get_node_or_null("Musica")
		if musica and musica.has_method("parar_agora"):
			musica.parar_agora()


## Volta a música da cena atual depois de uma transição.
static func retomar_musica(quem: Node) -> void:
	if quem and quem.is_inside_tree():
		var musica := quem.get_tree().root.get_node_or_null("Musica")
		if musica and musica.has_method("retomar"):
			musica.retomar()


## Volume final de um efeito (volume geral + volume dele)
static func volume_de(som: AudioStream) -> float:
	return VOLUME_GERAL + VOLUMES.get(som, 0.0)
