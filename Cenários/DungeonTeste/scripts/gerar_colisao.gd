extends Node3D
## Colocado no modelo .glb do mapa: cria a colisão (chão e paredes) de todas as
## malhas automaticamente quando a fase começa. Assim não precisa configurar nada no import.
##
## As colisões são "dos dois lados" (backface_collision): algumas paredes do modelo
## só têm a face virada para fora, e sem isso o player e os inimigos atravessam
## por dentro.

func _ready() -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		var malha := mi as MeshInstance3D
		if malha.find_children("*", "StaticBody3D", false, false).is_empty():
			malha.create_trimesh_collision()
		for forma in malha.find_children("*", "CollisionShape3D", true, false):
			var concava := (forma as CollisionShape3D).shape as ConcavePolygonShape3D
			if concava:
				concava.backface_collision = true
