extends RefCounted

## 全遊戲共用的傷害公式，玩家（player.gd）跟敵人（enemy_base.gd）的 take_damage()
## 都呼叫這裡，不要各自算一份，改公式只要改這裡一個地方。
##
## 防禦力用比例遞減：倍率 = 100 / (100 + 防禦力)。防禦永遠不會讓傷害歸零，
## 但每多一點防禦的邊際減傷效果會遞減，數值後續要怎麼調都不會出現「打不動」的下限問題。
## 另外套 0.9~1.1 的隨機浮動，最低保底 1 點傷害。

const VARIANCE_MIN: float = 0.9
const VARIANCE_MAX: float = 1.1

static func calculate(base_damage: int, defense: float) -> int:
	var multiplier: float = 100.0 / (100.0 + defense)
	var variance: float = randf_range(VARIANCE_MIN, VARIANCE_MAX)
	return maxi(1, int(round(base_damage * multiplier * variance)))
