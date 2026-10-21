class_name Ui
## Цвета, шрифты и мелкие сборщики интерфейса. Интерфейс строится кодом, поэтому
## весь облик — здесь: тёмный «карбон», красный, зелёный и белый флага Италии.

const RED := Color("e10600")
const RED_DARK := Color("9c0400")
const GREEN := Color("00a651")
const GREEN_LIGHT := Color("3ddc84")
const WHITE := Color("f5f6f8")
const GREY := Color("9aa0aa")
const AMBER := Color("ffc400")
const NITRO := Color("35c8ff")
const WRONG := Color("ff5a4f")
const PANEL := Color(0.06, 0.07, 0.09, 0.96)

## Bahnschrift есть в каждой Windows 10/11 и похожа на шрифты гоночных трансляций.
const FONT_NAMES := ["Bahnschrift", "Segoe UI", "Arial", "Helvetica", "Liberation Sans", "sans-serif"]

static var font: Font
static var bold: Font
static var title: Font
## Тема игры. Узлы под CanvasLayer не наследуют тему окна — им её ставят явно.
static var theme: Theme
## Сенсорный экран (телефон, доска): мелкий текст крупнее, см. text_size().
static var touch := false


static func setup() -> void:
	touch = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		# в браузере системных шрифтов нет: жирность и наклон делаем встроенному шрифту
		font = ThemeDB.fallback_font
		bold = _variation(font, 0.8, 0.0)
		title = _variation(font, 1.0, 0.2)
	else:
		font = _system(400, false)
		bold = _system(700, false)
		title = _system(700, true)
	theme = make_theme()


static func _variation(base: Font, embolden: float, slant: float) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.variation_embolden = embolden
	f.variation_transform = Transform2D(Vector2(1.0, slant), Vector2(0.0, 1.0), Vector2.ZERO)
	return f


## На телефоне макет 1280×720 ужимается вдвое, и мелкие подписи становятся
## крошечными; там их кегль подтягивается к 28.
static func text_size(size: int) -> int:
	if not touch or size >= 28:
		return size
	return roundi(size + (28 - size) * 0.35)


## Корневой Control для CanvasLayer: во весь экран, с темой игры.
static func layer_root(layer: CanvasLayer) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	layer.add_child(root)
	return root


static func _system(weight: int, italic: bool) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(FONT_NAMES)
	f.font_weight = weight
	f.font_italic = italic
	return f


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 22
	var normal := box(Color(0.1, 0.11, 0.14, 0.94), Color(1, 1, 1, 0.14), 2, 0.22)
	var hover := box(RED, Color(1, 1, 1, 0.45), 2, 0.22)
	var pressed := box(RED_DARK, Color(1, 1, 1, 0.45), 2, 0.22)
	var disabled := box(Color(0.1, 0.11, 0.14, 0.5), Color(1, 1, 1, 0.05), 2, 0.22)
	var focus := box(Color.TRANSPARENT, WHITE, 3, 0.22)
	focus.draw_center = false
	for type: String in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_font("font", type, bold)
		t.set_font_size("font_size", type, 24)
		for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, type, WHITE)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, Color(1, 1, 1, 0.08), 1, 0.0, 6))
	t.set_color("font_color", "Label", WHITE)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_color("default_color", "RichTextLabel", WHITE)
	return t


static func box(bg: Color, border := Color(0, 0, 0, 0), border_w := 0, skew := 0.0, radius := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.skew = Vector2(skew, 0.0)
	s.content_margin_left = 22.0
	s.content_margin_right = 22.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	s.anti_aliasing = true
	return s


static func label(text: String, size := 20, color := WHITE, strong := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", text_size(size))
	l.add_theme_color_override("font_color", color)
	if strong:
		l.add_theme_font_override("font", bold)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func rich(size := 22) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", text_size(size))
	r.add_theme_font_size_override("bold_font_size", text_size(size))
	return r


static func button(text: String, on_press: Callable, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func() -> void: Sfx.play("click"))
	b.pressed.connect(on_press)
	return b


## Самый крупный кегль (не больше size), при котором text влезает в max_w.
static func fit_size(text: String, max_w: float, size: int, min_size := 12) -> int:
	while size > min_size and bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
		size -= 1
	return size


## Фраза с пропуском для карточки: «Vado _____ Roma.»
static func blank(sentence: String) -> String:
	return _put(_escape(sentence), "[color=#%s]_____[/color]" % AMBER.to_html(false), "")


## Фраза с вписанным ответом; если ответ был неверный — он зачёркнут перед верным.
static func filled(sentence: String, answer: String, wrong := "") -> String:
	var insert := ""
	if wrong != "":
		insert = "[color=#%s][s]%s[/s][/color] " % [WRONG.to_html(false), _escape(wrong)]
	insert += "[color=#%s][b]%s[/b][/color]" % [GREEN_LIGHT.to_html(false), _escape(answer)]
	return _put(_escape(sentence), insert, answer)


## «sull'» пишется слитно со следующим словом: пробел после пропуска убираем.
static func _put(sentence: String, insert: String, word: String) -> String:
	if word.ends_with("'") and sentence.contains("___ "):
		return sentence.replace("___ ", insert)
	return sentence.replace("___", insert)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
