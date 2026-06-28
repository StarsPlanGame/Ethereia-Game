##======================================================
## PlayerAnimation.gd - 玩家动画控制组件
## 挂载：Player.tscn 下的 Node
## 职责：根据朝向与移动状态播放程序化占位动画
##       （美术资源缺失时通过代码模拟呼吸/走路抖动）
##       美术资源接入后可扩展为调用 AnimationPlayer
## 关联文档：05_SYSTEM_DESIGN.md §3 玩家系统
##======================================================
extends Node
class_name PlayerAnimation

## 朝向枚举（与 PlayerController.Facing 保持一致）
enum Facing { LEFT, RIGHT, UP, DOWN }

# ======== 节点引用 ========
@onready var sprite: Sprite2D = get_node("../Sprite2D")

# ======== 动画状态 =====###
var _facing: int = Facing.DOWN
var _is_moving: bool = false
var _time: float = 0.0

# ======== 动画参数（占位用，接入美术后可移除）========
const IDLE_BREATH_SCALE: float = 0.02   # idle 呼吸缩放幅度
const IDLE_BREATH_SPEED: float = 2.0   # idle 呼吸频率
const WALK_BOB_AMOUNT: float = 1.5     # walk 上下抖动幅度（像素）
const WALK_BOB_SPEED: float = 10.0     # walk 抖动频率

# ======== 原始属性缓存（用于动画恢复）========
var _base_scale: Vector2 = Vector2.ONE
var _base_offset: Vector2 = Vector2.ZERO
var _initialized: bool = false

# ======== 生命周期 ========
func _ready() -> void:
	if sprite == null:
		return
	_base_scale = sprite.scale
	_base_offset = sprite.offset
	_initialized = true

func _process(delta: float) -> void:
	if not _initialized or sprite == null:
		return
	_time += delta
	_apply_facing()
	if _is_moving:
		_apply_walk_anim()
	else:
		_apply_idle_anim()

# ======== 公共接口 ========
## 更新动画状态（由 PlayerController 每帧调用）
func update(facing: int, is_moving: bool) -> void:
	_facing = facing
	_is_moving = is_moving

# ======== 内部实现 ========
func _apply_facing() -> void:
	match _facing:
		Facing.LEFT:
			sprite.flip_h = true
		Facing.RIGHT:
			sprite.flip_h = false
		# UP/DOWN 不翻转，靠 sprite 朝向区分（占位阶段共用同一纹理）
		_:
			pass

## idle 动画：轻微呼吸缩放
func _apply_idle_anim() -> void:
	var breath: float = sin(_time * IDLE_BREATH_SPEED) * IDLE_BREATH_SCALE
	sprite.scale = _base_scale + Vector2(0, breath)
	sprite.offset = _base_offset

## walk 动画：上下抖动 + 轻微缩放
func _apply_walk_anim() -> void:
	var bob: float = sin(_time * WALK_BOB_SPEED) * WALK_BOB_AMOUNT
	var sway: float = sin(_time * WALK_BOB_SPEED * 0.5) * 0.02
	sprite.scale = _base_scale + Vector2(sway, sway)
	sprite.offset = _base_offset + Vector2(0, bob)
