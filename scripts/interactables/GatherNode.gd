##======================================================
## GatherNode.gd - 采集节点
## 挂载：Area2D（位于地图场景的可交互物节点下）
## 职责：玩家互动采集，给 InventorySystem 增加道具，标记已采集防重复
## 关联文档：02_TDD_TECHNICAL_DESIGN.md §4.5 / 05_SYSTEM_DESIGN.md §8
##======================================================
extends Area2D
class_name GatherNode

@export var item_id: String = ""           # 采集获得的道具 ID
@export var amount: int = 1                 # 单次采集数量
@export var prompt_text: String = "按 E 采集"
@export var gather_node_id: String = ""     # 全局唯一 ID（存档用，建议格式：场景名_序号）

func _ready() -> void:
	collision_layer = 16  # layer 5 = interactable
	collision_mask = 1    # layer 1 = player
	# 已采集则隐藏
	if gather_node_id != "" and SaveManager.is_gathered(gather_node_id):
		visible = false
		monitoring = false

func interact(_player: Node) -> void:
	if item_id == "":
		push_warning("[GatherNode] item_id 未配置: %s" % name)
		return
	if gather_node_id != "" and SaveManager.is_gathered(gather_node_id):
		return
	InventorySystem.add_item(item_id, amount)
	EventBus.notification_shown.emit("获得 %s × %d" % [DataManager.get_item(item_id).get("name", item_id), amount])
	if gather_node_id != "":
		SaveManager.mark_gathered(gather_node_id)
	visible = false
	monitoring = false
