##======================================================
## PlaceholderTextureGenerator.gd - 占位纹理生成器
## 职责：在美术资源缺失时，运行时生成纯色占位纹理
## 使用：PlaceholderTextureGenerator.get_solid_color(width, height, color)
## 缓存：相同参数的纹理只生成一次，避免内存浪费
##======================================================
class_name PlaceholderTextureGenerator
extends RefCounted

## 预定义占位颜色（按用途区分）
const COLOR_PLAYER: Color = Color(0.3, 0.6, 0.9, 1)      # 蓝色 - 玩家
const COLOR_NPC: Color = Color(0.4, 0.8, 0.4, 1)         # 绿色 - NPC
const COLOR_ENEMY: Color = Color(0.85, 0.3, 0.3, 1)      # 红色 - 敌人
const COLOR_ITEM: Color = Color(0.9, 0.8, 0.3, 1)        # 黄色 - 道具
const COLOR_GATHER: Color = Color(0.6, 0.4, 0.8, 1)      # 紫色 - 采集点
const COLOR_TRANSFER: Color = Color(0.3, 0.3, 0.3, 0.6)  # 灰色半透明 - 传送点

## 纹理缓存：key = "w_x_h_r_g_b_a"
static var _cache: Dictionary = {}

## 获取纯色占位纹理（带缓存）
static func get_solid_color(width: int = 32, height: int = 32, color: Color = Color.WHITE) -> ImageTexture:
	var key: String = "%d_%d_%d_%d_%d_%d" % [width, height, int(color.r*255), int(color.g*255), int(color.b*255), int(color.a*255)]
	if _cache.has(key):
		return _cache[key]
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	# 绘制边框增强可见性（深色描边）
	var border_color: Color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0)
	_draw_border(image, border_color)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

## 绘制 1px 边框
static func _draw_border(image: Image, color: Color) -> void:
	var w: int = image.get_width()
	var h: int = image.get_height()
	for x in range(w):
		image.set_pixel(x, 0, color)
		image.set_pixel(x, h - 1, color)
	for y in range(h):
		image.set_pixel(0, y, color)
		image.set_pixel(w - 1, y, color)

## 按角色类型获取占位纹理
static func get_for_role(role: String) -> ImageTexture:
	match role:
		"player":
			return get_solid_color(32, 48, COLOR_PLAYER)
		"npc":
			return get_solid_color(32, 48, COLOR_NPC)
		"enemy":
			return get_solid_color(32, 32, COLOR_ENEMY)
		"item":
			return get_solid_color(32, 32, COLOR_ITEM)
		"gather":
			return get_solid_color(24, 24, COLOR_GATHER)
		"transfer":
			return get_solid_color(40, 80, COLOR_TRANSFER)
		_:
			return get_solid_color(32, 32, Color.GRAY)

## 清除缓存（场景切换或内存紧张时调用）
static func clear_cache() -> void:
	_cache.clear()
