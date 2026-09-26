extends Resource

## 所有技能共用的資料基底（同 enemy_data.gd 的做法）：名稱/職業/冷卻/MP 等共用欄位放這裡，
## 「怎麼施放」交給子類別覆寫 cast()，例如 sword_nova_skill_data.gd、reflect_skill_data.gd。
## 新增技能 = 新增一份 .tres（resources/skills/）+ 需要的話寫一個效果場景，不用改 player.gd。
##
## 技能等級：*_per_level 欄位是每升一級增加的量，實際數值用 scaled() 換算。
## 技能點數/技能樹還沒做，目前所有技能一律 1 級（player.gd 的 skill_levels）。

## 唯一識別，冷卻/技能等級/之後存檔都用這個當 key，建立後不要改
@export var id: StringName
@export var display_name: String = ""
@export var icon: Texture2D
## 可使用的職業（對應 role_data.gd 的職業名稱），留空代表全職業可用
@export var roles: Array[String] = []
@export var max_level: int = 10

@export_category("Cost")
@export var cooldown: float = 1.0
@export var mp_cost: int = 0
@export var mp_cost_per_level: int = 0

func is_usable_by(role: String) -> bool:
	return roles.is_empty() or roles.has(role)

func get_mp_cost(level: int) -> int:
	return int(scaled(mp_cost, mp_cost_per_level, level))

## 子類別覆寫：額外的施放條件（例如護盾已經開著就不能再開），回傳 false 不扣 MP、不進冷卻
func can_cast(_caster: Node2D) -> bool:
	return true

## 子類別覆寫：實際施放。MP/冷卻/職業檢查由 player.gd 統一處理，這裡只管產生效果
func cast(_caster: Node2D, _level: int) -> void:
	push_warning("技能 %s 沒有實作 cast()" % id)

## 1 級 = base，之後每級 + per_level
static func scaled(base: Variant, per_level: Variant, level: int) -> Variant:
	return base + per_level * (level - 1)
