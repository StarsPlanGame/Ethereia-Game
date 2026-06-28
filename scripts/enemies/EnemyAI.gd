##======================================================
## EnemyAI.gd - 敌人 AI 状态机
## 挂载：EnemyBase.tscn 上的 Node 子节点（AI）
## 职责：根据状态机驱动敌人行为（待机/巡逻/追击/攻击）
## 关联文档：01_GDD_GAME_DESIGN.md §3.4 敌人 AI / 05_SYSTEM_DESIGN.md §7.2
##======================================================
extends Node
class_name EnemyAI

# ======== 状态枚举 ========
enum State {
	IDLE,       # 待机
	PATROL,     # 巡逻
	CHASE,      # 追击
	ATTACK,     # 攻击
	RETURN      # 返回出生点
}

# ======== 配置参数 ========
@export var initial_state: int = State.PATROL
@export var patrol_radius: float = 80.0       # 巡逻半径
@export var chase_range: float = 200.0        # 追击触发范围
@export var attack_range: float = 30.0        # 攻击范围
@export var attack_cooldown: float = 1.5      # 攻击间隔
@export var return_range: float = 400.0       # 超出此距离返回出生点

# ======== 运行时状态 ========
var enemy: EnemyBase = null
var current_state: int = State.IDLE
var home_position: Vector2 = Vector2.ZERO
var _attack_timer: float = 0.0
var _idle_timer: float = 0.0
var _idle_duration: float = 1.0
var _patrol_target: Vector2 = Vector2.ZERO

# ======== 初始化 ========
func initialize(host: EnemyBase) -> void:
	enemy = host
	current_state = initial_state
	home_position = enemy.global_position
	_pick_new_patrol_target()

# ======== 主更新 ========
func update(delta: float) -> void:
	if enemy == null or enemy.is_dead:
		return
	if _attack_timer > 0:
		_attack_timer -= delta
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.RETURN:
			_process_return(delta)

# ======== 状态处理 ========
func _process_idle(delta: float) -> void:
	enemy.velocity = Vector2.ZERO
	_idle_timer -= delta
	if _idle_timer <= 0:
		current_state = State.PATROL
		_pick_new_patrol_target()
	_check_player_detection()

func _process_patrol(delta: float) -> void:
	# 朝巡逻点移动
	var to_target: Vector2 = _patrol_target - enemy.global_position
	var dist: float = to_target.length()
	if dist < 10.0:
		# 到达巡逻点，转待机
		current_state = State.IDLE
		_idle_timer = _idle_duration
		_idle_duration = randf_range(0.8, 2.0)
		enemy.velocity = Vector2.ZERO
		return
	enemy.velocity = to_target.normalized() * enemy.move_speed * 0.5  # 巡逻速度减半
	_update_facing(enemy.velocity)
	_check_player_detection()

func _process_chase(delta: float) -> void:
	var player: Node2D = enemy.get_player_in_range()
	if player == null:
		# 丢失目标，返回
		current_state = State.RETURN
		return
	# 超出追击范围太远，返回
	if enemy.global_position.distance_to(home_position) > return_range:
		current_state = State.RETURN
		return
	# 进入攻击范围，转攻击
	var dist_to_player: float = enemy.global_position.distance_to(player.global_position)
	if dist_to_player <= attack_range:
		current_state = State.ATTACK
		enemy.velocity = Vector2.ZERO
		return
	# 朝玩家移动
	var dir: Vector2 = (player.global_position - enemy.global_position).normalized()
	enemy.velocity = dir * enemy.move_speed
	_update_facing(dir)

func _process_attack(delta: float) -> void:
	enemy.velocity = Vector2.ZERO
	var player: Node2D = enemy.get_player_in_range()
	if player == null:
		current_state = State.PATROL
		return
	var dist: float = enemy.global_position.distance_to(player.global_position)
	if dist > attack_range * 1.2:
		current_state = State.CHASE
		return
	# 攻击冷却结束，发起攻击
	if _attack_timer <= 0:
		_attack_timer = attack_cooldown
		enemy.enable_hitbox(0.3)

func _process_return(delta: float) -> void:
	var to_home: Vector2 = home_position - enemy.global_position
	var dist: float = to_home.length()
	if dist < 10.0:
		current_state = State.IDLE
		_idle_timer = _idle_duration
		enemy.velocity = Vector2.ZERO
		return
	enemy.velocity = to_home.normalized() * enemy.move_speed
	_update_facing(enemy.velocity)

# ======== 辅助 ========
func _check_player_detection() -> void:
	var player: Node2D = enemy.get_player_in_range()
	if player != null:
		var dist: float = enemy.global_position.distance_to(player.global_position)
		if dist <= chase_range:
			current_state = State.CHASE

func _pick_new_patrol_target() -> void:
	var angle: float = randf() * TAU
	var radius: float = randf() * patrol_radius
	_patrol_target = home_position + Vector2(cos(angle), sin(angle)) * radius

func _update_facing(velocity: Vector2) -> void:
	if enemy.sprite == null:
		return
	if velocity.x < 0:
		enemy.sprite.flip_h = true
	elif velocity.x > 0:
		enemy.sprite.flip_h = false
