extends Area2D

## 丟擲型敵人共用的拋物線投擲物：從起點飛到目標點的過程中持續旋轉，落地後在小範圍內
## 造成爆炸傷害。飛行用 tween 直接改 global_position（同 pickup.gd 掉落動畫的拋物線算法），
## 不用物理位移，才能穩定命中丟擲當下算好的落點，不受碰撞/摩擦影響。

const EXPLOSION_EFFECT = preload("res://scenes/effects/explosion_effect.tscn")
const ROTATION_SPEED: float = 14.0

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _damage: int = 0
var _attacker: Node2D = null

func _ready() -> void:
	monitoring = false
	sprite.play("fuse")

## start_pos/target_pos：起點跟目標落點。arc_height：拋物線頂點高度。
## throw_speed 用距離換算飛行時間，夾在 min/max_duration 之間避免太近瞬移、太遠飛太久。
## damage/attacker 落地爆炸時用（attacker 帶入才能觸發正確的擊退方向與反向鎖定）。
func launch(start_pos: Vector2, target_pos: Vector2, arc_height: float, throw_speed: float,
		min_duration: float, max_duration: float, damage: int, attacker: Node2D) -> void:
	global_position = start_pos
	rotation = 0.0
	_damage = damage
	_attacker = attacker

	var distance: float = start_pos.distance_to(target_pos)
	var duration: float = clampf(distance / throw_speed, min_duration, max_duration)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(_update_flight_position.bind(start_pos, target_pos, arc_height), 0.0, 1.0, duration)
	tween.tween_property(self, "rotation", ROTATION_SPEED * duration, duration)
	tween.chain().tween_callback(_explode)

## t 必須用線性時間走，理由同 pickup.gd：拋物線的 4t(1-t) 公式要配線性 t 才有自然的
## 「上升減速、下降加速」重力感，t 本身再套 easing 會疊加變成不自然的滑行。
func _update_flight_position(t: float, start_pos: Vector2, target_pos: Vector2, arc_height: float) -> void:
	var pos: Vector2 = start_pos.lerp(target_pos, t)
	pos.y -= 4.0 * arc_height * t * (1.0 - t)
	global_position = pos

## 落地當下用 PhysicsDirectSpaceState2D 直接查詢範圍內的目標，不透過 Area2D 的
## monitoring（開啟後要等物理伺服器下一步才會同步 overlap 清單，這裡是單次爆炸判定，
## 用即時查詢才不會因為只等一個 physics frame 而抓不到人）。
func _explode() -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = global_transform
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	for result in space_state.intersect_shape(query):
		var body = result.collider
		if body.has_method("take_damage"):
			body.take_damage(_damage, DamageNumber.DamageType.FIRE, _attacker)

	var effect = EXPLOSION_EFFECT.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position
	queue_free()
