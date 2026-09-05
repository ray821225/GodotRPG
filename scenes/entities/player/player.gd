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
const LEVELUP_EFFECT = preload("res://scenes/effects/levelup_effect.tscn")
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
const CHARGE_SLASH_TEXTURE_BIG = preload("res://assets/effects/skills/generic/charg_big.png")
const CHARGE_SLASH_FRAME_COUNT: int = 12
const CHARGE_SLASH_RELEASE_DURATION: float = 0.25
const CHARGE_SLASH_SCALE_START: float = 0.5
const CLICK_HOLD_THRESHOLD: float = 0.15

## ---- 升級經驗值曲線：exp_to_next(n) = EXP_CURVE_BASE * n ^ EXP_CURVE_EXPONENT ----
## n 為目前等級。之後想調整難度只要改這兩個數字，不用動計算邏輯：
## - EXP_CURVE_BASE：整條曲線整體平移，數字越大每一級都等比例變難（不影響「前後期差多少」的陡度）。
## - EXP_CURVE_EXPONENT：曲線陡度，越大後期漲得越誇張、前期幾乎沒感覺。
## 目前 base=30 / exponent=2.2 是抓「主要練到 50 級」的節奏（之後內容變多可以再往上延伸，
## 公式本身沒有等級上限）：Lv1→2 需 30 exp，Lv10→11 約 6000，Lv20→21 約 29500，
## Lv30→31 約 75000，Lv50→51 約 243000。
const EXP_CURVE_BASE: float = 30.0
const EXP_CURVE_EXPONENT: float = 2.2

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
@export var charge_slash_damage_multiplier: float = 50
@export var charge_slash_charge_time: float = 0.5
@export var charge_slash_move_speed_multiplier: float = 0.4

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
var is_charging_slash: bool = false
var _charge_slash_ready: bool = false
var _charge_scale_tween: Tween
var _left_click_claimed_by_charge: bool = false
var gold: int = 0
## 除了金幣以外的道具（例如肉）先單純計數，背包系統之後再串。
var inventory: Dictionary = {}
var level: int = 1
var exp: int = 0
## 升到下一級所需經驗值，隨等級變動，_ready() 與每次升級後都會重新計算。
var exp_to_next: int = 0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]
@onready var hit_box: Area2D = $HitBox
@onready var interact_area: Area2D = $InteractArea
@onready var health_bar: ProgressBar = $HUD/HUDControl/HPBar
@onready var gold_label: Label = $HUD/HUDControl/GoldLabel
@onready var exp_label: Label = $HUD/HUDControl/ExpLabel
@onready var charge_effect: AnimatedSprite2D = $ChargeEffect

func _ready() -> void:
	_apply_role_stats()
	hp = max_hp
	mp = max_mp
	health_bar.max_value = max_hp
	health_bar.value = hp
	hit_box.monitoring = false
	animation_tree.active = true
	_style_health_bar()
	charge_effect.sprite_frames = _build_charge_sprite_frames()
	exp_to_next = _exp_needed_for_level(level)
	_update_exp_label()

## 把 charg_big 這張橫向排列的蓄力精靈圖切成 CHARGE_SLASH_FRAME_COUNT 格，組成 AnimatedSprite2D
## 可播放的 charge 動畫（時長對齊 charge_slash_charge_time，設為 loop 讓蓄滿等待放開期間不會停在最後一偵）。
## 「變大」的效果改由 charge_effect 的 scale 從 CHARGE_SLASH_SCALE_START 漸變回 1.0 來表現。
func _build_charge_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	_add_charge_animation(frames, &"charge", CHARGE_SLASH_TEXTURE_BIG, charge_slash_charge_time, true)
	return frames

