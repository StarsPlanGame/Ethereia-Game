##======================================================
## GameRoot.gd - 游戏运行根节点
## 挂载：GameRoot.tscn 根节点（Node2D）
## 职责：持有玩家、UI、地图容器；注入 SceneLoader 引用；接收存档信号
## 关联文档：02_TDD_TECHNICAL_DESIGN.md §3.1
##======================================================
extends Node2D
class_name GameRoot

@onready var player: CharacterBody2D = $Player
@onready var scene_container: Node2D = $SceneContainer
@onready var ui_layer: CanvasLayer = $UILayer

func _ready() -> void:
	# 把场景容器引用注入 SceneLoader
	SceneLoader.current_scene_container = scene_container
	# 监听场景切换完成，玩家在新场景中显示
	EventBus.scene_changed.connect(_on_scene_changed)
	# 监听读档信号，分发玩家数据
	EventBus.game_loaded.connect(_on_game_loaded)
	# 默认加载青石镇（无存档时）
	if not SaveManager.has_save(1):
		SceneLoader.change_scene("qing_shi_town", "spawn_default")
	else:
		# 有存档则加载存档
		SaveManager.load_game(1)
		SceneLoader.change_scene(GameState.current_scene_id, GameState.current_spawn_id)

func _on_scene_changed(_scene_id: String) -> void:
	player.visible = true

## 读档后分发玩家数据（位置/属性/修炼）
func _on_game_loaded(_slot_id: int) -> void:
	var data: Dictionary = SaveManager.pop_pending_player_data()
	if data.is_empty():
		return
	if player != null and player.has_method("load_save_data"):
		# 构造完整玩家存档结构
		var player_data: Dictionary = {
			"position_x": data.get("position_x", 0),
			"position_y": data.get("position_y", 0),
			"facing": data.get("facing", 1),
			"stats": data.get("stats", {}),
			"cultivation": data.get("cultivation", {}),
		}
		player.load_save_data(player_data)
