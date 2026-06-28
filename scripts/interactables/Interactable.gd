##======================================================
## Interactable.gd - 可交互接口（GDScript 鸭子类型约定）
## 挂载：任何可交互节点（Area2D / StaticBody2D / Node2D）
## 职责：提供统一的 interact() 接口与提示文本
## 关联文档：02_TDD_TECHNICAL_DESIGN.md §4.3 / 05_SYSTEM_DESIGN.md §6
##
## 实现约定：所有可交互节点必须实现：
##   func interact(player: Node) -> void
## 可选挂载的导出变量：
##   prompt_text: String  - 显示给玩家的互动提示
##======================================================
extends Node
class_name Interactable

## 玩家进入范围时显示的提示文本
@export var prompt_text: String = "按 E 互动"

## 是否当前可交互（用于剧情锁定的可交互物）
@export var is_enabled: bool = true

## 子类应 override 此方法
func interact(_player: Node) -> void:
	push_warning("[Interactable] 子类未实现 interact(): %s" % name)
