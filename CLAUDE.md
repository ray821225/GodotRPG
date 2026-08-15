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

- `scenes/entities/` — 玩家與敵人（各自包含 `.tscn` 場景與同名 `.gd` 腳本）
- `scenes/maps/` — 地圖場景（`test_map.tscn` 為目前主場景）
- `scenes/ui/` — UI 元件（如 `damage_number`）
- `scenes/main`、`support`、`template`、`effects` — 目前僅有 `.gitkeep` 佔位，尚未使用
- `assets/` — 美術、音效、字型、圖塊集圖片（`.png` 皆附 `.import`）
- `resources/tilesets/` — 共用的 TileSet 資源（`.tres`）

### 實體共通模式（player.gd 與 slime.gd）

兩個角色皆為 `CharacterBody2D`，遵循一致的結構，新增實體時應沿用：

1. **狀態機**：以 `enum State` + `var state` 驅動，`_physics_process` 依狀態分派行為，切換狀態時呼叫動畫更新。
2. **戰鬥採用 duck typing**：攻擊時把 `HitBox`（Area2D）的 `monitoring` 設為 `true`，用計時器 `await get_tree().create_timer(...).timeout` 延遲後呼叫 `deal_damage()`，遍歷 `hit_box.get_overlapping_bodies()`，對「有 `take_damage` 方法」的 body 造成傷害。任何實作 `take_damage(amount: int)` 的節點都可被攻擊——這是實體間互動的核心契約。
3. **受擊回饋**：`take_damage()` → 更新 `health_bar`、`_spawn_damage_number()`（實例化 `res://scenes/ui/damage_number.tscn` 加到 `current_scene`）、`_flash_damage()`（用 tween 讓 sprite 閃紅）、HP 歸零則 `die()` → `queue_free()`。
4. **血條樣式**：以程式碼在 `_style_health_bar()` 中用 `StyleBoxFlat` 覆寫 `fill`/`background` theme。

### 動畫

- **Player**：使用 `AnimationTree` + `AnimationNodeStateMachine`，攻擊方向透過 `BlendSpace2D`（依滑鼠方向設定 `blend_position`）決定四向攻擊動畫。透過 `animation_playback.travel("idle"/"run"/"attack")` 切換。
- **Slime**：較簡單，直接用 `AnimationPlayer.play("idle"/"run"/"attack_down")`。
- 角色動畫皆為 sprite sheet 逐格（`Sprite2D:frame` 軌道，6 幀/動作，`hframes`/`vframes` 定義切割）。

### 碰撞層約定（重要，設定 Area2D/CharacterBody2D 時務必遵守）

- **Layer 1**：世界/地形（TileMap 的 physics layer）
- **Layer 2**：玩家（Player `collision_layer = 2`）
- **Layer 3**（值 4）：敵人（Slime `collision_layer = 4`）
- HitBox 與 DetectionArea 的 `collision_layer = 0`（自身不被偵測），僅設 `collision_mask` 指向要命中的目標層。例：玩家 HitBox `mask = 4`（打敵人）；史萊姆 HitBox/DetectionArea `mask = 2`（偵測/打玩家）。

### 地圖圖層（test_map.tscn）

以多個 `TileMapLayer` 依 `z_index` 分層堆疊（Water -5、FoamRocks -4、Ground -3、Shadow -2、Plateau -1、Props 0）。根節點與含實體/道具的圖層啟用 `y_sort_enabled` 以正確處理 2D 深度排序。地形使用 Godot 的 terrain/autotile（peering bits）自動接圖。
