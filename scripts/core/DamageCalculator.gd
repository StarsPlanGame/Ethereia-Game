##======================================================
## DamageCalculator.gd - 统一伤害计算工具
## 静态工具类，提供统一的伤害公式与暴击/方差处理
## 关联文档：01_GDD_GAME_DESIGN.md §3 战斗系统 / 05_SYSTEM_DESIGN.md §5
##======================================================
extends RefCounted
class_name DamageCalculator

## 统一伤害公式：max(1, atk + skill_dmg - def) * variance * crit_mult
## 所有伤害结算（玩家普攻/技能/敌人攻击）均应通过此函数计算
##
## 参数：
##   attacker_atk    攻击者攻击力（玩家 stats.attack 或敌人 attack）
##   defender_def    防御者防御力（玩家 stats.defense 或敌人 defense）
##   skill_damage    技能附加伤害（普攻传 0）
##   crit_chance     暴击率（0.0-1.0，默认 0）
##   crit_multiplier 暴击倍率（默认 1.5）
##   variance_ratio  伤害浮动比例（0.1 表示 ±10%，默认 0）
## 返回值：最终伤害值（int）
static func compute_damage(
		attacker_atk: int,
		defender_def: int,
		skill_damage: int = 0,
		crit_chance: float = 0.0,
		crit_multiplier: float = 1.5,
		variance_ratio: float = 0.0
	) -> Dictionary:
	# 基础伤害（不低于 1，保证攻击始终有反馈）
	var base_dmg: int = maxi(1, attacker_atk + skill_damage - defender_def)

	# 方差浮动（线性分布，对称浮动）
	var variance_mult: float = 1.0
	if variance_ratio > 0.0:
		variance_mult = randf_range(1.0 - variance_ratio, 1.0 + variance_ratio)

	# 暴击判定
	var is_crit: bool = crit_chance > 0.0 and randf() <= crit_chance
	var crit_mult: float = 1.0
	if is_crit:
		crit_mult = crit_multiplier

	# 最终伤害（取整保证 int）
	var final_dmg: int = maxi(1, int(round(base_dmg * variance_mult * crit_mult)))

	return {
		"damage": final_dmg,
		"is_crit": is_crit,
		"base_damage": base_dmg,
		"variance_mult": variance_mult,
		"crit_mult": crit_mult,
	}

## 简化版：仅计算伤害，不返回暴击信息
## 适用于不需要暴击反馈的场景（如持续伤害、环境伤害）
static func get_damage(
		attacker_atk: int,
		defender_def: int,
		skill_damage: int = 0
	) -> int:
	return maxi(1, attacker_atk + skill_damage - defender_def)
