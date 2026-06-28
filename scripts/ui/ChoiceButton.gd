##======================================================
## ChoiceButton.gd - 对话选项按钮
## 挂载：ChoiceButton.tscn 根节点（Button）
## 职责：作为对话选项的视觉与点击载体，配合 DialoguePanel 使用
##======================================================
extends Button
class_name ChoiceButton

func _ready() -> void:
	# 鼠标悬停时自动聚焦
	mouse_entered.connect(grab_focus)
