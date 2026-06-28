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
	# PlayerStats / PlayerCultivation 需要从玩家节点取（由 GameRoot 注入引用）
	# 此处通过信号让玩家节点贡献存档数据
	var player_data: Dictionary = _collect_player_save_data()
	save_data["player"] = player_data.get("player", {})
	save_data["cultivation"] = player_data.get("cultivation", {})
	save_data["inventory"] = InventorySystem.get_save_data()
	save_data["quests"] = QuestManager.get_save_data()
	save_data["story_flags"] = GameState.story_flags.duplicate(true)
	save_data["karma"] = KarmaManager.get_save_data()
	save_data["relationships"] = RelationshipManager.get_save_data()
	save_data["gathered_nodes"] = _gathered_nodes_data

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
	_gathered_nodes_data = data.get("gathered_nodes", {})
	# 玩家数据分发由 GameRoot 接收信号后处理
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

# ======== 内部辅助 ========
## 通过 EventBus 请求玩家节点提供存档数据
## GameRoot 监听 game_saving 信号并 emit game_save_collected
## TODO: 接入 GameRoot 实现后完善
func _collect_player_save_data() -> Dictionary:
	# 暂时返回空，由 GameRoot 在监听到 game_saved 信号前主动注入
	return {}
