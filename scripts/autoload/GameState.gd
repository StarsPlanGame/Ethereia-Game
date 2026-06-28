##======================================================
## GameState.gd - 全局游戏状态
## 挂载：Autoload 单例（project.godot 中注册）
## 职责：维护跨场景的全局游戏运行时状态
## 关联文档：05_SYSTEM_DESIGN.md §2.1
##======================================================
extends Node

# ======== 当前场景与位置 ========
## 当前场景 ID（对应 SceneLoader.scene_map 的 key）
var current_scene_id: String = "qing_shi_town"
## 当前出生点 ID（场景切换后定位玩家）
var current_spawn_id: String = "spawn_default"

# ======== 游戏运行时状态 ========
## 当前游戏天数（第一部分固定为 1）
var game_day: int = 1
## 是否处于对话中（对话期间锁定玩家移动）
var is_in_dialogue: bool = false
## 是否处于战斗中（用于 UI 切换与输入锁定）
var is_in_battle: bool = false
## 是否处于打坐修炼中
var is_cultivating: bool = false
## 是否暂停（用于暂停菜单）
var is_paused: bool = false

# ======== 剧情标记 ========
## 剧情标记字典（动态读写，存档保存）
## 第一部分已知键：
##   has_nether_jade        - 是否获得冥天玉
##   heard_forest_warning   - 听过山林警告
##   found_temple           - 发现冥墟古观
##   saved_town             - 拯救青石镇
##   entered_cultivation    - 进入修炼
var story_flags: Dictionary = {}

# ======== 接口 ========
## 设置剧情标记
func set_story_flag(key: String, value) -> void:
	story_flags[key] = value
	EventBus.story_flag_changed.emit(key, value)

## 读取剧情标记
func get_story_flag(key: String, default = false):
	return story_flags.get(key, default)

## 是否拥有某标记（bool 简化判断）
func has_story_flag(key: String) -> bool:
	return story_flags.get(key, false) == true

# ======== 存档接口 ========
func get_save_data() -> Dictionary:
	return {
		"current_scene_id": current_scene_id,
		"current_spawn_id": current_spawn_id,
		"game_day": game_day,
		"story_flags": story_flags.duplicate(true),
	}

func load_save_data(data: Dictionary) -> void:
	current_scene_id = data.get("current_scene_id", "qing_shi_town")
	current_spawn_id = data.get("current_spawn_id", "spawn_default")
	game_day = data.get("game_day", 1)
	story_flags = data.get("story_flags", {})
