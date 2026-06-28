##======================================================
## PlayerCombat.gd - 玩家战斗组件
## 挂载：Player.tscn 上的 Node 子节点（Combat）
## 职责：处理攻击输入、HitBox 朝向调整、伤害结算
## 关联文档：01_GDD_GAME_DESIGN.md §3 战斗系统 / 05_SYSTEM_DESIGN.md §5
##======================================================
extends Node
class_name PlayerCombat

@onready var parent: CharacterBody2D = get_parent()
@onready var stats: PlayerStats = parent.get_node("Stats")
@onready var hitbox: Area2D = parent.get_node_or_null("HitBox")
@onready var hurtbox: Area2D = parent.get_node_or_null("HurtBox")
@onready var hitbox_shape: CollisionShape2D = hitbox.get_node_or_null("HitBoxShape") if hitbox != null else null

# ======== 战斗状态 ========
var is_attacking: bool = false
var attack_combo_index: int = 0
var attack_cooldown: float = 0.0
## 本次攻击已经命中过的敌人（防止单次攻击多次伤害）
var _hit_targets: Array = []

# ======== 攻击参数 ========
const ATTACK_DURATION: float = 0.25  # 攻击判定持续时间
const ATTACK_COOLDOWN: float = 0.4   # 攻击间隔
const HITBOX_OFFSET: float = 30.0    # HitBox 距离玩家中心的偏移

# ======== 灵气弹 ========
const SPIRIT_BULLET_SCENE: PackedScene = preload("res://scenes/player/SpiritBullet.tscn")
const SPIRIT_BULLET_SPAWN_OFFSET: float = 20.0  # 投射物出生点距玩家中心
var skill_cooldown: float = 0.0

# ======== 生命周期 ========
func _ready() -> void:
	if hurtbox != null:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if hitbox != null:
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func _process(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if skill_cooldown > 0:
		skill_cooldown -= delta
	if GameState.is_paused or GameState.is_in_dialogue:
		return
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_perform_attack()
	if Input.is_action_just_pressed("skill_1"):
		_cast_spirit_bullet()

# ======== 攻击 ========
func _perform_attack() -> void:
	if attack_cooldown > 0:
		return
	is_attacking = true
	attack_cooldown = ATTACK_COOLDOWN
	_hit_targets.clear()
	# 根据朝向调整 HitBox 位置
	_update_hitbox_position()
	# 启用 HitBox 监测
	if hitbox != null:
		hitbox.monitoring = true
	# 攻击持续时间内保持判定
	await get_tree().create_timer(ATTACK_DURATION).timeout
	if hitbox != null:
		hitbox.monitoring = false
	is_attacking = false

## 根据玩家朝向调整 HitBox 形状位置
func _update_hitbox_position() -> void:
	if hitbox_shape == null:
		return
	match parent.facing:
		PlayerController.Facing.RIGHT:
			hitbox_shape.position = Vector2(HITBOX_OFFSET, 0)
		PlayerController.Facing.LEFT:
			hitbox_shape.position = Vector2(-HITBOX_OFFSET, 0)
		PlayerController.Facing.DOWN:
			hitbox_shape.position = Vector2(0, HITBOX_OFFSET)
		PlayerController.Facing.UP:
			hitbox_shape.position = Vector2(0, -HITBOX_OFFSET)

## 计算伤害：max(1, atk + skill_dmg - def)
func calculate_damage(target_defense: int, skill_damage: int = 0) -> int:
	return max(1, stats.attack + skill_damage - target_defense)

# ======== HitBox 命中敌人 ========
func _on_hitbox_area_entered(area: Area2D) -> void:
	# 命中敌人的 HurtBox（layer 7 = enemy_hurtbox）
	if not area.is_in_group("enemy_hurtbox"):
		return
	# 防止同一攻击多次命中同一敌人
	if area in _hit_targets:
		return
	_hit_targets.append(area)
	# 取敌人节点（HurtBox 的父节点）
	var enemy: Node = area.get_parent()
	if enemy == null or not enemy.has_method("take_damage"):
		return
	var dmg: int = calculate_damage(enemy.defense if "defense" in enemy else 0)
	enemy.take_damage(dmg)

# ======== 受击 ========
func _on_hurtbox_area_entered(area: Area2D) -> void:
	# 命中本玩家的 area 应在 enemy_hitbox 层（layer 9）
	if not area.is_in_group("enemy_hitbox"):
		return
	# 从 enemy_hitbox 节点向上找到敌人节点，取其攻击力
	var enemy: Node = area.get_parent()
	var incoming_dmg: int = 10
	if enemy != null and "attack" in enemy:
		incoming_dmg = enemy.attack
	stats.take_damage(incoming_dmg)

# ======== 技能 ========
## 发射灵气弹（按 K 键）
func _cast_spirit_bullet() -> void:
	# 检查技能是否已解锁
	if not GameState.has_story_flag("skill_unlocked_skill_spirit_bullet"):
		return
	if skill_cooldown > 0:
		return
	var skill_data: Dictionary = DataManager.get_skill("skill_spirit_bullet")
	if skill_data.is_empty():
		return
	# 检查灵力
	var mp_cost: int = skill_data.get("mp_cost", 5)
	if not stats.use_mana(mp_cost):
		EventBus.notification_shown.emit("灵力不足")
		return
	skill_cooldown = skill_data.get("cooldown", 1.0)
	# 实例化投射物
	var bullet: Area2D = SPIRIT_BULLET_SCENE.instantiate()
	bullet.damage = calculate_damage(0, skill_data.get("damage", 15))
	bullet.speed = skill_data.get("projectile_speed", 400)
	bullet.max_range = skill_data.get("range", 300)
	# 根据朝向设置方向与出生点
	var dir: Vector2 = _facing_to_vector(parent.facing)
	bullet.direction = dir
	bullet.position = parent.global_position + dir * SPIRIT_BULLET_SPAWN_OFFSET
	# 添加到玩家所在场景（玩家父节点）
	parent.get_parent().add_child(bullet)

## 朝向转单位向量
func _facing_to_vector(facing: int) -> Vector2:
	match facing:
		PlayerController.Facing.RIGHT:
			return Vector2.RIGHT
		PlayerController.Facing.LEFT:
			return Vector2.LEFT
		PlayerController.Facing.UP:
			return Vector2.UP
		PlayerController.Facing.DOWN:
			return Vector2.DOWN
	return Vector2.RIGHT
