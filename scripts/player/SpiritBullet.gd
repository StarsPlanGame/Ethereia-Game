##======================================================
## SpiritBullet.gd - 灵气弹投射物
## 挂载：SpiritBullet.tscn 根节点（Area2D）
## 职责：沿方向飞行，命中敌人造成伤害，超距或命中后销毁
## 关联文档：01_GDD_GAME_DESIGN.md §4.3 灵气弹 / 05_SYSTEM_DESIGN.md §6
##======================================================
extends Area2D
class_name SpiritBullet

# ======== 参数（由发射方设置）========
var direction: Vector2 = Vector2.RIGHT  # 飞行方向（已归一化）
var speed: float = 400.0                # 飞行速度
var damage: int = 15                    # 伤害值（含攻击者攻击力）
var max_range: float = 300.0            # 最大射程

var _traveled: float = 0.0              # 已飞行距离

# ======== 生命周期 ========
func _ready() -> void:
	# 命中敌人 HurtBox（layer 7）触发伤害
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# 5 秒后强制销毁（兜底）
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	var step: Vector2 = direction * speed * delta
	position += step
	_traveled += step.length()
	if _traveled >= max_range:
		queue_free()

# ======== 命中处理 ========
func _on_body_entered(body: Node) -> void:
	# 命中墙壁/地形（collision_layer 1 = 地形）直接销毁
	if body is TileMapLayer or body.get_class() == "TileMapLayer":
		queue_free()
		return
	# 命中敌人 CharacterBody
	if body.has_method("take_damage") and body.is_in_group("enemy"):
		body.take_damage(damage)
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	# 命中敌人 HurtBox
	if area.is_in_group("enemy_hurtbox"):
		var enemy: Node = area.get_parent()
		if enemy != null and enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		queue_free()
