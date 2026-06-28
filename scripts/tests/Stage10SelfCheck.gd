##======================================================
## Stage10SelfCheck.gd - 阶段 10 AI 数据驱动与统一伤害系统自检
## 运行：godot --headless --script res://scripts/tests/Stage10SelfCheck.gd
## 验证：DamageCalculator 公式、EnemyBase 数据加载、AI 参数同步
##======================================================
extends SceneTree

# 在 --script 模式下 class_name 全局类型可能未注册，需 preload
const DamageCalculator = preload("res://scripts/core/DamageCalculator.gd")
const MapBase = preload("res://scripts/core/MapBase.gd")

func _initialize() -> void:
	var runner: Node = TestRunner.new()
	root.add_child(runner)

# ======== 测试运行器 ========
class TestRunner extends Node:
	var _passed: int = 0
	var _failed: int = 0

	# 脚本引用
	var _DmgCalc: Script = preload("res://scripts/core/DamageCalculator.gd")
	var _EnemyBaseScene: PackedScene = load("res://scenes/enemies/EnemyBase.tscn")
	var _WolfScene: PackedScene = load("res://scenes/enemies/Wolf.tscn")
	var _NetherWolfScene: PackedScene = load("res://scenes/enemies/NetherWolf.tscn")
	var _NetherBeastScene: PackedScene = load("res://scenes/enemies/NetherBeast.tscn")

	# Autoload 引用
	var DataManager: Node
	var EventBus: Node

	func _ready() -> void:
		DataManager = get_node("/root/DataManager")
		EventBus = get_node("/root/EventBus")
		print("========== 阶段 10 战斗系统自检开始 ==========")
		_test_damage_calc_basic()
		_test_damage_calc_min_one()
		_test_damage_calc_with_skill()
		_test_damage_calc_crit()
		_test_damage_calc_variance()
		_test_damage_calc_full_combination()
		_test_damage_calc_get_damage_simple()
		_test_enemy_data_load_ai_params()
		_test_enemy_data_load_combat_params()
		_test_enemy_ai_params_synced_to_node()
		_test_player_stats_take_damage_no_double_defense()
		_test_wolf_scene_no_redundant_ai_config()
		_test_nether_beast_boss_params()
		_print_summary()
		get_tree().quit()

	# ======== 测试：基础伤害公式 ========
	func _test_damage_calc_basic() -> void:
		print("\n[测试] 基础伤害公式 max(1, atk + skill - def)")
		var result: Dictionary = _DmgCalc.compute_damage(20, 5, 0)
		_assert_eq(result.damage, 15, "20-5=15")
		_assert_false(result.is_crit, "无暴击率时应为普通伤害")

	# ======== 测试：最低伤害保护 ========
	func _test_damage_calc_min_one() -> void:
		print("\n[测试] 最低伤害保护")
		var result: Dictionary = _DmgCalc.compute_damage(3, 100, 0)
		_assert_eq(result.damage, 1, "atk < def 时应保底 1 伤害")

	# ======== 测试：技能附加伤害 ========
	func _test_damage_calc_with_skill() -> void:
		print("\n[测试] 技能附加伤害")
		var result: Dictionary = _DmgCalc.compute_damage(10, 5, 15)
		_assert_eq(result.damage, 20, "10+15-5=20")

	# ======== 测试：暴击判定 ========
	func _test_damage_calc_crit() -> void:
		print("\n[测试] 暴击判定")
		# crit_chance=1.0 必定暴击
		var result: Dictionary = _DmgCalc.compute_damage(20, 5, 0, 1.0, 2.0, 0.0)
		_assert_true(result.is_crit, "100% 暴击率应触发暴击")
		_assert_eq(result.damage, 30, "暴击伤害 (20-5)*2=30")
		_assert_eq(result.crit_mult, 2.0, "暴击倍率应为 2.0")

	# ======== 测试：伤害浮动 ========
	func _test_damage_calc_variance() -> void:
		print("\n[测试] 伤害浮动方差")
		# 多次测试验证浮动范围合理
		var in_range: bool = true
		for i in range(20):
			var result: Dictionary = _DmgCalc.compute_damage(20, 5, 0, 0.0, 1.5, 0.2)
			# 基础 15，方差 ±20% => [12, 18]
			if result.damage < 12 or result.damage > 18:
				in_range = false
				break
		_assert_true(in_range, "方差 ±20% 伤害应在 [12,18] 范围内")

	# ======== 测试：完整组合 ========
	func _test_damage_calc_full_combination() -> void:
		print("\n[测试] 完整组合（暴击+方差+技能）")
		# atk=10, def=5, skill=10, crit=1.0, mult=2.0, variance=0
		# base = 10+10-5 = 15, 暴击 *2 = 30
		var result: Dictionary = _DmgCalc.compute_damage(10, 5, 10, 1.0, 2.0, 0.0)
		_assert_true(result.is_crit, "应触发暴击")
		_assert_eq(result.damage, 30, "完整组合伤害应为 30")

	# ======== 测试：简化版 get_damage ========
	func _test_damage_calc_get_damage_simple() -> void:
		print("\n[测试] 简化版 get_damage")
		var dmg: int = _DmgCalc.get_damage(15, 5, 0)
		_assert_eq(dmg, 10, "15-5=10")
		var min_dmg: int = _DmgCalc.get_damage(1, 100, 0)
		_assert_eq(min_dmg, 1, "保底 1 伤害")

	# ======== 测试：敌人 AI 参数从数据表加载 ========
	func _test_enemy_data_load_ai_params() -> void:
		print("\n[测试] 敌人 AI 参数数据驱动加载")
		var enemy: CharacterBody2D = _WolfScene.instantiate()
		add_child(enemy)
		_assert_eq(enemy.ai_type, "melee_chase", "山狼 ai_type 应为 melee_chase")
		_assert_eq(enemy.detection_range, 200.0, "山狼 detection_range 应为 200")
		_assert_eq(enemy.attack_range, 30.0, "山狼 attack_range 应为 30")
		_assert_eq(enemy.attack_cooldown, 1.5, "山狼 attack_cooldown 应为 1.5")
		_assert_eq(enemy.patrol_radius, 80.0, "山狼 patrol_radius 应为 80")
		_assert_eq(enemy.return_range, 400.0, "山狼 return_range 应为 400")
		enemy.free()

	# ======== 测试：敌人战斗扩展参数加载 ========
	func _test_enemy_data_load_combat_params() -> void:
		print("\n[测试] 敌人战斗扩展参数数据驱动")
		var wolf: CharacterBody2D = _WolfScene.instantiate()
		add_child(wolf)
		_assert_eq(wolf.crit_chance, 0.05, "山狼暴击率应为 0.05")
		_assert_eq(wolf.crit_multiplier, 1.5, "山狼暴击倍率应为 1.5")
		_assert_eq(wolf.damage_variance, 0.1, "山狼伤害方差应为 0.1")
		wolf.free()
		var boss: CharacterBody2D = _NetherBeastScene.instantiate()
		add_child(boss)
		_assert_eq(boss.crit_chance, 0.15, "Boss 暴击率应为 0.15")
		_assert_eq(boss.crit_multiplier, 2.0, "Boss 暴击倍率应为 2.0")
		_assert_eq(boss.damage_variance, 0.2, "Boss 伤害方差应为 0.2")
		_assert_eq(boss.is_boss, true, "Boss 应为 boss 类型")
		_assert_eq(boss.complete_quest_on_death, "quest_004", "Boss 死亡应完成 quest_004")
		boss.free()

	# ======== 测试：AI 参数同步到节点 ========
	func _test_enemy_ai_params_synced_to_node() -> void:
		print("\n[测试] AI 参数同步到 AI 节点")
		var wolf: CharacterBody2D = _WolfScene.instantiate()
		add_child(wolf)
		var ai: Node = wolf.ai
		_assert_eq(ai.chase_range, 200.0, "AI chase_range 应同步为 200")
		_assert_eq(ai.attack_range, 30.0, "AI attack_range 应同步为 30")
		_assert_eq(ai.attack_cooldown, 1.5, "AI attack_cooldown 应同步为 1.5")
		wolf.free()
		var mutant: CharacterBody2D = _NetherWolfScene.instantiate()
		add_child(mutant)
		var ai2: Node = mutant.ai
		_assert_eq(ai2.chase_range, 250.0, "异化山狼 chase_range 应为 250")
		_assert_eq(ai2.attack_range, 35.0, "异化山狼 attack_range 应为 35")
		_assert_eq(ai2.attack_cooldown, 1.2, "异化山狼 attack_cooldown 应为 1.2")
		mutant.free()

	# ======== 测试：玩家 take_damage 不再二次减防 ========
	func _test_player_stats_take_damage_no_double_defense() -> void:
		print("\n[测试] 玩家 take_damage 不再二次减防")
		var stats_script = preload("res://scripts/player/PlayerStats.gd")
		var stats: Node = stats_script.new()
		stats.max_hp = 100
		stats.current_hp = 100
		stats.defense = 5
		# 传入 20 最终伤害，应直接扣 20（不再减防御）
		stats.take_damage(20)
		_assert_eq(stats.current_hp, 80, "扣除 20 伤害后 HP 应为 80（不减防御）")
		# 测试死亡边界
		stats.take_damage(1000)
		_assert_eq(stats.current_hp, 0, "HP 不应低于 0")
		stats.free()

	# ======== 测试：Wolf 场景已清理冗余 AI 配置 ========
	func _test_wolf_scene_no_redundant_ai_config() -> void:
		print("\n[测试] Wolf 场景不再有冗余 AI 配置")
		var packed: PackedScene = load("res://scenes/enemies/Wolf.tscn")
		var scene_text: String = FileAccess.open("res://scenes/enemies/Wolf.tscn", FileAccess.READ).get_as_text()
		_assert_false(scene_text.find("chase_range") >= 0, "Wolf.tscn 不应包含 chase_range")
		_assert_false(scene_text.find("attack_range") >= 0, "Wolf.tscn 不应包含 attack_range")
		_assert_false(scene_text.find("attack_cooldown") >= 0, "Wolf.tscn 不应包含 attack_cooldown")
		# 仍应保留 enemy_id
		_assert_true(scene_text.find("enemy_mountain_wolf") >= 0, "Wolf.tscn 应保留 enemy_id")

	# ======== 测试：Boss 参数完整 ========
	func _test_nether_beast_boss_params() -> void:
		print("\n[测试] 冥纹兽 Boss 参数完整")
		var boss: CharacterBody2D = _NetherBeastScene.instantiate()
		add_child(boss)
		_assert_eq(boss.enemy_id, "enemy_nether_beast", "Boss enemy_id 正确")
		_assert_eq(boss.enemy_name, "冥纹兽", "Boss 名称正确")
		_assert_eq(boss.max_hp, 200, "Boss HP 应为 200")
		_assert_eq(boss.current_hp, 200, "Boss 当前 HP 应等于最大 HP")
		_assert_eq(boss.attack, 25, "Boss 攻击力应为 25")
		_assert_eq(boss.defense, 8, "Boss 防御力应为 8")
		_assert_eq(boss.exp_reward, 100, "Boss 经验奖励应为 100")
		_assert_eq(boss.death_flag, "boss_defeated", "Boss 死亡标记应为 boss_defeated")
		_assert_eq(boss.ai_type, "boss", "Boss ai_type 应为 boss")
		_assert_eq(boss.detection_range, 400.0, "Boss detection_range 应为 400")
		_assert_eq(boss.return_range, 9999.0, "Boss return_range 应为 9999（不返回）")
		boss.free()

	# ======== 断言辅助 ========
	func _assert_eq(actual, expected, msg: String) -> void:
		if actual == expected:
			_passed += 1
			print("  [PASS] %s" % msg)
		else:
			_failed += 1
			print("  [FAIL] %s (期望: %s, 实际: %s)" % [msg, str(expected), str(actual)])

	func _assert_true(val: bool, msg: String) -> void:
		if val:
			_passed += 1
			print("  [PASS] %s" % msg)
		else:
			_failed += 1
			print("  [FAIL] %s (期望 true)" % msg)

	func _assert_false(val: bool, msg: String) -> void:
		if not val:
			_passed += 1
			print("  [PASS] %s" % msg)
		else:
			_failed += 1
			print("  [FAIL] %s (期望 false)" % msg)

	func _print_summary() -> void:
		print("\n========== 自检结果 ==========")
		print("通过: %d  失败: %d" % [_passed, _failed])
		if _failed == 0:
			print("阶段 10 战斗系统自检全部通过！")
		else:
			print("存在失败项，请检查！")
		print("==============================")
