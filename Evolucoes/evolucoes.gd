extends RefCounted
## Liga no player a evolução escolhida (guardada em GameState.evolucao).

const ORBES = preload("res://Evolucoes/orbes_fogo.gd")
const RAJADAO = preload("res://Evolucoes/rajadao.gd")
const FOGO_AMIGO = preload("res://Evolucoes/fogo_amigo.gd")

const NOMES := {
	"orbes": "Orbes de Fogo",
	"rajadao": "Rajadão",
	"fogo_amigo": "Fogo Amigo",
}

const DICAS := {
	"orbes": "3 bolas de fogo giram em volta de você. Encoste nos inimigos!",
	"rajadao": "Botão DIREITO do mouse (ou E) solta um laser de fogo!",
	"fogo_amigo": "Seu mascote de fogo caça os inimigos sozinho!",
}


static func aplicar(player: Node3D) -> void:
	match GameState.evolucao:
		"orbes":
			var orbes := ORBES.new()
			orbes.name = "OrbesFogo"
			player.add_child(orbes)
		"rajadao":
			var raj := RAJADAO.new()
			raj.name = "Rajadao"
			player.add_child(raj)
		"fogo_amigo":
			var pet := FOGO_AMIGO.new()
			pet.name = "FogoAmigo"
			pet.player = player
			pet.position = player.position + Vector3(1.2, -1.0, 0.8)
			# o pet anda solto pelo mapa, então fica na cena e não dentro do player
			player.get_parent().add_child.call_deferred(pet)
