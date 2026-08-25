# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

使用 Godot 引擎開發的 2D RPG 遊戲。雖然資料夾名稱為 `(4.4)`，`project.godot` 的 `config/features` 已升級至 **Godot 4.6**（Forward Plus 渲染）。使用 GDScript，程式碼與場景大量採用型別註記（`: int`、`-> void` 等）。1.以繁體中文回覆及註解,簡潔說明

## 執行與開發

本專案已透過 `.mcp.json` 設定 **godot MCP server**，優先使用其工具而非手動命令列：

- `mcp__godot__run_project` — 執行遊戲（主場景為 `scenes/maps/test_map.tscn`，uid `jk41fugdc6c7`）
- `mcp__godot__launch_editor` — 開啟 Godot 編輯器
- `mcp__godot__get_debug_output` — 取得執行時的 stdout/錯誤輸出
- `mcp__godot__stop_project` — 停止執行中的遊戲
- 場景/節點操作：`create_scene`、`add_node`、`save_scene`、`load_sprite` 等

沒有測試框架、建置腳本或 linter；驗證方式是實際執行遊戲並觀察 `get_debug_output`。

**輸入對應**（`project.godot` 定義）：`left`/`right`/`up`/`down` = WASD；攻擊為滑鼠左鍵（在腳本中直接以 `MOUSE_BUTTON_LEFT` 處理，非 InputMap action）。

## 架構

### 目錄結構

- `scenes/entities/player/` — 玩家（`player.tscn` + `player.gd`，`role_data.gd` 定義職業初始配點）
- `scenes/entities/enemies/` — 敵人，見下方「敵人架構」一節（`enemy_base.gd`/`enemy_data.gd` 共用，`slime.gd`/`slime_data.gd` 是近戰型別實作，非每種敵人各自一份腳本）
- `scenes/items/` — 掉落物（`pickup.tscn` + `pickup.gd`、`loot_data.gd`），見下方「掉落物系統」一節
- `scenes/maps/` — 地圖場景（`test_map.tscn` 為目前主場景）
- `scenes/ui/` — UI 元件（如 `damage_number`）
- `scenes/main`、`support`、`template` — 目前僅有 `.gitkeep` 佔位，尚未使用
- `assets/` — 美術、音效、字型、圖塊集圖片（`.png` 皆附 `.import`）；敵人 sprite 依種類分子資料夾，例如 `assets/sprites/enemies/slime/`
- `resources/tilesets/` — 共用的 TileSet 資源（`.tres`）
- `resources/enemies/` — 敵人資料驅動用的 `.tres`（`*_data_*.tres` 數值、`*_frames_*.tres` 動畫幀）

### 實體共通模式

玩家（`player.gd`）與敵人（`enemy_base.gd` 及其子類別）皆為 `CharacterBody2D`，共同遵循一致的結構：

1. **狀態機**：以 `enum State` + `var state` 驅動，`_physics_process` 依狀態分派行為，切換狀態時呼叫動畫更新。
2. **戰鬥採用 duck typing**：攻擊時把 `HitBox`（Area2D）的 `monitoring` 設為 `true`，用計時器延遲後呼叫 `deal_damage()`，遍歷 `hit_box.get_overlapping_areas()`，對「有 `take_damage` 方法」的節點造成傷害。任何實作 `take_damage(amount, type, attacker)` 的節點都可被攻擊——這是實體間互動的核心契約（`attacker` 為可選參數，帶入攻擊來源可觸發擊退與反向鎖定追擊）。
3. **受擊回饋**：`take_damage()` → 更新 `health_bar`、`_spawn_damage_number()`（實例化 `res://scenes/ui/damage_number.tscn` 加到 `current_scene`，根節點需設 `z_index`〔目前用 100〕蓋過地圖 y-sort，否則會被樹木等物件擋住）、`_flash_damage()`（tween 閃紅）、`apply_knockback(direction, strength)`（往受擊方向用 tween 輕推一小段距離），HP 歸零則 `die()`。
4. **血條樣式**：以程式碼在 `_style_health_bar()` 中用 `StyleBoxFlat` 覆寫 `fill`/`background` theme。
5. **HurtBox 與 CollisionShape2D 分離**：`HurtBox`（Area2D，`collision_layer` 設為自身陣營層）專門負責「被攻擊判定範圍」，`CollisionShape2D` 只管跟地形/其他角色的物理碰撞，兩者形狀與位置可以不同，避免角色被遠距離誤判命中。

