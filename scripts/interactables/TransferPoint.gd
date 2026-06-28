##======================================================
## TransferPoint.gd - 场景传送点
## 挂载：Area2D（位于地图场景的 TransferPoints 节点下）
## 职责：玩家触碰时通过 SceneLoader 切换到目标场景，并发射 area_entered 信号推进任务
## 关联文档：02_TDD_TECHNICAL_DESIGN.md §4.4 / 05_SYSTEM_DESIGN.md §7
##======================================================
extends Area2D
class_name TransferPoint

@export var target_scene_id: String = ""
@export var target_spawn_id: String = "spawn_default"
@export var is_one_way: bool = false  # 单向传送（如冥墟古观进入后不可返回）

func _ready() -> void:
	# 碰撞层：interactable，监测 player
	collision_layer = 0
	collision_mask = 1  # layer 1 = player
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if target_scene_id == "":
		return
	# 单向传送点：触发后禁用
	if is_one_way:
		monitoring = false
	# 发射进入区域信号，推进 enter_area 类任务目标
	EventBus.area_entered.emit(target_scene_id)
	SceneLoader.change_scene(target_scene_id, target_spawn_id)
