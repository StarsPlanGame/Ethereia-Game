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
## 注意：quest 类型道具（如冥天玉）不通过此接口使用，由剧情触发
func use_item(item_id: String) -> bool:
	var item_data: Dictionary = DataManager.get_item(item_id)
	if item_data.is_empty():
		push_warning("[Inventory] 道具数据不存在: %s" % item_id)
		return false
	if item_data.get("type") != "consumable":
		return false
	if not has_item(item_id):
		return false
	# 执行 effects 列表（即使为空也允许使用，如无效果的食材）
	var effects: Array = item_data.get("effects", [])
	var applied_any: bool = false
	for effect in effects:
		if not effect is Dictionary:
			continue
		if _apply_effect(effect):
			applied_any = true
	# 扣除道具并发出信号
	remove_item(item_id, 1)
	EventBus.item_used.emit(item_id, 1)
	# 给出使用反馈
	var item_name: String = item_data.get("name", item_id)
	if applied_any:
		EventBus.notification_shown.emit("使用了 %s" % item_name)
	else:
		EventBus.notification_shown.emit("使用了 %s（无效果）" % item_name)
	return true

## 应用单个消耗品效果
## 返回 true 表示效果成功应用
func _apply_effect(effect: Dictionary) -> bool:
	var effect_type: String = effect.get("type", "")
	var amount: int = int(effect.get("amount", 0))
	match effect_type:
		"heal_hp":
			var stats: Node = _get_player_stats()
			if stats == null:
				return false
			stats.heal(amount)
			return true
		"heal_mp":
			var stats: Node = _get_player_stats()
			if stats == null:
				return false
			stats.restore_mana(amount)
			return true
		"add_qi":
			var cult: Node = _get_player_cultivation()
			if cult == null:
				return false
			cult.add_qi(amount)
			return true
		"unlock_cultivation":
			# 解锁修炼能力（设置冥天玉标记）
			GameState.set_story_flag("has_nether_jade", true)
			return true
		_:
			push_warning("[Inventory] 未知消耗品效果类型: %s" % effect_type)
			return false

## 获取玩家 Stats 组件（懒加载，避免重复查找）
var _cached_stats: Node = null
func _get_player_stats() -> Node:
	if _cached_stats != null and is_instance_valid(_cached_stats):
		return _cached_stats
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	_cached_stats = player.get_node_or_null("Stats")
	return _cached_stats

## 获取玩家 Cultivation 组件（懒加载，避免重复查找）
var _cached_cultivation: Node = null
func _get_player_cultivation() -> Node:
	if _cached_cultivation != null and is_instance_valid(_cached_cultivation):
		return _cached_cultivation
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	_cached_cultivation = player.get_node_or_null("Cultivation")
	return _cached_cultivation

## 清除玩家组件缓存（玩家切换场景或销毁后调用）
func clear_player_cache() -> void:
	_cached_stats = null
	_cached_cultivation = null

# ======== 存档接口 ========
func get_save_data() -> Dictionary:
	return _inventory.duplicate(true)

func load_save_data(data: Dictionary) -> void:
	_inventory = data.duplicate(true)
