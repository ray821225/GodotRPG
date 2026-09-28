extends Node2D

## 挑釁對話框（全程式建立）：白底圓角框＋下方小尾巴，紅字罵人符號，
## 彈出 → 文字左右抖動 → 往上淡出。掛在施放者身上跟著角色移動。

const BG_COLOR: Color = Color(1, 1, 1, 0.95)
const BORDER_COLOR: Color = Color(0.15, 0.1, 0.1)
const TEXT_COLOR: Color = Color(0.85, 0.1, 0.1)
const TAIL_SIZE: Vector2 = Vector2(12, 9)
const SHAKE_AMOUNT: float = 1.5
## 框內左右留白，文字抖動以此為中心（直接設 position.x 會蓋掉容器排好的留白）
const PADDING_X: float = 10.0

var text: String = "@#$%&!"
var duration: float = 1.2

var _label: Label
var _t: float = 0.0

func _ready() -> void:
	z_index = 100
	scale = Vector2.ZERO

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = PADDING_X
	style.content_margin_right = PADDING_X
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.text = text
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	panel.add_child(_label)
	add_child(panel)

	# 框的底邊中央對齊節點原點上方（尾巴尖端 = 原點）
	var box: Vector2 = panel.get_combined_minimum_size()
	panel.position = Vector2(-box.x * 0.5, -box.y - TAIL_SIZE.y + 2)

	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(-TAIL_SIZE.x * 0.5, -TAIL_SIZE.y), Vector2(TAIL_SIZE.x * 0.5, -TAIL_SIZE.y), Vector2(0, 0)])
	tail.color = BG_COLOR
	add_child(tail)
	var tail_line := Line2D.new()
	tail_line.points = PackedVector2Array([Vector2(-TAIL_SIZE.x * 0.5, -TAIL_SIZE.y + 1), Vector2(0, 0), Vector2(TAIL_SIZE.x * 0.5, -TAIL_SIZE.y + 1)])
	tail_line.width = 2.0
	tail_line.default_color = BORDER_COLOR
	add_child(tail_line)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.15, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(duration)
	tween.tween_property(self, "position:y", position.y - 12, 0.25)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)

## 文字抖動：氣到發抖的感覺
func _process(delta: float) -> void:
	_t += delta
	_label.position.x = PADDING_X + sin(_t * 45.0) * SHAKE_AMOUNT
