##======================================================
## NPC.gd - 非玩家角色
## 挂载：NPC.tscn 根节点（Area2D）
## 职责：承载 NPC 数据，与玩家互动时触发对话
## 关联文档：05_SYSTEM_DESIGN.md §9.2 / 08_DATA_SCHEMA.md §5
##======================================================
extends Area2D
class_name NPC

## NPC 数据 ID（对应 npcs.json 中的 id 字段）
@export var npc_id: String = ""
## 互动提示文本
@export var prompt_text: String = "按 E 对话"
## 朝向（用于精灵翻转）
@export var facing_left: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel

func _ready() -> void:
	collision_layer = 4   # layer 3 = npc
	collision_mask = 1    # layer 1 = player（用于检测玩家进入）
	# 从数据表加载 NPC 信息显示
	if npc_id != "":
		var data: Dictionary = DataManager.get_npc(npc_id)
		if not data.is_empty():
			name_label.text = data.get("name", npc_id)
			# 初始化关系值（仅首次）
			if RelationshipManager.get_relationship(npc_id) == 0:
				RelationshipManager.set_relationship(npc_id, data.get("initial_relationship", 0))
	# 朝向
	if sprite:
		sprite.flip_h = facing_left

## 玩家互动调用（实现 Interactable 接口约定）
func interact(_player: Node) -> void:
	if npc_id == "":
		push_warning("[NPC] npc_id 未配置: %s" % name)
		return
	DialogueManager.start_dialogue_with(npc_id)
