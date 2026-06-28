##======================================================
## Stage12SelfCheck.gd - P0 阻断性修复自检
## 测试范围：
##   1. quest_006 触发链完整性（quest_005.next_quest_id 链接）
##   2. quest_006 数据结构（talk_to_npc 目标 + locked 状态）
##   3. dlg_shen_qingluo_report 对话存在性及 complete_quest 效果
##   4. UILayer 脚本接口（HPLabel/MPLabel/QuestHintLabel + _update_quest_hint）
##   5. GameRoot.tscn HUD 节点结构（HPLabel/MPLabel/QuestHintLabel 节点存在）
## 说明：
##   --script 模式下 Autoload 全局标识符未注册，通过
##   get_node_or_null("/root/XXX") 获取 Autoload 节点访问数据。
##   UILayer 非 Autoload，通过脚本反射验证接口完整性。
##   GameRoot.tscn 通过 load+instantiate 验证节点结构。
## 运行：
##   godot --headless --path . --script res://scripts/tests/Stage12SelfCheck.gd
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
	var _UILayer: Script = preload("res://scripts/ui/UILayer.gd")
	var _GameRoot_scene: PackedScene = load("res://scenes/core/GameRoot.tscn")

	# Autoload 节点引用
	var _data_mgr_node: Node

	func _ready() -> void:
		print("==============================")
		print("阶段 12：P0 阻断性修复自检")
		print("==============================")
		_data_mgr_node = get_node_or_null("/root/DataManager")
		_test_quest_005_next_quest_link()
		_test_quest_006_data_integrity()
		_test_dlg_shen_qingluo_report_existence()
		_test_uilayer_script_interface()
		_test_gameroot_hud_node_structure()
		_print_summary()
		get_tree().quit()

	# ======== 测试：quest_005 → quest_006 触发链 ========
	func _test_quest_005_next_quest_link() -> void:
		print("\n[测试] quest_005 → quest_006 触发链")
		_assert_true(_data_mgr_node != null, "DataManager Autoload 节点应存在")
		if _data_mgr_node == null:
			return
		var q5: Dictionary = _data_mgr_node.get_quest("quest_005")
		_assert_true(not q5.is_empty(), "quest_005 应存在于数据表")
		if q5.is_empty():
			return
		_assert_eq(q5.get("next_quest_id"), "quest_006", "quest_005 的 next_quest_id 应为 quest_006")
		# 验证 quest_006 也存在
		var q6: Dictionary = _data_mgr_node.get_quest("quest_006")
		_assert_true(not q6.is_empty(), "quest_006 应存在于数据表（触发链终点）")

	# ======== 测试：quest_006 数据完整性 ========
	func _test_quest_006_data_integrity() -> void:
		print("\n[测试] quest_006 数据完整性")
		if _data_mgr_node == null:
			return
		var q: Dictionary = _data_mgr_node.get_quest("quest_006")
		_assert_true(not q.is_empty(), "quest_006 应存在")
		if q.is_empty():
			return
		_assert_eq(q.get("name"), "汇报青萝", "任务名称应为'汇报青萝'")
		_assert_eq(q.get("state"), "locked", "quest_006 初始状态应为 locked")
		var objectives: Array = q.get("objectives", [])
		_assert_eq(objectives.size(), 1, "quest_006 应有 1 个目标")
		if objectives.size() == 0:
			return
		var obj: Dictionary = objectives[0]
		_assert_eq(obj.get("type"), "talk_to_npc", "目标类型应为 talk_to_npc")
		_assert_eq(obj.get("target_id"), "npc_shen_qingluo", "目标 NPC 应为 npc_shen_qingluo")
		_assert_eq(obj.get("required"), 1, "目标所需次数应为 1")
		_assert_eq(obj.get("current"), 0, "目标初始进度应为 0")

	# ======== 测试：dlg_shen_qingluo_report 对话存在性及效果 ========
	func _test_dlg_shen_qingluo_report_existence() -> void:
		print("\n[测试] dlg_shen_qingluo_report 对话分支")
		if _data_mgr_node == null:
			return
		var dlg: Dictionary = _data_mgr_node.get_dialogue("dlg_shen_qingluo_report")
		_assert_true(not dlg.is_empty(), "dlg_shen_qingluo_report 应存在于对话数据表")
		if dlg.is_empty():
			return
		_assert_eq(dlg.get("npc_id"), "npc_shen_qingluo", "对话关联 NPC 应为 npc_shen_qingluo")
		# 验证条件匹配 quest_006 active
		var cond: Dictionary = dlg.get("condition", {})
		_assert_eq(cond.get("type"), "quest_state", "条件类型应为 quest_state")
		_assert_eq(cond.get("quest_id"), "quest_006", "条件任务 ID 应为 quest_006")
		_assert_eq(cond.get("state"), "active", "条件状态应为 active")
		# 验证 nodes 中存在 complete_quest quest_006 效果
		var nodes: Array = dlg.get("nodes", [])
		_assert_true(nodes.size() > 0, "对话应包含节点")
		var has_complete_quest_effect: bool = false
		for node in nodes:
			var effects: Array = node.get("effects", [])
			for eff in effects:
				if eff.get("type") == "complete_quest" and eff.get("quest_id") == "quest_006":
					has_complete_quest_effect = true
					break
			if has_complete_quest_effect:
				break
		_assert_true(has_complete_quest_effect, "对话应包含 complete_quest quest_006 效果（用于交付任务）")
		# 验证有 is_end 节点
		var has_end_node: bool = false
		for node in nodes:
			if node.get("is_end", false) == true:
				has_end_node = true
				break
		_assert_true(has_end_node, "对话应包含 is_end 结束节点")

	# ======== 测试：UILayer 脚本接口 ========
	# 注：UILayer.gd 依赖 EventBus Autoload，--script 模式下编译失败，
	# 方法列表为空。因此方法存在性通过源码文本搜索验证。
	func _test_uilayer_script_interface() -> void:
		print("\n[测试] UILayer 脚本接口（HUD 增强）")
		_assert_true(_UILayer != null, "UILayer 脚本应可加载")
		# 验证 HUD 增强属性存在（属性元数据在编译失败时仍可访问）
		var props: Array = _UILayer.get_script_property_list()
		var prop_names: Array = []
		for p in props:
			prop_names.append(p.name)
		_assert_true("hp_label" in prop_names, "UILayer 应有 hp_label 属性（HP 数值显示）")
		_assert_true("mp_label" in prop_names, "UILayer 应有 mp_label 属性（MP 数值显示）")
		_assert_true("quest_hint_label" in prop_names, "UILayer 应有 quest_hint_label 属性（任务提示）")
		_assert_true("hp_bar" in prop_names, "UILayer 应有 hp_bar 属性（HP 进度条）")
		_assert_true("mp_bar" in prop_names, "UILayer 应有 mp_bar 属性（MP 进度条）")
		_assert_true("realm_label" in prop_names, "UILayer 应有 realm_label 属性（境界显示）")
		# 方法存在性通过源码文本搜索验证（避免编译失败导致方法列表为空）
		var source: String = _UILayer.source_code
		_assert_true(source.find("func _update_quest_hint") >= 0, "UILayer 源码应包含 _update_quest_hint 方法")
		_assert_true(source.find("func _on_quest_changed") >= 0, "UILayer 源码应包含 _on_quest_changed 方法")
		_assert_true(source.find("func _on_hp_changed") >= 0, "UILayer 源码应包含 _on_hp_changed 方法")
		_assert_true(source.find("func _on_mp_changed") >= 0, "UILayer 源码应包含 _on_mp_changed 方法")
		_assert_true(source.find("func _on_cultivation_changed") >= 0, "UILayer 源码应包含 _on_cultivation_changed 方法")

	# ======== 测试：GameRoot.tscn HUD 节点结构 ========
	func _test_gameroot_hud_node_structure() -> void:
		print("\n[测试] GameRoot.tscn HUD 节点结构")
		_assert_true(_GameRoot_scene != null, "GameRoot.tscn 应可加载")
		if _GameRoot_scene == null:
			return
		var instance: Node = _GameRoot_scene.instantiate()
		_assert_true(instance != null, "GameRoot.tscn 应可实例化")
		if instance == null:
			return
		# 查找 UILayer 和 HUD 节点
		var ui_layer: Node = instance.get_node_or_null("UILayer")
		_assert_true(ui_layer != null, "GameRoot 应包含 UILayer 节点")
		if ui_layer == null:
			instance.free()
			return
		var hud: Node = ui_layer.get_node_or_null("HUD")
		_assert_true(hud != null, "UILayer 应包含 HUD 节点")
		if hud == null:
			instance.free()
			return
		# 验证 HUD 增强节点存在
		_assert_true(hud.has_node("HPBar"), "HUD 应包含 HPBar 节点")
		_assert_true(hud.has_node("MPBar"), "HUD 应包含 MPBar 节点")
		_assert_true(hud.has_node("HPLabel"), "HUD 应包含 HPLabel 节点（GDD §9.3 数值显示）")
		_assert_true(hud.has_node("MPLabel"), "HUD 应包含 MPLabel 节点（GDD §9.3 数值显示）")
		_assert_true(hud.has_node("RealmLabel"), "HUD 应包含 RealmLabel 节点")
		_assert_true(hud.has_node("QuestHintLabel"), "HUD 应包含 QuestHintLabel 节点（GDD §9.3 任务提示）")
		# 验证 PromptLabel 存在
		_assert_true(ui_layer.has_node("PromptLabel"), "UILayer 应包含 PromptLabel 节点（交互提示）")
		instance.free()

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
			print("阶段 12 P0 阻断性修复自检全部通过")
		else:
			print("阶段 12 自检存在失败项")
		print("==============================")
