##======================================================
## InventorySystem.gd - 背包系统
## 挂载：Autoload 单例
## 职责：管理玩家持有道具的增删查改与消耗品使用
## 关联文档：05_SYSTEM_DESIGN.md §2.4 / 08_DATA_SCHEMA.md §2
##======================================================
extends Node

# ======== 内存数据 ========
## key: item_id, value: 数量（已自动处理堆叠）
var _inventory: Dictionary = {}

# ======== 查询接口 ========
func get_item_count(item_id: String) -> int:
	return _inventory.get(item_id, 0)

func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount

func get_all_items() -> Dictionary:
	return _inventory.duplicate(true)

# ======== 修改接口 ========
## 添加道具（自动堆叠），成功后发送 item_collected 信号
func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	_inventory[item_id] = _inventory.get(item_id, 0) + amount
	EventBus.item_collected.emit(item_id, amount)

## 移除道具，成功返回 true 并发送 item_removed 信号
func remove_item(item_id: String, amount: int = 1) -> bool:
	if not has_item(item_id, amount):
		return false
	_inventory[item_id] -= amount
	if _inventory[item_id] <= 0:
		_inventory.erase(item_id)
	EventBus.item_removed.emit(item_id, amount)
	return true

## 使用消耗品（基于 effects 字段触发效果）
## 第一部分效果类型：heal_hp / heal_mp / unlock_cultivation / add_qi
## TODO: 待 PlayerStats / CultivationSystem 实现后接入
func use_item(item_id: String) -> bool:
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		push_warning("[Inventory] 道具数据不存在: %s" % item_id)
		return false
	if item_data.get("type") != "consumable":
		return false
	if not has_item(item_id):
		return false
	# TODO: 执行 effects 列表
	# for effect in item_data.get("effects", []):
	#     _apply_effect(effect)
	remove_item(item_id, 1)
	EventBus.item_used.emit(item_id, 1)
	return true

# ======== 存档接口 ========
func get_save_data() -> Dictionary:
	return _inventory.duplicate(true)

func load_save_data(data: Dictionary) -> void:
	_inventory = data.duplicate(true)
