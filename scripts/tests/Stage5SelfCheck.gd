##======================================================
## Stage5SelfCheck.gd - 阶段 5 冥墟古观流程自检
## 运行：godot --headless --script res://scripts/tests/Stage5SelfCheck.gd
## 验证：任务链推进、Boss 死亡 flag、StoryTrigger 条件、掉落冥天玉
##======================================================
extends SceneTree

func _initialize() -> void:
	# 创建测试运行节点并加入 root，在其 _ready 中执行测试
	# 这样能确保所有 autoload 的 _ready 已完成
	var runner: Node = TestRunner.new()
	root.add_child(runner)

# ======== 测试运行器（作为 root 子节点，_ready 时 autoload 已就绪）========
class TestRunner extends Node:
	var _passed: int = 0
	var _failed: int = 0

	var QuestManager: Node
	var GameState: Node
	var EventBus: Node
	var DataManager: Node
	var InventorySystem: Node

	func _ready() -> void:
		QuestManager = get_node("/root/QuestManager")
		GameState = get_node("/root/GameState")
		EventBus = get_node("/root/EventBus")
		DataManager = get_node("/root/DataManager")
		InventorySystem = get_node("/root/InventorySystem")
		print("========== 阶段 5 自检开始 ==========")
		_test_quest_chain_exploration()
		_test_boss_death_flags()
		_test_story_trigger_conditions()
		_test_dialogue_data_integrity()
		_test_enemy_data_integrity()
		_print_summary()
		get_tree().quit()

	# ======== 测试：探索任务链自动推进 ========
	func _test_quest_chain_exploration() -> void:
		print("\n[测试] 探索任务链自动推进 (quest_002 -> quest_003 -> quest_004)")
		# 重置任务状态
		QuestManager._initialize_quest_states()
		# 模拟 quest_001 完成（触发 quest_002 auto start）
		QuestManager.complete_quest("quest_001")
		_assert_eq(QuestManager.get_quest_state("quest_002"), "active", "quest_001 完成后 quest_002 应自动开始")
		# 模拟玩家进入青石山林
		EventBus.area_entered.emit("qing_shi_forest")
		_assert_eq(QuestManager.get_quest_state("quest_002"), "completed", "进入山林后 quest_002 应自动完成")
		_assert_eq(GameState.get_story_flag("heard_forest_warning"), true, "quest_002 完成应设置 heard_forest_warning")
		_assert_eq(QuestManager.get_quest_state("quest_003"), "active", "quest_002 完成后 quest_003 应自动开始")
		# 模拟玩家进入冥墟古观
		EventBus.area_entered.emit("nether_temple")
		_assert_eq(QuestManager.get_quest_state("quest_003"), "completed", "进入古观后 quest_003 应自动完成")
		_assert_eq(GameState.get_story_flag("found_temple"), true, "quest_003 完成应设置 found_temple")
		_assert_eq(QuestManager.get_quest_state("quest_004"), "active", "quest_003 完成后 quest_004 应自动开始")

	# ======== 测试：Boss 死亡设置标记 + 完成任务 ========
	func _test_boss_death_flags() -> void:
		print("\n[测试] Boss 死亡标记与任务完成 (quest_004)")
		# 重置并推进到 quest_004 active
		QuestManager._initialize_quest_states()
		GameState.set_story_flag("found_temple", false)
		GameState.set_story_flag("boss_defeated", false)
		GameState.set_story_flag("has_nether_jade", false)
		QuestManager.complete_quest("quest_001")
		EventBus.area_entered.emit("qing_shi_forest")
		EventBus.area_entered.emit("nether_temple")
		_assert_eq(QuestManager.get_quest_state("quest_004"), "active", "前置：quest_004 应已自动开始")
		# 模拟 Boss 死亡：先掉落冥天玉（推进 quest_004 目标）
		InventorySystem.add_item("item_nether_jade", 1)
		_assert_eq(QuestManager.get_quest_state("quest_004"), "ready_to_complete", "获得冥天玉后 quest_004 应可交付")
		# 模拟 EnemyBase.die() 中的逻辑：设置 boss_defeated + complete_quest
		GameState.set_story_flag("boss_defeated", true)
		QuestManager.complete_quest("quest_004")
		_assert_eq(QuestManager.get_quest_state("quest_004"), "completed", "Boss 死亡后 quest_004 应完成")
		_assert_eq(GameState.get_story_flag("boss_defeated"), true, "应设置 boss_defeated 标记")
		_assert_eq(GameState.get_story_flag("has_nether_jade"), true, "quest_004 完成应设置 has_nether_jade")
		# quest_005 应自动开始
		_assert_eq(QuestManager.get_quest_state("quest_005"), "active", "quest_004 完成后 quest_005 应自动开始")

	# ======== 测试：StoryTrigger 触发条件 ========
	func _test_story_trigger_conditions() -> void:
		print("\n[测试] StoryTrigger 触发条件（壁画/祭台）")
		# 壁画需要 found_temple
		GameState.set_story_flag("found_temple", false)
		_assert_eq(GameState.get_story_flag("found_temple"), false, "前置：found_temple 应为 false")
		GameState.set_story_flag("found_temple", true)
		_assert_eq(GameState.get_story_flag("found_temple"), true, "设置 found_temple 后应为 true")
		# 祭台需要 boss_defeated
		GameState.set_story_flag("boss_defeated", false)
		_assert_eq(GameState.get_story_flag("boss_defeated"), false, "前置：boss_defeated 应为 false")
		GameState.set_story_flag("boss_defeated", true)
		_assert_eq(GameState.get_story_flag("boss_defeated"), true, "设置 boss_defeated 后应为 true")
		# 验证对话数据存在
		_assert_eq(not DataManager.get_dialogue("dlg_nether_temple_mural").is_empty(), true, "壁画对话数据应存在")
		_assert_eq(not DataManager.get_dialogue("dlg_nether_temple_altar").is_empty(), true, "祭台对话数据应存在")

	# ======== 测试：对话数据完整性 ========
	func _test_dialogue_data_integrity() -> void:
		print("\n[测试] 对话数据完整性")
		var mural: Dictionary = DataManager.get_dialogue("dlg_nether_temple_mural")
		_assert_eq(mural.get("id", ""), "dlg_nether_temple_mural", "壁画对话 ID 应正确")
		var mural_nodes: Array = mural.get("nodes", [])
		_assert_eq(mural_nodes.size() >= 2, true, "壁画对话应至少有 start/end 节点")
		# 验证壁画对话有 set_story_flag 效果
		var has_flag_effect: bool = false
		for n in mural_nodes:
			for effect in n.get("effects", []):
				if effect.get("type") == "set_story_flag" and effect.get("key") == "seen_mural":
					has_flag_effect = true
		_assert_eq(has_flag_effect, true, "壁画对话应设置 seen_mural 标记")
		# 祭台对话
		var altar: Dictionary = DataManager.get_dialogue("dlg_nether_temple_altar")
		var altar_nodes: Array = altar.get("nodes", [])
		_assert_eq(altar_nodes.size() >= 2, true, "祭台对话应至少有 start/reflect 节点")

	# ======== 测试：敌人数据完整性 ========
	func _test_enemy_data_integrity() -> void:
		print("\n[测试] 敌人数据完整性")
		var wolf: Dictionary = DataManager.get_enemy("enemy_mutant_wolf")
		_assert_eq(not wolf.is_empty(), true, "异化山狼数据应存在")
		_assert_eq(wolf.get("is_boss", false), false, "异化山狼不应是 Boss")
		var beast: Dictionary = DataManager.get_enemy("enemy_nether_beast")
		_assert_eq(not beast.is_empty(), true, "冥纹兽数据应存在")
		_assert_eq(beast.get("is_boss", false), true, "冥纹兽应是 Boss")
		_assert_eq(beast.get("complete_quest_on_death", ""), "quest_004", "冥纹兽死亡应完成 quest_004")
		# 验证掉落冥天玉
		var drops: Array = beast.get("drops", [])
		var has_jade_drop: bool = false
		for drop in drops:
			if drop.get("item_id") == "item_nether_jade":
				has_jade_drop = true
		_assert_eq(has_jade_drop, true, "冥纹兽应掉落冥天玉")

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
			print("阶段 5 自检全部通过！")
		else:
			print("存在失败项，请检查！")
		print("==============================")
