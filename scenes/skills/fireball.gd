extends Area2D

const FRAME_DIR := "res://assets/effects/skills/fire/FXpack13_Effect3/"
const FRAME_COUNT := 60
const IMPACT_EFFECT = preload("res://scenes/effects/fireball_impact.tscn")

@export var speed: float = 500.0
@export var damage: int = 30
@export var max_distance: float = 400.0

var direction: Vector2 = Vector2.RIGHT
var traveled: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	sprite.sprite_frames = _build_sprite_frames()
	sprite.play("fly")
	body_entered.connect(_on_body_entered)

func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("fly")
	frames.set_animation_speed("fly", 30.0)
	frames.set_animation_loop("fly", false)
	for i in range(1, FRAME_COUNT + 1):
		frames.add_frame("fly", load(FRAME_DIR + str(i) + ".png"))
	return frames

func launch(start_position: Vector2, dir: Vector2) -> void:
	global_position = start_position
	direction = dir.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	var motion: Vector2 = direction * speed * delta
	global_position += motion
	traveled += motion.length()
	if traveled >= max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, DamageNumber.DamageType.FIRE)
	_spawn_impact(body)
	queue_free()

func _spawn_impact(body: Node = null) -> void:
	var effect = IMPACT_EFFECT.instantiate()
	get_tree().current_scene.add_child(effect)
	if body is Node2D:
		effect.global_position = (body as Node2D).global_position + Vector2(0, -34)
	else:
		effect.global_position = global_position
