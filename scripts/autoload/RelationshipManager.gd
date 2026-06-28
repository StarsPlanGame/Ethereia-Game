##======================================================
## RelationshipManager.gd - NPC 关系系统
## 挂载：Autoload 单例
## 职责：管理 NPC 对玩家的好感度（用于对话分支与剧情判断）
## 关联文档：05_SYSTEM_DESIGN.md §2.9 / 11.2
## 第一部分 NPC：shen_qingluo / han_zhaoye / li_shen / zhao_zhanggui / xiao_he
##======================================================
extends Node

var _relationships: Dictionary = {}

func change_relationship(npc_id: String, amount: int) -> void:
	_relationships[npc_id] = _relationships.get(npc_id, 0) + amount
	EventBus.relationship_changed.emit(npc_id, _relationships[npc_id])

func get_relationship(npc_id: String) -> int:
	return _relationships.get(npc_id, 0)

func set_relationship(npc_id: String, value: int) -> void:
	_relationships[npc_id] = value
	EventBus.relationship_changed.emit(npc_id, value)

func get_all_relationships() -> Dictionary:
	return _relationships.duplicate(true)

func get_save_data() -> Dictionary:
	return _relationships.duplicate(true)

func load_save_data(data: Dictionary) -> void:
	_relationships = data.duplicate(true)
