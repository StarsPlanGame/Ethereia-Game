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
	# 默认加载青石镇（无存档时）
	if not SaveManager.has_save(1):
		SceneLoader.change_scene("qing_shi_town", "spawn_default")
	else:
		# 有存档则加载存档
		SaveManager.load_game(1)
		SceneLoader.change_scene(GameState.current_scene_id, GameState.current_spawn_id)

func _on_scene_changed(_scene_id: String) -> void:
	player.visible = true
