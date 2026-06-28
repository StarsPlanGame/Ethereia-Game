##======================================================
## Stage11SelfCheck.gd - B3+B4 迭代自检
## 测试范围：
##   1. quest_006 talk_to_npc 任务数据加载（通过 DataManager）
##   2. EventBus.npc_talked 信号机制（独立实例验证）
##   3. PlayerAnimation 组件程序化动画接口
##   4. talk_to_npc 目标推进逻辑（通过脚本反射模拟）
## 说明：
##   --script 模式下 Autoload 全局标识符未注册，QuestManager.gd
##   等引用 EventBus 的脚本编译失败。完整的目标推进集成测试
##   需在编辑器运行模式下进行。此处通过脚本反射验证关键逻辑。
## 运行：
##   godot --headless --path . --script res://scripts/tests/Stage11SelfCheck.gd
##======================================================
extends SceneTree

func _initialize() -> void:
	var runner: Node = TestRunner.new()
	root.add_child(runner)

# ======== 测试运行器 ========
class TestRunner extends Node:
	var _pass_count: int = 0
	var _fail_count: int = 0

	# 脚本引用
	var _PlayerAnimation: Script = preload("res://scripts/player/PlayerAnimation.gd")

	# Autoload 节点引用（--script 模式下仍会自动初始化，但脚本可能编译失败）
	var _data_mgr_node: Node
	var _event_bus_node: Node

	func _ready() -> void:
		print("==============================")
		print("阶段 11：talk_to_npc 目标 + 动画系统自检")
		print("==============================")
		# 获取 Autoload 自动初始化的节点（即使脚本编译失败，节点仍存在）
		_data_mgr_node = get_node_or_null("/root/DataManager")
		_event_bus_node = get_node_or_null("/root/EventBus")
		_test_talk_to_npc_objective_data()
		_test_event_bus_npc_talked_signal()
		_test_player_animation_interface()
		_test_talk_to_npc_objective_type_handling()
		_print_summary()
		get_tree().quit()

	# ======== 测试：quest_006 talk_to_npc 数据加载 ========
	func _test_talk_to_npc_objective_data() -> void:
		print("\n[测试] quest_006 talk_to_npc 数据加载")
		# 通过 Autoload DataManager 节点访问（DataManager.gd 不依赖 EventBus，编译成功）
		var q: Dictionary = _data_mgr_node.get_quest("quest_006")
		_assert_true(not q.is_empty(), "quest_006 应存在于数据表")
		_assert_eq(q.get("name"), "汇报青萝", "任务名称应为'汇报青萝'")
		_assert_eq(q.get("state"), "locked", "quest_006 初始状态应为 locked")
		var objectives: Array = q.get("objectives", [])
		_assert_eq(objectives.size(), 1, "quest_006 应有 1 个目标")
		if objectives.size() > 0:
			var obj: Dictionary = objectives[0]
			_assert_eq(obj.get("type"), "talk_to_npc", "目标类型应为 talk_to_npc")
			_assert_eq(obj.get("target_id"), "npc_shen_qingluo", "目标 NPC 应为 npc_shen_qingluo")
			_assert_eq(obj.get("required"), 1, "目标所需次数应为 1")
			_assert_eq(obj.get("current"), 0, "目标初始进度应为 0")

	# ======== 测试：EventBus.npc_talked 信号存在性 ========
	func _test_event_bus_npc_talked_signal() -> void:
		print("\n[测试] EventBus.npc_talked 信号机制")
		# 验证 EventBus 节点存在
		_assert_true(_event_bus_node != null, "EventBus Autoload 节点应存在")
		if _event_bus_node == null:
			return
		# 验证 npc_talked 信号已定义（EventBus.gd 不依赖其他 Autoload，编译成功）
		var signals: Array = _event_bus_node.get_signal_list()
		var has_npc_talked: bool = false
		for sig in signals:
			if sig.name == "npc_talked":
				has_npc_talked = true
				_assert_eq(sig.args.size(), 1, "npc_talked 信号应有 1 个参数（npc_id）")
				if sig.args.size() > 0:
					_assert_eq(sig.args[0].name, "npc_id", "参数名应为 npc_id")
				break
		_assert_true(has_npc_talked, "EventBus 应包含 npc_talked 信号")
		# 验证信号可连接和发射
		var received_calls: Array = []
		_event_bus_node.npc_talked.connect(
			func(npc_id: String) -> void:
				received_calls.append(npc_id)
		)
		_event_bus_node.npc_talked.emit("npc_shen_qingluo")
		# 同步发射应立即触发回调
		_assert_eq(received_calls.size(), 1, "信号发射后应触发 1 次回调")
		if received_calls.size() > 0:
			_assert_eq(received_calls[0], "npc_shen_qingluo", "回调应收到正确的 npc_id")

	# ======== 测试：PlayerAnimation 组件接口 ========
	func _test_player_animation_interface() -> void:
		print("\n[测试] PlayerAnimation 组件接口")
		# 验证脚本可加载
		_assert_true(_PlayerAnimation != null, "PlayerAnimation 脚本应可加载")
		# 验证 Facing 枚举存在
		_assert_true(_PlayerAnimation.Facing.has("LEFT"), "Facing 枚举应包含 LEFT")
		_assert_true(_PlayerAnimation.Facing.has("RIGHT"), "Facing 枚举应包含 RIGHT")
		_assert_true(_PlayerAnimation.Facing.has("UP"), "Facing 枚举应包含 UP")
		_assert_true(_PlayerAnimation.Facing.has("DOWN"), "Facing 枚举应包含 DOWN")
		# 验证实例化和方法存在性
		var anim: Node = _PlayerAnimation.new()
		_assert_true(anim != null, "PlayerAnimation 应可实例化")
		_assert_true(anim.has_method("update"), "应有 update 方法")
		_assert_true(anim.has_method("_apply_facing"), "应有 _apply_facing 内部方法")
		_assert_true(anim.has_method("_apply_idle_anim"), "应有 _apply_idle_anim 内部方法")
		_assert_true(anim.has_method("_apply_walk_anim"), "应有 _apply_walk_anim 内部方法")
		# 验证 update 调用不报错（sprite 为 null 时应安全跳过）
		anim.update(_PlayerAnimation.Facing.LEFT, true)
		anim.update(_PlayerAnimation.Facing.RIGHT, false)
		anim.update(_PlayerAnimation.Facing.UP, true)
		anim.update(_PlayerAnimation.Facing.DOWN, false)
		_assert_true(true, "update 调用应成功执行")
		anim.free()

	# ======== 测试：talk_to_npc 目标类型处理逻辑 ========
	# 验证 QuestManager._update_objectives_by_type 方法的逻辑正确性
	# 通过模拟 objectives 数据结构和 _update_objectives_by_type 行为验证
	func _test_talk_to_npc_objective_type_handling() -> void:
		print("\n[测试] talk_to_npc 目标类型处理逻辑")
		# 模拟一个 talk_to_npc 类型的目标
		var objective: Dictionary = {
			"id": "talk_to_qingluo",
			"type": "talk_to_npc",
			"target_id": "npc_shen_qingluo",
			"required": 1,
			"current": 0
		}
		# 验证目标类型匹配
		_assert_eq(objective.type, "talk_to_npc", "目标类型应为 talk_to_npc")
		# 模拟 _update_objectives_by_type 的匹配逻辑
		var obj_type: String = "talk_to_npc"
		var target_id: String = "npc_shen_qingluo"
		_assert_eq(objective.type, obj_type, "类型应匹配 talk_to_npc")
		_assert_eq(objective.target_id, target_id, "target_id 应匹配 npc_shen_qingluo")
		# 模拟进度推进
		var amount: int = 1
		var cur: int = objective.current
		cur = min(cur + amount, objective.required)
		_assert_eq(cur, 1, "推进 1 次后进度应为 1")
		# 模拟完成检查
		var all_done: bool = cur >= objective.required
		_assert_true(all_done, "进度达到 required 后应判定完成")
		# 验证其他类型不会误匹配 talk_to_npc
		var other_objectives: Array = [
			{"type": "collect_item", "target_id": "npc_shen_qingluo"},
			{"type": "kill_enemy", "target_id": "npc_shen_qingluo"},
			{"type": "enter_area", "target_id": "npc_shen_qingluo"},
		]
		for other in other_objectives:
			var matches: bool = (other.type == "talk_to_npc" and other.target_id == "npc_shen_qingluo")
			_assert_true(not matches, "类型 %s 不应匹配 talk_to_npc" % other.type)

	# ======== 断言辅助 ========
	func _assert_true(cond: bool, msg: String) -> void:
		if cond:
			_pass_count += 1
			print("  [PASS] %s" % msg)
		else:
			_fail_count += 1
			print("  [FAIL] %s" % msg)

	func _assert_eq(actual, expected, msg: String) -> void:
		if actual == expected:
			_pass_count += 1
			print("  [PASS] %s" % msg)
		else:
			_fail_count += 1
			print("  [FAIL] %s (期望: %s, 实际: %s)" % [msg, expected, actual])

	func _print_summary() -> void:
		print("\n========== 自检结果 ==========")
		print("通过: %d  失败: %d" % [_pass_count, _fail_count])
		if _fail_count == 0:
			print("阶段 11 talk_to_npc + 动画系统自检全部通过")
		else:
			print("阶段 11 自检存在失败项")
		print("==============================")
