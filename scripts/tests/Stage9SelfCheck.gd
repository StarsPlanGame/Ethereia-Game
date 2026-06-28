##======================================================
## Stage9SelfCheck.gd - 阶段 9 地图骨架与占位资源自检
## 运行：godot --headless --script res://scripts/tests/Stage9SelfCheck.gd
## 验证：MapBase 边界墙生成、占位纹理生成、场景加载完整性
##======================================================
extends SceneTree

# 在 --script 模式下 class_name 全局类型可能未注册，需 preload
const PlaceholderTextureGenerator = preload("res://scripts/core/PlaceholderTextureGenerator.gd")
const MapBase = preload("res://scripts/core/MapBase.gd")

func _initialize() -> void:
	var runner: Node = TestRunner.new()
	root.add_child(runner)

# ======== 测试运行器 ========
class TestRunner extends Node:
	var _passed: int = 0
	var _failed: int = 0
	# 通过脚本引用访问静态方法
	var PTG: Script = preload("res://scripts/core/PlaceholderTextureGenerator.gd")
	var MapBaseScript: Script = preload("res://scripts/core/MapBase.gd")

	func _ready() -> void:
		print("========== 阶段 9 地图骨架自检开始 ==========")
		_test_placeholder_texture_generation()
		_test_placeholder_texture_caching()
		_test_placeholder_texture_for_role()
		_test_map_base_boundary_walls()
		_test_map_base_spawn_position()
		_test_scene_loading_qing_shi_town()
		_test_scene_loading_qing_shi_forest()
		_test_scene_loading_nether_temple()
		_print_summary()
		get_tree().quit()

	# ======== 测试：占位纹理生成 ========
	func _test_placeholder_texture_generation() -> void:
		print("\n[测试] 占位纹理生成")
		var tex: ImageTexture = PTG.get_solid_color(32, 32, Color.RED)
		_assert_not_null(tex, "纯色纹理应成功生成")
		_assert_eq(tex.get_width(), 32, "纹理宽度应为 32")
		_assert_eq(tex.get_height(), 32, "纹理高度应为 32")

	# ======== 测试：占位纹理缓存 ========
	func _test_placeholder_texture_caching() -> void:
		print("\n[测试] 占位纹理缓存机制")
		var tex1: ImageTexture = PTG.get_solid_color(64, 64, Color.BLUE)
		var tex2: ImageTexture = PTG.get_solid_color(64, 64, Color.BLUE)
		_assert_eq(tex1, tex2, "相同参数应返回缓存实例")
		var tex3: ImageTexture = PTG.get_solid_color(64, 64, Color.GREEN)
		_assert_not_eq(tex1, tex3, "不同颜色应返回不同实例")

	# ======== 测试：角色占位纹理 ========
	func _test_placeholder_texture_for_role() -> void:
		print("\n[测试] 角色占位纹理")
		var player_tex: ImageTexture = PTG.get_for_role("player")
		_assert_not_null(player_tex, "player 纹理应成功生成")
		var npc_tex: ImageTexture = PTG.get_for_role("npc")
		_assert_not_null(npc_tex, "npc 纹理应成功生成")
		var enemy_tex: ImageTexture = PTG.get_for_role("enemy")
		_assert_not_null(enemy_tex, "enemy 纹理应成功生成")
		_assert_not_eq(player_tex, npc_tex, "player 和 npc 纹理应不同")
		_assert_not_eq(player_tex, enemy_tex, "player 和 enemy 纹理应不同")

	# ======== 测试：MapBase 边界墙生成 ========
	func _test_map_base_boundary_walls() -> void:
		print("\n[测试] MapBase 边界墙生成")
		var map: Node2D = MapBaseScript.new()
		map.map_width = 1280.0
		map.map_height = 720.0
		map.auto_bounds = true
		add_child(map)
		_assert_true(map.has_node("BoundaryWalls"), "应生成 BoundaryWalls 节点")
		var walls: Node = map.get_node("BoundaryWalls")
		_assert_eq(walls.get_child_count(), 4, "应生成 4 面墙")
		var wall_names: Array = ["Wall_Top", "Wall_Bottom", "Wall_Left", "Wall_Right"]
		for wall_name in wall_names:
			_assert_true(walls.has_node(wall_name), "应存在 %s" % wall_name)
			var wall: StaticBody2D = walls.get_node(wall_name)
			_assert_eq(wall.collision_layer, 8, "%s 碰撞层应为 8（墙壁层）" % wall_name)
		map.free()

	# ======== 测试：MapBase 出生点查找 ========
	func _test_map_base_spawn_position() -> void:
		print("\n[测试] MapBase 出生点查找")
		var map: Node2D = MapBaseScript.new()
		map.map_width = 1280.0
		map.map_height = 720.0
		# 不设置 auto_bounds 避免生成墙
		map.auto_bounds = false
		add_child(map)
		var pos: Vector2 = map.get_spawn_position("spawn_default")
		_assert_eq(pos, Vector2(640, 360), "无 SpawnPoints 时应返回地图中心")
		var sp: Node2D = Node2D.new()
		sp.name = "SpawnPoints"
		map.add_child(sp)
		var marker: Marker2D = Marker2D.new()
		marker.name = "spawn_default"
		marker.position = Vector2(100, 200)
		sp.add_child(marker)
		pos = map.get_spawn_position("spawn_default")
		_assert_eq(pos, Vector2(100, 200), "应返回 spawn_default 位置")
		pos = map.get_spawn_position("nonexistent")
		_assert_eq(pos, Vector2(100, 200), "不存在时应回退到 spawn_default")
		map.free()

	# ======== 测试：青石镇场景加载 ========
	func _test_scene_loading_qing_shi_town() -> void:
		print("\n[测试] 青石镇场景加载")
		var packed: PackedScene = load("res://scenes/maps/QingShiTown.tscn")
		_assert_not_null(packed, "QingShiTown.tscn 应可加载")
		var scene: Node2D = packed.instantiate()
		add_child(scene)
		# 检查是否使用了 MapBase 脚本
		_assert_true(scene.get_script() == MapBaseScript, "QingShiTown 应使用 MapBase 脚本")
		_assert_eq(scene.map_name, "青石镇", "map_name 应为青石镇")
		_assert_true(scene.has_node("SpawnPoints"), "应存在 SpawnPoints 节点")
		_assert_true(scene.has_node("TransferPoints"), "应存在 TransferPoints 节点")
		_assert_true(scene.has_node("NPCs"), "应存在 NPCs 节点")
		_assert_true(scene.has_node("GatherNodes"), "应存在 GatherNodes 节点")
		var npcs: Node = scene.get_node("NPCs")
		_assert_eq(npcs.get_child_count(), 3, "青石镇应有 3 个 NPC")
		var gathers: Node = scene.get_node("GatherNodes")
		_assert_eq(gathers.get_child_count(), 3, "青石镇应有 3 个采集点")
		scene.free()

	# ======== 测试：青石山林场景加载 ========
	func _test_scene_loading_qing_shi_forest() -> void:
		print("\n[测试] 青石山林场景加载")
		var packed: PackedScene = load("res://scenes/maps/QingShiForest.tscn")
		_assert_not_null(packed, "QingShiForest.tscn 应可加载")
		var scene: Node2D = packed.instantiate()
		add_child(scene)
		_assert_true(scene.get_script() == MapBaseScript, "QingShiForest 应使用 MapBase 脚本")
		_assert_eq(scene.map_name, "青石山林", "map_name 应为青石山林")
		_assert_true(scene.has_node("Enemies"), "应存在 Enemies 节点")
		var enemies: Node = scene.get_node("Enemies")
		_assert_eq(enemies.get_child_count(), 4, "青石山林应有 4 个敌人")
		scene.free()

	# ======== 测试：冥墟古观场景加载 ========
	func _test_scene_loading_nether_temple() -> void:
		print("\n[测试] 冥墟古观场景加载")
		var packed: PackedScene = load("res://scenes/maps/NetherTemple.tscn")
		_assert_not_null(packed, "NetherTemple.tscn 应可加载")
		var scene: Node2D = packed.instantiate()
		add_child(scene)
		_assert_true(scene.get_script() == MapBaseScript, "NetherTemple 应使用 MapBase 脚本")
		_assert_eq(scene.map_name, "冥墟古观", "map_name 应为冥墟古观")
		_assert_true(scene.has_node("StoryTriggers"), "应存在 StoryTriggers 节点")
		_assert_true(scene.has_node("Enemies"), "应存在 Enemies 节点")
		var enemies: Node = scene.get_node("Enemies")
		_assert_eq(enemies.get_child_count(), 3, "冥墟古观应有 3 个敌人")
		scene.free()

	# ======== 断言辅助 ========
	func _assert_eq(actual, expected, msg: String) -> void:
		if actual == expected:
			_passed += 1
			print("  [PASS] %s" % msg)
		else:
			_failed += 1
			print("  [FAIL] %s (期望: %s, 实际: %s)" % [msg, str(expected), str(actual)])

	func _assert_not_null(obj, msg: String) -> void:
		if obj != null:
			_passed += 1
			print("  [PASS] %s" % msg)
		else:
			_failed += 1
			print("  [FAIL] %s (期望非 null)" % msg)

	func _assert_not_eq(actual, expected, msg: String) -> void:
		if actual != expected:
			_passed += 1
			print("  [PASS] %s" % msg)
		else:
			_failed += 1
			print("  [FAIL] %s (期望不等于: %s, 实际: %s)" % [msg, str(expected), str(actual)])

	func _assert_true(val: bool, msg: String) -> void:
		if val:
			_passed += 1
			print("  [PASS] %s" % msg)
		else:
			_failed += 1
			print("  [FAIL] %s (期望 true)" % msg)

	func _print_summary() -> void:
		print("\n========== 自检结果 ==========")
		print("通过: %d  失败: %d" % [_passed, _failed])
		if _failed == 0:
			print("阶段 9 地图骨架自检全部通过！")
		else:
			print("存在失败项，请检查！")
		print("==============================")
