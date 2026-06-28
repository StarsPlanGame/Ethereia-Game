##======================================================
## DamageResolver.gd - 伤害计算工具
## 挂载：无（静态工具类，直接调用静态方法）
## 职责：统一伤害计算公式，支持暴击/格挡扩展
## 关联文档：01_GDD_GAME_DESIGN.md §3.3 伤害公式
##======================================================
class_name DamageResolver

## 计算物理伤害：max(1, atk - def)
## 第一部分简化版，无暴击/格挡
static func calculate_physical_damage(attack: int, defense: int) -> int:
	return max(1, attack - defense)

## 计算技能伤害：max(1, atk + skill_dmg - def)
static func calculate_skill_damage(attack: int, skill_damage: int, defense: int) -> int:
	return max(1, attack + skill_damage - defense)
