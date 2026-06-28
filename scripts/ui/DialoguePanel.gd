##======================================================
## DialoguePanel.gd - 对话框 UI
## 挂载：DialoguePanel.tscn 根节点（Control / Panel）
## 职责：监听 DialogueManager 信号，显示对话内容与选项，处理玩家输入
## 关联文档：05_SYSTEM_DESIGN.md §14.3
##======================================================
extends Control
class_name DialoguePanel

@onready var speaker_label: Label = $Panel/Margin/VBox/SpeakerLabel
@onready var text_label: RichTextLabel = $Panel/Margin/VBox/TextLabel
@onready var choices_container: VBoxContainer = $Panel/Margin/VBox/ChoicesContainer
@onready var advance_hint: Label = $Panel/Margin/VBox/AdvanceHint

## 选项按钮预制
const ChoiceButtonScene := preload("res://scenes/ui/ChoiceButton.tscn")

## 当前是否显示选项
var _has_choices: bool = false

func _ready() -> void:
	# 连接 DialogueManager 信号
	DialogueManager.dialogue_node_changed.connect(_on_node_changed)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	# 默认隐藏
	visible = false

func _process(_delta: float) -> void:
	if not visible:
		return
	# 无选项时按 E/空格推进
	if not _has_choices:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
			DialogueManager.advance()

## 显示新节点内容
func _on_node_changed(speaker: String, text: String, choices: Array) -> void:
	visible = true
	speaker_label.text = speaker
	text_label.text = text
	# 清空旧选项
	for child in choices_container.get_children():
		child.queue_free()
	# 显示新选项
	_has_choices = not choices.is_empty()
	advance_hint.visible = not _has_choices
	if _has_choices:
		for i in range(choices.size()):
			var btn: Button = ChoiceButtonScene.instantiate()
			btn.text = "%d. %s" % [i + 1, choices[i].get("text", "选项")]
			btn.pressed.connect(_on_choice_pressed.bind(i))
			choices_container.add_child(btn)
	# 焦点第一个选项方便键盘选择
	if _has_choices and choices_container.get_child_count() > 0:
		choices_container.get_child(0).grab_focus()

func _on_dialogue_ended(_dialogue_id: String) -> void:
	visible = false
	speaker_label.text = ""
	text_label.text = ""
	for child in choices_container.get_children():
		child.queue_free()
	_has_choices = false

func _on_choice_pressed(index: int) -> void:
	DialogueManager.choose_option(index)

## 处理数字键 1-4 快速选择选项
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _has_choices:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_str: String = String.chr(event.physical_keycode)
		if key_str.is_valid_int():
			var idx: int = key_str.to_int() - 1
			if idx >= 0 and idx < choices_container.get_child_count():
				DialogueManager.choose_option(idx)
