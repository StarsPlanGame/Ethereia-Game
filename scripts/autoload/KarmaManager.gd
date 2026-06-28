##======================================================
## KarmaManager.gd - 因果系统
## 挂载：Autoload 单例
## 职责：记录玩家关键选择的影响，为后续剧情分支提供判断依据
## 关联文档：05_SYSTEM_DESIGN.md §2.8 / 11.1
## 第一部分因果键：hidden_jade / helped_town / explored_temple
##======================================================
extends Node

var _karma: Dictionary = {}

func add_karma(key: String, amount: int = 1) -> void:
	_karma[key] = _karma.get(key, 0) + amount
	EventBus.karma_changed.emit(key, _karma[key])

func get_karma(key: String) -> int:
	return _karma.get(key, 0)

func has_karma(key: String) -> bool:
	return _karma.has(key) and _karma[key] != 0

func get_all_karma() -> Dictionary:
	return _karma.duplicate(true)

func get_save_data() -> Dictionary:
	return _karma.duplicate(true)

func load_save_data(data: Dictionary) -> void:
	_karma = data.duplicate(true)
