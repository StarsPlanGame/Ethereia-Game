##======================================================
## EventBus.gd - 全局信号总线
## 挂载：Autoload 单例（project.godot 中注册）
## 职责：解耦各系统之间的通信，所有跨系统信号集中定义
## 关联文档：02_TDD_TECHNICAL_DESIGN.md §7.1 / 05_SYSTEM_DESIGN.md §2.2
##======================================================
extends Node

# ======== 道具相关 ========
signal item_collected(item_id: String, amount: int)
signal item_used(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)

# ======== 任务相关 ========
signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

# ======== 战斗相关 ========
signal enemy_killed(enemy_id: String)
signal player_hp_changed(current: int, max_value: int)
signal player_mp_changed(current: int, max_value: int)
signal player_died

# ======== 区域相关 ========
signal area_entered(area_id: String)

# ======== 对话相关 ========
signal dialogue_started(dialogue_id: String)
signal dialogue_finished(dialogue_id: String)
## 玩家与 NPC 完成一次对话（用于 talk_to_npc 任务目标推进）
signal npc_talked(npc_id: String)

# ======== 修炼相关 ========
signal cultivation_changed(realm: String, level: int, qi: int)
signal breakthrough_success(realm: String, level: int)
signal breakthrough_failed(realm: String, level: int)

# ======== 因果与关系 ========
signal karma_changed(key: String, value: int)
signal relationship_changed(npc_id: String, value: int)

# ======== 剧情标记 ========
signal story_flag_changed(key: String, value)

# ======== 场景相关 ========
signal scene_change_requested(scene_id: String, spawn_id: String)
signal scene_changed(scene_id: String)

# ======== 存档相关 ========
signal game_saved(slot_id: int)
signal game_loaded(slot_id: int)

# ======== UI 相关 ========
signal interaction_prompt_shown(text: String)
signal interaction_prompt_hidden
signal notification_shown(text: String)
