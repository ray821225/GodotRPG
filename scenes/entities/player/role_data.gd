extends RefCounted

## 各職業初始配點（demo：init lv:5，四維基礎屬性各 10，每升一級 +5 屬性點 +5 技能點）
const BASE_STATS: Dictionary = {
	"Knight": {"hp": 10000, "mp": 50, "atk": 60, "m_atk": 20, "def": 80, "m_def": 80, "atk_speed": 0.5, "walk_speed": 300},
	#"Sword": {"hp": 80, "mp": 70, "atk": 110, "m_atk": 20, "def": 60, "m_def": 50, "atk_speed": 1.3, "walk_speed": 110},
	#"Wizard": {"hp": 50, "mp": 100, "atk": 30, "m_atk": 120, "def": 30, "m_def": 60, "atk_speed": 0.8, "walk_speed": 90},
	#"Priest": {"hp": 60, "mp": 90, "atk": 60, "m_atk": 90, "def": 30, "m_def": 60, "atk_speed": 0.9, "walk_speed": 90},
	#"Archer": {"hp": 70, "mp": 80, "atk": 120, "m_atk": 60, "def": 30, "m_def": 30, "atk_speed": 1.1, "walk_speed": 105},
	#"Ninja": {"hp": 60, "mp": 90, "atk": 140, "m_atk": 60, "def": 20, "m_def": 20, "atk_speed": 1.45, "walk_speed": 120},
}
#1

static func get_stats(role_name: String) -> Dictionary:
	return BASE_STATS.get(role_name, {})
