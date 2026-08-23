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
const EnemyData = preload("res://scenes/entities/enemies/enemy_data.gd")
const KNOCKBACK_ON_HIT: float = 14.0

@export var data: EnemyData

var speed: int
var chase_speed: int
var use_detection: bool = true
var detection_range: float
var attack_range: float
var attack_speed: float
var max_hp: int
var attack_damage: int
var wander_range: float
var wander_interval: float
var respawn_delay: float

var state: State = State.IDLE
var move_direction: Vector2 = Vector2.ZERO
var player: CharacterBody2D = null
var spawn_position: Vector2
var wander_target: Vector2
var hp: int

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
	use_detection = data.use_detection
	detection_range = data.detection_range
	attack_range = data.attack_range
	attack_speed = data.attack_speed
	max_hp = data.max_hp
	attack_damage = data.attack_damage
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
		update_sprite_direction()

func wander_loop() -> void:
	var dir: Vector2 = (wander_target - global_position)
	if dir.length() < 8.0:
		state = State.IDLE
		sprite.play("idle")
		return
	move_direction = dir.normalized()
	velocity = move_direction * speed
	sprite.play("run")

func chase_loop() -> void:
	if player == null:
		state = State.IDLE
		sprite.play("idle")
		return

	var dir: Vector2 = (player.global_position - global_position)
	var dist: float = dir.length()

	if dist > detection_range * 1.5:
		player = null
		state = State.IDLE
		sprite.play("idle")
		return

	if dist <= attack_range:
		attack()
		return

	move_direction = dir.normalized()
	velocity = move_direction * chase_speed
	sprite.play("run")

func attack() -> void:
	if state == State.ATTACK:
		return
	state = State.ATTACK

	var dir: Vector2 = Vector2.DOWN
	if player:
		dir = (player.global_position - global_position).normalized()
	if abs(dir.x) > 0.01:
		sprite.flip_h = dir.x < 0

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
	hp -= amount
	health_bar.visible = true
	health_bar.value = hp
	_spawn_damage_number(amount, type)
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
	player = null
	_stop_attacking()
	hurt_box.collision_layer = 0
	detection_area.monitoring = false
	health_bar.visible = false
	collision_shape.set_deferred("disabled", true)

	sprite.play("death")

	await sprite.animation_finished
	sprite.visible = false

	await get_tree().create_timer(respawn_delay).timeout
	_respawn()

func _respawn() -> void:
	global_position = spawn_position
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

func update_sprite_direction() -> void:
	if move_direction.x < -0.01:
		sprite.flip_h = true
	elif move_direction.x > 0.01:
		sprite.flip_h = false

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
