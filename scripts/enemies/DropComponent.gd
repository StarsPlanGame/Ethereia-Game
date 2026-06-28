##======================================================
## DropComponent.gd - 敌人掉落组件
## 挂载：EnemyBase.tscn 上的 Node 子节点（Drop）
## 职责：敌人死亡时按数据表配置掉落道具
## 关联文档：02_TDD_TECHNICAL_DESIGN.md §4.6 / 08_DATA_SCHEMA.md §4
##======================================================
extends Node
class_name DropComponent

# ======== 掉落表配置 ========
## 直接在节点上配置（覆盖数据表），格式同 enemies.json 的 drops 字段
@export var custom_drops: Array = []
## 是否使用数据表中的掉落配置（默认 true）
@export var use_data_table: bool = true

# ======== 掉落逻辑 ========
func drop_loot() -> void:
	var drops: Array = _get_drops()
	for drop in drops:
		var item_id: String = drop.get("item_id", "")
		var chance: float = drop.get("chance", 1.0)
		var amount: int = drop.get("amount", 1)
		if item_id == "":
			continue
		# 概率判定
		if randf() > chance:
			continue
		# 直接加入背包（第一部分简化：无地面掉落物）
		InventorySystem.add_item(item_id, amount)
		var item_name: String = DataManager.get_item(item_id).get("name", item_id)
		EventBus.notification_shown.emit("获得 %s × %d" % [item_name, amount])

## 获取有效掉落表
func _get_drops() -> Array:
	if not use_data_table and not custom_drops.is_empty():
		return custom_drops
	# 从敌人数据表读取
	var enemy: Node = get_parent()
	if enemy == null or not ("enemy_id" in enemy):
		return []
	var data: Dictionary = DataManager.get_enemy(enemy.enemy_id)
	return data.get("drops", [])
