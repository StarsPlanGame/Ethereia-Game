##======================================================
## EmptyMap.gd - 占位地图基类
## 挂载：临时占位地图（待美术 TileSet 接入后替换为正式版本）
## 职责：仅作为场景可加载的最小骨架，验证 SceneLoader 工作正常
##======================================================
extends Node2D
class_name EmptyMap

@export var map_name: String = "未命名场景"

func _ready() -> void:
	print("[Map] 进入场景: %s" % map_name)
