extends Node2D

## 反彈光球（暫時版，全程式繪製）：從玩家沿一條微彎的弧線追向攻擊者（目標移動也會跟著修正），
## 後面拖一條漸細的拖尾，命中時造成 REFLECT 傷害並炸出放射狀火花。

const FLIGHT_TIME: float = 0.28
const CURVE_OFFSET: float = 45.0
const TARGET_OFFSET: Vector2 = Vector2(0, -24) # 對準敵人身體而非腳底
const TRAIL_LENGTH: int = 10
const COLOR: Color = Color(0.55, 0.8, 1.0) # 對齊護盾素材的藍色
const SPARK_COUNT: int = 10
const Sfx = preload("res://scenes/support/sfx.gd")
const SFX_HIT = preload("res://assets/audio/sfx/reflect_hit.wav")

var _target: Node2D
var _source: Node2D
var _damage: int = 0
var _from: Vector2
var _control: Vector2
var _trail: Line2D
var _spark: float = -1.0 # < 0 代表還在飛

func launch(from: Vector2, target: Node2D, damage: int, source: Node2D) -> void:
	z_index = 100
	global_position = from
	_from = from
	_target = target
	_damage = damage
	_source = source
	# 弧線控制點：起終點中點往垂直方向隨機偏移，多顆同時發射時不會疊成一條線
	var to: Vector2 = _target_pos()
	var normal: Vector2 = (to - from).orthogonal().normalized()
	_control = (from + to) * 0.5 + normal * randf_range(-CURVE_OFFSET, CURVE_OFFSET)

	_trail = Line2D.new()
	_trail.top_level = true
	_trail.z_index = 99
	_trail.width = 8.0
	_trail.width_curve = Curve.new()
	_trail.width_curve.add_point(Vector2(0, 0))
	_trail.width_curve.add_point(Vector2(1, 1))
	var grad := Gradient.new()
	grad.set_color(0, Color(COLOR, 0.0))
	grad.set_color(1, Color(COLOR, 0.8))
	_trail.gradient = grad
	add_child(_trail)

	var tween := create_tween()
	tween.tween_method(_fly, 0.0, 1.0, FLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_hit)

func _target_pos() -> Vector2:
	if is_instance_valid(_target):
		return _target.global_position + TARGET_OFFSET
	return global_position

## 二次貝茲曲線，終點每幀重新取目標位置
func _fly(t: float) -> void:
	var to: Vector2 = _target_pos()
	var a: Vector2 = _from.lerp(_control, t)
	var b: Vector2 = _control.lerp(to, t)
	global_position = a.lerp(b, t)
	_trail.add_point(global_position)
	if _trail.get_point_count() > TRAIL_LENGTH:
		_trail.remove_point(0)
	queue_redraw()

func _hit() -> void:
	if is_instance_valid(_target) and _target.has_method("take_damage"):
		var src: Node2D = _source if is_instance_valid(_source) else null
		_target.take_damage(_damage, DamageNumber.DamageType.REFLECT, src)
	Sfx.play(self, SFX_HIT, -4.0, 0.1)
	_trail.clear_points()
	_spark = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_spark", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)

func _process(_delta: float) -> void:
	if _spark >= 0.0:
		queue_redraw()

func _draw() -> void:
	if _spark < 0.0:
		draw_circle(Vector2.ZERO, 10.0, Color(COLOR, 0.35))
		draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1, 0.95))
		return
	var a: float = 1.0 - _spark
	for i in range(SPARK_COUNT):
		var dir := Vector2.RIGHT.rotated(TAU * i / SPARK_COUNT)
		var inner: float = 6.0 + 20.0 * _spark
		var outer: float = inner + 10.0 * a
		draw_line(dir * inner, dir * outer, Color(1, 0.95, 1, a), 2.0)
	draw_circle(Vector2.ZERO, 12.0 * a, Color(COLOR, 0.6 * a))
