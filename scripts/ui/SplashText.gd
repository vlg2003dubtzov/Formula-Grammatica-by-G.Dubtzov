class_name SplashText
extends Label
## Надпись у логотипа, как жёлтая фраза в меню Minecraft: наискосок,
## пульсирует и светится. Ставится ребёнком подписи-логотипа; центр надписи —
## точка родителя anchor_point (доля его размера) плюс сдвиг nudge.

const YELLOW := Color("ffff00")
const SHADOW := Color("3f3f00")

var anchor_point := Vector2(1.0, 0.5)
var nudge := Vector2(92, -16)
var _glow: Label
var _t := 0.0


func _init(caption: String) -> void:
	text = caption


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style(self, YELLOW)
	add_theme_color_override("font_shadow_color", SHADOW)
	add_theme_constant_override("shadow_offset_x", 3)
	add_theme_constant_override("shadow_offset_y", 3)
	# свечение — та же надпись позади, только широкая полупрозрачная обводка
	_glow = Label.new()
	_glow.text = text
	_glow.show_behind_parent = true
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style(_glow, Color(1, 1, 0, 0))
	_glow.add_theme_constant_override("outline_size", 26)
	_glow.add_theme_color_override("font_outline_color", Color(1.0, 0.95, 0.35, 0.5))
	add_child(_glow)
	rotation = deg_to_rad(-20.0)


func _style(l: Label, colour: Color) -> void:
	l.add_theme_font_override("font", Ui.title)
	l.add_theme_font_size_override("font_size", Ui.text_size(26))
	l.add_theme_color_override("font_color", colour)


func _process(delta: float) -> void:
	_t += delta
	var pulse := absf(sin(_t * TAU * 0.9))
	scale = Vector2.ONE * (1.0 + 0.08 * pulse)
	_glow.modulate.a = 0.55 + 0.45 * pulse
	var parent := get_parent() as Control
	if parent == null:
		return
	size = get_minimum_size()
	_glow.size = size
	pivot_offset = size * 0.5
	position = parent.size * anchor_point + nudge - size * 0.5
