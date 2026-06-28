##======================================================
## UILayer.gd - UI 层管理
## 挂载：GameRoot.tscn 中的 UILayer（CanvasLayer）
## 职责：管理提示文本、通知、HP/MP HUD、境界/灵气显示、任务提示、对话框等 UI 切换
## 关联文档：05_SYSTEM_DESIGN.md §14 UI 系统 / 01_GDD_GAME_DESIGN.md §9.3 HUD 布局
##======================================================
extends CanvasLayer
class_name UILayer

@onready var prompt_label: Label = $PromptLabel
@onready var notification_label: Label = $NotificationLabel
@onready var hp_bar: ProgressBar = $HUD/HPBar
@onready var mp_bar: ProgressBar = $HUD/MPBar
@onready var realm_label: Label = $HUD/RealmLabel
## HP 数值文本（如 "100/100"），GDD §9.3 要求
@onready var hp_label: Label = $HUD/HPLabel
## MP 数值文本（如 "30/30"），GDD §9.3 要求
@onready var mp_label: Label = $HUD/MPLabel
## 当前活动任务提示（如 "任务：药铺采药 1/3"），GDD §9.3 要求
@onready var quest_hint_label: Label = $HUD/QuestHintLabel

func _ready() -> void:
	EventBus.interaction_prompt_shown.connect(_on_prompt_shown)
	EventBus.interaction_prompt_hidden.connect(_on_prompt_hidden)
	EventBus.notification_shown.connect(_on_notification_shown)
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.player_mp_changed.connect(_on_mp_changed)
	EventBus.cultivation_changed.connect(_on_cultivation_changed)
	EventBus.breakthrough_success.connect(_on_breakthrough_success)
	# 任务相关信号：刷新底部任务提示
	EventBus.quest_started.connect(_on_quest_changed)
	EventBus.quest_updated.connect(_on_quest_changed)
	EventBus.quest_completed.connect(_on_quest_changed)
	EventBus.quest_failed.connect(_on_quest_changed)
	# 初始化 UI 隐藏
	if prompt_label: prompt_label.visible = false
	if notification_label: notification_label.visible = false
	# 初始化任务提示
	_update_quest_hint()

# ======== 交互提示 ========
func _on_prompt_shown(text: String) -> void:
	if prompt_label == null:
		return
	prompt_label.text = text
	prompt_label.visible = true

func _on_prompt_hidden() -> void:
	if prompt_label == null:
		return
	prompt_label.visible = false

# ======== 通知 ========
func _on_notification_shown(text: String) -> void:
	if notification_label == null:
		return
	notification_label.text = text
	notification_label.visible = true
	# 2 秒后自动隐藏
	await get_tree().create_timer(2.0).timeout
	notification_label.visible = false

# ======== HP/MP HUD ========
func _on_hp_changed(cur: int, max_v: int) -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = max_v
	hp_bar.value = cur
	if hp_label != null:
		hp_label.text = "%d/%d" % [cur, max_v]

func _on_mp_changed(cur: int, max_v: int) -> void:
	if mp_bar == null:
		return
	mp_bar.max_value = max_v
	mp_bar.value = cur
	if mp_label != null:
		mp_label.text = "%d/%d" % [cur, max_v]

# ======== 境界/灵气 ========
func _on_cultivation_changed(realm: String, level: int, qi: int) -> void:
	if realm_label == null:
		return
	# GDD §9.3 规范格式："境界：凡人    灵气：0/100"
	realm_label.text = "境界：%s %d层    灵气：%d/100" % [realm, level, qi]

func _on_breakthrough_success(realm: String, level: int) -> void:
	_on_notification_shown("突破成功！进入 %s %d层" % [realm, level])

# ======== 任务提示 ========
func _on_quest_changed(_quest_id: String) -> void:
	_update_quest_hint()

## 刷新底部任务提示：显示第一个活动任务的名称与首个未完成目标进度
func _update_quest_hint() -> void:
	if quest_hint_label == null:
		return
	var active_quests: Array = QuestManager.get_active_quests()
	if active_quests.is_empty():
		quest_hint_label.text = ""
		quest_hint_label.visible = false
		return
	var quest_id: String = active_quests[0]
	var q: Dictionary = DataManager.get_quest(quest_id)
	var quest_name: String = q.get("name", quest_id)
	# 取首个未完成目标作为提示
	var progress_text: String = ""
	var objectives: Array = q.get("objectives", [])
	for obj in objectives:
		var obj_id: String = obj.get("id", "")
		var required: int = obj.get("required", 1)
		var current: int = QuestManager.get_objective_progress(quest_id, obj_id)
		if current < required:
			progress_text = "%d/%d" % [current, required]
			break
	if progress_text == "" and not objectives.is_empty():
		# 所有目标已完成但任务未交付
		var last_obj: Dictionary = objectives[-1]
		var last_required: int = last_obj.get("required", 1)
		progress_text = "%d/%d" % [last_required, last_required]
	quest_hint_label.text = "任务：%s %s" % [quest_name, progress_text]
	quest_hint_label.visible = true
