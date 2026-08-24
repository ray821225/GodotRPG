extends CharacterBody2D

enum State {
	IDLE,
	RUN,
	ATTACK,
	BLOCK,
	DEAD,
}

const DAMAGE_NUMBER = preload("res://scenes/ui/damage_number.tscn")
const DEATH_EFFECT = preload("res://scenes/effects/death_effect.tscn")
const BLOCK_EFFECT = preload("res://scenes/effects/block_effect.tscn")
const COUNTER_EFFECT = preload("res://scenes/effects/counter_effect.tscn")
const FIREBALL = preload("res://scenes/skills/fireball.tscn")
const ICE_SPIKE = preload("res://scenes/skills/icespike.tscn")
const RoleData = preload("res://scenes/entities/player/role_data.gd")
const DamageMath = preload("res://scenes/entities/damage_math.gd")
const ATTACK_ANIM_LENGTH: float = 0.6
const ATTACK_LOCK_DURATION: float = 0.3
const ATTACK_HIT_DELAY: float = 0.12
const KNOCKBACK_ON_HIT: float = 10.0
const KNOCKBACK_ON_BLOCK: float = 22.0

@export_category("Role")
@export var role: String = "Knight"

@export_category("Stats")
@export var speed: int = 200
@export var attack_speed: float = 0.3
@export var max_hp: int = 10000
@export var attack_damage: int = 10

@export_category("Block")
@export var block_damage_reduction: float = 0.8
@export var block_window: float = 0.2
@export var block_cooldown: float = 1.0
@export var counter_window: float = 0.2
@export var counter_damage_bonus: float = 0.25

@export_category("Skills")
@export var fireball_damage: int = 30
@export var fireball_speed: float = 500.0
@export var fireball_cooldown: float = 1.0
@export var icespike_damage: int = 25
@export var icespike_speed: float = 450.0
@export var icespike_cooldown: float = 1.0

var state: State = State.IDLE
var move_direction: Vector2 = Vector2(0, 0)
var hp: int
var max_mp: int
var mp: int
var def: int
var m_atk: int
var m_def: int
var attack_ready: bool = true
var block_ready: bool = true
var is_parry_active: bool = false
var block_success: bool = false
var can_counter: bool = false
var fireball_ready: bool = true
var icespike_ready: bool = true

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
@onready var hit_box: Area2D = $HitBox
@onready var health_bar: ProgressBar = $HUD/HUDControl/HPBar

func _ready() -> void:
	_apply_role_stats()
	hp = max_hp
	mp = max_mp
	health_bar.max_value = max_hp
	health_bar.value = hp
	hit_box.monitoring = false
	animation_tree.active = true
	_style_health_bar()

func _apply_role_stats() -> void:
	var stats: Dictionary = RoleData.get_stats(role)
	if stats.is_empty():
		return
	max_hp = stats.hp
	max_mp = stats.mp
	attack_damage = stats.atk
	m_atk = stats.m_atk
	def = stats.def
	m_def = stats.m_def
	attack_speed = stats.atk_speed
	speed = stats.walk_speed

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
	elif event.is_action_pressed("block"):
		try_block()
	elif event.is_action_pressed("skill_fireball"):
		cast_fireball()
	elif event.is_action_pressed("skill_icespike"):
		cast_icespike()

func _physics_process(_delta: float) -> void:
	if state == State.ATTACK or state == State.DEAD:
		return
	if state != State.BLOCK:
		movement_loop()

func try_block() -> void:
	if not block_ready or state == State.ATTACK or state == State.DEAD:
		return
	block_ready = false
	is_parry_active = true
	block_success = false
	state = State.BLOCK
	set_velocity(Vector2.ZERO)
	move_and_slide()
	_set_block_visual(true)
	update_animation()

	await get_tree().create_timer(block_window).timeout
	is_parry_active = false
	if state == State.BLOCK:
		state = State.IDLE
		_set_block_visual(false)
		update_animation()

	if block_success:
		block_ready = true
		return

	await get_tree().create_timer(maxf(block_cooldown - block_window, 0.0)).timeout
	block_ready = true

func _set_block_visual(active: bool) -> void:
	$Sprite2D.modulate = Color(0.7, 0.85, 1.0) if active else Color(1, 1, 1)

## 格擋中被攻擊輸入打斷時呼叫：清掉格擋視覺與 parry 判定，讓 attack() 能正常出招。
## try_block() 自己的計時器之後還是會照原本節奏跑完 block_cooldown，不會因此提早重置。
func _cancel_block() -> void:
	is_parry_active = false
	_set_block_visual(false)

func cast_fireball() -> void:
	if not fireball_ready or state == State.DEAD:
		return
	fireball_ready = false

	var mouse_pos: Vector2 = get_global_mouse_position()
	var muzzle_pos: Vector2 = global_position + Vector2(0, -32)
	var cast_dir: Vector2 = (mouse_pos - muzzle_pos).normalized()

	var fireball = FIREBALL.instantiate()
	get_tree().current_scene.add_child(fireball)
	fireball.damage = fireball_damage
	fireball.speed = fireball_speed
	fireball.launch(muzzle_pos + cast_dir * 30, cast_dir)

	await get_tree().create_timer(fireball_cooldown).timeout
	fireball_ready = true

