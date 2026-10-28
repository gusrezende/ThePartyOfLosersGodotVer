extends Node3D
## Colocado no modelo .glb do mapa: cria a colisão (chão e paredes) de todas as
## malhas automaticamente quando a fase começa. Assim não precisa configurar nada no import.

func _ready() -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		var malha := mi as MeshInstance3D
		if malha.find_children("*", "StaticBody3D", false, false).is_empty():
			malha.create_trimesh_collision()
