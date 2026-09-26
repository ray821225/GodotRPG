extends Node2D

## AOE 劍擊技能：劍從空中垂直墜落插入地面，接著在原地播放「金色衝擊波」動畫
## （groud_attack.png，橫向 7 格），對範圍內的目標一次造成橢圓範圍傷害。判定用
## PhysicsDirectSpaceState2D 直接查詢（同 dynamite.gd 的落地爆炸邏輯），只在衝擊波
## 剛炸開的那一幀（IMPACT_FRAME）算一次傷害，其餘幀純視覺淡出，不會重複命中。
## 劍落地瞬間就消失，接手播放衝擊波動畫。
## 同一支腳本可套不同素材：幀數直接讀 GroundSprite 的 hframes；
## 素材本身已畫好劍落下（例如 groud_attack2.png）時關掉 sword_drop 即可。

@export var sword_drop: bool = true
@export var fps: float = 14.0
## 在第幾幀造成傷害（0 起算），設在衝擊波炸開的那一幀
@export var impact_frame: int = 0

const FALL_HEIGHT: float = 120.0
const FALL_DURATION: float = 0.13

@export var damage: int = 0
@export var radius: Vector2 = Vector2(70.0, 40.0) # 橢圓半軸（x = 水平、y = 垂直），俯視角下扁一點較貼近地面視覺
const ELLIPSE_SEGMENTS: int = 24
@export var target_collision_mask: int = 4
@export var show_debug_radius: bool = true # 除錯用，畫出實際傷害判定的紅圈，正式版記得關掉

var attacker: Node2D = null

@onready var sword_pivot: Node2D = $SwordPivot
@onready var ground_sprite: Sprite2D = $GroundSprite

func _ready() -> void:
	z_index = 100
	ground_sprite.visible = false
	queue_redraw()

	if not sword_drop:
		sword_pivot.visible = false
		ground_sprite.visible = true
		_play_ground_effect()
		return

	var rest_y: float = sword_pivot.position.y
	sword_pivot.position.y = rest_y - FALL_HEIGHT

	var tween := create_tween()
	tween.tween_property(sword_pivot, "position:y", rest_y, FALL_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished

	if not is_inside_tree():
		return
	sword_pivot.visible = false
	ground_sprite.visible = true
	_play_ground_effect()

func _play_ground_effect() -> void:
	for i in range(ground_sprite.hframes):
		if not is_inside_tree():
			return
		ground_sprite.frame = i
		if i == impact_frame:
			_deal_damage()
		await get_tree().create_timer(1.0 / fps).timeout
	queue_free()

func _draw() -> void:
	if not show_debug_radius:
		return
	var points := _ellipse_points()
	points.append(points[0])
	draw_polyline(points, Color(1, 0, 0, 0.9), 2.0)

## Godot 沒有內建橢圓 Shape，用多邊形近似（凸多邊形，碰撞查詢可直接用）
func _ellipse_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(ELLIPSE_SEGMENTS):
		var angle: float = TAU * i / ELLIPSE_SEGMENTS
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points

func _deal_damage() -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var shape := ConvexPolygonShape2D.new()
	shape.points = _ellipse_points()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = target_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	for result in space_state.intersect_shape(query):
		var body = result.collider
		if body.has_method("take_damage"):
			body.take_damage(damage, DamageNumber.DamageType.PHYSICAL, attacker)
