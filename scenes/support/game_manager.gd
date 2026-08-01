extends Node

const GAME_OVER_SCENE = preload("res://scenes/ui/game_over.tscn")

var _game_ended: bool = false

func on_player_died() -> void:
	if _game_ended:
		return
	_game_ended = true
	var ui = GAME_OVER_SCENE.instantiate()
	get_tree().current_scene.add_child(ui)

func reset() -> void:
	_game_ended = false