func cast_icespike() -> void:
	if not icespike_ready or state == State.DEAD:
		return
	icespike_ready = false

	var mouse_pos: Vector2 = get_global_mouse_position()
	var muzzle_pos: Vector2 = global_position + Vector2(0, -32)
	var cast_dir: Vector2 = (mouse_pos - muzzle_pos).normalized()

	var icespike = ICE_SPIKE.instantiate()
	get_tree().current_scene.add_child(icespike)
	icespike.damage = icespike_damage
	icespike.speed = icespike_speed
	icespike.launch(muzzle_pos + cast_dir * 30, cast_dir)

	await get_tree().create_timer(icespike_cooldown).timeout
	icespike_ready = true

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
		State.BLOCK:
			animation_playback.travel("idle")

func attack() -> void:
	if not attack_ready or state == State.ATTACK or state == State.DEAD:
		return
	if state == State.BLOCK:
		_cancel_block()
	attack_ready = false
	var is_counter: bool = can_counter
	can_counter = false
	state = State.ATTACK

	var mouse_pos: Vector2 = get_global_mouse_position()
	var attack_dir: Vector2 = (mouse_pos - global_position).normalized()
	$Sprite2D.flip_h = attack_dir.x < 0 and abs(attack_dir.x) >= abs(attack_dir.y)
	animation_tree.set("parameters/attack/BlendSpace2D/blend_position", attack_dir)
	animation_tree.set("parameters/attack/TimeScale/scale", ATTACK_ANIM_LENGTH / ATTACK_LOCK_DURATION)
	update_animation()

	hit_box.position = attack_dir * 40
	hit_box.monitoring = true

	await get_tree().create_timer(ATTACK_HIT_DELAY).timeout
	deal_damage(is_counter)

	await get_tree().create_timer(ATTACK_LOCK_DURATION - ATTACK_HIT_DELAY).timeout
	hit_box.monitoring = false
	state = State.IDLE

	await get_tree().create_timer(maxf(attack_speed - ATTACK_LOCK_DURATION, 0.0)).timeout
	attack_ready = true

func deal_damage(is_counter: bool = false) -> void:
	if not hit_box.monitoring:
		return
	var areas = hit_box.get_overlapping_areas()
	var damage: int = attack_damage
	if is_counter:
		damage = int(round(attack_damage * (1.0 + counter_damage_bonus)))

	var hit_any: bool = false
	var last_target: Node2D = null
	for area in areas:
		var target = area.get_parent()
		if target.has_method("take_damage"):
			target.take_damage(damage, DamageNumber.DamageType.PHYSICAL, self)
			hit_any = true
			last_target = target

	if is_counter and hit_any:
		_spawn_counter_effect(last_target.global_position)

func take_damage(amount: int, attacker: Node2D = null) -> void:
	if state == State.DEAD:
		return
	if is_parry_active:
		block_success = true
		_spawn_block_effect()
		is_parry_active = false
		if state == State.BLOCK:
			state = State.IDLE
			_set_block_visual(false)
			update_animation()
		if attacker and attacker.has_method("apply_knockback"):
			attacker.apply_knockback(attacker.global_position - global_position, KNOCKBACK_ON_BLOCK)
		amount = int(round(amount * (1.0 - block_damage_reduction)))
		_open_counter_window()
		if amount <= 0:
			return

	var final_damage: int = DamageMath.calculate(amount, def)
	hp -= final_damage
	health_bar.value = hp
	_spawn_damage_number(final_damage)
	_flash_damage()
	if attacker:
		apply_knockback(global_position - attacker.global_position, KNOCKBACK_ON_HIT)
	if hp <= 0:
		die()

## 往 direction 方向輕輕滑一小段距離，打中/被打中時用來做「有被擊中」的手感回饋。
func apply_knockback(direction: Vector2, strength: float) -> void:
	if direction.length() < 0.01:
		return
	var target_pos: Vector2 = global_position + direction.normalized() * strength
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _open_counter_window() -> void:
	can_counter = true
	await get_tree().create_timer(counter_window).timeout
	can_counter = false

func _spawn_block_effect() -> void:
	var effect = BLOCK_EFFECT.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position + Vector2(0, -40)

func _spawn_counter_effect(target_position: Vector2) -> void:
	var effect = COUNTER_EFFECT.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = target_position + Vector2(0, -30)

func _spawn_damage_number(amount: int) -> void:
	var dn = DAMAGE_NUMBER.instantiate()
	get_tree().current_scene.add_child(dn)
	dn.setup(amount, global_position + Vector2(randf_range(-8.0, 8.0), -70.0), DamageNumber.DamageType.TAKEN)

func _flash_damage() -> void:
	$Sprite2D.modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1), 0.35)

func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	$Sprite2D.visible = false
	hit_box.monitoring = false
	$HurtBox.collision_layer = 0
	animation_tree.active = false
	$CollisionShape2D.set_deferred("disabled", true)

	var effect = DEATH_EFFECT.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position + Vector2(0, -48)

	await get_tree().create_timer(1.5).timeout
	GameManager.on_player_died()
	queue_free()
