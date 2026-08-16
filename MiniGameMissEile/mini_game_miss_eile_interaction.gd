extends Area3D

@export var tecla_interacao := KEY_E
@export var cena_minigame: PackedScene

var jogador_perto := false


func _ready():

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta):

	if jogador_perto:

		if Input.is_key_pressed(tecla_interacao):

			abrir_minigame()


func _on_body_entered(body):

	if body.is_in_group("player"):

		jogador_perto = true

		print("Pressione E para interagir com MissEile")


func _on_body_exited(body):

	if body.is_in_group("player"):

		jogador_perto = false


func abrir_minigame():

	jogador_perto = false

	if cena_minigame:

		get_tree().change_scene_to_packed(cena_minigame)

	else:

		print("ERRO: Cena do minigame não foi configurada!")
