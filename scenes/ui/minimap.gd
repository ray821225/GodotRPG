extends Control

## 右上角小地圖:SubViewport 用獨立的 World2D，把目前地圖的地形 TileMapLayer
## （Ground/Water/Props...）複製一份進去渲染，故意不共用主世界，
## 敵人/玩家本體等非地形節點不會被複製，小地圖上不會出現怪物。
## 玩家/傳送門位置另外疊一層 UI 圓點標示。切地圖後（portal 重載場景）
## _ready() 會重新執行，自動抓新地圖範圍並重新複製地形。

@onready var viewport: SubViewport = $ViewportContainer/Viewport
@onready var camera: Camera2D = $ViewportContainer/Viewport/MinimapCamera
@onready var player_dot: Panel = $MarkersLayer/PlayerDot
@onready var portal_dot: Panel = $MarkersLayer/PortalDot

var _player: Node2D
var _portal: Node2D
var _world_top_left: Vector2 = Vector2.ZERO
var _world_size: Vector2 = Vector2.ONE
var _view_size: Vector2 = Vector2.ONE

func _ready() -> void:
	_style_dot(player_dot, Color(1.0, 0.9, 0.2))
	_style_dot(portal_dot, Color(0.3, 0.8, 1.0))
	call_deferred("_setup")

func _style_dot(dot: Panel, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(dot.size.x / 2.0))
	dot.add_theme_stylebox_override("panel", style)

func _setup() -> void:
	_player = owner as Node2D
	if _player == null:
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	viewport.world_2d = World2D.new()
	_clone_terrain_layers(current_scene)

	var ground: TileMapLayer = current_scene.get_node_or_null("Ground") as TileMapLayer
	if ground == null or ground.tile_set == null:
		return
	var used_rect: Rect2i = ground.get_used_rect()
	var tile_size: Vector2 = Vector2(ground.tile_set.tile_size)
	_world_top_left = ground.to_global(ground.map_to_local(used_rect.position)) - tile_size * 0.5
	_world_size = Vector2(used_rect.size) * tile_size
	_view_size = Vector2(viewport.size)

	camera.global_position = _world_top_left + _world_size * 0.5
	var zoom: float = minf(_view_size.x / _world_size.x, _view_size.y / _world_size.y)
	camera.zoom = Vector2(zoom, zoom)

	_portal = _find_portal(current_scene)
	portal_dot.visible = _portal != null
	if _portal:
		portal_dot.position = _world_to_local(_portal.global_position) - portal_dot.size * 0.5

## 只複製地形圖層本身（不含子節點/腳本），玩家、敵人、傳送門等一律不進小地圖世界，
## 用各圖層目前的 global 位置/旋轉/縮放對齊，避免地圖根節點位移造成地形偏移。
func _clone_terrain_layers(current_scene: Node) -> void:
	for child in current_scene.get_children():
		if child is TileMapLayer:
			var layer: TileMapLayer = child
			var dup: TileMapLayer = TileMapLayer.new()
			dup.tile_set = layer.tile_set
			dup.tile_map_data = layer.tile_map_data
			dup.position = layer.global_position
			dup.rotation = layer.global_rotation
			dup.scale = layer.global_scale
			dup.z_index = layer.z_index
			dup.y_sort_enabled = layer.y_sort_enabled
			dup.visible = layer.visible
			viewport.add_child(dup)

func _find_portal(current_scene: Node) -> Node2D:
	for child in current_scene.get_children():
		var s: Script = child.get_script()
		if s != null and s.resource_path == "res://scenes/entities/portal/portal.gd":
			return child
	return null

func _world_to_local(world_pos: Vector2) -> Vector2:
	var ratio: Vector2 = (world_pos - _world_top_left) / _world_size
	return ratio * _view_size

func _process(_delta: float) -> void:
	if _player == null or _world_size.x <= 0.0:
		return
	var pos: Vector2 = _world_to_local(_player.global_position)
	pos.x = clampf(pos.x, 0.0, _view_size.x)
	pos.y = clampf(pos.y, 0.0, _view_size.y)
	player_dot.position = pos - player_dot.size * 0.5
