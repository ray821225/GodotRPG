extends Area2D

## 戰旗（暫時版，全程式繪製，之後有素材再換）：
## - 插旗：從上方落下插進地面，揚起塵土、地面光圈展開
## - 飄動：旗面切成多條直欄，每欄依正弦波上下位移，離旗桿越遠擺幅越大，
##   並依波形斜率調亮/調暗做出布料起伏的明暗
## - 範圍：地面光圈，有友軍在範圍內時變亮
## - 最後 2 秒閃爍，時間到淡出並移除所有增益
## 增益契約（duck typing，同 take_damage）：範圍內有 add_stat_modifier() 的節點會被套用，
## 離開時呼叫 remove_stat_modifier(self)。

const DUST_EFFECT = preload("res://scenes/effects/dust_effect.tscn")
const Sfx = preload("res://scenes/support/sfx.gd")
const SFX_PLANT = preload("res://assets/audio/sfx/banner_plant.wav")

const POLE_HEIGHT: float = 110.0
const POLE_WIDTH: float = 4.0
const FLAG_SIZE: Vector2 = Vector2(56.0, 36.0)
const FLAG_COLUMNS: int = 16
const WAVE_SPEED: float = 7.0
const WAVE_LENGTH: float = 0.25 # 每欄相位差
const WAVE_AMPLITUDE: float = 6.0
const FLAG_COLOR: Color = Color(0.78, 0.16, 0.14)
const TRIM_COLOR: Color = Color(0.95, 0.78, 0.3)
const POLE_COLOR: Color = Color(0.4, 0.27, 0.15)
const RING_COLOR: Color = Color(0.95, 0.78, 0.3)
const DROP_HEIGHT: float = 90.0
const DROP_DURATION: float = 0.15
const WARN_TIME: float = 2.0
const FADE_DURATION: float = 0.4

var radius: float = 64.0
var duration: float = 10.0
var defense_bonus: float = 0.3

var _t: float = 0.0
var _drop_offset: float = 0.0
var _ring_scale: float = 0.0
var _ending: bool = false
var _affected: Array[Node] = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ring: Node2D = $Ring

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	# 落地前不套增益
	monitoring = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	ring.draw.connect(_draw_ring)

	_drop_offset = -DROP_HEIGHT
	var tween := create_tween()
	tween.tween_property(self, "_drop_offset", 0.0, DROP_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_on_planted)
	tween.tween_property(self, "_ring_scale", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	get_tree().create_timer(duration).timeout.connect(_expire)

func _on_planted() -> void:
	monitoring = true
	Sfx.play(self, SFX_PLANT, -3.0)
	var dust = DUST_EFFECT.instantiate()
	get_tree().current_scene.add_child(dust)
	dust.global_position = global_position

func _process(delta: float) -> void:
	_t += delta
	if not _ending and _t > duration - WARN_TIME:
		modulate.a = 0.4 if fmod(_t, 0.24) < 0.12 else 1.0
	queue_redraw()
	ring.queue_redraw()

func _on_body_entered(body: Node) -> void:
	if _ending or not body.has_method("add_stat_modifier") or _affected.has(body):
		return
	body.add_stat_modifier(self, &"def", defense_bonus)
	_affected.append(body)

func _on_body_exited(body: Node) -> void:
	if not _affected.has(body):
		return
	_affected.erase(body)
	if is_instance_valid(body):
		body.remove_stat_modifier(self)

func _expire() -> void:
	_ending = true
	_clear_modifiers()
	set_deferred("monitoring", false)
	modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(queue_free)

## 換地圖等情況旗子被直接移除時，也要把增益拿掉
func _exit_tree() -> void:
	_clear_modifiers()

func _clear_modifiers() -> void:
	for body in _affected:
		if is_instance_valid(body):
			body.remove_stat_modifier(self)
	_affected.clear()

func _draw() -> void:
	var base := Vector2(0, _drop_offset)
	var top := base + Vector2(0, -POLE_HEIGHT)
	# 旗桿＋頂端金球
	draw_rect(Rect2(top.x - POLE_WIDTH * 0.5, top.y, POLE_WIDTH, POLE_HEIGHT), POLE_COLOR)
	draw_circle(top + Vector2(0, -3), 5.0, TRIM_COLOR)

	# 旗面：逐欄畫四邊形，y 位移 = sin 波 × 離旗桿距離比例（根部固定、尾端擺最大）
	var flag_top: Vector2 = top + Vector2(POLE_WIDTH * 0.5, 3.0)
	var col_w: float = FLAG_SIZE.x / FLAG_COLUMNS
	for i in range(FLAG_COLUMNS):
		var x0: float = i * col_w
		var x1: float = x0 + col_w
		var y0: float = _wave(i)
		var y1: float = _wave(i + 1)
		# 下緣做成燕尾：最後幾欄往中間收
		var cut0: float = _swallowtail(i)
		var cut1: float = _swallowtail(i + 1)
		var shade: float = clampf((y1 - y0) * 0.35, -0.3, 0.3)
		var color: Color = FLAG_COLOR.lightened(shade) if shade > 0.0 else FLAG_COLOR.darkened(-shade)
		var quad := PackedVector2Array([
			flag_top + Vector2(x0, y0),
			flag_top + Vector2(x1, y1),
			flag_top + Vector2(x1, y1 + FLAG_SIZE.y - cut1),
			flag_top + Vector2(x0, y0 + FLAG_SIZE.y - cut0),
		])
		draw_colored_polygon(quad, color)
		# 上下金邊
		draw_line(flag_top + Vector2(x0, y0), flag_top + Vector2(x1, y1), TRIM_COLOR, 2.0)
		draw_line(flag_top + Vector2(x0, y0 + FLAG_SIZE.y - cut0), flag_top + Vector2(x1, y1 + FLAG_SIZE.y - cut1), TRIM_COLOR, 1.5)

	# 旗面中央的盾形紋章，跟著所在那欄的波一起動
	var mid: int = int(FLAG_COLUMNS * 0.5) - 1
	var emblem_center: Vector2 = flag_top + Vector2(mid * col_w, _wave(mid) + FLAG_SIZE.y * 0.45)
	draw_colored_polygon(PackedVector2Array([
		emblem_center + Vector2(-7, -8),
		emblem_center + Vector2(7, -8),
		emblem_center + Vector2(7, 2),
		emblem_center + Vector2(0, 10),
		emblem_center + Vector2(-7, 2),
	]), TRIM_COLOR)

func _wave(column: int) -> float:
	var ratio: float = float(column) / FLAG_COLUMNS
	return sin(_t * WAVE_SPEED - column * WAVE_LENGTH) * WAVE_AMPLITUDE * ratio

func _swallowtail(column: int) -> float:
	var start: int = FLAG_COLUMNS - 3
	if column <= start:
		return 0.0
	return FLAG_SIZE.y * 0.5 * float(column - start) / 3.0 * 0.6

## 地面光圈（畫在 Ring 子節點上，z_index -1 壓在角色下面）；有友軍在範圍內時變亮
func _draw_ring() -> void:
	if _ring_scale <= 0.0:
		return
	var r: float = radius * _ring_scale
	var boost: float = 0.25 if not _affected.is_empty() else 0.0
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	var fill := RING_COLOR
	fill.a = 0.08 + 0.05 * pulse + boost * 0.5
	ring.draw_circle(Vector2.ZERO, r, fill)
	var edge := RING_COLOR
	edge.a = 0.5 + 0.3 * pulse + boost
	ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, edge, 2.0, true)
