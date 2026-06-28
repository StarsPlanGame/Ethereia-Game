##======================================================
## SaveManager.gd - 存档系统
## 挂载：Autoload 单例
## 职责：聚合各系统的 get_save_data 写入 JSON，读取时分发 load_save_data
## 关联文档：05_SYSTEM_DESIGN.md §2.7 / 02_TDD §6
##======================================================
extends Node

const SAVE_VERSION := "0.1.0"
const SAVE_DIR := "user://"
const SAVE_FILE_TEMPLATE := "save_slot_%d.json"

# ======== 接口 ========
func save_game(slot_id: int = 1) -> void:
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	# 聚合各系统数据
	save_data.merge(GameState.get_save_data())
	# 玩家数据：通过 group("player") 查找玩家节点
	var player_data: Dictionary = _collect_player_save_data()
	save_data["player"] = player_data.get("stats", {})
	save_data["cultivation"] = player_data.get("cultivation", {})
	save_data["inventory"] = InventorySystem.get_save_data()
	save_data["quests"] = QuestManager.get_save_data()
	save_data["story_flags"] = GameState.story_flags.duplicate(true)
	save_data["karma"] = KarmaManager.get_save_data()
	save_data["relationships"] = RelationshipManager.get_save_data()
	save_data["gathered_nodes"] = _gathered_nodes_data
	save_data["story_triggered"] = _story_triggered_data

	var path: String = SAVE_DIR + (SAVE_FILE_TEMPLATE % slot_id)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 无法写入存档: %s" % path)
		return
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	EventBus.game_saved.emit(slot_id)
	print("[SaveManager] 存档成功: %s" % path)

func load_game(slot_id: int = 1) -> void:
	var path: String = SAVE_DIR + (SAVE_FILE_TEMPLATE % slot_id)
	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] 存档不存在: %s" % path)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] 无法读取存档: %s" % path)
		return
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("[SaveManager] 存档 JSON 解析失败")
		return
	var data: Dictionary = json.data

	# 分发到各系统
	GameState.load_save_data({
		"current_scene_id": data.get("current_scene_id", "qing_shi_town"),
		"current_spawn_id": data.get("current_spawn_id", "spawn_default"),
		"game_day": data.get("game_day", 1),
		"story_flags": data.get("story_flags", {}),
	})
	InventorySystem.load_save_data(data.get("inventory", {}))
	QuestManager.load_save_data(data.get("quests", {}))
	KarmaManager.load_save_data(data.get("karma", {}))
	RelationshipManager.load_save_data(data.get("relationships", {}))
	_gathered_nodes = data.get("gathered_nodes", {})
	_story_triggered = data.get("story_triggered", {})
	# 玩家数据由 GameRoot 监听 game_loaded 信号后分发
	_pending_player_data = {
		"stats": data.get("player", {}),
		"cultivation": data.get("cultivation", {}),
		"position_x": data.get("position_x", 0),
		"position_y": data.get("position_y", 0),
		"facing": data.get("facing", 1),
	}
	EventBus.game_loaded.emit(slot_id)
	print("[SaveManager] 读档成功: %s" % path)

func has_save(slot_id: int = 1) -> bool:
	return FileAccess.file_exists(SAVE_DIR + (SAVE_FILE_TEMPLATE % slot_id))

func delete_save(slot_id: int = 1) -> void:
	var path: String = SAVE_DIR + (SAVE_FILE_TEMPLATE % slot_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# ======== 采集点状态（不属于任何单例，暂存于此）========
var _gathered_nodes: Dictionary = {}
var _gathered_nodes_data: Dictionary:
	get:
		return _gathered_nodes

func mark_gathered(node_id: String) -> void:
	_gathered_nodes[node_id] = true

func is_gathered(node_id: String) -> bool:
	return _gathered_nodes.get(node_id, false)

## 清空所有采集点记录（仅测试用）
func reset_gathered() -> void:
	_gathered_nodes.clear()

# ======== 剧情触发器状态（一次性触发防重复）========
var _story_triggered: Dictionary = {}
var _story_triggered_data: Dictionary:
	get:
		return _story_triggered

func mark_story_triggered(trigger_id: String) -> void:
	_story_triggered[trigger_id] = true

func is_story_triggered(trigger_id: String) -> bool:
	return _story_triggered.get(trigger_id, false)

## 清空所有剧情触发记录（仅测试用）
func reset_story_triggered() -> void:
	_story_triggered.clear()

# ======== 待分发的玩家数据（GameRoot 读档时取用）========
var _pending_player_data: Dictionary = {}

## GameRoot 在 game_loaded 信号后调用，取出待分发的玩家数据
func pop_pending_player_data() -> Dictionary:
	var data: Dictionary = _pending_player_data
	_pending_player_data = {}
	return data

# ======== 内部辅助 ========
## 通过 group("player") 查找玩家节点并收集存档数据
func _collect_player_save_data() -> Dictionary:
	var tree: SceneTree = get_tree()
	if tree == null:
		return {}
	var player: Node = tree.get_first_node_in_group("player")
	if player == null or not player.has_method("get_save_data"):
		return {}
	return player.get_save_data()
