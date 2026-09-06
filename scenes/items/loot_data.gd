extends Resource

## 掉落物資料：一份 LootData 描述「掉落什麼、長怎樣、多少數量、抽中權重」。
## coin 用 amount 當金額，其他道具（例如肉）用 amount 當數量。

@export var item_id: String = "coin"
@export var texture: Texture2D
## 有填的話優先用這個播放動畫（例如金幣的旋轉效果），沒填才 fallback 用上面的靜態 texture。
@export var sprite_frames: SpriteFrames
@export var amount: int = 1
## 加權隨機抽選用：權重越高越常掉落，數值只有相對比例有意義，不用總和為 1。
@export var weight: float = 1.0
## 顯示縮放倍率，預設 1.0（沿用貼圖原始像素大小）。原始美術素材解析度不一致時，
## 用這個縮小顯示即可，不用另外裁切存縮圖檔。
@export var display_scale: float = 1.0
