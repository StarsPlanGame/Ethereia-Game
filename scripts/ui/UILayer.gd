##======================================================
## UILayer.gd - UI 层管理
## 挂载：GameRoot.tscn 中的 UILayer（CanvasLayer）
## 职责：管理提示文本、通知、HP/MP HUD、对话框等 UI 切换
## 关联文档：05_SYSTEM_DESIGN.md §14 UI 系统
##======================================================
extends CanvasLayer
class_name UILayer

@onready var prompt_label: Label = $PromptLabel
@onready var notification_label: Label = $NotificationLabel
@onready var hp_bar: ProgressBar = $HUD/HPBar
@onready var mp_bar: ProgressBar = $HUD/MPBar
@onready var realm_label: Label = $HUD/RealmLabel

func _ready() -> void:
	EventBus.interaction_prompt_shown.connect(_on_prompt_shown)
	EventBus.interaction_prompt_hidden.connect(_on_prompt_hidden)
	EventBus.notification_shown.connect(_on_notification_shown)
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.player_mp_changed.connect(_on_mp_changed)
	EventBus.cultivation_changed.connect(_on_cultivation_changed)
	EventBus.breakthrough_success.connect(_on_breakthrough_success)
	# 初始化 UI 隐藏
	if prompt_label: prompt_label.visible = false
	if notification_label: notification_label.visible = false

func _on_prompt_shown(text: String) -> void:
	if prompt_label == null:
		return
	prompt_label.text = text
	prompt_label.visible = true

func _on_prompt_hidden() -> void:
	if prompt_label == null:
		return
	prompt_label.visible = false

func _on_notification_shown(text: String) -> void:
	if notification_label == null:
		return
	notification_label.text = text
	notification_label.visible = true
	# 2 秒后自动隐藏
	await get_tree().create_timer(2.0).timeout
	notification_label.visible = false

func _on_hp_changed(cur: int, max_v: int) -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = max_v
	hp_bar.value = cur

func _on_mp_changed(cur: int, max_v: int) -> void:
	if mp_bar == null:
		return
	mp_bar.max_value = max_v
	mp_bar.value = cur

func _on_cultivation_changed(realm: String, level: int, qi: int) -> void:
	if realm_label == null:
		return
	realm_label.text = "%s %d层  灵气: %d/100" % [realm, level, qi]

func _on_breakthrough_success(realm: String, level: int) -> void:
	_on_notification_shown("突破成功！进入 %s %d层" % [realm, level])
