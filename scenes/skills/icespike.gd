extends Area2D

const IMPACT_EFFECT = preload("res://scenes/effects/icespike_impact.tscn")
const FRAME_COUNT := 20
const FPS := 24.0

@export var speed: float = 450.0
@export var damage: int = 25
@export var max_distance: float = 900.0

var direction: Vector2 = Vector2.RIGHT
var traveled: float = 0.0
var _alive: bool = true

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_animate()

func _animate() -> void:
	for frame in range(FRAME_COUNT):
		if not _alive:
			return
		sprite.frame = frame
		await get_tree().create_timer(1.0 / FPS).timeout

func launch(start_position: Vector2, dir: Vector2) -> void:
	global_position = start_position
	direction = dir.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	var motion: Vector2 = direction * speed * delta
	global_position += motion
	traveled += motion.length()
	if traveled >= max_distance:
		_alive = false
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, DamageNumber.DamageType.ICE)
	_alive = false
	_spawn_impact(body)
	queue_free()

func _spawn_impact(body: Node = null) -> void:
	var effect = IMPACT_EFFECT.instantiate()
	get_tree().current_scene.add_child(effect)
	if body is Node2D:
		effect.global_position = (body as Node2D).global_position + Vector2(0, -34)
	else:
		effect.global_position = global_position
