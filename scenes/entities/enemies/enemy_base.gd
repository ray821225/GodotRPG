extends CharacterBody2D

## 所有敵人共用的行為基底：狀態機、漫遊/追擊、受傷/血條/傷害數字、死亡與重生。
## 「怎麼發動攻擊」不屬於共用行為（近戰用 HitBox、遠程射箭、法師施法都不一樣），
## 交給子類別覆寫 _perform_attack() / _stop_attacking() / _apply_extra_data() 這三個掛勾即可，
## 其餘邏輯不用重寫。近戰型別見 enemy_melee.gd。

enum State {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	DEAD,
}

const DAMAGE_NUMBER = preload("res://scenes/ui/damage_number.tscn")
const PICKUP = preload("res://scenes/items/pickup.tscn")
const DUST_EFFECT = preload("res://scenes/effects/dust_effect.tscn")
const EnemyData = preload("res://scenes/entities/enemies/enemy_data.gd")
const DamageMath = preload("res://scenes/entities/damage_math.gd")
const KNOCKBACK_ON_HIT: float = 14.0
const WANDER_STUCK_CHECK_INTERVAL: float = 0.4
const WANDER_STUCK_MIN_DISTANCE: float = 12.0
const WANDER_STUCK_LIMIT: int = 3

@export var data: EnemyData

var speed: int
var chase_speed: int
var faces_left_by_default: bool = false
var use_detection: bool = true
var detection_range: float
var leash_range: float = 350.0
var attack_range: float
var attack_needs_horizontal_align: bool = false
var attack_align_tolerance: float = 40.0
var attack_speed: float
var max_hp: int
var attack_damage: int
var defense: float = 10.0
var magic_defense: float = 10.0
var wander_range: float
var wander_interval: float
var respawn_delay: float

var state: State = State.IDLE
var move_direction: Vector2 = Vector2.ZERO
var player: CharacterBody2D = null
var spawn_position: Vector2
var wander_target: Vector2
var hp: int

var _wander_stuck_check_elapsed: float = 0.0
var _wander_stuck_count: int = 0
var _wander_check_position: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var wander_timer: Timer = $WanderTimer
@onready var detection_area: Area2D = $DetectionArea
@onready var hurt_box: Area2D = $HurtBox
@onready var health_bar: ProgressBar = $HealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_apply_data()
	hp = max_hp
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_bar.visible = false
	spawn_position = global_position
	wander_target = spawn_position
	wander_timer.one_shot = true
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	_restart_wander_timer()
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	detection_area.monitoring = use_detection
	_style_health_bar()

func _apply_data() -> void:
	if data == null:
		push_error("Enemy '%s' 未指定 data (EnemyData resource)" % name)
		return
	sprite.sprite_frames = data.sprite_frames
	sprite.play("idle")
	speed = data.speed
	chase_speed = data.chase_speed
	faces_left_by_default = data.faces_left_by_default
	use_detection = data.use_detection
	detection_range = data.detection_range
	leash_range = data.leash_range
	attack_range = data.attack_range
	attack_needs_horizontal_align = data.attack_needs_horizontal_align
	attack_align_tolerance = data.attack_align_tolerance
	attack_speed = data.attack_speed
	max_hp = data.max_hp
	attack_damage = data.attack_damage
	defense = data.defense
	magic_defense = data.magic_defense
	wander_range = data.wander_range
	wander_interval = data.wander_interval
	respawn_delay = data.respawn_delay
	_apply_extra_data()

## 子類別覆寫：讀取自己專屬的 data 欄位（例如近戰的 attack_animations）。
func _apply_extra_data() -> void:
	pass

func _style_health_bar() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.75, 0.25)
	fill.set_corner_radius_all(3)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg.set_corner_radius_all(3)

	health_bar.add_theme_stylebox_override("fill", fill)
	health_bar.add_theme_stylebox_override("background", bg)

