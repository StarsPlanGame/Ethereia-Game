##======================================================
## QuestPanel.gd - 任务面板 UI
## 挂载：QuestPanel.tscn 根节点（Control）
## 职责：显示玩家所有任务（active/ready_to_complete/completed），按 Q 切换显示
## 关联文档：05_SYSTEM_DESIGN.md §14.4
##======================================================
extends Control
class_name QuestPanel

@onready var active_container: VBoxContainer = $Panel/Margin/VBox/Scroll/Content/ActiveContainer
@onready var completed_container: VBoxContainer = $Panel/Margin/VBox/Scroll/Content/CompletedContainer
@onready var empty_label: Label = $Panel/Margin/VBox/EmptyLabel

func _ready() -> void:
	visible = false
	# 监听任务事件实时刷新
	EventBus.quest_started.connect(_refresh)
	EventBus.quest_updated.connect(_refresh)
	EventBus.quest_completed.connect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_quest"):
		toggle_visibility()

func toggle_visibility() -> void:
	visible = not visible
	if visible:
		_refresh()
		# 打开面板时锁定玩家移动
		GameState.is_paused = true
	else:
		GameState.is_paused = false

func _refresh(_qid: String = "") -> void:
	if not visible:
		return
	_clear_container(active_container)
	_clear_container(completed_container)
	var has_any: bool = false
	for quest_id in DataManager.get_all_quests():
		var state_str: String = QuestManager.get_quest_state(quest_id)
		if state_str == "locked":
			continue
		var q: Dictionary = DataManager.get_quest(quest_id)
		var label: Label = Label.new()
		var text: String = "[%s] %s\n  %s" % [_state_display(state_str), q.get("name", quest_id), q.get("description", "")]
		# 追加目标进度
		for obj in q.get("objectives", []):
			var cur: int = QuestManager.get_objective_progress(quest_id, obj.get("id"))
			var req: int = obj.get("required", 1)
			text += "\n  · %s (%d/%d)" % [obj.get("description", obj.get("id")), cur, req]
		label.text = text
		if state_str == "completed":
			completed_container.add_child(label)
		else:
			active_container.add_child(label)
		has_any = true
	empty_label.visible = not has_any

func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()

func _state_display(state_str: String) -> String:
	match state_str:
		"available":
			return "可接取"
		"active":
			return "进行中"
		"ready_to_complete":
			return "可交付"
		"completed":
			return "已完成"
		_:
			return state_str
