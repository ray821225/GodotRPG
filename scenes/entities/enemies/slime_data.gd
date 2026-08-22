extends Resource

## 史萊姆的「模型」資料：換色/調數值只要換一份 SlimeData resource，不用改場景或程式碼。

@export var display_name: String = "Slime"
@export var sprite_frames: SpriteFrames

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
