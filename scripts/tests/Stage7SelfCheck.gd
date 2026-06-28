##======================================================
## Stage7SelfCheck.gd - 阶段 7 存档与打磨自检
## 运行：godot --headless --script res://scripts/tests/Stage7SelfCheck.gd
## 验证：存档/读档完整性、各系统数据往返、主菜单/暂停菜单场景结构
##======================================================
extends SceneTree

func _initialize() -> void:
	var runner: Node = TestRunner.new()
	root.add_child(runner)

# ======== 测试运行器 ========
class TestRunner extends Node:
	var _passed: int = 0
	var _failed: int = 0

	var SaveManager: Node
	var GameState: Node
	var EventBus: Node
	var DataManager: Node
	var InventorySystem: Node
	var QuestManager: Node
	var KarmaManager: Node
	var RelationshipManager: Node

	func _ready() -> void:
		SaveManager = get_node("/root/SaveManager")
		GameState = get_node("/root/GameState")
		EventBus = get_node("/root/EventBus")
		DataManager = get_node("/root/DataManager")
		InventorySystem = get_node("/root/InventorySystem")
		QuestManager = get_node("/root/QuestManager")
		KarmaManager = get_node("/root/KarmaManager")
		RelationshipManager = get_node("/root/RelationshipManager")
		print("========== 阶段 7 自检开始 ==========")
		_test_save_load_roundtrip()
		_test_story_flags_persistence()
		_test_karma_relationship_persistence()
		_test_inventory_persistence()
		_test_quests_persistence()
		_test_story_triggered_persistence()
		_test_main_menu_scene()
		_test_pause_menu_scene()
		_test_player_data_collection()
		_test_save_version()
		_print_summary()
		get_tree().quit()

	# ======== 测试：存档读档往返 ========
	func _test_save_load_roundtrip() -> void:
		print("\n[测试] 存档/读档往返")
		# 准备测试数据
		_setup_test_state()
		# 创建模拟玩家节点加入场景树（带 group）
		var player: CharacterBody2D = _create_test_player()
		add_child(player)
		# 保存
		SaveManager.save_game(99)
		_assert_eq(SaveManager.has_save(99), true, "存档后应存在")
		# 修改运行时状态
		GameState.set_story_flag("test_flag", false)
		InventorySystem.remove_item("item_spirit_grass", 5)
		# 读取
		SaveManager.load_game(99)
		_assert_eq(GameState.get_story_flag("test_flag"), true, "读档后 test_flag 应恢复为 true")
		_assert_eq(InventorySystem.get_item_count("item_spirit_grass"), 5, "读档后灵草数量应恢复为 5")
		# 清理
		SaveManager.delete_save(99)
		player.free()

	# ======== 测试：剧情标记持久化 ========
	func _test_story_flags_persistence() -> void:
		print("\n[测试] 剧情标记持久化")
		GameState.story_flags.clear()
		GameState.set_story_flag("has_nether_jade", true)
		GameState.set_story_flag("boss_defeated", true)
		GameState.set_story_flag("found_temple", true)
		var player: CharacterBody2D = _create_test_player()
		add_child(player)
		SaveManager.save_game(98)
		# 清空后读档
		GameState.story_flags.clear()
		_assert_eq(GameState.get_story_flag("has_nether_jade"), false, "清空后标记应为 false")
		SaveManager.load_game(98)
		_assert_eq(GameState.get_story_flag("has_nether_jade"), true, "读档后 has_nether_jade 应恢复")
		_assert_eq(GameState.get_story_flag("boss_defeated"), true, "读档后 boss_defeated 应恢复")
		_assert_eq(GameState.get_story_flag("found_temple"), true, "读档后 found_temple 应恢复")
		SaveManager.delete_save(98)
		player.free()

	# ======== 测试：因果与关系持久化 ========
	func _test_karma_relationship_persistence() -> void:
		print("\n[测试] 因果与关系持久化")
		KarmaManager.add_karma("hidden_jade", 3)
		RelationshipManager.change_relationship("shen_qingluo", 15)
		var player: CharacterBody2D = _create_test_player()
		add_child(player)
		SaveManager.save_game(97)
		# 清空后读档
		KarmaManager.load_save_data({})
		RelationshipManager.load_save_data({})
		_assert_eq(KarmaManager.get_karma("hidden_jade"), 0, "清空后因果应为 0")
		SaveManager.load_game(97)
		_assert_eq(KarmaManager.get_karma("hidden_jade"), 3, "读档后 hidden_jade 应为 3")
		_assert_eq(RelationshipManager.get_relationship("shen_qingluo"), 15, "读档后 shen_qingluo 关系应为 15")
		SaveManager.delete_save(97)
		player.free()

	# ======== 测试：背包持久化 ========
	func _test_inventory_persistence() -> void:
		print("\n[测试] 背包持久化")
		InventorySystem._inventory.clear()
		InventorySystem.add_item("item_nether_jade", 1)
		InventorySystem.add_item("currency_spirit_stone", 100)
		var player: CharacterBody2D = _create_test_player()
		add_child(player)
		SaveManager.save_game(96)
		InventorySystem.remove_item("item_nether_jade", 1)
		InventorySystem.remove_item("currency_spirit_stone", 100)
		SaveManager.load_game(96)
		_assert_eq(InventorySystem.get_item_count("item_nether_jade"), 1, "读档后冥天玉应为 1")
		_assert_eq(InventorySystem.get_item_count("currency_spirit_stone"), 100, "读档后灵石应为 100")
		SaveManager.delete_save(96)
		player.free()

	# ======== 测试：任务状态持久化 ========
	func _test_quests_persistence() -> void:
		print("\n[测试] 任务状态持久化")
		QuestManager._initialize_quest_states()
		QuestManager.complete_quest("quest_001")
		_assert_eq(QuestManager.get_quest_state("quest_001"), "completed", "前置：quest_001 应完成")
		var player: CharacterBody2D = _create_test_player()
		add_child(player)
		SaveManager.save_game(95)
		# 重置后读档
		QuestManager._initialize_quest_states()
		_assert_eq(QuestManager.get_quest_state("quest_001"), "available", "重置后 quest_001 应为 available")
		SaveManager.load_game(95)
		_assert_eq(QuestManager.get_quest_state("quest_001"), "completed", "读档后 quest_001 应恢复为 completed")
		SaveManager.delete_save(95)
		player.free()

	# ======== 测试：剧情触发器状态持久化 ========
	func _test_story_triggered_persistence() -> void:
		print("\n[测试] 剧情触发器状态持久化")
		SaveManager.reset_story_triggered()
		SaveManager.mark_story_triggered("nether_temple_mural")
		SaveManager.mark_story_triggered("nether_temple_altar")
		var player: CharacterBody2D = _create_test_player()
		add_child(player)
		SaveManager.save_game(94)
		SaveManager.reset_story_triggered()
		_assert_eq(SaveManager.is_story_triggered("nether_temple_mural"), false, "重置后壁画触发应为 false")
		SaveManager.load_game(94)
		_assert_eq(SaveManager.is_story_triggered("nether_temple_mural"), true, "读档后壁画触发应恢复")
		_assert_eq(SaveManager.is_story_triggered("nether_temple_altar"), true, "读档后祭台触发应恢复")
		SaveManager.delete_save(94)
		player.free()

	# ======== 测试：主菜单场景 ========
	func _test_main_menu_scene() -> void:
		print("\n[测试] 主菜单场景结构")
		var scene: PackedScene = load("res://scenes/ui/MainMenu.tscn")
		_assert_eq(scene != null, true, "MainMenu.tscn 应可加载")
		var menu: Node = scene.instantiate()
		_assert_eq(menu != null, true, "MainMenu 应能实例化")
		var new_game_btn: Node = menu.get_node_or_null("Panel/Margin/VBox/NewGameButton")
		_assert_eq(new_game_btn != null, true, "应包含 NewGameButton")
		var continue_btn: Node = menu.get_node_or_null("Panel/Margin/VBox/ContinueButton")
		_assert_eq(continue_btn != null, true, "应包含 ContinueButton")
		var quit_btn: Node = menu.get_node_or_null("Panel/Margin/VBox/QuitButton")
		_assert_eq(quit_btn != null, true, "应包含 QuitButton")
		# 验证方法存在
		_assert_eq(menu.has_method("_on_new_game_pressed"), true, "应有 _on_new_game_pressed 方法")
		_assert_eq(menu.has_method("_on_continue_pressed"), true, "应有 _on_continue_pressed 方法")
		menu.free()

	# ======== 测试：暂停菜单场景 ========
	func _test_pause_menu_scene() -> void:
		print("\n[测试] 暂停菜单场景结构")
		var scene: PackedScene = load("res://scenes/ui/PauseMenu.tscn")
		_assert_eq(scene != null, true, "PauseMenu.tscn 应可加载")
		var menu: Node = scene.instantiate()
		_assert_eq(menu != null, true, "PauseMenu 应能实例化")
		var resume_btn: Node = menu.get_node_or_null("Panel/Margin/VBox/ResumeButton")
		_assert_eq(resume_btn != null, true, "应包含 ResumeButton")
		var save_btn: Node = menu.get_node_or_null("Panel/Margin/VBox/SaveButton")
		_assert_eq(save_btn != null, true, "应包含 SaveButton")
		var main_menu_btn: Node = menu.get_node_or_null("Panel/Margin/VBox/MainMenuButton")
		_assert_eq(main_menu_btn != null, true, "应包含 MainMenuButton")
		_assert_eq(menu.has_method("toggle_visibility"), true, "应有 toggle_visibility 方法")
		_assert_eq(menu.has_method("_on_save_pressed"), true, "应有 _on_save_pressed 方法")
		menu.free()

	# ======== 测试：玩家数据收集 ========
	func _test_player_data_collection() -> void:
		print("\n[测试] 玩家数据收集（通过 group 查找）")
		# 无玩家时返回空
		var empty_data: Dictionary = SaveManager._collect_player_save_data()
		_assert_eq(empty_data.is_empty(), true, "无玩家时应返回空字典")
		# 有玩家时返回数据
		var player: CharacterBody2D = _create_test_player()
		add_child(player)
		var data: Dictionary = SaveManager._collect_player_save_data()
		_assert_eq(data.has("stats"), true, "玩家存档应包含 stats")
		_assert_eq(data.has("cultivation"), true, "玩家存档应包含 cultivation")
		_assert_eq(data.has("position_x"), true, "玩家存档应包含 position_x")
		player.free()

	# ======== 测试：存档版本号 ========
	func _test_save_version() -> void:
		print("\n[测试] 存档版本号")
		_assert_eq(SaveManager.SAVE_VERSION != "", true, "SAVE_VERSION 不应为空")
		_assert_eq(SaveManager.SAVE_DIR == "user://", true, "SAVE_DIR 应为 user://")

	# ======== 辅助：设置测试状态 ========
	func _setup_test_state() -> void:
		GameState.story_flags.clear()
		GameState.set_story_flag("test_flag", true)
		GameState.current_scene_id = "nether_temple"
		GameState.current_spawn_id = "spawn_test"
		InventorySystem._inventory.clear()
		InventorySystem.add_item("item_spirit_grass", 5)

	# ======== 辅助：创建带 group 的测试玩家（纯内嵌类，避免外部脚本依赖）========
	func _create_test_player() -> CharacterBody2D:
		var player: CharacterBody2D = TestPlayerStub.new()
		var stats: Node = TestStats.new()
		stats.name = "Stats"
		player.add_child(stats)
		var cult: Node = TestCult.new()
		cult.name = "Cultivation"
		player.add_child(cult)
		return player

	# ======== 内嵌类：测试玩家桩 ========
	class TestPlayerStub extends CharacterBody2D:
		func _ready() -> void:
			if not is_in_group("player"):
				add_to_group("player")
		func get_save_data() -> Dictionary:
			return {
				"position_x": global_position.x,
				"position_y": global_position.y,
				"facing": 1,
				"stats": $Stats.get_save_data(),
				"cultivation": $Cultivation.get_save_data(),
			}
		func load_save_data(data: Dictionary) -> void:
			global_position = Vector2(data.get("position_x", 0), data.get("position_y", 0))
			if data.has("stats"):
				$Stats.load_save_data(data["stats"])
			if data.has("cultivation"):
				$Cultivation.load_save_data(data["cultivation"])

	class TestStats extends Node:
		var max_hp: int = 100
		var current_hp: int = 100
		var max_mp: int = 30
		var current_mp: int = 30
		var attack: int = 10
		var defense: int = 5
		var move_speed: float = 150.0
		func get_save_data() -> Dictionary:
			return {
				"max_hp": max_hp, "current_hp": current_hp,
				"max_mp": max_mp, "current_mp": current_mp,
				"attack": attack, "defense": defense, "move_speed": move_speed,
			}
		func load_save_data(data: Dictionary) -> void:
			max_hp = data.get("max_hp", 100)
			current_hp = data.get("current_hp", 100)
			max_mp = data.get("max_mp", 30)
			current_mp = data.get("current_mp", 30)
			attack = data.get("attack", 10)
			defense = data.get("defense", 5)
			move_speed = data.get("move_speed", 150.0)

	class TestCult extends Node:
		var realm: int = 0
		var realm_level: int = 0
		var spirit_qi: int = 0
		var spirit_qi_max: int = 100
		var has_nether_jade: bool = false
		func get_save_data() -> Dictionary:
			return {
				"realm": realm, "realm_level": realm_level,
				"spirit_qi": spirit_qi, "spirit_qi_max": spirit_qi_max,
				"has_nether_jade": has_nether_jade,
			}
		func load_save_data(data: Dictionary) -> void:
			realm = data.get("realm", 0)
			realm_level = data.get("realm_level", 0)
			spirit_qi = data.get("spirit_qi", 0)
			spirit_qi_max = data.get("spirit_qi_max", 100)
			has_nether_jade = data.get("has_nether_jade", false)

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
			print("阶段 7 自检全部通过！")
		else:
			print("存在失败项，请检查！")
		print("==============================")
