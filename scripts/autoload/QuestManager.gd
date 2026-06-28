##======================================================
## QuestManager.gd - 任务系统
## 挂载：Autoload 单例
## 职责：任务状态机管理 + 目标进度跟踪 + 监听 EventBus 自动推进
## 关联文档：05_SYSTEM_DESIGN.md §2.5 / 08_DATA_SCHEMA.md §3
##======================================================
extends Node

# ======== 任务状态枚举 ========
enum State {
	LOCKED,            # 未解锁
	AVAILABLE,         # 可接取
	ACTIVE,            # 进行中
	READY_TO_COMPLETE, # 可交付
	COMPLETED,         # 已完成
	FAILED             # 失败
}

## 状态字符串 <-> 枚举映射
const STATE_NAME := {
	State.LOCKED: "locked",
	State.AVAILABLE: "available",
	State.ACTIVE: "active",
	State.READY_TO_COMPLETE: "ready_to_complete",
	State.COMPLETED: "completed",
	State.FAILED: "failed",
}

# ======== 运行时数据 =====###
## key: quest_id, value: { "state": State, "objectives": { obj_id: current_progress } }
var _quest_states: Dictionary = {}

# ======== 生命周期 ========
func _ready() -> void:
	# 监听 EventBus 信号以自动推进任务目标
	EventBus.item_collected.connect(_on_item_collected)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.area_entered.connect(_on_area_entered)
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	EventBus.npc_talked.connect(_on_npc_talked)
	EventBus.cultivation_changed.connect(_on_cultivation_changed)
	# 从 DataManager 初始化所有任务为数据表中的初始状态
	_initialize_quest_states()

## 把所有任务表中的初始 state 加载到内存
func _initialize_quest_states() -> void:
	for quest_id in DataManager.get_all_quests():
		var q: Dictionary = DataManager.get_quest(quest_id)
		var state_str: String = q.get("state", "locked")
		var state: State = _state_from_string(state_str)
		var objectives_progress: Dictionary = {}
		for obj in q.get("objectives", []):
			objectives_progress[obj.get("id")] = obj.get("current", 0)
		_quest_states[quest_id] = {
			"state": state,
			"objectives": objectives_progress,
		}

# ======== 查询接口 ========
func get_quest_state(quest_id: String) -> String:
	if not _quest_states.has(quest_id):
		return "locked"
	return STATE_NAME.get(_quest_states[quest_id]["state"], "locked")

func get_active_quests() -> Array:
	var result: Array = []
	for qid in _quest_states:
		if _quest_states[qid]["state"] == State.ACTIVE:
			result.append(qid)
	return result

func get_objective_progress(quest_id: String, objective_id: String) -> int:
	if not _quest_states.has(quest_id):
		return 0
	return _quest_states[quest_id]["objectives"].get(objective_id, 0)

# ======== 状态变更接口 ========
func start_quest(quest_id: String) -> void:
	if not _quest_states.has(quest_id):
		push_warning("[Quest] 任务不存在: %s" % quest_id)
		return
	var cur: int = _quest_states[quest_id]["state"]
	if cur != State.AVAILABLE and cur != State.LOCKED:
		return  # 已开始或已完成
	_quest_states[quest_id]["state"] = State.ACTIVE
	EventBus.quest_started.emit(quest_id)
	print("[Quest] 任务开始: %s" % quest_id)

func update_objective(quest_id: String, objective_id: String, amount: int = 1) -> void:
	if not _quest_states.has(quest_id):
		return
	if _quest_states[quest_id]["state"] != State.ACTIVE:
		return
	var q: Dictionary = DataManager.get_quest(quest_id)
	for obj in q.get("objectives", []):
		if obj.get("id") == objective_id:
			var cur: int = _quest_states[quest_id]["objectives"].get(objective_id, 0)
			cur = min(cur + amount, obj.get("required", 1))
			_quest_states[quest_id]["objectives"][objective_id] = cur
			EventBus.quest_updated.emit(quest_id)
			_check_quest_completion(quest_id)
			return

func complete_quest(quest_id: String) -> void:
	if not _quest_states.has(quest_id):
		return
	_quest_states[quest_id]["state"] = State.COMPLETED
	_grant_rewards(quest_id)
	_trigger_next_quest(quest_id)
	_apply_quest_side_effects(quest_id)
	EventBus.quest_completed.emit(quest_id)
	print("[Quest] 任务完成: %s" % quest_id)

## 尝试交付任务（由 NPC 对话调用）
## 仅当任务处于 READY_TO_COMPLETE 状态时才能完成
func try_complete_quest(quest_id: String) -> bool:
	if not _quest_states.has(quest_id):
		return false
	if _quest_states[quest_id]["state"] != State.READY_TO_COMPLETE:
		return false
	complete_quest(quest_id)
	return true

