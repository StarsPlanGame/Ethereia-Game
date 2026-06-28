##======================================================
## SceneLoader.gd - 场景切换系统
## 挂载：Autoload 单例
## 职责：根据 scene_id 加载地图、定位玩家到 spawn_id、防重复切换
## 关联文档：05_SYSTEM_DESIGN.md §2.6 / 02_TDD §5
##======================================================
extends Node

# ======== 场景 ID -> 资源路径映射 ========
const SCENE_MAP := {
	"qing_shi_town": "res://scenes/maps/QingShiTown.tscn",
	"qing_shi_forest": "res://scenes/maps/QingShiForest.tscn",
	"nether_temple": "res://scenes/maps/NetherTemple.tscn",
}

# ======== 切换防抖 ========
var _is_changing: bool = false
var _pending_scene_id: String = ""
var _pending_spawn_id: String = ""

# ======== 引用 ========
## 当前场景容器节点（由 GameRoot 在 _ready() 中注入）
var current_scene_container: Node = null
## 当前活动场景根节点
var current_scene: Node = null

# ======== 接口 ========
func change_scene(scene_id: String, spawn_id: String = "") -> void:
	if _is_changing:
		print("[SceneLoader] 已在切换中，忽略请求: %s" % scene_id)
		return
	if not SCENE_MAP.has(scene_id):
		push_error("[SceneLoader] 未知场景 ID: %s" % scene_id)
		return
	if current_scene_container == null:
		push_error("[SceneLoader] current_scene_container 未注入，请检查 GameRoot 初始化")
		return
	_is_changing = true
	_pending_scene_id = scene_id
	_pending_spawn_id = spawn_id
	EventBus.scene_change_requested.emit(scene_id, spawn_id)
	_do_change_scene()

func _do_change_scene() -> void:
	# 释放当前场景
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	# 加载新场景
	var path: String = SCENE_MAP[_pending_scene_id]
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("[SceneLoader] 无法加载场景: %s" % path)
		_is_changing = false
		return
	current_scene = packed.instantiate()
	current_scene_container.add_child(current_scene)
	# 更新 GameState
	GameState.current_scene_id = _pending_scene_id
	GameState.current_spawn_id = _pending_spawn_id
	# 通知场景内的 SpawnPoint 系统
	_notify_spawn_point()
	_is_changing = false
	EventBus.scene_changed.emit(_pending_scene_id)
	print("[SceneLoader] 场景已切换: %s (spawn=%s)" % [_pending_scene_id, _pending_spawn_id])

## 在新场景中查找对应 spawn_id 的 Marker2D，并把玩家移动过去
## 玩家节点由 GameRoot 持有，跨场景不销毁
func _notify_spawn_point() -> void:
	if _pending_spawn_id == "":
		return
	if current_scene == null:
		return
	# 查找场景中的 SpawnPoints 节点组
	var spawn_points: Node = current_scene.get_node_or_null("SpawnPoints")
	if spawn_points == null:
		return
	for sp in spawn_points.get_children():
		if sp is Marker2D and sp.name == _pending_spawn_id:
			# 通知 GameRoot 移动玩家到此处
			var player: Node2D = _get_player()
			if player != null:
				player.global_position = sp.global_position
			return

## 获取 GameRoot 中的玩家节点
func _get_player() -> Node2D:
	var game_root: Node = current_scene_container.get_parent()
	if game_root == null:
		return null
	return game_root.get_node_or_null("Player")
