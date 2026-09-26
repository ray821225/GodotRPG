extends Area2D

## 掉落在地上的道具：由 enemy_base.gd 的 _drop_loot() 生成並呼叫 setup() 帶入對應的 LootData。
## 玩家的 InteractArea 偵測到後按互動鍵呼叫 collect()，duck typing 契約同 take_damage()：
## 任何實作 collect(collector) 的節點都能被互動拾取。

const LootData = preload("res://scenes/items/loot_data.gd")

const DROP_DURATION: float = 0.5
const DROP_ARC_HEIGHT: float = 100.0
const COLLECT_POP_DURATION: float = 0.1
const COLLECT_FLY_DURATION: float = 0.25

## 掉落物存活 15 秒後消失，消失前 3 秒開始閃爍提示，最後淡出而非瞬間消失。
const LIFETIME_DURATION: float = 15.0
const BLINK_DURATION: float = 3.0
const BLINK_INTERVAL: float = 0.15
const FADE_OUT_DURATION: float = 0.3

var item_id: String = ""
var amount: int = 0
var _collected: bool = false
var _blink_tween: Tween

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var name_tag: Label = $NameTag

func _ready() -> void:
	get_tree().create_timer(LIFETIME_DURATION - BLINK_DURATION).timeout.connect(_start_blink)
	# 滑鼠 hover 顯示名稱，同 enemy_base.gd 的名牌做法
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## 金幣依金額分級外觀：[金額下限, 顯示名稱, 旋轉動畫]，由大到小比對。
const COIN_TIERS: Array = [
	[1000, "金幣", preload("res://resources/items/gold_spin_frames.tres")],
	[100, "銀幣", preload("res://resources/items/silver_spin_frames.tres")],
	[1, "銅幣", preload("res://resources/items/bronze_spin_frames.tres")],
]

## 有 sprite_frames（例如金幣的旋轉動畫）就播動畫，沒有就照舊用靜態 texture。
## amount_override >= 0 時覆寫 LootData 的數量（金幣金額由敵人資料隨機決定）。
func setup(loot: LootData, amount_override: int = -1) -> void:
	item_id = loot.item_id
	amount = amount_override if amount_override >= 0 else loot.amount
	var label_name: String = loot.display_name if loot.display_name != "" else item_id
	var frames: SpriteFrames = loot.sprite_frames
	# 金幣一律顯示金額（例如「5 銅幣」），其他道具數量 >1 才顯示「x N」
	if item_id == "coin":
		for tier in COIN_TIERS:
			if amount >= tier[0]:
				label_name = tier[1]
				frames = tier[2]
				break
		name_tag.text = "%d %s" % [amount, label_name]
	else:
		name_tag.text = "%s x%d" % [label_name, amount] if amount > 1 else label_name
	if frames:
		anim_sprite.sprite_frames = frames
		anim_sprite.play(loot.sprite_frames.get_animation_names()[0])
		anim_sprite.visible = true
		sprite.visible = false
	else:
		sprite.texture = loot.texture
		sprite.scale = Vector2.ONE * loot.display_scale

## 掉落動畫：從怪物身上的 start_pos 為起點，縮放從 0 變大、邊旋轉邊飛到地上的 end_pos，
## 飛行途中先關掉碰撞判定，避免玩家在半空中就撿到。
func play_drop_animation(start_pos: Vector2, end_pos: Vector2) -> void:
	global_position = start_pos
	scale = Vector2.ZERO
	rotation = 0.0
	collision_shape.set_deferred("disabled", true)

	var spins: float = float(randi_range(1, 2)) * TAU

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, DROP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", spins, DROP_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_update_drop_position.bind(start_pos, end_pos), 0.0, 1.0, DROP_DURATION)
	tween.chain().tween_callback(collision_shape.set_deferred.bind("disabled", false))

## t 必須用線性時間走（不能套 easing），拋物線本身的 4t(1-t) 公式才會自然呈現
## 「上升減速、下降加速」的重力感；如果連 t 都做緩動，會疊加變成落地前不自然地滑行減速。
func _update_drop_position(t: float, start_pos: Vector2, end_pos: Vector2) -> void:
	var pos: Vector2 = start_pos.lerp(end_pos, t)
	pos.y -= 4.0 * DROP_ARC_HEIGHT * t * (1.0 - t)
	global_position = pos

## 撿取動畫：先關掉碰撞避免同一幀被重複拾取，數值立刻生效（金幣/背包不等動畫），
## 視覺上讓道具先彈跳一下再飛向玩家並縮小淡出，動畫結束才真正移除節點。
func collect(collector: Node) -> void:
	if _collected:
		return
	_collected = true
	name_tag.visible = false
	if _blink_tween:
		_blink_tween.kill()
	collision_shape.set_deferred("disabled", true)

	if collector.has_method("collect_item"):
		collector.collect_item(item_id, amount)

	var target: Node2D = collector as Node2D
	var fly_to: Vector2 = target.global_position if target else global_position

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.3, COLLECT_POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", fly_to, COLLECT_FLY_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, COLLECT_FLY_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, COLLECT_FLY_DURATION)
	tween.chain().tween_callback(queue_free)

## 消失倒數進入最後 3 秒：用循環 tween 讓透明度來回閃爍，提醒玩家快消失了。
func _start_blink() -> void:
	if _collected:
		return
	_blink_tween = create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(self, "modulate:a", 0.2, BLINK_INTERVAL)
	_blink_tween.tween_property(self, "modulate:a", 1.0, BLINK_INTERVAL)
	get_tree().create_timer(BLINK_DURATION).timeout.connect(_expire)

## 閃爍時間到才真正消失，用淡出取代直接 queue_free，避免瞬間消失的突兀感。
func _expire() -> void:
	if _collected:
		return
	_collected = true
	name_tag.visible = false
	if _blink_tween:
		_blink_tween.kill()
	collision_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(queue_free)

func _on_mouse_entered() -> void:
	if not _collected:
		name_tag.visible = true

func _on_mouse_exited() -> void:
	name_tag.visible = false
