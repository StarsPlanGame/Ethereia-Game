##======================================================
## PlayerCombat.gd - 玩家战斗组件
## 挂载：Player.tscn 上的 Node 子节点（Combat）
## 职责：处理攻击输入、伤害结算、HitBox/HurtBox 管理
## 关联文档：01_GDD_GAME_DESIGN.md §3 战斗系统 / 05_SYSTEM_DESIGN.md §5
##======================================================
extends Node
class_name PlayerCombat

@onready var parent: CharacterBody2D = get_parent()
@onready var stats: PlayerStats = parent.get_node("Stats")
@onready var hitbox: Area2D = parent.get_node_or_null("HitBox")
@onready var hurtbox: Area2D = parent.get_node_or_null("HurtBox")

# ======== 战斗状态 ========
var is_attacking: bool = false
var attack_combo_index: int = 0
var attack_cooldown: float = 0.0

# ======== 生命周期 ========
func _ready() -> void:
	if hurtbox != null:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

func _process(delta: float) -> void:
	if attack_cooldown > 0:
		attack_cooldown -= delta
	if GameState.is_paused or GameState.is_in_dialogue:
		return
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_perform_attack()

# ======== 攻击 ========
func _perform_attack() -> void:
	if attack_cooldown > 0:
		return
	is_attacking = true
	attack_cooldown = 0.4  # 攻击间隔（秒）
	# TODO: 启用 HitBox、播放攻击动画
	# 攻击结束后通过动画事件复位 is_attacking
	if hitbox != null:
		hitbox.monitoring = true
	# 模拟攻击持续时间
	await get_tree().create_timer(0.2).timeout
	if hitbox != null:
		hitbox.monitoring = false
	is_attacking = false

## 计算伤害：max(1, atk + skill_dmg - def)
func calculate_damage(target_defense: int, skill_damage: int = 0) -> int:
	return max(1, stats.attack + skill_damage - target_defense)

# ======== 受击 ========
func _on_hurtbox_area_entered(area: Area2D) -> void:
	# 命中本玩家的 area 应在 enemy_hitbox 层
	if not area.is_in_group("enemy_hitbox"):
		return
	# TODO: 从 enemy 取实际伤害值，暂用占位 10
	var incoming_dmg: int = 10
	stats.take_damage(incoming_dmg)

# ======== 技能 ========
## 使用 skill_id 对应的技能
## TODO: 待 SkillsSystem 与 PlayerAnimation 实现后完善
func use_skill(skill_id: String) -> void:
	var skill_data: Dictionary = DataManager.get_skill(skill_id)
	if skill_data.is_empty():
		push_warning("[PlayerCombat] 技能不存在: %s" % skill_id)
		return
	if not stats.use_mana(skill_data.get("mp_cost", 0)):
		return  # 灵力不足
	# TODO: 触发技能效果（投射物 / 范围伤害 / Buff）
	EventBus.notification_shown.emit("使用技能: %s" % skill_data.get("name", skill_id))
