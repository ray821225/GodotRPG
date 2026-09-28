extends Node2D

## 暈眩星星（全程式繪製）：3 顆黃色小星星沿扁橢圓繞圈，跑到後面時變小變暗做出前後深度感。
## 由 enemy_base.gd 的 stun() 掛在敵人頭上，暈眩結束時移除。

const STAR_COUNT: int = 3
const ORBIT: Vector2 = Vector2(14.0, 4.0)
const SPIN_SPEED: float = 6.0
const STAR_RADIUS: float = 4.5
const STAR_COLOR: Color = Color(1.0, 0.88, 0.25)
const OUTLINE_COLOR: Color = Color(0.45, 0.3, 0.0)

var _t: float = 0.0

func _ready() -> void:
	z_index = 100

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	for i in range(STAR_COUNT):
		var a: float = _t * SPIN_SPEED + TAU * i / STAR_COUNT
		var pos := Vector2(cos(a) * ORBIT.x, sin(a) * ORBIT.y)
		# sin(a) < 0 代表在橢圓後半圈：縮小、變暗
		var depth: float = 0.75 + 0.25 * sin(a)
		_draw_star(pos, STAR_RADIUS * depth, _t * 4.0 + i, depth)

func _draw_star(center: Vector2, r: float, rot: float, brightness: float) -> void:
	var points := PackedVector2Array()
	for k in range(10):
		var ang: float = rot + PI * k / 5.0 - PI * 0.5
		var rad: float = r if k % 2 == 0 else r * 0.45
		points.append(center + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(points, STAR_COLOR.darkened(1.0 - brightness))
	points.append(points[0])
	draw_polyline(points, OUTLINE_COLOR, 1.0, true)
