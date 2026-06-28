##======================================================
## PlayerStats.gd - 玩家属性组件
## 挂载：Player.tscn 上的 Node 子节点（Stats）
## 职责：维护玩家 HP/MP/属性/防御值，提供伤害结算
## 关联文档：01_GDD_GAME_DESIGN.md §3 战斗系统 / 05_SYSTEM_DESIGN.md §3.1
##======================================================
extends Node
class_name PlayerStats

# ======== 基础属性（凡人初始值）========
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var max_mp: int = 30
@export var current_mp: int = 30

@export var attack: int = 10
@export var defense: int = 5
@export var move_speed: float = 150.0

# ======== 接口 ========
func take_damage(dmg: int) -> void:
	var actual: int = max(1, dmg - defense)
	current_hp = max(0, current_hp - actual)
	EventBus.player_hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		EventBus.player_died.emit()

func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	EventBus.player_hp_changed.emit(current_hp, max_hp)

func use_mana(amount: int) -> bool:
	if current_mp < amount:
		return false
	current_mp -= amount
	EventBus.player_mp_changed.emit(current_mp, max_mp)
	return true

func restore_mana(amount: int) -> void:
	current_mp = min(max_mp, current_mp + amount)
	EventBus.player_mp_changed.emit(current_mp, max_mp)

# ======== 存档接口 ========
func get_save_data() -> Dictionary:
	return {
		"max_hp": max_hp, "current_hp": current_hp,
		"max_mp": max_mp, "current_mp": current_mp,
		"attack": attack, "defense": defense, "move_speed": move_speed,
	}

func load_save_data(data: Dictionary) -> void:
	max_hp = data.get("max_hp", 100)
	current_hp = data.get("current_hp", 100)
	max_mp = data.get("max_mp", 30)
	current_mp = data.get("current_mp", 30)
	attack = data.get("attack", 10)
	defense = data.get("defense", 5)
	move_speed = data.get("move_speed", 150.0)
