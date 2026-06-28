##======================================================
## PlayerCultivation.gd - 玩家修炼组件
## 挂载：Player.tscn 上的 Node 子节点（Cultivation）
## 职责：维护境界、灵气积累、突破逻辑、打坐状态切换
## 关联文档：01_GDD_GAME_DESIGN.md §4 修炼系统 / 03_WORLD_BIBLE.md §2 境界
##======================================================
extends Node
class_name PlayerCultivation

# ======== 境界枚举 ========
enum Realm {
	MORTAL,        # 凡人
	QI_REFINING,   # 炼气
	FOUNDATION,    # 筑基
	GOLDEN_CORE,   # 金丹
	NASCENT_SOUL,  # 元婴
	SPIRIT_TRANSFORM,  # 化神
	UNIFY,         # 合体
	GREAT_VOID,    # 大乘
	TRIBULATION    # 渡劫
}

const REALM_NAMES := {
	Realm.MORTAL: "凡人",
	Realm.QI_REFINING: "炼气",
	Realm.FOUNDATION: "筑基",
	Realm.GOLDEN_CORE: "金丹",
	Realm.NASCENT_SOUL: "元婴",
	Realm.SPIRIT_TRANSFORM: "化神",
	Realm.UNIFY: "合体",
	Realm.GREAT_VOID: "大乘",
	Realm.TRIBULATION: "渡劫",
}

# ======== 修炼状态 ========
var realm: int = Realm.MORTAL
var realm_level: int = 0  # 大境界内小层次（如炼气一层 = QI_REFINING_1）
var spirit_qi: int = 0     # 灵气值
var spirit_qi_max: int = 100
var is_meditating: bool = false  # 打坐中
var has_nether_jade: bool = false  # 是否拥有冥天玉（修炼前提）

# ======== 打坐参数 ========
const MEDITATE_QI_PER_SECOND := 2.0
var _qi_accumulator: float = 0.0

# ======== 生命周期 ========
func _ready() -> void:
	EventBus.story_flag_changed.connect(_on_story_flag_changed)

func _process(delta: float) -> void:
	if not is_meditating:
		return
	if not has_nether_jade:
		return
	# 累积灵气
	_qi_accumulator += MEDITATE_QI_PER_SECOND * delta
	while _qi_accumulator >= 1.0:
		_qi_accumulator -= 1.0
		add_qi(1)

# ======== 公共接口 ========
func set_nether_jade(value: bool) -> void:
	has_nether_jade = value

func add_qi(amount: int) -> void:
	spirit_qi = min(spirit_qi_max, spirit_qi + amount)
	EventBus.cultivation_changed.emit(REALM_NAMES[realm], realm_level, spirit_qi)

func start_meditation() -> void:
	if not has_nether_jade:
		EventBus.notification_shown.emit("需要冥天玉才能修炼")
		return
	is_meditating = true
	GameState.is_cultivating = true

func stop_meditation() -> void:
	is_meditating = false
	GameState.is_cultivating = false

## 检查突破条件（冥天玉 + 灵气满 + 任务完成 + 心境3）
## 第一部分仅要求前两项
func can_breakthrough() -> bool:
	if not has_nether_jade:
		return false
	if spirit_qi < spirit_qi_max:
		return false
	# TODO: 接入任务完成与心境判定
	if realm != Realm.MORTAL:
		return false  # 第一部分只允许突破一次
	return true

func do_breakthrough() -> bool:
	if not can_breakthrough():
		EventBus.breakthrough_failed.emit(REALM_NAMES[realm], realm_level)
		return false
	realm = Realm.QI_REFINING
	realm_level = 1
	spirit_qi = 0
	# 突破后属性提升（路线图 §8 验收标准：max_hp+20, max_mp+50）
	var stats: PlayerStats = get_parent().get_node("Stats")
	stats.max_hp += 20
	stats.current_hp = stats.max_hp
	stats.max_mp += 50
	stats.current_mp = stats.max_mp
	stats.attack += 5
	stats.defense += 3
	# 通知 HUD 更新
	EventBus.player_hp_changed.emit(stats.current_hp, stats.max_hp)
	EventBus.player_mp_changed.emit(stats.current_mp, stats.max_mp)
	EventBus.breakthrough_success.emit(REALM_NAMES[realm], realm_level)
	EventBus.cultivation_changed.emit(REALM_NAMES[realm], realm_level, spirit_qi)
	return true

# ======== 信号回调 ========
func _on_story_flag_changed(key: String, value) -> void:
	if key == "has_nether_jade":
		has_nether_jade = (value == true)

# ======== 存档接口 ========
func get_save_data() -> Dictionary:
	return {
		"realm": realm,
		"realm_level": realm_level,
		"spirit_qi": spirit_qi,
		"has_nether_jade": has_nether_jade,
	}

func load_save_data(data: Dictionary) -> void:
	realm = data.get("realm", Realm.MORTAL)
	realm_level = data.get("realm_level", 0)
	spirit_qi = data.get("spirit_qi", 0)
	has_nether_jade = data.get("has_nether_jade", false)
