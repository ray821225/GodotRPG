extends CharacterBody2D

enum State {
	IDLE,
	RUN,
	ATTACK,
	DEAD,
}

const DAMAGE_NUMBER = preload("res://scenes/ui/damage_number.tscn")
const DEATH_EFFECT = preload("res://scenes/effects/death_effect.tscn")

@export_category("Stats")
@export var speed: int = 400
@export var attack_speed: float = 0.6
@export var max_hp: int = 10
@export var attack_damage: int = 1

var state: State = State.IDLE
var move_direction: Vector2 = Vector2(0, 0)
var hp: int

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
@onready var hit_box: Area2D = $HitBox
@onready var health_bar: ProgressBar = $HUD/HUDControl/HPBar

func _ready() -> void:
	hp = max_hp
	health_bar.max_value = max_hp
	health_bar.value = hp
	hit_box.monitoring = false
	animation_tree.active = true
	_style_health_bar()

func _style_health_bar() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.12, 0.1)
	fill.set_corner_radius_all(4)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	bg.set_corner_radius_all(4)

	health_bar.add_theme_stylebox_override("fill", fill)
	health_bar.add_theme_stylebox_override("background", bg)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attack()

func _physics_process(_delta: float) -> void:
	if not state == State.ATTACK:
		movement_loop()

func movement_loop() -> void:
	move_direction.x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	move_direction.y = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
	var motion: Vector2 = move_direction.normalized() * speed
	set_velocity(motion)
	move_and_slide()

	if state == State.IDLE or State.RUN:
		if move_direction.x < -0.01:
			$Sprite2D.flip_h = true
		elif move_direction.x > 0.01:
			$Sprite2D.flip_h = false

	if motion != Vector2.ZERO and state == State.IDLE:
		state = State.RUN
		update_animation()
	elif motion == Vector2.ZERO and state == State.RUN:
		state = State.IDLE
		update_animation()

func update_animation() -> void:
	match state:
		State.IDLE:
			animation_playback.travel("idle")
		State.RUN:
			animation_playback.travel("run")
		State.ATTACK:
			animation_playback.travel("attack")

func attack() -> void:
	if state == State.ATTACK:
		return
	state = State.ATTACK

	var mouse_pos: Vector2 = get_global_mouse_position()
	var attack_dir: Vector2 = (mouse_pos - global_position).normalized()
	$Sprite2D.flip_h = attack_dir.x < 0 and abs(attack_dir.x) >= abs(attack_dir.y)
	animation_tree.set("parameters/attack/BlendSpace2D/blend_position", attack_dir)
	update_animation()

	hit_box.position = attack_dir * 40
	hit_box.monitoring = true

	await get_tree().create_timer(0.15).timeout
	deal_damage()

	await get_tree().create_timer(attack_speed - 0.15).timeout
	hit_box.monitoring = false
	state = State.IDLE

func deal_damage() -> void:
	var bodies = hit_box.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)

func take_damage(amount: int) -> void:
	hp -= amount
	health_bar.value = hp
	_spawn_damage_number(amount)
	_flash_damage()
	if hp <= 0:
		die()

func _spawn_damage_number(amount: int) -> void:
	var dn = DAMAGE_NUMBER.instantiate()
	get_tree().current_scene.add_child(dn)
	dn.setup(amount, global_position + Vector2(randf_range(-8.0, 8.0), -60.0))

func _flash_damage() -> void:
	$Sprite2D.modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1), 0.35)

func die() -> void:
	state = State.DEAD
	$Sprite2D.visible = false
	hit_box.monitoring = false
	animation_tree.active = false

	var effect = DEATH_EFFECT.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position + Vector2(0, -48)

	await get_tree().create_timer(1.5).timeout
	GameManager.on_player_died()
	queue_free()
