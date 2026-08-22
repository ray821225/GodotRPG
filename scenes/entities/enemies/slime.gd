extends CharacterBody2D

## 通用史萊姆行為腳本，外觀/數值皆由 SlimeData（見 data 欄位）決定，
## 新增顏色/變種時只需另建一份 SlimeData resource，不用複製這支腳本。

enum State {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	DEAD,
}

const DAMAGE_NUMBER = preload("res://scenes/ui/damage_number.tscn")
const SlimeData = preload("res://scenes/entities/enemies/slime_data.gd")
const ATTACK_ANIMATIONS: Array[StringName] = [&"attack", &"attack2"]
## 各攻擊動畫的實際播放秒數（幀數 / speed），攻擊判定節奏要跟著動畫長度走，不能寫死。
const ATTACK_ANIM_LENGTHS: Dictionary = {
	&"attack": 12.0 / 15.0,
	&"attack2": 13.0 / 15.0,
}
const ATTACK_HIT_DELAY_RATIO: float = 0.375

@export var data: SlimeData

var speed: int
var chase_speed: int
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
@onready var hit_box: Area2D = $HitBox
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
	hit_box.monitoring = false
	_style_health_bar()

func _apply_data() -> void:
	if data == null:
		push_error("Slime '%s' 未指定 data (SlimeData resource)" % name)
		return
	sprite.sprite_frames = data.sprite_frames
	sprite.play("idle")
	speed = data.speed
	chase_speed = data.chase_speed
	detection_range = data.detection_range
	attack_range = data.attack_range
	attack_speed = data.attack_speed
	max_hp = data.max_hp
	attack_damage = data.attack_damage
	wander_range = data.wander_range
	wander_interval = data.wander_interval
	respawn_delay = data.respawn_delay

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

	# 素材是無方向性的史萊姆撲擊動畫，僅依左右翻轉貼圖；兩種攻擊動作隨機挑一種。
	if abs(dir.x) > 0.01:
		sprite.flip_h = dir.x < 0
	var anim_name: StringName = ATTACK_ANIMATIONS.pick_random()
	sprite.play(anim_name)

	hit_box.position = dir * 35
	hit_box.monitoring = true

	# 攻擊週期長度要跟著「實際播放的動畫」走，不能寫死用 attack_speed，
	# 不然動畫還沒播完就提早切回 CHASE、搶著開始下一次攻擊，造成一次揮擊算兩次傷害。
	var cycle_duration: float = maxf(ATTACK_ANIM_LENGTHS[anim_name], attack_speed)
	var hit_delay: float = ATTACK_ANIM_LENGTHS[anim_name] * ATTACK_HIT_DELAY_RATIO
	await get_tree().create_timer(hit_delay).timeout
	deal_damage()

	await get_tree().create_timer(cycle_duration - hit_delay).timeout
	hit_box.monitoring = false
	if state != State.DEAD:
		if player:
			state = State.CHASE
		else:
			state = State.IDLE
			sprite.play("idle")

func deal_damage() -> void:
	if not hit_box.monitoring:
		return
	var areas = hit_box.get_overlapping_areas()
	for area in areas:
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

func take_damage(amount: int, type: DamageNumber.DamageType = DamageNumber.DamageType.PHYSICAL) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	health_bar.visible = true
	health_bar.value = hp
	_spawn_damage_number(amount, type)
	_flash_damage()
	if hp <= 0:
		die()

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
	hit_box.monitoring = false
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
	detection_area.monitoring = true
	sprite.play("idle")
	_restart_wander_timer()

func update_sprite_direction() -> void:
	if move_direction.x < -0.01:
		sprite.flip_h = true
	elif move_direction.x > 0.01:
		sprite.flip_h = false

func _restart_wander_timer() -> void:
	# 每次都重新抽一個隨機間隔，避免所有史萊姆的漫遊/停止節奏同步。
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
