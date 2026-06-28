##======================================================
## CultivationPanel.gd - 修炼面板 UI
## 挂载：CultivationPanel.tscn 根节点（Control）
## 职责：显示境界/灵气进度，提供打坐与突破操作，按 C 切换显示
## 关联文档：01_GDD_GAME_DESIGN.md §4 修炼系统 / 05_SYSTEM_DESIGN.md §14.5
##======================================================
extends Control
class_name CultivationPanel

@onready var realm_label: Label = $Panel/Margin/VBox/RealmLabel
@onready var qi_bar: ProgressBar = $Panel/Margin/VBox/QiBar
@onready var qi_label: Label = $Panel/Margin/VBox/QiLabel
@onready var meditate_button: Button = $Panel/Margin/VBox/MeditateButton
@onready var breakthrough_button: Button = $Panel/Margin/VBox/BreakthroughButton
@onready var hint_label: Label = $Panel/Margin/VBox/HintLabel

# 玩家修炼组件引用（懒加载）
var _cultivation: Node = null

func _ready() -> void:
	visible = false
	# 监听修炼事件实时刷新
	EventBus.cultivation_changed.connect(_on_cultivation_changed)
	EventBus.breakthrough_success.connect(_on_breakthrough_success)
	EventBus.breakthrough_failed.connect(_on_breakthrough_failed)
	EventBus.story_flag_changed.connect(_on_story_flag_changed)
	meditate_button.pressed.connect(_on_meditate_pressed)
	breakthrough_button.pressed.connect(_on_breakthrough_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_cultivation"):
		toggle_visibility()

## 获取玩家修炼组件（缓存）
func _get_cultivation() -> Node:
	if _cultivation != null and is_instance_valid(_cultivation):
		return _cultivation
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	_cultivation = player.get_node_or_null("Cultivation")
	return _cultivation

func toggle_visibility() -> void:
	visible = not visible
	if visible:
		_refresh()
		GameState.is_paused = true
	else:
		GameState.is_paused = false

## 刷新面板显示
func _refresh() -> void:
	var cult: Node = _get_cultivation()
	if cult == null:
		hint_label.text = "修炼系统未就绪"
		hint_label.visible = true
		return
	var realm: String = cult.REALM_NAMES.get(cult.realm, "未知")
	var level: int = cult.realm_level
	var qi: int = cult.spirit_qi
	var qi_max: int = cult.spirit_qi_max
	realm_label.text = "境界：%s %d层" % [realm, level]
	qi_bar.max_value = qi_max
	qi_bar.value = qi
	qi_label.text = "灵气：%d / %d" % [qi, qi_max]
	# 冥天玉未获得时提示
	if not cult.has_nether_jade:
		hint_label.text = "尚未获得冥天玉，无法修炼"
		hint_label.visible = true
		meditate_button.disabled = true
		breakthrough_button.disabled = true
		return
	hint_label.visible = false
	# 打坐按钮状态
	if cult.is_meditating:
		meditate_button.text = "停止打坐"
	else:
		meditate_button.text = "开始打坐"
	meditate_button.disabled = false
	# 突破按钮状态
	breakthrough_button.disabled = not cult.can_breakthrough()

## 打坐按钮回调
func _on_meditate_pressed() -> void:
	var cult: Node = _get_cultivation()
	if cult == null:
		return
	if cult.is_meditating:
		cult.stop_meditation()
	else:
		cult.start_meditation()
	_refresh()

## 突破按钮回调
func _on_breakthrough_pressed() -> void:
	var cult: Node = _get_cultivation()
	if cult == null:
		return
	cult.do_breakthrough()
	_refresh()

## 修炼状态变化回调
func _on_cultivation_changed(_realm: String, _level: int, _qi: int) -> void:
	if visible:
		_refresh()

func _on_breakthrough_success(_realm: String, _level: int) -> void:
	_refresh()

func _on_breakthrough_failed(_realm: String, _level: int) -> void:
	EventBus.notification_shown.emit("突破条件不足")

func _on_story_flag_changed(key: String, _value) -> void:
	# 冥天玉状态变化时刷新
	if key == "has_nether_jade" and visible:
		_refresh()