# ======== 内部辅助 ========
func _check_quest_completion(quest_id: String) -> void:
	var q: Dictionary = DataManager.get_quest(quest_id)
	var all_done: bool = true
	for obj in q.get("objectives", []):
		var required: int = obj.get("required", 1)
		var cur: int = _quest_states[quest_id]["objectives"].get(obj.get("id"), 0)
		if cur < required:
			all_done = false
			break
	if all_done:
		_quest_states[quest_id]["state"] = State.READY_TO_COMPLETE
		EventBus.quest_updated.emit(quest_id)
		print("[Quest] 任务可交付: %s" % quest_id)
		# 自动完成：无 rewards 的探索任务，或数据表标记 auto_complete 的任务
		if q.get("rewards", []).is_empty() or q.get("auto_complete", false):
			complete_quest(quest_id)

func _grant_rewards(quest_id: String) -> void:
	var q: Dictionary = DataManager.get_quest(quest_id)
	for reward in q.get("rewards", []):
		match reward.get("type"):
			"item", "currency":
				InventorySystem.add_item(reward.get("id"), reward.get("amount", 1))
			"unlock":
				# 解锁技能/系统：写入 skill_unlocked_<id> 剧情标记
				var unlock_id: String = reward.get("id", "")
				if unlock_id != "":
					GameState.set_story_flag("skill_unlocked_" + unlock_id, true)

func _trigger_next_quest(quest_id: String) -> void:
	var q: Dictionary = DataManager.get_quest(quest_id)
	var next_id: String = q.get("next_quest_id", "")
	if next_id != "" and _quest_states.has(next_id):
		if _quest_states[next_id]["state"] == State.LOCKED:
			_quest_states[next_id]["state"] = State.AVAILABLE
			# 自动启动下一任务（探索任务链无需回 NPC 接取）
			start_quest(next_id)

func _apply_quest_side_effects(quest_id: String) -> void:
	var q: Dictionary = DataManager.get_quest(quest_id)
	for key in q.get("story_flags", {}):
		GameState.set_story_flag(key, q["story_flags"][key])
	for key in q.get("karma_effects", {}):
		KarmaManager.add_karma(key, q["karma_effects"][key])
	for npc_id in q.get("relationship_effects", {}):
		RelationshipManager.change_relationship(npc_id, q["relationship_effects"][npc_id])

func _state_from_string(s: String) -> State:
	for key in STATE_NAME:
		if STATE_NAME[key] == s:
			return key
	return State.LOCKED

# ======== EventBus 监听器 ========
func _on_item_collected(item_id: String, _amount: int) -> void:
	_update_objectives_by_type("collect_item", item_id, _amount)
	_update_objectives_by_type("obtain_item", item_id, _amount)

func _on_enemy_killed(enemy_id: String) -> void:
	_update_objectives_by_type("kill_enemy", enemy_id, 1)

func _on_area_entered(area_id: String) -> void:
	_update_objectives_by_type("enter_area", area_id, 1)

func _on_dialogue_finished(_dialogue_id: String) -> void:
	# talk_to_npc 类型目标改由 _on_npc_talked 处理（携带 npc_id 更精确）
	pass

## 玩家与 NPC 完成对话时触发，推进 talk_to_npc 类型目标
func _on_npc_talked(npc_id: String) -> void:
	_update_objectives_by_type("talk_to_npc", npc_id, 1)

func _on_cultivation_changed(realm: String, level: int, _qi: int) -> void:
	_update_objectives_by_type("reach_cultivation", "%s_%d" % [realm, level], 1)

func _update_objectives_by_type(obj_type: String, target_id: String, amount: int) -> void:
	for quest_id in _quest_states:
		if _quest_states[quest_id]["state"] != State.ACTIVE:
			continue
		var q: Dictionary = DataManager.get_quest(quest_id)
		for obj in q.get("objectives", []):
			if obj.get("type") == obj_type and obj.get("target_id") == target_id:
				update_objective(quest_id, obj.get("id"), amount)

# ======== 存档接口 ========
func get_save_data() -> Dictionary:
	var result: Dictionary = {}
	for qid in _quest_states:
		var entry: Dictionary = _quest_states[qid]
		result[qid] = {
			"state": STATE_NAME.get(entry["state"], "locked"),
			"objectives": entry["objectives"].duplicate(true),
		}
	return result

func load_save_data(data: Dictionary) -> void:
	_quest_states.clear()
	for qid in data:
		var entry: Dictionary = data[qid]
		_quest_states[qid] = {
			"state": _state_from_string(entry.get("state", "locked")),
			"objectives": entry.get("objectives", {}).duplicate(true),
		}