func _physics_process(_delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.WANDER:
			wander_loop()
		State.CHASE:
			chase_loop()
		State.ATTACK:
			velocity = Vector2.ZERO
		State.DEAD:
			velocity = Vector2.ZERO

	if state != State.DEAD:
		move_and_slide()
	# 攻擊時的朝向由 attack() 依照目標方向決定，這裡不能再用移動方向覆蓋回去，
	# 不然攻擊動畫會被「進入攻擊前殘留的舊 move_direction」蓋掉，看起來一直朝同一邊。
	if state == State.WANDER or state == State.CHASE:
		update_sprite_direction()

func wander_loop() -> void:
	var dir: Vector2 = (wander_target - global_position)
	if dir.length() < 8.0:
		_end_wander()
		return

	# 卡住偵測：每隔一小段時間檢查有沒有實際前進，被地形（例如樹）卡住走不動的話，
	# 放棄這次的漫遊目標回到 IDLE，避免永遠頂著障礙物原地抖動。
	_wander_stuck_check_elapsed += get_physics_process_delta_time()
	if _wander_stuck_check_elapsed >= WANDER_STUCK_CHECK_INTERVAL:
		_wander_stuck_check_elapsed = 0.0
		if global_position.distance_to(_wander_check_position) < WANDER_STUCK_MIN_DISTANCE:
			_wander_stuck_count += 1
			if _wander_stuck_count >= WANDER_STUCK_LIMIT:
				_end_wander()
				return
		else:
			_wander_stuck_count = 0
		_wander_check_position = global_position

	move_direction = dir.normalized()
	velocity = move_direction * speed
	sprite.play("run")

func _end_wander() -> void:
	state = State.IDLE
	sprite.play("idle")
	_wander_stuck_count = 0
	_wander_stuck_check_elapsed = 0.0

func chase_loop() -> void:
	if player == null:
		state = State.IDLE
		sprite.play("idle")
		return

	var dir: Vector2 = (player.global_position - global_position)
	var dist: float = dir.length()

	if global_position.distance_to(spawn_position) > leash_range:
		_give_up_chase()
		return

	if dist <= attack_range:
		if not attack_needs_horizontal_align or absf(dir.y) <= attack_align_tolerance:
			attack()
			return
		# 距離夠了但垂直落差太大：攻擊動畫只有左右鏡像打不到這個角度，
		# 要往上下移動去貼近玩家的 Y 座標（縮小 dir.y），不是追 X，
		# 對齊了（dir.y 落在容許範圍內）下一輪 chase_loop() 才會真的攻擊。
		move_direction = Vector2(0.0, signf(dir.y))
		velocity = move_direction * chase_speed
		sprite.play("run")
		return

	move_direction = dir.normalized()
	velocity = move_direction * chase_speed
	sprite.play("run")

## 追太遠（超過 leash_range）或玩家跑太遠時放棄追擊：血補滿、走回出生點，
## 沿用 WANDER 的移動（含卡住偵測），走到家自然變回 IDLE。
func _give_up_chase() -> void:
	player = null
	hp = max_hp
	health_bar.value = hp
	health_bar.visible = false
	wander_target = spawn_position
	state = State.WANDER
	sprite.play("run")
	_wander_stuck_count = 0
	_wander_stuck_check_elapsed = 0.0
	_wander_check_position = global_position

func attack() -> void:
	if state == State.ATTACK:
		return
	state = State.ATTACK

	var dir: Vector2 = Vector2.DOWN
	if player:
		dir = (player.global_position - global_position).normalized()
	if abs(dir.x) > 0.01:
		sprite.flip_h = (dir.x < 0) != faces_left_by_default

	# _perform_attack() 由子類別覆寫，實際上大多是 async coroutine，
	# 靜態分析器只看基底類別的簽章會誤判成不需要 await，這裡明確抑制。
	@warning_ignore("redundant_await")
	await _perform_attack(dir)

	if state != State.DEAD:
		if player:
			state = State.CHASE
		else:
			state = State.IDLE
			sprite.play("idle")

## 子類別覆寫：實際的攻擊手段（近戰揮擊判定、遠程射箭、法師施法…），
## 播完動畫、造成傷害/生成彈幕都在這裡處理，結束後才會回到 CHASE/IDLE。
func _perform_attack(_dir: Vector2) -> void:
	push_warning("%s 沒有實作 _perform_attack()" % get_script().resource_path)

## 子類別覆寫：死亡瞬間要順便關掉的攻擊判定（例如近戰的 hit_box.monitoring）。
func _stop_attacking() -> void:
	pass

func take_damage(amount: int, type: DamageNumber.DamageType = DamageNumber.DamageType.PHYSICAL, attacker: Node2D = null) -> void:
	if state == State.DEAD:
		return
	var def_value: float = defense if type == DamageNumber.DamageType.PHYSICAL else magic_defense
	var final_damage: int = DamageMath.calculate(amount, def_value)
	hp -= final_damage
	health_bar.visible = true
	health_bar.value = hp
	_spawn_damage_number(final_damage, type)
	_flash_damage()
	if attacker:
		apply_knockback(global_position - attacker.global_position, KNOCKBACK_ON_HIT)
		# 不管有沒有主動索敵，被打中一律反過來鎖定攻擊者、開始追擊。
		if attacker is CharacterBody2D and attacker.has_method("take_damage"):
			player = attacker
			if state != State.ATTACK:
				state = State.CHASE
	if hp <= 0:
		die()

## 往 direction 方向輕輕滑一小段距離，打中/被打中時用來做「有被擊中」的手感回饋。
func apply_knockback(direction: Vector2, strength: float) -> void:
	if direction.length() < 0.01:
		return
	var target_pos: Vector2 = global_position + direction.normalized() * strength
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _spawn_damage_number(amount: int, type: DamageNumber.DamageType) -> void:
	var dn = DAMAGE_NUMBER.instantiate()
	get_tree().current_scene.add_child(dn)
	dn.setup(amount, global_position + Vector2(randf_range(-8.0, 8.0), -45.0), type)

func _flash_damage() -> void:
	sprite.modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.35)

