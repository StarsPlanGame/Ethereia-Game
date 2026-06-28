##======================================================
## DataManager.gd - 数据读取中心
## 挂载：Autoload 单例
## 职责：统一加载和管理所有 JSON 数据文件
## 关联文档：05_SYSTEM_DESIGN.md §2.3 / 08_DATA_SCHEMA.md
##======================================================
extends Node

# ======== 数据文件路径 ========
const DATA_DIR := "res://data"
const PATH_ITEMS := "res://data/items.json"
const PATH_QUESTS := "res://data/quests.json"
const PATH_ENEMIES := "res://data/enemies.json"
const PATH_SKILLS := "res://data/skills.json"
const PATH_DIALOGUES := "res://data/dialogues.json"
const PATH_NPCS := "res://data/npcs.json"

# ======== 内存数据缓存 ========
## 以 id 为 key 的字典，便于 O(1) 查询
var _items: Dictionary = {}
var _quests: Dictionary = {}
var _enemies: Dictionary = {}
var _skills: Dictionary = {}
var _dialogues: Dictionary = {}
var _npcs: Dictionary = {}

var _loaded: bool = false

# ======== 生命周期 ========
func _ready() -> void:
	load_all_data()

# ======== 数据加载 ========
## 加载所有数据文件到内存
func load_all_data() -> void:
	_items = _load_json_as_dict_by_id(PATH_ITEMS)
	_quests = _load_json_as_dict_by_id(PATH_QUESTS)
	_enemies = _load_json_as_dict_by_id(PATH_ENEMIES)
	_skills = _load_json_as_dict_by_id(PATH_SKILLS)
	_dialogues = _load_json_file(PATH_DIALOGUES)  # 对话以 ID 为键直接存储
	_npcs = _load_json_as_dict_by_id(PATH_NPCS)
	_loaded = true
	print("[DataManager] 数据加载完成：items=%d quests=%d enemies=%d skills=%d dialogues=%d npcs=%d" % [
		_items.size(), _quests.size(), _enemies.size(),
		_skills.size(), _dialogues.size(), _npcs.size()
	])

## 重新加载所有数据（编辑器内调试用）
func reload() -> void:
	load_all_data()

# ======== 查询接口 ========
func get_item(item_id: String) -> Dictionary:
	return _items.get(item_id, {})

func get_quest(quest_id: String) -> Dictionary:
	return _quests.get(quest_id, {})

func get_enemy(enemy_id: String) -> Dictionary:
	return _enemies.get(enemy_id, {})

func get_skill(skill_id: String) -> Dictionary:
	return _skills.get(skill_id, {})

func get_dialogue(dialogue_id: String) -> Dictionary:
	return _dialogues.get(dialogue_id, {})

func get_npc(npc_id: String) -> Dictionary:
	return _npcs.get(npc_id, {})

func get_all_items() -> Dictionary:
	return _items

func get_all_quests() -> Dictionary:
	return _quests

func get_all_dialogues() -> Dictionary:
	return _dialogues

# ======== 内部工具 ========
## 加载 JSON 数组，按 "id" 或 "quest_id" 字段索引为字典
func _load_json_as_dict_by_id(path: String) -> Dictionary:
	var arr: Variant = _load_json_file(path)
	if arr is Array:
		var dict: Dictionary = {}
		for entry in arr:
			if entry is Dictionary:
				var id: String = entry.get("id", entry.get("quest_id", ""))
				if id != "":
					dict[id] = entry
		return dict
	return {}

## 通用 JSON 加载（文件不存在时返回空 Dictionary）
func _load_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("[DataManager] 数据文件不存在: %s" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DataManager] 无法打开文件: %s" % path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("[DataManager] JSON 解析失败 %s 行 %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data
