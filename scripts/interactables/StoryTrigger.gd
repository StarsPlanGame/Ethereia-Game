##======================================================
## StoryTrigger.gd - 剧情触发器
## 挂载：Area2D（位于地图场景的 StoryTriggers 节点下）
## 职责：玩家交互时触发剧情对话 / 给予道具 / 设置剧情标记 / 解锁任务
## 关联文档：02_TDD_TECHNICAL_DESIGN.md §4.6 / 05_SYSTEM_DESIGN.md §10
##
## 触发类型：
##   - "dialogue"：启动指定对话
##   - "give_item"：直接给予道具（配合 collect_item / obtain_item 任务）
##   - "set_flag"：设置 story_flag
##   - "complete_quest"：强制完成任务（用于剧情必经节点）
##   - "composite"：按顺序触发 effects 列表中的全部效果
##
## 一次性触发：触发后自动禁用并隐藏，配合 story_flag 防重复
##======================================================
extends Area2D
class_name StoryTrigger

# ======== 触发类型枚举 ========
enum TriggerType {
	DIALOGUE,      # 启动对话
	GIVE_ITEM,     # 给予道具
	SET_FLAG,      # 设置剧情标记
	START_QUEST,   # 启动任务
	COMPLETE_QUEST,# 强制完成任务
	COMPOSITE      # 复合效果
}

# ======== 导出参数 ========
@export var trigger_id: String = ""                       # 全局唯一 ID（防重复触发，存档用）
@export var trigger_type: TriggerType = TriggerType.DIALOGUE
@export var dialogue_id: String = ""                      # DIALOGUE 类型用
@export var item_id: String = ""                          # GIVE_ITEM 类型用
@export var item_amount: int = 1                          # GIVE_ITEM 类型用
@export var flag_key: String = ""                         # SET_FLAG 类型用
@export var flag_value: bool = true                       # SET_FLAG 类型用
@export var quest_id: String = ""                         # START_QUEST / COMPLETE_QUEST 用
@export var also_start_quest: String = ""                 # COMPLETE_QUEST 后自动启动此任务
@export var effects: Array = []                           # COMPOSITE 类型用，效果列表
@export var one_shot: bool = true                         # 是否一次性触发
@export var require_flag: String = ""                     # 需要的剧情标记（空则无条件）
@export var require_flag_value: bool = true               # 需要的剧情标记值
@export var prompt_text: String = "按 E 查看"
@export var auto_trigger: bool = false                    # 自动触发（玩家进入区域即触发，无需 E）

# ======== 内部状态 ========
var _triggered: bool = false

func _ready() -> void:
	collision_layer = 16  # layer 5 = interactable
	collision_mask = 1    # layer 1 = player
	# 已触发过则隐藏
	if trigger_id != "" and SaveManager.is_story_triggered(trigger_id):
		_triggered = true
		visible = false
		monitoring = false
		return
	# 自动触发模式：监听 body 进入
	if auto_trigger:
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	interact(body)

## 玩家交互入口（由 PlayerInteraction 调用）
func interact(_player: Node) -> void:
	if _triggered:
		return
	# 检查前置剧情标记
	if require_flag != "" and GameState.get_story_flag(require_flag) != require_flag_value:
		EventBus.notification_shown.emit("此刻似乎还无法触发...")
		return
	_triggered = true
	# 标记存档
	if trigger_id != "":
		SaveManager.mark_story_triggered(trigger_id)
	# 按类型触发效果
	_apply_trigger()
	# 一次性触发后禁用
	if one_shot:
		visible = false
		monitoring = false

## 应用触发效果
func _apply_trigger() -> void:
	match trigger_type:
		TriggerType.DIALOGUE:
			if dialogue_id != "":
				DialogueManager.start_dialogue(dialogue_id)
		TriggerType.GIVE_ITEM:
			if item_id != "":
				InventorySystem.add_item(item_id, item_amount)
				var item_name: String = DataManager.get_item(item_id).get("name", item_id)
				EventBus.notification_shown.emit("获得 %s × %d" % [item_name, item_amount])
		TriggerType.SET_FLAG:
			if flag_key != "":
				GameState.set_story_flag(flag_key, flag_value)
		TriggerType.START_QUEST:
			if quest_id != "":
				QuestManager.start_quest(quest_id)
		TriggerType.COMPLETE_QUEST:
			if quest_id != "":
				QuestManager.complete_quest(quest_id)
			# 完成后自动启动下一任务
			if also_start_quest != "":
				QuestManager.start_quest(also_start_quest)
		TriggerType.COMPOSITE:
			_apply_effects(effects)
		_:
			push_warning("[StoryTrigger] 未知触发类型: %d" % trigger_type)

## 应用效果列表（与 DialogueManager 效果格式兼容）
func _apply_effects(effect_list: Array) -> void:
	for effect in effect_list:
		if not effect is Dictionary:
			continue
		var effect_type: String = effect.get("type", "")
		match effect_type:
			"start_quest":
				QuestManager.start_quest(effect.get("quest_id", ""))
			"complete_quest":
				QuestManager.complete_quest(effect.get("quest_id", ""))
			"try_complete_quest":
				QuestManager.try_complete_quest(effect.get("quest_id", ""))
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
			"start_dialogue":
				DialogueManager.start_dialogue(effect.get("dialogue_id", ""))
			"unlock_cultivation":
				GameState.set_story_flag("has_nether_jade", true)
			_:
				push_warning("[StoryTrigger] 未知效果类型: %s" % effect_type)
