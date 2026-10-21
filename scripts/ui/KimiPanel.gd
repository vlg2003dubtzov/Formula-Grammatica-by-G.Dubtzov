class_name KimiPanel
extends Control
## Кими в левом нижнем углу: портрет-шлем, табличка с именем и облачко с
## репликой, которая печатается по буквам.

const TYPE_SPEED := 55.0  # букв в секунду

var _speech: VBoxContainer
var _bubble: PanelContainer
var _text: RichTextLabel
var _more: Label
var _portrait: Control
var _tween: Tween
## Через сколько секунд облачко погаснет (−1 — висит, пока не нажмут «дальше»).
var _hide_in := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	# облачко и его хвостик прячутся и гаснут вместе
	_speech = VBoxContainer.new()
	_speech.add_theme_constant_override("separation", 0)
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_speech)
	_bubble = PanelContainer.new()
	var style := Ui.box(Color(0.97, 0.97, 0.98, 0.97), Ui.RED, 0, 0.0, 10)
	style.border_width_left = 6
	style.content_margin_left = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.add_child(_bubble)
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(inner)
	_text = Ui.rich(21)
	_text.add_theme_color_override("default_color", Color(0.1, 0.1, 0.13))
	_text.add_theme_font_override("normal_font", Ui.font)
	inner.add_child(_text)
	_more = Ui.label("Tocca per continuare  »" if Ui.touch else "Spazio o clic: avanti  »", 15, Ui.RED, true)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inner.add_child(_more)

	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, 16)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.draw.connect(func() -> void:
		tail.draw_colored_polygon(PackedVector2Array([Vector2(40, 0), Vector2(78, 0), Vector2(48, 16)]), Color(0.97, 0.97, 0.98, 0.97)))
	_speech.add_child(tail)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_portrait = Control.new()
	_portrait.custom_minimum_size = Vector2(108, 108)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.draw.connect(_draw_portrait)
	row.add_child(_portrait)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", Ui.box(Ui.RED, Color(0, 0, 0, 0), 0, 0.25))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(Ui.label("KIMI ANTONELLI", 22, Ui.WHITE, true))
	names.add_child(plate)
	names.add_child(Ui.label("pilota · la tua guida", 16, Ui.GREY))
	_speech.visible = false


func _process(delta: float) -> void:
	if _hide_in > 0.0:
		_hide_in -= delta
		if _hide_in <= 0.0:
			var tw := create_tween()
			tw.tween_property(_speech, "modulate:a", 0.0, 0.4)


## wait — реплика ждёт «дальше» (вступление); иначе гаснет через hold секунд.
func say(text: String, wait := false, hold := 4.0) -> void:
	if text == "":
		return
	_text.text = text
	_text.visible_ratio = 0.0
	_speech.visible = true
	_speech.modulate.a = 1.0
	_more.visible = wait
	if _tween:
		_tween.kill()
	var duration := text.length() / TYPE_SPEED
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, duration)
	_hide_in = -1.0 if wait else hold + duration


func is_typing() -> bool:
	return _speech.visible and _text.visible_ratio < 1.0


func finish_typing() -> void:
	if _tween:
		_tween.kill()
	_text.visible_ratio = 1.0


## Обобщённый шлем в цветах флага (не копия настоящего шлема пилота).
func _draw_portrait() -> void:
	var p := _portrait
	var c := p.size * 0.5
	p.draw_circle(c, 53.0, Ui.RED)
	p.draw_circle(c, 49.0, Color(0.1, 0.11, 0.14))
	var h := c + Vector2(0, 6)
	p.draw_circle(h, 38.0, Color("f2f2f2"))
	p.draw_rect(Rect2(h.x - 30, h.y + 6, 60, 26), Color("f2f2f2"))
	p.draw_arc(h, 31.0, PI * 1.08, PI * 1.92, 20, Color("009246"), 7.0)
	p.draw_arc(h, 23.0, PI * 1.1, PI * 1.9, 20, Ui.RED, 7.0)
	p.draw_rect(Rect2(h.x - 31, h.y - 4, 62, 20), Color("16202e"))
	p.draw_rect(Rect2(h.x - 26, h.y - 1, 30, 4), Color(0.55, 0.75, 1.0, 0.6))
	p.draw_rect(Rect2(h.x - 22, h.y + 22, 44, 6), Color(0.1, 0.11, 0.14))
