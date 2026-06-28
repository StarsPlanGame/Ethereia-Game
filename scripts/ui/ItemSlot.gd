##======================================================
## ItemSlot.gd - 背包单格
## 挂载：ItemSlot.tscn 根节点（Panel）
## 职责：显示单个道具的图标、名称、数量、描述悬浮提示；双击使用消耗品
##======================================================
extends Panel
class_name ItemSlot

var item_id: String = ""

@onready var name_label: Label = $VBox/NameLabel
@onready var count_label: Label = $VBox/CountLabel
@onready var type_label: Label = $VBox/TypeLabel
@onready var desc_label: Label = $VBox/DescLabel

func setup(id: String, display_name: String, count: int, type: String, desc: String) -> void:
	item_id = id
	if not is_node_ready():
		await ready
	name_label.text = display_name
	count_label.text = "× %d" % count
	type_label.text = _type_display(type)
	desc_label.text = desc

func _type_display(type_str: String) -> String:
	match type_str:
		"consumable":
			return "消耗品"
		"material":
			return "材料"
		"equipment":
			return "装备"
		"quest":
			return "任务物品"
		"currency":
			return "货币"
		_:
			return type_str

func _gui_input(event: InputEvent) -> void:
	# 双击使用消耗品（通知由 InventorySystem.use_item 统一发射）
	if event is InputEventMouseButton and event.pressed and event.double_click:
		InventorySystem.use_item(item_id)
