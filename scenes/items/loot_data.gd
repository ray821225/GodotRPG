extends Resource

## 掉落物資料：一份 LootData 描述「掉落什麼、長怎樣、多少數量、抽中權重」。
## coin 用 amount 當金額，其他道具（例如肉）用 amount 當數量。

@export var item_id: String = "coin"
@export var texture: Texture2D
@export var amount: int = 1
## 加權隨機抽選用：權重越高越常掉落，數值只有相對比例有意義，不用總和為 1。
@export var weight: float = 1.0
