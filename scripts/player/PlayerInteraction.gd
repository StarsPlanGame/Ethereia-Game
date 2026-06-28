##======================================================
## PlayerInteraction.gd - 玩家交互组件
## 挂载：Player.tscn 上的 Node 子节点（Interaction）
## 职责：检测可交互对象、处理 interact 输入、显示提示 UI
## 关联文档：01_GDD_GAME_DESIGN.md §2.2 / 05_SYSTEM_DESIGN.md §6
##======================================================
extends Node
class_name PlayerInteraction

@onready var parent: CharacterBody2D = get_parent()
@onready var detection_area: Area2D = parent.get_node_or_null("InteractionArea")

# ======== 当前可交互对象 ========
var _current_interactable: Node = null
var _available_interactables: Array[Node] = []

# ======== 生命周期 ========
func _ready() -> void:
	if detection_area != null:
		detection_area.area_entered.connect(_on_area_entered)
		detection_area.area_exited.connect(_on_area_exited)
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if GameState.is_paused or GameState.is_in_dialogue:
		return
	if Input.is_action_just_pressed("interact"):
		_try_interact()

# ======== 检测 ========
func _on_area_entered(area: Area2D) -> void:
	if area.has_method("interact"):
		_available_interactables.append(area)
		_select_nearest()

func _on_area_exited(area: Area2D) -> void:
	_available_interactables.erase(area)
	if area == _current_interactable:
		_select_nearest()

func _on_body_entered(body: Node) -> void:
	if body.has_method("interact"):
		_available_interactables.append(body)
		_select_nearest()

func _on_body_exited(body: Node) -> void:
	_available_interactables.erase(body)
	if body == _current_interactable:
		_select_nearest()

func _select_nearest() -> void:
	var new_target: Node = null
	if not _available_interactables.is_empty():
		# 简化：取第一个；后续可改为按距离排序
		new_target = _available_interactables[0]
	if new_target == _current_interactable:
		return
	# 隐藏旧提示
	if _current_interactable != null:
		EventBus.interaction_prompt_hidden.emit()
	_current_interactable = new_target
	# 显示新提示
	if _current_interactable != null:
		var prompt_text: String = "按 E 互动"
		if _current_interactable.get("prompt_text") != null:
			prompt_text = _current_interactable.prompt_text
		EventBus.interaction_prompt_shown.emit(prompt_text)

func _try_interact() -> void:
	if _current_interactable == null:
		return
	if not _current_interactable.has_method("interact"):
		return
	_current_interactable.interact(parent)

func clear_targets() -> void:
	_available_interactables.clear()
	if _current_interactable != null:
		EventBus.interaction_prompt_hidden.emit()
	_current_interactable = null
