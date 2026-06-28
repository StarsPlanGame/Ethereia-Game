##======================================================
## EnemyBase.gd - 敌人基类
## 挂载：EnemyBase.tscn 根节点（CharacterBody2D）
## 职责：维护敌人 HP/属性/受击/死亡，集成 AI 与掉落组件
## 关联文档：01_GDD_GAME_DESIGN.md §3 战斗系统 / 05_SYSTEM_DESIGN.md §7
##======================================================
extends CharacterBody2D
class_name EnemyBase

# ======== 数据驱动属性（从 enemies.json 加载）========
@export var enemy_id: String = ""        # 敌人数据 ID
@export var death_flag: String = ""      # 死亡时设置的剧情标记（Boss 专用）
var enemy_name: String = ""
var max_hp: int = 30
var current_hp: int = 30
var attack: int = 8
var defense: int = 2
var move_speed: float = 100.0
var exp_reward: int = 5
var is_boss: bool = false
var complete_quest_on_death: String = ""  # 死亡时自动完成的任务 ID
# 战斗扩展参数（数据驱动）
var crit_chance: float = 0.0           # 暴击率
var crit_multiplier: float = 1.5       # 暴击倍率
var damage_variance: float = 0.0       # 伤害浮动比例
# AI 参数（数据驱动，覆盖 AI 节点 @export 默认值）
var ai_type: String = "melee_chase"
var detection_range: float = 200.0
var attack_range: float = 30.0
var attack_cooldown: float = 1.5
var patrol_radius: float = 80.0
var return_range: float = 400.0

# ======== 内部状态 ========
var is_dead: bool = false
var _invulnerable_timer: float = 0.0  # 受击后短暂无敌（防穿模连击）

# 占位纹理生成器（使用 const preload 确保在任何模式下都可加载）
const _PTG = preload("res://scripts/core/PlaceholderTextureGenerator.gd")
# 统一伤害计算器
const _DmgCalc = preload("res://scripts/core/DamageCalculator.gd")

# ======== 组件引用 ========
@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox
@onready var detection_area: Area2D = $DetectionArea
@onready var ai: Node = $AI
@onready var drop_component: Node = $Drop
@onready var health_bar: ProgressBar = $HealthBar

# ======== 生命周期 ========
func _ready() -> void:
	add_to_group("enemy")
	# 从数据表加载属性
	if enemy_id != "":
		_load_from_data(enemy_id)
	# 占位纹理（美术资源缺失时自动生成红色方块）
	if sprite != null and sprite.texture == null:
		sprite.texture = _PTG.get_for_role("enemy")
	# HurtBox 加入组便于玩家 HitBox 识别
	if hurtbox != null:
		hurtbox.add_to_group("enemy_hurtbox")
	# HitBox 加入组便于玩家 HurtBox 识别
	if hitbox != null:
		hitbox.add_to_group("enemy_hitbox")
		hitbox.monitoring = false  # 默认关闭，AI 攻击时启用
	# 初始化血条
	if health_bar != null:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	# 同步数据驱动的 AI 参数到 AI 节点（覆盖场景中的 @export 值）
	_apply_ai_params()
	# 初始化 AI
	if ai != null and ai.has_method("initialize"):
		ai.initialize(self)

## 将数据表加载的 AI 参数同步到 AI 节点（数据表优先于场景配置）
func _apply_ai_params() -> void:
	if ai == null:
		return
	if "chase_range" in ai:
		ai.chase_range = detection_range
	if "attack_range" in ai:
		ai.attack_range = attack_range
	if "attack_cooldown" in ai:
		ai.attack_cooldown = attack_cooldown
	if "patrol_radius" in ai:
		ai.patrol_radius = patrol_radius
	if "return_range" in ai:
		ai.return_range = return_range

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _invulnerable_timer > 0:
		_invulnerable_timer -= delta
	# AI 驱动移动
	if ai != null and ai.has_method("update"):
		ai.update(delta)
	move_and_slide()

# ======== 数据加载 ========
func _load_from_data(id: String) -> void:
	var data: Dictionary = DataManager.get_enemy(id)
	if data.is_empty():
		push_warning("[Enemy] 敌人数据不存在: %s" % id)
		return
	enemy_name = data.get("name", id)
	max_hp = data.get("hp", 30)
	current_hp = max_hp
	attack = data.get("attack", 8)
	defense = data.get("defense", 2)
	move_speed = data.get("move_speed", 100)
	exp_reward = data.get("exp", 5)
	is_boss = data.get("is_boss", false)
	complete_quest_on_death = data.get("complete_quest_on_death", "")
	# 战斗扩展参数
	crit_chance = data.get("crit_chance", 0.0)
	crit_multiplier = data.get("crit_multiplier", 1.5)
	damage_variance = data.get("damage_variance", 0.0)
	# AI 参数（数据表为单一数据源）
	ai_type = data.get("ai_type", "melee_chase")
	detection_range = data.get("detection_range", 200.0)
	attack_range = data.get("attack_range", 30.0)
	attack_cooldown = data.get("attack_cooldown", 1.5)
	patrol_radius = data.get("patrol_radius", 80.0)
	return_range = data.get("return_range", 400.0)

# ======== 受击接口 ========
func take_damage(dmg: int) -> void:
	if is_dead:
		return
	if _invulnerable_timer > 0:
		return
	current_hp = max(0, current_hp - dmg)
	_invulnerable_timer = 0.2  # 200ms 无敌
	# 更新血条
	if health_bar != null:
		health_bar.value = current_hp
	_play_hit_effect()
	if current_hp <= 0:
		die()

func _play_hit_effect() -> void:
	# 简单受击闪红
	if sprite != null:
		sprite.modulate = Color(1, 0.3, 0.3)
		await get_tree().create_timer(0.1).timeout
		if sprite != null:
			sprite.modulate = Color(1, 1, 1)

# ======== 死亡 ========
func die() -> void:
	if is_dead:
		return
	is_dead = true
	# 触发掉落
	if drop_component != null and drop_component.has_method("drop_loot"):
		drop_component.drop_loot()
	# 通知任务系统
	EventBus.enemy_killed.emit(enemy_id)
	# Boss 死亡设置剧情标记
	if death_flag != "":
		GameState.set_story_flag(death_flag, true)
	# Boss 死亡自动完成任务（如 quest_004）
	if complete_quest_on_death != "":
		QuestManager.complete_quest(complete_quest_on_death)
	# 隐藏 HitBox/HurtBox 避免死后触发
	if hitbox != null:
		hitbox.monitoring = false
	if hurtbox != null:
		hurtbox.monitoring = false
	# 死亡淡出
	if sprite != null:
		var tw: Tween = create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tw.tween_callback(queue_free)

# ======== 攻击辅助 ========
## AI 调用：启用 HitBox 一段时间进行攻击判定
func enable_hitbox(duration: float = 0.3) -> void:
	if is_dead or hitbox == null:
		return
	hitbox.monitoring = true
	await get_tree().create_timer(duration).timeout
	if hitbox != null:
		hitbox.monitoring = false

# ======== 玩家检测 ========
## 获取检测区域内最近的玩家
func get_player_in_range() -> Node2D:
	if detection_area == null:
		return null
	var bodies: Array = detection_area.get_overlapping_bodies()
	var player: Node2D = null
	for body in bodies:
		if body.is_in_group("player"):
			if player == null or global_position.distance_to(body.global_position) < global_position.distance_to(player.global_position):
				player = body
	return player
