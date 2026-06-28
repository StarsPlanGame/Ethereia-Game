##======================================================
## Stage8SelfCheck.gd - 阶段 8 消耗品效果系统自检
## 运行：godot --headless --script res://scripts/tests/Stage8SelfCheck.gd
## 验证：消耗品使用流程、效果应用、数量扣减、边界条件
##======================================================
extends SceneTree

func _initialize() -> void:
	var runner: Node = TestRunner.new()
	root.add_child(runner)

# ======== 测试运行器 ========
class TestRunner extends Node:
	var _passed: int = 0
	var _failed: int = 0

	var InventorySystem: Node
	var GameState: Node
	var EventBus: Node
	var DataManager: Node

	func _ready() -> void:
		InventorySystem = get_node("/root/InventorySystem")
		GameState = get_node("/root/GameState")
		EventBus = get_node("/root/EventBus")
		DataManager = get_node("/root/DataManager")
		print("========== 阶段 8 消耗品自检开始 ==========")
		_test_heal_hp_effect()
		_test_heal_mp_effect()
		_test_add_qi_effect()
		_test_unlock_cultivation_effect()
		_test_consumable_quantity_decrement()
		_test_non_consumable_rejected()
		_test_nonexistent_item_rejected()
		_test_insufficient_quantity_rejected()
		_test_empty_effects_consumable()
		_test_multiple_effects_single_item()
		_test_item_used_signal_emitted()
		_print_summary()
		get_tree().quit()

	# ======== 测试：heal_hp 效果 ========
	func _test_heal_hp_effect() -> void:
		print("\n[测试] 回血丹 heal_hp 效果")
		var player: CharacterBody2D = _create_test_player(20, 100, 30, 30)
		add_child(player)
		InventorySystem.clear_player_cache()
		InventorySystem._inventory.clear()
		InventorySystem.add_item("item_health_pill", 1)
		# 使用前 HP=20
		var stats: Node = player.get_node("Stats")
		_assert_eq(stats.current_hp, 20, "使用前 HP 应为 20")
		var result: bool = InventorySystem.use_item("item_health_pill")
		_assert_eq(result, true, "使用回血丹应返回 true")
		_assert_eq(stats.current_hp, 50, "使用后 HP 应为 50（+30）")
		_assert_eq(InventorySystem.get_item_count("item_health_pill"), 0, "使用后道具应被消耗")
		player.free()

	# ======== 测试：heal_mp 效果 ========
	func _test_heal_mp_effect() -> void:
		print("\n[测试] 回气丹 heal_mp 效果")
		var player: CharacterBody2D = _create_test_player(100, 100, 5, 30)
		add_child(player)
		InventorySystem.clear_player_cache()
		InventorySystem._inventory.clear()
		InventorySystem.add_item("item_qi_recovery_pill", 1)
		var stats: Node = player.get_node("Stats")
		_assert_eq(stats.current_mp, 5, "使用前 MP 应为 5")
		InventorySystem.use_item("item_qi_recovery_pill")
		_assert_eq(stats.current_mp, 25, "使用后 MP 应为 25（+20）")
		player.free()

	# ======== 测试：add_qi 效果 ========
	func _test_add_qi_effect() -> void:
		print("\n[测试] add_qi 效果（虚构测试消耗品）")
		# 创建临时测试消耗品数据
		var test_item_id: String = "test_qi_pill"
		DataManager._items[test_item_id] = {
			"id": test_item_id,
			"name": "测试聚气丹",
			"type": "consumable",
			"effects": [{ "type": "add_qi", "amount": 30 }]
		}
		var player: CharacterBody2D = _create_test_player(100, 100, 30, 30)
		add_child(player)
		InventorySystem.clear_player_cache()
		InventorySystem._inventory.clear()
		InventorySystem.add_item(test_item_id, 1)
		var cult: Node = player.get_node("Cultivation")
		_assert_eq(cult.spirit_qi, 0, "使用前灵气应为 0")
		InventorySystem.use_item(test_item_id)
		_assert_eq(cult.spirit_qi, 30, "使用后灵气应为 30")
		# 清理测试数据
		DataManager._items.erase(test_item_id)
		player.free()

	# ======== 测试：unlock_cultivation 效果 ========
	func _test_unlock_cultivation_effect() -> void:
		print("\n[测试] unlock_cultivation 效果（虚构测试消耗品）")
		var test_item_id: String = "test_unlock_pill"
		DataManager._items[test_item_id] = {
			"id": test_item_id,
			"name": "测试解锁丹",
			"type": "consumable",
			"effects": [{ "type": "unlock_cultivation" }]
		}
		var player: CharacterBody2D = _create_test_player(100, 100, 30, 30)
		add_child(player)
		InventorySystem.clear_player_cache()
		InventorySystem._inventory.clear()
		GameState.set_story_flag("has_nether_jade", false)
		InventorySystem.add_item(test_item_id, 1)
		_assert_eq(GameState.get_story_flag("has_nether_jade"), false, "使用前 has_nether_jade 应为 false")
		InventorySystem.use_item(test_item_id)
		_assert_eq(GameState.get_story_flag("has_nether_jade"), true, "使用后 has_nether_jade 应为 true")
		DataManager._items.erase(test_item_id)
		player.free()

	# ======== 测试：消耗品数量扣减 ========
	func _test_consumable_quantity_decrement() -> void:
		print("\n[测试] 消耗品使用后数量正确扣减")
		var player: CharacterBody2D = _create_test_player(10, 100, 30, 30)
		add_child(player)
		InventorySystem.clear_player_cache()
		InventorySystem._inventory.clear()
		InventorySystem.add_item("item_health_pill", 3)
		InventorySystem.use_item("item_health_pill")
		_assert_eq(InventorySystem.get_item_count("item_health_pill"), 2, "使用 1 个后应剩 2 个")
		InventorySystem.use_item("item_health_pill")
		_assert_eq(InventorySystem.get_item_count("item_health_pill"), 1, "使用 2 个后应剩 1 个")
		InventorySystem.use_item("item_health_pill")
		_assert_eq(InventorySystem.get_item_count("item_health_pill"), 0, "使用 3 个后应剩 0 个")
		_assert_eq(InventorySystem.has_item("item_health_pill"), false, "用完后应不再持有")
		player.free()

	# ======== 测试：非消耗品被拒绝 ========
	func _test_non_consumable_rejected() -> void:
		print("\n[测试] 非消耗品道具被拒绝使用")
		var player: CharacterBody2D = _create_test_player(100, 100, 30, 30)
		add_child(player)
		InventorySystem.clear_player_cache()
		InventorySystem._inventory.clear()
		# 灵草是 material 类型
		InventorySystem.add_item("item_spirit_grass", 5)
		var result: bool = InventorySystem.use_item("item_spirit_grass")
		_assert_eq(result, false, "材料类道具应无法使用")
		_assert_eq(InventorySystem.get_item_count("item_spirit_grass"), 5, "拒绝使用后数量不应减少")
		player.free()

	# ======== 测试：不存在的道具被拒绝 ========
	func _test_nonexistent_item_rejected() -> void:
		print("\n[测试] 不存在的道具被拒绝使用")
		var result: bool = InventorySystem.use_item("item_nonexistent_xyz")
		_assert_eq(result, false, "不存在的道具应返回 false")

	# ======== 测试：数量不足被拒绝 ========
	func _test_insufficient_quantity_rejected() -> void:
		print("\n[测试] 数量不足时使用失败")
		var player: CharacterBody2D = _create_test_player(50, 100, 30, 30)
		add_child(player)
		InventorySystem.clear_player_cache()
		InventorySystem._inventory.clear()
		# 不添加任何道具，直接尝试使用
		var result: bool = InventorySystem.use_item("item_health_pill")
		_assert_eq(result, false, "无道具时应返回 false")
		var stats: Node = player.get_node("Stats")
		_assert_eq(stats.current_hp, 50, "失败使用后 HP 不应变化")
		player.free()

	# ======== 测试：空 effects 消耗品 ========
	func _test_empty_effects_consumable() -> void:
		print("\n[测试] 空 effects 列表的消耗品可使用但无效果")
		var test_item_id: String = "test_empty_pill"
		DataManager._items[test_item_id] = {
			"id": test_item_id,
			"name": "测试空丹",
			"type": "consumable",
			"effects": []
		}
		var player: CharacterBody2D = _create_test_player(50, 100, 30, 30)
		add_child(player)
		InventorySystem.clear_player_cache()
		InventorySystem._inventory.clear()
		InventorySystem.add_item(test_item_id, 1)
		var result: bool = InventorySystem.use_item(test_item_id)
		_assert_eq(result, true, "空 effects 消耗品应可使用")
		_assert_eq(InventorySystem.get_item_count(test_item_id), 0, "使用后应被消耗")
		var stats: Node = player.get_node("Stats")
		_assert_eq(stats.current_hp, 50, "HP 不应变化")
		DataManager._items.erase(test_item_id)
		player.free()

	# ======== 测试：单道具多效果 ========
	func _test_multiple_effects_single_item() -> void:
		print("\n[测试] 单个消耗品包含多个效果")
		var test_item_id: String = "test_combo_pill"
		DataManager._items[test_item_id] = {
			"id": test_item_id,
			"name": "测试双效丹",
			"type": "consumable",
			"effects": [
				{ "type": "heal_hp", "amount": 30 },
				{ "type": "heal_mp", "amount": 20 }
			]
		}
		var player: CharacterBody2D = _create_test_player(20, 100, 5, 30)
		add_child(player)
		InventorySystem.clear_player_cache()
		InventorySystem._inventory.clear()
		InventorySystem.add_item(test_item_id, 1)
		var stats: Node = player.get_node("Stats")
		InventorySystem.use_item(test_item_id)
		_assert_eq(stats.current_hp, 50, "双效丹 HP 应 +30 = 50")
		_assert_eq(stats.current_mp, 25, "双效丹 MP 应 +20 = 25")
		DataManager._items.erase(test_item_id)
		player.free()

	# ======== 测试：item_used 信号正确发射 ========
	func _test_item_used_signal_emitted() -> void:
		print("\n[测试] 使用消耗品后 item_used 信号发射")
		var player: CharacterBody2D = _create_test_player(50, 100, 30, 30)
		add_child(player)
		InventorySystem.clear_player_cache()
		InventorySystem._inventory.clear()
		InventorySystem.add_item("item_health_pill", 1)
		# 使用数组存储结果（GDScript Lambda 无法修改外部局部变量）
		var result_box: Array = [false, "", 0]
		var handler: Callable = func(id: String, amt: int):
			result_box[0] = true
			result_box[1] = id
			result_box[2] = amt
		EventBus.item_used.connect(handler)
		InventorySystem.use_item("item_health_pill")
		EventBus.item_used.disconnect(handler)
		_assert_eq(result_box[0], true, "应收到 item_used 信号")
		_assert_eq(result_box[1], "item_health_pill", "信号应携带正确 item_id")
		_assert_eq(result_box[2], 1, "信号应携带正确 amount")
		player.free()

	# ======== 辅助：创建测试玩家（带 Stats 和 Cultivation）========
	func _create_test_player(hp: int = 100, max_hp: int = 100, mp: int = 30, max_mp: int = 30) -> CharacterBody2D:
		var player: CharacterBody2D = TestPlayerStub.new()
		var stats: Node = TestStats.new()
		stats.max_hp = max_hp
		stats.current_hp = hp
		stats.max_mp = max_mp
		stats.current_mp = mp
		stats.name = "Stats"
		player.add_child(stats)
		var cult: Node = TestCult.new()
		cult.name = "Cultivation"
		player.add_child(cult)
		return player

	# ======== 内嵌桩类 ========
	class TestPlayerStub extends CharacterBody2D:
		func _ready() -> void:
			if not is_in_group("player"):
				add_to_group("player")

	class TestStats extends Node:
		var max_hp: int = 100
		var current_hp: int = 100
		var max_mp: int = 30
		var current_mp: int = 30
		var attack: int = 10
		var defense: int = 5
		var move_speed: float = 150.0
		func take_damage(dmg: int) -> void:
			current_hp = max(0, current_hp - dmg)
		func heal(amount: int) -> void:
			current_hp = min(max_hp, current_hp + amount)
		func use_mana(amount: int) -> bool:
			if current_mp < amount: return false
			current_mp -= amount
			return true
		func restore_mana(amount: int) -> void:
			current_mp = min(max_mp, current_mp + amount)

	class TestCult extends Node:
		var realm: int = 0
		var realm_level: int = 0
		var spirit_qi: int = 0
		var spirit_qi_max: int = 100
		var has_nether_jade: bool = false
		var is_meditating: bool = false
		func add_qi(amount: int) -> void:
			spirit_qi = min(spirit_qi_max, spirit_qi + amount)
		func start_meditation() -> void:
			is_meditating = true
		func stop_meditation() -> void:
			is_meditating = false

	# ======== 断言辅助 ========
	func _assert_eq(actual, expected, msg: String) -> void:
		if actual == expected:
			_passed += 1
			print("  [PASS] %s" % msg)
		else:
			_failed += 1
			print("  [FAIL] %s (期望: %s, 实际: %s)" % [msg, str(expected), str(actual)])

	func _print_summary() -> void:
		print("\n========== 自检结果 ==========")
		print("通过: %d  失败: %d" % [_passed, _failed])
		if _failed == 0:
			print("阶段 8 消耗品自检全部通过！")
		else:
			print("存在失败项，请检查！")
		print("==============================")