### 敵人架構：EnemyBase / EnemyData（新增敵人請沿用這套骨架）

敵人邏輯拆成「行為」與「資料」兩層，新增顏色或種類不必複製程式碼：

- **`scenes/entities/enemies/enemy_base.gd`**：所有敵人共用的行為基底。內含狀態機（IDLE/WANDER/CHASE/ATTACK/DEAD）、漫遊（`_restart_wander_timer()` 每次重新抽隨機間隔，避免多隻敵人漫遊/停止節奏同步）、追擊、受傷、死亡、重生。「怎麼發動攻擊」不算共用行為，交給子類別覆寫三個掛勾即可：
  - `_perform_attack(dir)`：實際攻擊手段（近戰揮擊判定、之後的遠程射箭、法師施法…）
  - `_stop_attacking()`：死亡瞬間要順便關掉的攻擊判定（例如近戰的 `hit_box.monitoring`）
  - `_apply_extra_data()`：讀取子類別專屬的 data 欄位
- **`scenes/entities/enemies/enemy_data.gd`**：所有敵人共用的資料基底（`Resource`），欄位含 hp/速度/攻速/攻擊力/巡邏/重生秒數，以及 `use_detection`（是否主動索敵；關閉時不會主動靠近，但只要被打中一次就會回頭鎖定攻擊者追擊——`take_damage()` 收到 `attacker` 就會設定 `player = attacker` 並切到 CHASE，跟 `use_detection` 無關）。
- **近戰型別（目前唯一實作）**：`scenes/entities/enemies/slime.gd extends enemy_base.gd`，用 `HitBox` 判定傷害；`data.attack_animations`（`Array[StringName]`）可放多組動畫名稱、每次攻擊隨機挑一種播放，動畫實際長度直接從 `SpriteFrames.get_frame_count()/get_animation_speed()` 換算，不能寫死秒數（否則動畫還沒播完就提早收招、搶跑下一次攻擊，會變成一次揮擊算兩次傷害）。`scenes/entities/enemies/slime_data.gd extends enemy_data.gd` 是對應資料型別，額外加了 `attack_animations`。之後要新增「近戰哥布林」之類，直接沿用 `slime.gd` + `slime_data.gd` 當骨架即可（屆時再考慮把檔名改中性）；遠程/法師型別則另外繼承 `enemy_base.gd`/`enemy_data.gd`，只需實作各自的 `_perform_attack()` 與資料子類別。
- **資料驅動的顏色範例（史萊姆）**：`scenes/entities/enemies/slime.tscn` 是共用場景（`AnimatedSprite2D` 不內建 `sprite_frames`，由 `_ready()` 依 `data` 動態指派）。7 個顏色分別是 `resources/enemies/slime_data_<color>.tres`（數值）+ `resources/enemies/slime_frames_<color>.tres`（動畫幀，來源圖在 `assets/sprites/enemies/slime/`）。新增一個顏色/變種：複製一份 `slime_data_*.tres`、指到新的 `SpriteFrames` resource，在地圖場景 instance `slime.tscn`、把 `data` 欄位指過去即可，不用寫程式碼或複製場景。

### 掉落物系統

