##======================================================
## Stage6SelfCheck.gd - 阶段 6 修炼与突破流程自检
## 运行：godot --headless --script res://scripts/tests/Stage6SelfCheck.gd
## 验证：冥天玉解锁修炼、打坐积累灵气、突破属性变化、quest_005 推进、灵气弹解锁
##======================================================
extends SceneTree

func _initialize() -> void:
	var runner: Node = TestRunner.new()
	root.add_child(runner)

# ======== 测试运行器 ========
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
		print("========== 阶段 6 自检开始 ==========")
		_test_cultivation_lock_without_jade()
		_test_meditation_qi_accumulation()
		_test_breakthrough_attributes()
		_test_quest_005_progression()
		_test_spirit_bullet_unlock()
		_test_skill_data_integrity()
		_test_cultivation_panel_scene()
		_print_summary()
		get_tree().quit()

	# ======== 测试：冥天玉未获得时不能修炼 ========
	func _test_cultivation_lock_without_jade() -> void:
		print("\n[测试] 冥天玉未获得时修炼锁定")
		var cult: Node = _create_cultivation_component()
		# 未获得冥天玉
		cult.has_nether_jade = false
		_assert_eq(cult.can_breakthrough(), false, "无冥天玉时不能突破")
		_assert_eq(cult.is_meditating, false, "初始非打坐状态")
		cult.start_meditation()
		_assert_eq(cult.is_meditating, false, "无冥天玉时打坐应失败")
		cult.free()

	# ======== 测试：打坐积累灵气 ========
	func _test_meditation_qi_accumulation() -> void:
		print("\n[测试] 打坐积累灵气")
		var cult: Node = _create_cultivation_component()
		cult.has_nether_jade = true
		_assert_eq(cult.spirit_qi, 0, "初始灵气应为 0")
		cult.add_qi(50)
		_assert_eq(cult.spirit_qi, 50, "添加 50 灵气后应为 50")
		cult.add_qi(100)  # 超过上限
		_assert_eq(cult.spirit_qi, cult.spirit_qi_max, "灵气不应超过上限 100")
		# 灵气未满不能突破
		cult.spirit_qi = 50
		_assert_eq(cult.can_breakthrough(), false, "灵气未满时不能突破")
		cult.free()

	# ======== 测试：突破后属性变化 ========
	func _test_breakthrough_attributes() -> void:
		print("\n[测试] 突破后属性变化 (max_hp+20, max_mp+50)")
		var player: Node = _create_player_with_cultivation()
		var stats: Node = player.get_node("Stats")
		var cult: Node = player.get_node("Cultivation")
		cult.has_nether_jade = true
		cult.spirit_qi = cult.spirit_qi_max
		var old_hp: int = stats.max_hp
		var old_mp: int = stats.max_mp
		var old_atk: int = stats.attack
		var old_def: int = stats.defense
		var result: bool = cult.do_breakthrough()
		_assert_eq(result, true, "突破应成功")
		_assert_eq(cult.realm, 1, "突破后境界应为 QI_REFINING(1)")  # Realm.QI_REFINING = 1
		_assert_eq(cult.realm_level, 1, "突破后层次应为 1")
		_assert_eq(stats.max_hp, old_hp + 20, "max_hp 应 +20")
		_assert_eq(stats.max_mp, old_mp + 50, "max_mp 应 +50")
		_assert_eq(stats.attack, old_atk + 5, "attack 应 +5")
		_assert_eq(stats.defense, old_def + 3, "defense 应 +3")
		_assert_eq(stats.current_hp, stats.max_hp, "current_hp 应回满")
		_assert_eq(stats.current_mp, stats.max_mp, "current_mp 应回满")
		_assert_eq(cult.spirit_qi, 0, "突破后灵气应清零")
		# 第二次突破应失败（第一部分只允许一次）
		cult.spirit_qi = cult.spirit_qi_max
		_assert_eq(cult.can_breakthrough(), false, "已突破后不能再次突破")
		player.free()

	# ======== 测试：quest_005 突破推进 ========
	func _test_quest_005_progression() -> void:
		print("\n[测试] quest_005 突破推进与自动完成")
		QuestManager._initialize_quest_states()
		# 推进到 quest_005 active
		QuestManager.complete_quest("quest_001")
		EventBus.area_entered.emit("qing_shi_forest")
		EventBus.area_entered.emit("nether_temple")
		InventorySystem.add_item("item_nether_jade", 1)
		QuestManager.complete_quest("quest_004")
		_assert_eq(QuestManager.get_quest_state("quest_005"), "active", "前置：quest_005 应已自动开始")
		# 模拟突破：发射 cultivation_changed 信号
		EventBus.cultivation_changed.emit("炼气", 1, 0)
		_assert_eq(QuestManager.get_quest_state("quest_005"), "completed", "突破后 quest_005 应自动完成")
		_assert_eq(GameState.get_story_flag("entered_cultivation"), true, "quest_005 完成应设置 entered_cultivation")

	# ======== 测试：灵气弹技能解锁 ========
	func _test_spirit_bullet_unlock() -> void:
		print("\n[测试] 灵气弹技能解锁 (quest_005 unlock reward)")
		# quest_005 的 rewards 包含 unlock skill_spirit_bullet
		GameState.set_story_flag("skill_unlocked_skill_spirit_bullet", false)
		# 重新完成 quest_005 触发奖励
		QuestManager._initialize_quest_states()
		QuestManager.complete_quest("quest_001")
		EventBus.area_entered.emit("qing_shi_forest")
		EventBus.area_entered.emit("nether_temple")
		InventorySystem.add_item("item_nether_jade", 1)
		QuestManager.complete_quest("quest_004")
		EventBus.cultivation_changed.emit("炼气", 1, 0)
		_assert_eq(GameState.has_story_flag("skill_unlocked_skill_spirit_bullet"), true, "quest_005 完成应解锁灵气弹技能")
		# 验证物品奖励也发放了
		var pill_count: int = InventorySystem.get_item_count("item_qi_recovery_pill")
		_assert_eq(pill_count >= 3, true, "quest_005 应奖励 3 个聚气丹")

	# ======== 测试：技能数据完整性 ========
	func _test_skill_data_integrity() -> void:
		print("\n[测试] 技能数据完整性")
		var skill: Dictionary = DataManager.get_skill("skill_spirit_bullet")
		_assert_eq(not skill.is_empty(), true, "灵气弹技能数据应存在")
		_assert_eq(skill.get("name", ""), "灵气弹", "技能名称应为灵气弹")
		_assert_eq(skill.get("mp_cost", 0) > 0, true, "灵气弹应消耗灵力")
		_assert_eq(skill.get("damage", 0) > 0, true, "灵气弹应有伤害值")
		_assert_eq(skill.get("range", 0) > 0, true, "灵气弹应有射程")
		_assert_eq(skill.get("projectile_speed", 0) > 0, true, "灵气弹应有投射速度")

	# ======== 测试：CultivationPanel 场景结构 ========
	func _test_cultivation_panel_scene() -> void:
		print("\n[测试] CultivationPanel 场景结构")
		var scene: PackedScene = load("res://scenes/ui/CultivationPanel.tscn")
		_assert_eq(scene != null, true, "CultivationPanel.tscn 应可加载")
		var panel: Node = scene.instantiate()
		_assert_eq(panel != null, true, "CultivationPanel 应能实例化")
		# 验证关键节点存在
		var realm_label: Node = panel.get_node_or_null("Panel/Margin/VBox/RealmLabel")
		_assert_eq(realm_label != null, true, "应包含 RealmLabel 节点")
		var qi_bar: Node = panel.get_node_or_null("Panel/Margin/VBox/QiBar")
		_assert_eq(qi_bar != null, true, "应包含 QiBar 节点")
		var meditate_btn: Node = panel.get_node_or_null("Panel/Margin/VBox/MeditateButton")
		_assert_eq(meditate_btn != null, true, "应包含 MeditateButton 节点")
		var breakthrough_btn: Node = panel.get_node_or_null("Panel/Margin/VBox/BreakthroughButton")
		_assert_eq(breakthrough_btn != null, true, "应包含 BreakthroughButton 节点")
		panel.free()

	# ======== 辅助：创建独立修炼组件 ========
	func _create_cultivation_component() -> Node:
		var cult: Node = preload("res://scripts/player/PlayerCultivation.gd").new()
		return cult

	# ======== 辅助：创建带 Stats 的 Player ========
	func _create_player_with_cultivation() -> Node:
		var player: CharacterBody2D = CharacterBody2D.new()
		var stats: Node = preload("res://scripts/player/PlayerStats.gd").new()
		stats.name = "Stats"
		player.add_child(stats)
		var cult: Node = preload("res://scripts/player/PlayerCultivation.gd").new()
		cult.name = "Cultivation"
		player.add_child(cult)
		add_child(player)  # 加入场景树以启用信号
		return player

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
			print("阶段 6 自检全部通过！")
		else:
			print("存在失败项，请检查！")
		print("==============================")