func die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	# player 此時是最後一個攻擊者（take_damage() 設定），要在歸零前先取出來發經驗值。
	var killer: CharacterBody2D = player
	player = null
	_stop_attacking()
	if killer and data and killer.has_method("gain_exp"):
		killer.gain_exp(data.exp_reward)
	hurt_box.collision_layer = 0
	detection_area.monitoring = false
	health_bar.visible = false
	collision_shape.set_deferred("disabled", true)
	# 死亡有可能是在物理查詢 flush 中觸發（例如技能的 area_entered 訊號），這時直接
	# add_child 一個新的 Area2D（掉落物）會撞到「不能在 flush 中改變物理狀態」的
	# 引擎限制，所以整個延後到這一幀的物理處理結束後再執行。
	_drop_loot.call_deferred()

	# 有些素材還沒補死亡動畫（例如大青蛙），沒有就直接停頓一下淡出，不要整個爆錯誤。
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	else:
		await get_tree().create_timer(0.3).timeout
	sprite.visible = false

	await get_tree().create_timer(respawn_delay).timeout
	_respawn()

## 死亡時依 data.loot_table 加權隨機掉一個東西（機率由 loot_drop_chance 決定），
## 生成在死亡位置附近的小範圍隨機偏移，避免同一格重疊的掉落物完全疊在一起。
func _drop_loot() -> void:
	if data == null or data.loot_table.is_empty():
		return
	if randf() > data.loot_drop_chance:
		return
	var loot: EnemyData.LootData = _pick_weighted_loot()
	if loot == null:
		return
	var pickup = PICKUP.instantiate()
	get_tree().current_scene.add_child(pickup)
	pickup.setup(loot)
	var drop_offset: Vector2 = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
	pickup.play_drop_animation(global_position, global_position + drop_offset)

func _pick_weighted_loot() -> EnemyData.LootData:
	var total_weight: float = 0.0
	for entry in data.loot_table:
		total_weight += entry.weight
	if total_weight <= 0.0:
		return null
	var roll: float = randf() * total_weight
	for entry in data.loot_table:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return data.loot_table[-1]

func _respawn() -> void:
	global_position = spawn_position
	_spawn_dust_effect()
	hp = max_hp
	health_bar.value = hp
	wander_target = spawn_position
	move_direction = Vector2.ZERO
	state = State.IDLE
	sprite.visible = true
	sprite.modulate = Color(1, 1, 1)
	collision_shape.set_deferred("disabled", false)
	hurt_box.collision_layer = 4
	detection_area.monitoring = use_detection
	sprite.play("idle")
	_restart_wander_timer()

func _spawn_dust_effect() -> void:
	var effect = DUST_EFFECT.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position

func update_sprite_direction() -> void:
	if move_direction.x < -0.01:
		sprite.flip_h = not faces_left_by_default
	elif move_direction.x > 0.01:
		sprite.flip_h = faces_left_by_default

func _restart_wander_timer() -> void:
	# 每次都重新抽一個隨機間隔，避免所有敵人的漫遊/停止節奏同步。
	wander_timer.wait_time = randf_range(wander_interval * 0.6, wander_interval * 1.4)
	wander_timer.start()

func _on_wander_timer_timeout() -> void:
	if state == State.IDLE:
		var offset: Vector2 = Vector2(
			randf_range(-wander_range, wander_range),
			randf_range(-wander_range, wander_range)
		)
		wander_target = spawn_position + offset
		state = State.WANDER
		sprite.play("run")
		_wander_stuck_count = 0
		_wander_stuck_check_elapsed = 0.0
		_wander_check_position = global_position
	_restart_wander_timer()

func _on_detection_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and body.name == "Player":
		player = body
		if state != State.ATTACK and state != State.DEAD:
			state = State.CHASE

func _on_detection_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		if state != State.ATTACK and state != State.DEAD:
			state = State.IDLE
			sprite.play("idle")
