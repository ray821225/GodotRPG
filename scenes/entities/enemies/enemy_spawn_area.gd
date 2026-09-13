@tool
extends Node2D

## 區域刷怪點：在圓形/矩形範圍內隨機生成 min_count~max_count 隻怪物，取代大量重複的
## 單點 Marker2D（enemy_spawn_point.gd）。怪物生成後行為（追擊、重生等）完全比照
## enemy_base.gd 既有邏輯——重生時是回到「自己」被抽中的那個隨機座標，不是區域
## 中心，所以重生後範圍依然自然分散，不需要額外處理。

const EnemyData = preload("res://scenes/entities/enemies/enemy_data.gd")

enum ShapeType { CIRCLE, RECTANGLE }

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData
@export var min_count: int = 20
@export var max_count: int = 30
@export var shape_type: ShapeType = ShapeType.CIRCLE:
	set(value):
		shape_type = value
		queue_redraw()
## shape_type = Circle 時使用。
@export var radius: float = 200.0:
	set(value):
		radius = value
		queue_redraw()
## shape_type = Rectangle 時使用，以節點座標為中心的寬高。
@export var rect_size: Vector2 = Vector2(400.0, 300.0):
	set(value):
		rect_size = value
		queue_redraw()

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if enemy_scene == null:
		push_error("SpawnArea '%s' 沒有指定 enemy_scene" % name)
		return

	var count: int = randi_range(min_count, max_count)
	for i in count:
		var enemy: Node = enemy_scene.instantiate()
		if enemy_data != null and "data" in enemy:
			enemy.data = enemy_data
		enemy.position = position + _random_point_in_area()
		# 地圖場景剛載入時，父節點自己還在初始化子節點，這時直接 add_child() 會被拒絕
		# （"Parent node is busy setting up children"），要延到下一幀才能加進樹。
		get_parent().add_child.call_deferred(enemy)

func _random_point_in_area() -> Vector2:
	match shape_type:
		ShapeType.RECTANGLE:
			return Vector2(
				randf_range(-rect_size.x * 0.5, rect_size.x * 0.5),
				randf_range(-rect_size.y * 0.5, rect_size.y * 0.5)
			)
		_:
			var angle: float = randf_range(0.0, TAU)
			var distance: float = sqrt(randf()) * radius
			return Vector2(cos(angle), sin(angle)) * distance

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(0.2, 1.0, 0.3, 0.8)
	match shape_type:
		ShapeType.RECTANGLE:
			draw_rect(Rect2(-rect_size * 0.5, rect_size), color, false, 2.0)
		_:
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, 2.0)