- **`scenes/items/loot_data.gd`**：掉落物資料（`Resource`），欄位為 `item_id`（`"coin"` / `"meat"` 等）、`texture`、`amount`（coin 當金額，其他道具當數量）、`weight`（加權隨機用，只有相對比例有意義）。`resources/items/loot_*.tres` 是實際的掉落項目（`loot_coin_1~6.tres` 對應 6 種金額，`loot_meat.tres`）。
- **`enemy_data.gd`** 新增 `loot_drop_chance`（死亡時掉東西的機率）與 `loot_table: Array[LootData]`，預設已 preload 上述全部 7 種，個別敵人要客製掉落表可直接在該敵人的 `.tres` 裡覆寫這個欄位。
- **`enemy_base.gd`** 的 `die()` 會呼叫 `_drop_loot()`：機率過關後用 `weight` 加權隨機抽一項，`instantiate` `scenes/items/pickup.tscn` 並在死亡位置附近小範圍隨機偏移。
- **`scenes/items/pickup.gd`**：掉在地上的 `Area2D`，`setup(loot)` 帶入貼圖/`item_id`/`amount`。拾取走 duck typing 契約：呼叫方（玩家）對它呼叫 `collect(collector)`，內部再呼叫 `collector.collect_item(item_id, amount)`；沒有實作 `collect_item` 的節點不會觸發效果。
- **玩家端**：`player.gd` 的 `InteractArea`（`collision_mask = 16`）偵測範圍內的掉落物，按 `interact`（F 鍵）觸發 `_try_interact()`，對範圍內所有掉落物呼叫 `collect()`。`collect_item()` 裡 `item_id == "coin"` 直接加 `gold`（同步更新 HUD 的 `GoldLabel`），其餘道具先丟進 `inventory` 這個 Dictionary 計數，尚未接背包 UI（階段 3 待補）。

### 動畫

- **Player**：使用 `AnimationTree` + `AnimationNodeStateMachine`，攻擊方向透過 `BlendSpace2D`（依滑鼠方向設定 `blend_position`）決定四向攻擊動畫。透過 `animation_playback.travel("idle"/"run"/"attack")` 切換。攻擊的「動作鎖定時間」（`ATTACK_LOCK_DURATION`）與「下一次可攻擊的冷卻」（`attack_speed`）刻意分開算，動畫播放速度不隨攻速拉長/壓縮，手感才不會忽快忽慢。
- **敵人**：用 `AnimatedSprite2D` + `SpriteFrames`（非 `AnimationPlayer` 逐幀 track），`sprite.play("idle"/"run"/"attack"/...)` 切換，動畫本身用幾幀、幾 fps 都由對應的 `slime_frames_*.tres` 決定，程式碼不寫死。
- 角色動畫皆為 sprite sheet 逐格拆分（Player 用 `Sprite2D:frame` 軌道 + `hframes`/`vframes`；敵人用 `AtlasTexture` 依幀切割後組進 `SpriteFrames`）。

### 碰撞層約定（重要，設定 Area2D/CharacterBody2D 時務必遵守）

- **Layer 1**：世界/地形（TileMap 的 physics layer）
- **Layer 2**：玩家（Player `collision_layer = 2`）
- **Layer 3**（值 4）：敵人（Slime `collision_layer = 4`）
- **Layer 5**（值 16）：掉落物（`Pickup` `collision_layer = 16`，`monitoring = false`／`monitorable = true`，本身不主動偵測誰）
- HitBox 與 DetectionArea 的 `collision_layer = 0`（自身不被偵測），僅設 `collision_mask` 指向要命中的目標層。例：玩家 HitBox `mask = 4`（打敵人）；史萊姆 HitBox/DetectionArea `mask = 2`（偵測/打玩家）；玩家 `InteractArea` `mask = 16`（偵測掉落物）。

### 地圖圖層（test_map.tscn）

以多個 `TileMapLayer` 依 `z_index` 分層堆疊（Water -5、FoamRocks -4、Ground -3、Shadow -2、Plateau -1、Props 0）。根節點與含實體/道具的圖層啟用 `y_sort_enabled` 以正確處理 2D 深度排序。地形使用 Godot 的 terrain/autotile（peering bits）自動接圖。