func _add_charge_animation(frames: SpriteFrames, anim_name: StringName, sheet: Texture2D, duration: float, loop: bool = false) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, CHARGE_SLASH_FRAME_COUNT / duration)
	frames.set_animation_loop(anim_name, loop)
	var frame_size: Vector2 = sheet.get_size() / Vector2(CHARGE_SLASH_FRAME_COUNT, 1)
	for i in range(CHARGE_SLASH_FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(frame_size.x * i, 0, frame_size.x, frame_size.y)
		frames.add_frame(anim_name, atlas)

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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_left_click_pressed()
		else:
			_on_left_click_released()
	elif event.is_action_pressed("block"):
		try_block()
	elif event.is_action_pressed("skill_fireball"):
		cast_fireball()
	elif event.is_action_pressed("skill_icespike"):
		cast_icespike()
	elif event.is_action_pressed("interact"):
		_try_interact()

func _physics_process(_delta: float) -> void:
	if state == State.ATTACK or state == State.DEAD:
		return
	if state != State.BLOCK:
		movement_loop()

func try_block() -> void:
	if not block_ready or state == State.ATTACK or state == State.DEAD or is_charging_slash:
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
	var speed_multiplier: float = charge_slash_move_speed_multiplier if is_charging_slash else 1.0
	var motion: Vector2 = move_direction.normalized() * speed * speed_multiplier
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

## 左鍵點一下算普攻、按住算蓄力斬：按下先不出手，等 CLICK_HOLD_THRESHOLD 這麼久，
## 這段時間內放開就是單純點擊 → attack()；還按著就判定為長按 → 進入蓄力（由 _left_click_claimed_by_charge 標記，
## 放開時 _on_left_click_released() 才不會又補一次 attack()）。
func _on_left_click_pressed() -> void:
	_left_click_claimed_by_charge = false
	if not attack_ready or state == State.ATTACK or state == State.DEAD:
		return
	await get_tree().create_timer(CLICK_HOLD_THRESHOLD).timeout
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if not attack_ready or state == State.ATTACK or state == State.DEAD:
		return
	_left_click_claimed_by_charge = true
	start_charge_slash()

func _on_left_click_released() -> void:
	if is_charging_slash:
		if _charge_slash_ready:
			_fire_charge_slash()
		else:
			_cancel_charge_slash()
		return
	if not _left_click_claimed_by_charge:
		attack()

func attack() -> void:
	if not attack_ready or state == State.ATTACK or state == State.DEAD or is_charging_slash:
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

## 蓄力斬：按住左鍵超過 CLICK_HOLD_THRESHOLD 開始蓄力，charge_effect 播放 charge 動畫（大圖，loop，
## 一輪時長對齊 charge_slash_charge_time），移動速度依 charge_slash_move_speed_multiplier 變慢；同時 scale 從
## CHARGE_SLASH_SCALE_START（縮小版）漸變回 1.0（正常大小），快蓄滿時視覺上會明顯變大。
## 蓄滿後不會自動出招，而是進入「蓄力完成」狀態等待放開左鍵，放開的當下才朝放開瞬間的滑鼠方向揮出，
## 傷害為 attack_damage 的 charge_slash_damage_multiplier 倍。蓄力未滿就放開左鍵則直接取消，不會出招。
func start_charge_slash() -> void:
	if not attack_ready or state == State.ATTACK or state == State.DEAD or is_charging_slash:
		return
	if state == State.BLOCK:
		_cancel_block()
	is_charging_slash = true
	_charge_slash_ready = false
	charge_effect.modulate.a = 1.0
	charge_effect.visible = true
	charge_effect.scale = Vector2.ONE * CHARGE_SLASH_SCALE_START
	charge_effect.play(&"charge")

	if _charge_scale_tween:
		_charge_scale_tween.kill()
	_charge_scale_tween = create_tween()
	_charge_scale_tween.tween_property(charge_effect, "scale", Vector2.ONE, charge_slash_charge_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	await get_tree().create_timer(charge_slash_charge_time).timeout
	if not is_charging_slash:
		return
	_charge_slash_ready = true

func _cancel_charge_slash() -> void:
	if not is_charging_slash:
		return
	is_charging_slash = false
	_charge_slash_ready = false
	if _charge_scale_tween:
		_charge_scale_tween.kill()
	charge_effect.stop()
	charge_effect.visible = false

func _fire_charge_slash() -> void:
	is_charging_slash = false
	_charge_slash_ready = false
	if _charge_scale_tween:
		_charge_scale_tween.kill()
	charge_effect.scale = Vector2.ONE

	attack_ready = false
	state = State.ATTACK

	var mouse_pos: Vector2 = get_global_mouse_position()
	var attack_dir: Vector2 = (mouse_pos - global_position).normalized()
	$Sprite2D.flip_h = attack_dir.x < 0 and abs(attack_dir.x) >= abs(attack_dir.y)
	animation_tree.set("parameters/attack/BlendSpace2D/blend_position", attack_dir)
	animation_tree.set("parameters/attack/TimeScale/scale", ATTACK_ANIM_LENGTH / ATTACK_LOCK_DURATION)
	update_animation()

	hit_box.position = attack_dir * 40
	hit_box.monitoring = true

	var fade_tween := create_tween()
	fade_tween.tween_interval(CHARGE_SLASH_RELEASE_DURATION)
	fade_tween.tween_property(charge_effect, "modulate:a", 0.0, 0.15)
	fade_tween.tween_callback(func() -> void: charge_effect.visible = false)

	await get_tree().create_timer(ATTACK_HIT_DELAY).timeout
	deal_damage(false, charge_slash_damage_multiplier)

	await get_tree().create_timer(ATTACK_LOCK_DURATION - ATTACK_HIT_DELAY).timeout
	hit_box.monitoring = false
	state = State.IDLE

	await get_tree().create_timer(maxf(attack_speed - ATTACK_LOCK_DURATION, 0.0)).timeout
	attack_ready = true

func deal_damage(is_counter: bool = false, damage_multiplier: float = 1.0) -> void:
	if not hit_box.monitoring:
		return
	var areas = hit_box.get_overlapping_areas()
	var damage: int = int(round(attack_damage * damage_multiplier))
	if is_counter:
		damage = int(round(damage * (1.0 + counter_damage_bonus)))

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

func take_damage(amount: int, type: DamageNumber.DamageType = DamageNumber.DamageType.PHYSICAL, attacker: Node2D = null) -> void:
	if state == State.DEAD:
		return
	var blocked: bool = false
	if is_parry_active:
		blocked = true
		block_success = true
		_spawn_block_effect()
		is_parry_active = false
		if state == State.BLOCK:
			state = State.IDLE
			_set_block_visual(false)
			update_animation()
		# 只有近戰（物理）攻擊格擋成功才把對方震退：遠程/爆炸傷害來源（例如炸彈客）
		# 命中當下人可能離很遠，套用震退會變成敵人莫名滑動一下，很奇怪。
		if type == DamageNumber.DamageType.PHYSICAL and attacker and attacker.has_method("apply_knockback"):
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
	if attacker and not blocked:
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

## 按互動鍵時呼叫：對 InteractArea 範圍內所有掉落物一次拾取（怪物可能一次掉好幾個）。
func _try_interact() -> void:
	for area in interact_area.get_overlapping_areas():
		if area.has_method("collect"):
			area.collect(self)

## 拾取契約：任何 Pickup 撿起來都呼叫這個方法。coin 直接加金幣，其他道具先進 inventory 計數。
func collect_item(item_id: String, amount: int) -> void:
	if item_id == "coin":
		gold += amount
		gold_label.text = "Gold: %d" % gold
	else:
		inventory[item_id] = inventory.get(item_id, 0) + amount

func _exp_needed_for_level(n: int) -> int:
	return int(round(EXP_CURVE_BASE * pow(n, EXP_CURVE_EXPONENT)))

## 怪物死亡時由 enemy_base.gd 呼叫。用 while 而非 if 是因為一次補很多經驗值
## （例如之後加大量 exp 的道具/任務獎勵）要能一口氣連續升好幾級。
func gain_exp(amount: int) -> void:
	exp += amount
	var leveled_up: bool = false
	while exp >= exp_to_next:
		exp -= exp_to_next
		level += 1
		exp_to_next = _exp_needed_for_level(level)
		leveled_up = true
	_update_exp_label()
	if leveled_up:
		_spawn_levelup_effect()

func _update_exp_label() -> void:
	exp_label.text = "Lv.%d  EXP %d/%d" % [level, exp, exp_to_next]

func _spawn_levelup_effect() -> void:
	var effect = LEVELUP_EFFECT.instantiate()
	# 位置一定要在 add_child 之前設定：effect 的 _ready() 是在 add_child 當下同步執行，
	# 若晚一步才設 global_position，_ready() 裡讀到的會是預設的 (0,0)，飄浮動畫就會從
	# 原點飄向角色實際位置，離出生點越遠看起來就像飄過頭一路衝到地圖邊界。
	effect.global_position = global_position + Vector2(0, -40)
	get_tree().current_scene.add_child(effect)

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
	is_charging_slash = false
	_charge_slash_ready = false
	if _charge_scale_tween:
		_charge_scale_tween.kill()
	charge_effect.stop()
	charge_effect.visible = false
	$HurtBox.collision_layer = 0
	animation_tree.active = false
	$CollisionShape2D.set_deferred("disabled", true)

	var effect = DEATH_EFFECT.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = global_position + Vector2(0, -48)

	await get_tree().create_timer(1.5).timeout
	GameManager.on_player_died()
	queue_free()
