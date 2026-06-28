##======================================================
## MainMenu.gd - 主菜单
## 挂载：MainMenu.tscn 根节点（Control）
## 职责：提供新游戏/继续/退出入口，启动游戏主场景
## 关联文档：04_MVP_ROADMAP.md §9 阶段7 / 05_SYSTEM_DESIGN.md §14.6
##======================================================
extends Control
class_name MainMenu

const GAME_SCENE_PATH := "res://scenes/core/Main.tscn"

@onready var continue_button: Button = $Panel/Margin/VBox/ContinueButton
@onready var notification_label: Label = $Panel/Margin/VBox/NotificationLabel

func _ready() -> void:
	# 无存档时禁用「继续游戏」
	if not SaveManager.has_save(1):
		continue_button.disabled = true
		continue_button.text = "继续游戏（无存档）"
	notification_label.visible = false

## 新游戏：删除旧存档后进入游戏
func _on_new_game_pressed() -> void:
	SaveManager.delete_save(1)
	# 重置运行时状态，避免上一局残留
	_reset_runtime_state()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

## 继续游戏：直接进入主场景，GameRoot 会自动读档
func _on_continue_pressed() -> void:
	if not SaveManager.has_save(1):
		_show_notification("无可用存档")
		return
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

## 退出游戏
func _on_quit_pressed() -> void:
	get_tree().quit()

## 重置运行时单例状态（新游戏时清空上一局残留）
func _reset_runtime_state() -> void:
	GameState.story_flags.clear()
	GameState.current_scene_id = "qing_shi_town"
	GameState.current_spawn_id = "spawn_default"
	SaveManager.reset_gathered()
	SaveManager.reset_story_triggered()

func _show_notification(text: String) -> void:
	notification_label.text = text
	notification_label.visible = true
	await get_tree().create_timer(2.0).timeout
	notification_label.visible = false
