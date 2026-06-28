##======================================================
## PauseMenu.gd - 暂停菜单
## 挂载：PauseMenu.tscn 根节点（Control）
## 职责：按 ESC 切换显示，提供继续/保存/返回主菜单入口
## 关联文档：04_MVP_ROADMAP.md §9 阶段7 / 05_SYSTEM_DESIGN.md §14.7
##======================================================
extends Control
class_name PauseMenu

const MAIN_MENU_PATH := "res://scenes/ui/MainMenu.tscn"

@onready var resume_button: Button = $Panel/Margin/VBox/ResumeButton
@onready var save_button: Button = $Panel/Margin/VBox/SaveButton
@onready var notification_label: Label = $Panel/Margin/VBox/NotificationLabel

func _ready() -> void:
	visible = false
	notification_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_visibility()

## 切换暂停菜单显示
func toggle_visibility() -> void:
	# 对话中不允许暂停
	if GameState.is_in_dialogue:
		return
	visible = not visible
	if visible:
		GameState.is_paused = true
		# 关闭其他面板避免冲突
		_close_other_panels()
	else:
		GameState.is_paused = false

## 继续游戏
func _on_resume_pressed() -> void:
	visible = false
	GameState.is_paused = false

## 保存游戏到槽位 1
func _on_save_pressed() -> void:
	SaveManager.save_game(1)
	_show_notification("已保存")

## 返回主菜单（先保存当前进度）
func _on_main_menu_pressed() -> void:
	SaveManager.save_game(1)
	GameState.is_paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)

## 退出游戏
func _on_quit_pressed() -> void:
	SaveManager.save_game(1)
	get_tree().quit()

## 关闭同层级其他面板
func _close_other_panels() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == self:
			continue
		if child is Control and child.has_method("toggle_visibility"):
			# 同类面板（QuestPanel/InventoryPanel/CultivationPanel）若打开则关闭
			if child.visible:
				child.toggle_visibility()
		elif child is Control and "visible" in child and child.visible:
			# DialoguePanel 等不通过 toggle_visibility 的，跳过避免误关
			pass

func _show_notification(text: String) -> void:
	notification_label.text = text
	notification_label.visible = true
	await get_tree().create_timer(1.5).timeout
	notification_label.visible = false
