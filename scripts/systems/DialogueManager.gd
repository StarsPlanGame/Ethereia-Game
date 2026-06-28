##======================================================
## DialogueManager.gd - 对话系统
## 挂载：Autoload 单例
## 职责：解析 dialogues.json 节点图，推进对话，处理选项分支与效果触发
## 关联文档：05_SYSTEM_DESIGN.md §9 对话系统 / 08_DATA_SCHEMA.md §6
##
## 对话数据结构（dialogues.json）：
##   {
##     "dlg_xxx": {
##       "id": "dlg_xxx",
##       "npc_id": "npc_xxx",
##       "condition": { "type": "always" | "quest_state", ... },
##       "nodes": [
##         { "id": "start", "speaker": "沈青萝", "text": "...", "next": "xxx",
##           "effects": [ { "type": "start_quest", "quest_id": "..." } ] },
##         { "id": "accept_choice", "choices": [
##             { "text": "选项1", "next": "node_id", "effects": [] }, ...
##         ] },
##         { "id": "end", "is_end": true }
##       ]
##     }
##   }
##======================================================
extends Node

# ======== 信号 ========
signal dialogue_node_changed(speaker: String, text: String, choices: Array)
signal dialogue_ended(dialogue_id: String)

# ======== 当前对话状态 =====###
var _current_dialogue_id: String = ""
var _current_node: Dictionary = {}
var _current_npc_id: String = ""
var _is_active: bool = false

# ======== 公共接口 ========
func is_active() -> bool:
	return _is_active

## 根据当前 NPC 状态选择合适的对话 ID 并启动
## 优先级：条件匹配的对话 > 默认对话
func start_dialogue_with(npc_id: String) -> void:
	var dialogue_id: String = _pick_dialogue_id_for(npc_id)
	if dialogue_id == "":
		push_warning("[Dialogue] NPC %s 无可用对话" % npc_id)
		return
	start_dialogue(dialogue_id, npc_id)

## 显式启动某个对话 ID
func start_dialogue(dialogue_id: String, npc_id: String = "") -> void:
	var data: Dictionary = DataManager.get_dialogue(dialogue_id)
	if data.is_empty():
		push_warning("[Dialogue] 对话数据不存在: %s" % dialogue_id)
		return
	_current_dialogue_id = dialogue_id
	_current_npc_id = npc_id
	_is_active = true
	# 锁定玩家移动
	GameState.is_in_dialogue = true
	EventBus.dialogue_started.emit(dialogue_id)
	# 跳转到 start 节点
	_goto_node("start")

## 推进到下一节点（无选项时由 UI 调用，如按 E/空格/点击）
func advance() -> void:
	if not _is_active:
		return
	if _current_node.is_empty():
		end_dialogue()
		return
	# 如果当前节点是选项节点，advance 不生效（必须通过 choose_option）
	if _current_node.has("choices"):
		return
	# 如果当前节点是结束节点
	if _current_node.get("is_end", false):
		end_dialogue()
		return
	var next_id: String = _current_node.get("next", "")
	if next_id == "":
		end_dialogue()
		return
	_goto_node(next_id)

## 选择某个选项（index 为 choices 数组下标）
func choose_option(index: int) -> void:
	if not _is_active:
		return
	if not _current_node.has("choices"):
		return
	var choices: Array = _current_node["choices"]
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	# 触发选项效果
	_apply_effects(choice.get("effects", []))
	# 跳转到选项指定的下一节点
	var next_id: String = choice.get("next", "")
	if next_id == "":
		end_dialogue()
		return
	_goto_node(next_id)

## 强制结束对话
func end_dialogue() -> void:
	if not _is_active:
		return
	var ended_id: String = _current_dialogue_id
	_current_dialogue_id = ""
	_current_node = {}
	_current_npc_id = ""
	_is_active = false
	GameState.is_in_dialogue = false
	EventBus.dialogue_finished.emit(ended_id)
	dialogue_ended.emit(ended_id)

# ======== 内部实现 ========
## 根据条件选择 NPC 当前可用的对话
func _pick_dialogue_id_for(npc_id: String) -> String:
	var best_id: String = ""
	for dlg_id in DataManager.get_all_dialogues():
		var dlg: Dictionary = DataManager.get_dialogue(dlg_id)
		if dlg.get("npc_id") != npc_id:
			continue
		if _check_condition(dlg.get("condition", {})):
			# 取第一个匹配的（数据表中按优先级排序）
			best_id = dlg_id
			break
	return best_id

## 检查对话条件
func _check_condition(cond: Dictionary) -> bool:
	var cond_type: String = cond.get("type", "always")
	match cond_type:
		"always":
			return true
		"quest_state":
			var qid: String = cond.get("quest_id", "")
			var required_state: String = cond.get("state", "available")
			return QuestManager.get_quest_state(qid) == required_state
		"story_flag":
			var key: String = cond.get("key", "")
			var required_value = cond.get("value", true)
			return GameState.get_story_flag(key) == required_value
		"has_item":
			var item_id: String = cond.get("item_id", "")
			return InventorySystem.has_item(item_id)
		_:
			return true

## 跳转到指定节点
func _goto_node(node_id: String) -> void:
	var dlg: Dictionary = DataManager.get_dialogue(_current_dialogue_id)
	if dlg.is_empty():
		end_dialogue()
		return
	var nodes: Array = dlg.get("nodes", [])
	for n in nodes:
		if n.get("id") == node_id:
			_current_node = n
			# 触发节点效果
			_apply_effects(n.get("effects", []))
			# 检查是否是结束节点
			if n.get("is_end", false):
				# 发送空内容，UI 应收到后自动关闭
				dialogue_node_changed.emit("", "", [])
				# 延迟一帧后结束，让 UI 有机会响应
				call_deferred("end_dialogue")
				return
			# 发送节点内容到 UI
			var speaker: String = n.get("speaker", "")
			var text: String = n.get("text", "")
			var choices: Array = n.get("choices", [])
			dialogue_node_changed.emit(speaker, text, choices)
			return
	# 找不到节点则结束
	end_dialogue()

## 应用效果列表
func _apply_effects(effects: Array) -> void:
	for effect in effects:
		if not effect is Dictionary:
			continue
		var effect_type: String = effect.get("type", "")
		match effect_type:
			"start_quest":
				QuestManager.start_quest(effect.get("quest_id", ""))
			"complete_quest":
				QuestManager.complete_quest(effect.get("quest_id", ""))
			"add_item":
				InventorySystem.add_item(effect.get("id", ""), effect.get("amount", 1))
			"remove_item":
				InventorySystem.remove_item(effect.get("id", ""), effect.get("amount", 1))
			"set_story_flag":
				GameState.set_story_flag(effect.get("key", ""), effect.get("value", true))
			"add_karma":
				KarmaManager.add_karma(effect.get("key", ""), effect.get("amount", 1))
			"change_relationship":
				RelationshipManager.change_relationship(effect.get("npc_id", ""), effect.get("amount", 0))
			"unlock_cultivation":
				GameState.set_story_flag("has_nether_jade", true)
			_:
				push_warning("[Dialogue] 未知效果类型: %s" % effect_type)
