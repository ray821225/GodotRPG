extends Node

const GAME_OVER_SCENE = preload("res://scenes/ui/game_over.tscn")

var _game_ended: bool = false

## 換地圖時要保留的玩家狀態（change_scene_to_file 會把整棵樹連玩家一起砍掉重建，
## 所以由這裡暫存，新地圖的 Player _ready() 時再讀回去）。
var player_state: Dictionary = {}

## 玩家進新地圖後要傳送到的 Marker2D 名稱（對應目標地圖裡同名的節點）。
var pending_spawn_point: StringName = &""

func on_player_died() -> void:
	if _game_ended:
		return
	_game_ended = true
	var ui = GAME_OVER_SCENE.instantiate()
	get_tree().current_scene.add_child(ui)

func reset() -> void:
	_game_ended = false

## Portal 呼叫：記住玩家狀態與目標重生點，再換場景。
func teleport(player: Node, target_map: String, spawn_point: StringName) -> void:
	save_player_state(player)
	pending_spawn_point = spawn_point
	get_tree().call_deferred("change_scene_to_file", target_map)

func save_player_state(player: Node) -> void:
	player_state = {
		"hp": player.hp,
		"gold": player.gold,
		"inventory": player.inventory.duplicate(),
		"level": player.level,
		"exp": player.exp,
		"exp_to_next": player.exp_to_next,
	}

func has_player_state() -> bool:
	return not player_state.is_empty()

func restore_player_state(player: Node) -> void:
	if player_state.is_empty():
		return
	player.hp = player_state.hp
	player.gold = player_state.gold
	player.inventory = player_state.inventory.duplicate()
	player.level = player_state.level
	player.exp = player_state.exp
	player.exp_to_next = player_state.exp_to_next

## 消耗掉待用的重生點：新地圖的 Player 進場時呼叫，把自己移到同名 Marker2D 位置。
func consume_pending_spawn(player: Node2D) -> void:
	if pending_spawn_point == &"":
		return
	var spawn := player.get_tree().current_scene.find_child(pending_spawn_point, true, false)
	if spawn:
		player.global_position = spawn.global_position
	pending_spawn_point = &""
