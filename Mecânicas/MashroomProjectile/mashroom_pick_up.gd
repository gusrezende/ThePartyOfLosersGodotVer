extends Area3D
## Cogumelo explosivo no chão.
## O player só pega se estiver com a mão VAZIA. Se já estiver segurando um,
## este fica no chão; depois que ele jogar o que tem, é só encostar de novo
## (ou continuar parado em cima) que pega.


func _on_body_entered(body: Node3D) -> void:
	_tentar_pegar(body)


func _physics_process(_delta: float) -> void:
	# player parado em cima do cogumelo: pega assim que a mão ficar livre
	for body in get_overlapping_bodies():
		_tentar_pegar(body)


func _tentar_pegar(body: Node3D) -> void:
	if is_queued_for_deletion() or not body.is_in_group("player"):
		return
	if body.get("is_holding_mushroom") == true:
		return   # já está segurando um: não pega, e este continua no chão
	if body.has_method("pick_up_mushroom"):
		body.pick_up_mushroom()
		queue_free()
