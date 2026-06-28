##======================================================
## InventoryPanel.gd - 背包面板 UI
## 挂载：InventoryPanel.tscn 根节点（Control）
## 职责：显示玩家持有的所有道具，按 I 切换显示，双击使用消耗品
## 关联文档：05_SYSTEM_DESIGN.md §14.4
##======================================================
extends Control
class_name InventoryPanel

@onready var grid: GridContainer = $Panel/Margin/VBox/Scroll/Grid
@onready var empty_label: Label = $Panel/Margin/VBox/EmptyLabel

## 单格预制
const ItemSlotScene := preload("res://scenes/ui/ItemSlot.tscn")

func _ready() -> void:
	visible = false
	EventBus.item_collected.connect(_on_inventory_changed)
	EventBus.item_removed.connect(_on_inventory_changed)
	EventBus.item_used.connect(_on_inventory_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		toggle_visibility()

func toggle_visibility() -> void:
	visible = not visible
	if visible:
		_refresh()
		GameState.is_paused = true
	else:
		GameState.is_paused = false

func _on_inventory_changed(_id: String, _amount: int) -> void:
	if visible:
		_refresh()

func _refresh() -> void:
	# 清空旧条目
	for child in grid.get_children():
		child.queue_free()
	var items: Dictionary = InventorySystem.get_all_items()
	var has_any: bool = false
	for item_id in items:
		var slot: Control = ItemSlotScene.instantiate()
		var item_data: Dictionary = DataManager.get_item(item_id)
		var name: String = item_data.get("name", item_id)
		var type: String = item_data.get("type", "item")
		var desc: String = item_data.get("description", "")
		slot.setup(item_id, name, items[item_id], type, desc)
		grid.add_child(slot)
		has_any = true
	empty_label.visible = not has_any
