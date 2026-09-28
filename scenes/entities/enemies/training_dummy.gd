extends "res://scenes/entities/enemies/enemy_base.gd"

## 訓練假人（稻草人）：不移動、不追擊、不攻擊，被打只播放搖晃的 hurt 動畫。
## 血條、傷害數字、閃紅、死亡重生沿用 enemy_base，只覆寫會讓它動起來的部分。

func _ready() -> void:
	super._ready()
	sprite.animation_finished.connect(_on_sprite_animation_finished)

func take_damage(amount: int, type: DamageNumber.DamageType = DamageNumber.DamageType.PHYSICAL, attacker: Node2D = null) -> void:
	super.take_damage(amount, type, attacker)
	if state == State.DEAD:
		return
	# 基底被打會鎖定攻擊者並切 CHASE，假人一律留在原地
	player = null
	state = State.IDLE
	# 往攻擊者的反方向晃（素材預設是被右邊打、往左倒）
	if attacker:
		sprite.flip_h = attacker.global_position.x < global_position.x
	sprite.stop()
	sprite.play("hurt")

## 被挑釁只跳驚嘆號，不追擊
func taunt(_source: Node2D) -> void:
	if state != State.DEAD:
		_show_alert()

## 釘在地上，不被擊退
func apply_knockback(_direction: Vector2, _strength: float) -> void:
	pass

## 不漫遊：基底 _ready()/_respawn() 會呼叫這兩個
func _start_wandering() -> void:
	state = State.IDLE

func _restart_wander_timer() -> void:
	pass

func _perform_attack(_dir: Vector2) -> void:
	pass

func _on_sprite_animation_finished() -> void:
	if sprite.animation == &"hurt" and state != State.DEAD:
		sprite.play("idle")
