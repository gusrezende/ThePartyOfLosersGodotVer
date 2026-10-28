extends StaticBody3D
## Parede que quebra quando o COGUMELO EXPLOSIVO explode perto dela.
## (O mashroom_projectile.gd avisa o grupo "reage_explosao".)

const TORRE = preload("res://Mecânicas/torre_ponte.gd")

@export var alcance_extra := 1.5
@export var quantidade_lascas := 22
@export var cor_lascas := Color(0.32, 0.28, 0.7)

var _quebrada := false


func _ready() -> void:
	add_to_group("reage_explosao")


func receber_explosao(posicao: Vector3, raio: float) -> void:
	if _quebrada:
		return
	var caixa := _caixa_global()
	var mais_perto := posicao.clamp(caixa.position, caixa.end)
	if mais_perto.distance_to(posicao) > raio + alcance_extra:
		return
	_quebrada = true

	var efeito = TORRE.Destrocos.new()
	efeito.caixa = caixa
	efeito.quantidade = quantidade_lascas
	efeito.cor = cor_lascas
	var malhas := find_children("*", "MeshInstance3D", true, false)
	if malhas.size() > 0:
		efeito.material_madeira = (malhas[0] as MeshInstance3D).get_active_material(0)
	get_parent().add_child(efeito)
	queue_free()


func _caixa_global() -> AABB:
	var caixa := AABB(global_position, Vector3.ZERO)
	for v in find_children("*", "VisualInstance3D", true, false):
		caixa = caixa.merge((v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb())
	return caixa
