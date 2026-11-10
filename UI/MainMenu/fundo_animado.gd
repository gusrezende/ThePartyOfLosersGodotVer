extends TextureRect
## Fundo animado do menu: passa pelos quadros da lista "quadros", em loop.
## Para mudar a ordem, repetir quadros ou a velocidade, mexa no Inspetor.

## Quadros na ordem em que aparecem (pode repetir o mesmo quadro)
@export var quadros: Array[Texture2D] = []
## Quadros por segundo
@export var fps := 4.0

var _tempo := 0.0


func _ready() -> void:
	if not quadros.is_empty():
		texture = quadros[0]


func _process(delta: float) -> void:
	if quadros.size() < 2:
		return
	_tempo += delta * fps
	texture = quadros[int(_tempo) % quadros.size()]
