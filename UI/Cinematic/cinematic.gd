extends Control

const Sons = preload("res://Músicas/sons.gd")

## Narração da cinemática. O arquivo já está montado na linha do tempo do vídeo:
## cada frase começa exatamente quando a legenda dela aparece.
const NARRACAO := preload("res://UI/Cinematic/narracao_cinematica.ogg")
## Volume da narração (dB)
const VOLUME_NARRACAO := 0.0
## Se a narração parecer adiantada ou atrasada em relação ao vídeo, ajuste aqui
## (em segundos; positivo = a narração começa depois).
const ATRASO_NARRACAO := 0.0

@onready var video: VideoStreamPlayer = $VideoStreamPlayer
@onready var skip_button: Button = $SkipButton

var _acabou := false
var _narracao: AudioStreamPlayer


func _ready() -> void:
	video.finished.connect(_terminar)
	skip_button.pressed.connect(_terminar)

	_narracao = AudioStreamPlayer.new()
	_narracao.stream = NARRACAO
	_narracao.volume_db = VOLUME_NARRACAO
	add_child(_narracao)

	# música de fundo mais baixa enquanto o narrador fala
	Sons.abaixar_musica(self, true)

	video.play()
	if ATRASO_NARRACAO > 0.0:
		await get_tree().create_timer(ATRASO_NARRACAO).timeout
		if not _acabou:
			_narracao.play()
	else:
		_narracao.play(-ATRASO_NARRACAO)


func _terminar() -> void:
	if _acabou:
		return
	_acabou = true
	video.stop()
	_narracao.stop()
	Sons.abaixar_musica(self, false)   # a próxima música volta no volume normal
	get_tree().change_scene_to_file("res://Cenários/DungeonTeste/dungeon_teste.tscn")  # confira o caminho real
