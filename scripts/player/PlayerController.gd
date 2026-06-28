##======================================================
## PlayerController.gd - 玩家控制与移动
## 挂载：Player.tscn 根节点（CharacterBody2D）
## 职责：处理输入、移动、动画状态切换、外部锁定状态
## 关联文档：01_GDD_GAME_DESIGN.md §2 玩家操作 / 05_SYSTEM_DESIGN.md §3
##======================================================
extends CharacterBody2D
class_name PlayerController

# ======== 组件引用（@onready 拖拽或自动查找）========
@onready var stats: PlayerStats = $Stats
@onready var combat: Node = $Combat
@onready var interaction: Node = $Interaction
@onready var cultivation: Node = $Cultivation
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

# ======== 移动锁定（引用计数，多个系统可同时锁）========
var _lock_count: int = 0
var _move_locks: Dictionary = {}  # key: 锁定来源标识，便于调试

# ======== 朝向 ========
enum Facing { LEFT, RIGHT, UP, DOWN }
var facing: int = Facing.DOWN

# ======== 生命周期 ========
func _ready() -> void:
	add_to_group("player")
	# 监听场景切换完成信号，由 SceneLoader 接管玩家位置
	EventBus.scene_changed.connect(_on_scene_changed)

func _physics_process(_delta: float) -> void:
	if is_locked():
		velocity = Vector2.ZERO
		return
	var input_vec: Vector2 = _get_input_vector()
	if input_vec != Vector2.ZERO:
		_update_facing(input_vec)
		velocity = input_vec * stats.move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_update_animation(input_vec)

# ======== 输入处理 ========
func _get_input_vector() -> Vector2:
	var v := Vector2.ZERO
	v.x = Input.get_axis("move_left", "move_right")
	v.y = Input.get_axis("move_up", "move_down")
	if v != Vector2.ZERO:
		v = v.normalized()
	return v

func _update_facing(v: Vector2) -> void:
	if abs(v.x) > abs(v.y):
		facing = Facing.RIGHT if v.x > 0 else Facing.LEFT
	else:
		facing = Facing.DOWN if v.y > 0 else Facing.UP

func _update_animation(input_vec: Vector2) -> void:
	# TODO: 接入美术资源后切换动画
	# 简化：根据朝向翻转 sprite
	if facing == Facing.LEFT:
		sprite.flip_h = true
	elif facing == Facing.RIGHT:
		sprite.flip_h = false

# ======== 锁定移动接口（外部系统调用）========
## 请求锁定移动。source 是来源标识（如 "dialogue" / "menu" / "battle"）
func lock_movement(source: String) -> void:
	if _move_locks.has(source):
		return
	_move_locks[source] = true
	_lock_count += 1

## 解除锁定。会自动减引用计数
func unlock_movement(source: String) -> void:
	if not _move_locks.has(source):
		return
	_move_locks.erase(source)
	_lock_count -= 1

func is_locked() -> bool:
	return _lock_count > 0 or GameState.is_in_dialogue or GameState.is_paused

# ======== 信号回调 ========
func _on_scene_changed(_scene_id: String) -> void:
	# 场景切换后重置锁定（避免遗留状态）
	_move_locks.clear()
	_lock_count = 0

# ======== 存档接口 ========
func get_save_data() -> Dictionary:
	var data := {
		"position_x": global_position.x,
		"position_y": global_position.y,
		"facing": facing,
		"stats": stats.get_save_data(),
	}
	if cultivation != null and cultivation.has_method("get_save_data"):
		data["cultivation"] = cultivation.get_save_data()
	return data

func load_save_data(data: Dictionary) -> void:
	global_position = Vector2(data.get("position_x", 0), data.get("position_y", 0))
	facing = data.get("facing", Facing.DOWN)
	if data.has("stats"):
		stats.load_save_data(data["stats"])
	if data.has("cultivation") and cultivation != null and cultivation.has_method("load_save_data"):
		cultivation.load_save_data(data["cultivation"])
