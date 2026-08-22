extends CharacterBody2D

enum State {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	DEAD,
}

const DAMAGE_NUMBER = preload("res://scenes/ui/damage_number.tscn")

@export_category("Stats")
@export var speed: int = 80
@export var chase_speed: int = 140
@export var detection_range: float = 250.0
@export var attack_range: float = 36.0
@export var attack_speed: float = 0.8
@export var max_hp: int = 60
@export var attack_damage: int = 8

@export_category("Wander")
@export var wander_range: float = 100.0
@export var wander_interval: float = 3.0

@export_category("Respawn")
@export var respawn_delay: float = 5.0

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
	hp = max_hp
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_bar.visible = false
	spawn_position = global_position
	wander_target = spawn_position
	wander_timer.wait_time = wander_interval
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	wander_timer.start()
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	hit_box.monitoring = false
	_style_health_bar()

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

	# 素材是無方向性的史萊姆撲擊動畫，僅依左右翻轉貼圖。
	if abs(dir.x) > 0.01:
		sprite.flip_h = dir.x < 0
	sprite.play("attack")

	hit_box.position = dir * 35
	hit_box.monitoring = true

	await get_tree().create_timer(0.3).timeout
	deal_damage()

	await get_tree().create_timer(attack_speed - 0.3).timeout
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
	wander_timer.start()

func update_sprite_direction() -> void:
	if move_direction.x < -0.01:
		sprite.flip_h = true
	elif move_direction.x > 0.01:
		sprite.flip_h = false

func _on_wander_timer_timeout() -> void:
	if state == State.IDLE:
		var offset: Vector2 = Vector2(
			randf_range(-wander_range, wander_range),
			randf_range(-wander_range, wander_range)
		)
		wander_target = spawn_position + offset
		state = State.WANDER
		sprite.play("run")

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
