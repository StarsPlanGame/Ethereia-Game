##======================================================
## MapBase.gd - 地图场景基类
## 挂载：所有正式地图场景的根节点（Node2D）
## 职责：
##   1. 提供玩家出生点查找接口
##   2. 场景边界墙壁碰撞（防止玩家走出地图）
##   3. 地图通用初始化流程
## 替换：原 EmptyMap.gd（仅占位骨架）
## 关联文档：02_TDD_TECHNICAL_DESIGN.md §3.1
##======================================================
extends Node2D
class_name MapBase

## 地图名称（用于日志和 UI 显示）
@export var map_name: String = "未命名场景"
## 地图宽度（像素，用于生成边界墙）
@export var map_width: float = 1280.0
## 地图高度（像素，用于生成边界墙）
@export var map_height: float = 720.0
## 是否自动生成边界墙
@export var auto_bounds: bool = true

func _ready() -> void:
	print("[Map] 进入场景: %s" % map_name)
	if auto_bounds:
		_setup_boundary_walls()

## 查找玩家出生点
## 返回全局坐标，找不到时返回地图中心
func get_spawn_position(spawn_id: String = "spawn_default") -> Vector2:
	var spawn_points: Node = get_node_or_null("SpawnPoints")
	if spawn_points == null:
		return Vector2(map_width / 2.0, map_height / 2.0)
	var marker: Marker2D = spawn_points.get_node_or_null(spawn_id)
	if marker == null:
		# 回退到默认出生点
		marker = spawn_points.get_node_or_null("spawn_default")
	if marker == null:
		return Vector2(map_width / 2.0, map_height / 2.0)
	return marker.global_position

## 创建场景边界墙壁（防止玩家走出地图）
func _setup_boundary_walls() -> void:
	# 如果已存在 BoundaryWalls 节点，不重复创建
	if has_node("BoundaryWalls"):
		return
	var walls: Node2D = Node2D.new()
	walls.name = "BoundaryWalls"
	add_child(walls)
	walls.owner = self
	# 四面墙：上、下、左、右
	_create_wall(walls, "Wall_Top", Vector2(map_width / 2.0, -20), Vector2(map_width + 40, 40))
	_create_wall(walls, "Wall_Bottom", Vector2(map_width / 2.0, map_height + 20), Vector2(map_width + 40, 40))
	_create_wall(walls, "Wall_Left", Vector2(-20, map_height / 2.0), Vector2(40, map_height + 40))
	_create_wall(walls, "Wall_Right", Vector2(map_width + 20, map_height / 2.0), Vector2(40, map_height + 40))

## 创建单个墙壁（StaticBody2D + RectangleShape2D）
func _create_wall(parent: Node, wall_name: String, pos: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = wall_name
	body.position = pos
	# 碰撞层 = layer 4（墙壁）
	body.collision_layer = 8
	body.collision_mask = 0
	parent.add_child(body)
	body.owner = self
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	shape.owner = self
	# 可视化占位（半透明灰色，方便调试）
	var vis: ColorRect = ColorRect.new()
	vis.color = Color(0.5, 0.5, 0.5, 0.3)
	vis.size = size
	vis.position = -size / 2.0
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(vis)
	vis.owner = self
