extends Node
## AUTOLOAD: toca a música certa em cada cena, sozinho.
##
## - Troca de música com um "crossfade" (uma some enquanto a outra aparece).
## - Se a cena nova usa a MESMA música (ex.: morreu e a fase recarregou),
##   a música continua de onde estava, sem recomeçar.
## - Continua tocando com o jogo pausado (diálogo, sala de point and click).
## - Cenas que não estão na lista abaixo ficam em silêncio (menu, cinemática...).
##
## Para colocar música em outra cena: adicione uma linha em MUSICAS.

const DUNGEON := preload("res://Músicas/curious_motif.mp3")   # Dungeon Teste
const BOSS := preload("res://Músicas/is_that_a_gnome_in_jetpacks.mp3")

## Cena -> música
var MUSICAS := {
	"res://Cenários/DungeonTeste/dungeon_teste.tscn": DUNGEON,
	"res://Cenários/BossMissEile/bossMissEile.tscn": BOSS,
}

## Volume da música (em dB; 0 = volume do arquivo, -6 = metade da força)
@export var volume_db := -6.0
## Duração da troca entre músicas, em segundos
@export var tempo_troca := 1.2
## Quanto a música abaixa durante as conversas com NPC (em dB)
@export var abaixar_em_conversa_db := -14.0

var _tocadores: Array[AudioStreamPlayer] = []
var _ativo := 0                 # qual dos 2 tocadores está tocando a música atual
var _cena_atual := ""
var _musica_atual: AudioStream = null
var _tw: Tween
var _tw_abaixar: Tween
var _abaixada := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_tocadores.append(p)
	for m in [DUNGEON, BOSS]:
		if "loop" in m:
			m.loop = true   # repete sem parar


func _process(_delta: float) -> void:
	var cena := get_tree().current_scene
	var caminho := cena.scene_file_path if cena else ""
	if caminho == _cena_atual:
		return
	_cena_atual = caminho
	tocar(MUSICAS.get(caminho, null))


## Toca uma música (null = silêncio). Se já está tocando ela, não faz nada.
func tocar(musica: AudioStream) -> void:
	if musica == _musica_atual:
		return
	_musica_atual = musica
	var saindo := _tocadores[_ativo]
	_ativo = 1 - _ativo
	var entrando := _tocadores[_ativo]

	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(saindo, "volume_db", -80.0, tempo_troca).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if musica:
		entrando.stream = musica
		entrando.volume_db = -40.0
		entrando.play()
		_tw.tween_property(entrando, "volume_db", _volume_alvo(), tempo_troca).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.chain().tween_callback(saindo.stop)


func _volume_alvo() -> float:
	return volume_db + (abaixar_em_conversa_db if _abaixada else 0.0)


## Abaixa a música (true) ou volta ao normal (false). Usado nas conversas com NPC.
func abaixar(sim: bool) -> void:
	if sim == _abaixada:
		return
	_abaixada = sim
	if _musica_atual == null:
		return
	if _tw_abaixar and _tw_abaixar.is_valid():
		_tw_abaixar.kill()
	_tw_abaixar = create_tween()
	_tw_abaixar.tween_property(_tocadores[_ativo], "volume_db", _volume_alvo(), 0.4 if sim else 0.8) \
		.set_trans(Tween.TRANS_SINE)
