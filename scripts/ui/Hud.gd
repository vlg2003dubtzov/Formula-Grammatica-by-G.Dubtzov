class_name Hud
extends CanvasLayer
## Интерфейс гонки: карточка с фразой сверху, табло справа, Кими слева внизу,
## стартовый светофор и крупные вспышки («VIA!», «NITRO!»).

signal skip_intro
signal pause_pressed

## Плашки ответов стоят ровно над полосами: CHIP_W + CHIP_GAP = Track.LANE_W.
const CHIP_W := 180.0
const CHIP_GAP := 10.0

var kimi: KimiPanel
var lights: StartLights

var _root: Control
var _card: PanelContainer
var _sentence: RichTextLabel
var _hint: Label
var _chips: Array[PanelContainer] = []
var _chip_labels: Array[Label] = []
var _distance: Label
var _lane := 1
var _answer := -1
var _chosen := -1

var _level: Label
var _topic: Label
var _score: Label
var _speed: Label
var _speed_bar: ProgressBar
var _progress: Label
var _streak: Label
var _nitro: Control
var _nitro_charge := 0
var _nitro_left := 0.0
var _lives: Control
var _lives_now := 3
var _lives_max := 3

var _flash: ColorRect
var _banner: Label
var _skip: Button

var _chip_styles := {
	"normal": Ui.box(Color(0.13, 0.14, 0.18), Color(1, 1, 1, 0.2), 2, 0.0, 4),
	"lane": Ui.box(Color(0.22, 0.23, 0.29), Ui.WHITE, 3, 0.0, 4),
	"right": Ui.box(Ui.GREEN, Ui.GREEN_LIGHT, 3, 0.0, 4),
	"wrong": Ui.box(Ui.WRONG.darkened(0.3), Ui.WRONG, 3, 0.0, 4),
	"faded": Ui.box(Color(0.13, 0.14, 0.18, 0.4), Color(1, 1, 1, 0.08), 2, 0.0, 4),
}


func _ready() -> void:
	_root = Ui.layer_root(self)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_build_card()
	_build_stats()
	_build_kimi()
	_build_lights()
	_build_banner()
	_build_buttons()
	_ignore_mouse(_root)


func setup(level: Dictionary, total: int, lives: int, endless: bool) -> void:
	_level.text = str(level.get("title", ""))
	_topic.text = str(level.get("topic", ""))
	_lives_max = maxi(lives, 0)
	set_lives(lives)
	set_progress(0, 0 if endless else total)
	set_score(0)
	set_streak(0, 1)


# --- Карточка с фразой --------------------------------------------------------

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", Ui.box(Color(0.05, 0.06, 0.08, 0.94), Color(1, 1, 1, 0.12), 2, 0.0, 6))
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.offset_left = -320
	_card.offset_right = 320
	_card.offset_top = 10
	_card.offset_bottom = 10
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_card.add_child(col)
	_sentence = Ui.rich(30)
	_sentence.add_theme_font_override("normal_font", Ui.bold)
	col.add_child(_sentence)
	_hint = Ui.label("", 20, Ui.AMBER, true)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(CHIP_GAP))
	col.add_child(row)
	for i in Track.LANES:
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(CHIP_W, 46)
		var l := Ui.label("", 24, Ui.WHITE, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_child(l)
		row.add_child(chip)
		_chips.append(chip)
		_chip_labels.append(l)
	_distance = Ui.label("", 16, Ui.GREY)
	_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_distance)
	_card.visible = false


func show_question(q: Dictionary) -> void:
	_card.visible = true
	_answer = -1
	_chosen = -1
	_sentence.text = "[center]%s[/center]" % Ui.blank(str(q["sentence"]))
	var hint := str(q.get("hint", ""))
	_hint.text = hint + " = ?" if hint != "" else ""
	_hint.visible = hint != ""
	var opts: Array = q["options"]
	for i in Track.LANES:
		var word := str(opts[i])
		_chip_labels[i].text = word
		_chip_labels[i].add_theme_font_size_override("font_size", Ui.fit_size(word, CHIP_W - 14.0, 26, 13))
	_refresh_chips()
	_card.modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(_card, "modulate", Color.WHITE, 0.35)


## Фраза с верным ответом; неверный выбор — зачёркнут.
func show_answer(q: Dictionary, chosen: int) -> void:
	var opts: Array = q["options"]
	_answer = int(q["correct"])
	_chosen = chosen
	var wrong := "" if chosen == _answer else str(opts[chosen])
	_sentence.text = "[center]%s[/center]" % Ui.filled(str(q["sentence"]), str(opts[_answer]), wrong)
	_distance.text = ""
	_refresh_chips()


func hide_card() -> void:
	_card.visible = false


func set_lane(lane: int) -> void:
	_lane = lane
	_refresh_chips()


## Метров до арки; отрицательное — строку прячем.
func set_distance(meters: float) -> void:
	_distance.text = "" if meters < 0.0 or _answer >= 0 else "porta tra %d m" % ceili(meters)


func _refresh_chips() -> void:
	for i in _chips.size():
		var key := "normal"
		if _answer >= 0:
			key = "right" if i == _answer else ("wrong" if i == _chosen else "faded")
		elif i == _lane:
			key = "lane"
		_chips[i].add_theme_stylebox_override("panel", _chip_styles[key])


# --- Табло справа -------------------------------------------------------------

func _build_stats() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -296
	panel.offset_right = -12
	panel.offset_top = 10
	panel.offset_bottom = 10
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	_level = Ui.label("", 22, Ui.WHITE, true)
	_level.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_level)
	_topic = Ui.label("", 16, Ui.RED, true)
	_topic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_topic)
	col.add_child(_gap(8))
	col.add_child(_caption("PUNTI"))
	_score = Ui.label("0", 44, Ui.WHITE, true)
	col.add_child(_score)
	col.add_child(_caption("VELOCITÀ"))
	_speed = Ui.label("0 km/h", 28, Ui.WHITE, true)
	col.add_child(_speed)
	_speed_bar = ProgressBar.new()
	_speed_bar.max_value = 1.0
	_speed_bar.step = 0.0
	_speed_bar.show_percentage = false
	_speed_bar.custom_minimum_size = Vector2(0, 8)
	_speed_bar.add_theme_stylebox_override("background", Ui.box(Color(1, 1, 1, 0.1)))
	_speed_bar.add_theme_stylebox_override("fill", Ui.box(Ui.RED))
	col.add_child(_speed_bar)
	col.add_child(_gap(6))
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 20)
	col.add_child(pair)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_caption("DOMANDA"))
	_progress = Ui.label("", 26, Ui.WHITE, true)
	left.add_child(_progress)
	pair.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_caption("SERIE"))
	_streak = Ui.label("0", 26, Ui.WHITE, true)
	right.add_child(_streak)
	pair.add_child(right)
	col.add_child(_gap(6))
	col.add_child(_caption("NITRO · 3 GIUSTE DI FILA"))
	_nitro = Control.new()
	_nitro.custom_minimum_size = Vector2(0, 20)
	_nitro.draw.connect(_draw_nitro)
	col.add_child(_nitro)
	col.add_child(_gap(6))
	col.add_child(_caption("VITE"))
	_lives = Control.new()
	_lives.custom_minimum_size = Vector2(0, 32)
	_lives.draw.connect(_draw_lives)
	col.add_child(_lives)


func _caption(text: String) -> Label:
	return Ui.label(text, 14, Ui.GREY, true)


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func set_score(score: int) -> void:
	_score.text = str(score)


func set_speed(kmh: float, ratio: float) -> void:
	_speed.text = "%d km/h" % roundi(kmh)
	_speed_bar.value = clampf(ratio, 0.0, 1.0)


func set_progress(i: int, total: int) -> void:
	_progress.text = "%d / %d" % [i, total] if total > 0 else str(i)


func set_streak(streak: int, mult: int) -> void:
	_streak.text = "%d  ×%d" % [streak, mult] if mult > 1 else str(streak)


func set_lives(lives: int) -> void:
	_lives_now = lives
	_lives.queue_redraw()


## charge — сколько верных подряд накоплено к следующему нитро; left — 1…0, пока нитро горит.
func set_nitro(charge: int, left: float) -> void:
	if charge == _nitro_charge and is_equal_approx(left, _nitro_left):
		return
	_nitro_charge = charge
	_nitro_left = left
	_nitro.queue_redraw()


func _draw_nitro() -> void:
	var w := (_nitro.size.x - 16.0) / 3.0
	for i in 3:
		var x := i * (w + 8.0)
		var pts := PackedVector2Array([Vector2(x + 6, 0), Vector2(x + w + 6, 0), Vector2(x + w, 18), Vector2(x, 18)])
		_nitro.draw_colored_polygon(pts, Color(1, 1, 1, 0.1))
		var fill := 0.0
		if _nitro_left > 0.0:
			fill = clampf(_nitro_left * 3.0 - i, 0.0, 1.0)
		elif i < _nitro_charge:
			fill = 1.0
		if fill > 0.0:
			var fw := w * fill
			_nitro.draw_colored_polygon(PackedVector2Array([Vector2(x + 6, 0), Vector2(x + fw + 6, 0), Vector2(x + fw, 18), Vector2(x, 18)]), Ui.NITRO)


func _draw_lives() -> void:
	if _lives_now < 0:
		_lives.draw_string(Ui.bold, Vector2(0, 24), "senza limiti", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.text_size(22), Ui.WHITE)
		return
	for i in _lives_max:
		var c := Vector2(16 + i * 38, 16)
		if i < _lives_now:
			_lives.draw_circle(c, 15.0, Color(0.07, 0.07, 0.08))
			_lives.draw_arc(c, 11.0, 0.0, TAU, 28, Ui.RED, 2.5)
			_lives.draw_circle(c, 6.0, Color(0.55, 0.57, 0.6))
		else:
			_lives.draw_arc(c, 14.0, 0.0, TAU, 28, Color(1, 1, 1, 0.22), 2.0)


# --- Кими, светофор, вспышки, кнопки ------------------------------------------

func _build_kimi() -> void:
	kimi = KimiPanel.new()
	kimi.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	kimi.offset_left = 12
	kimi.offset_right = 12 + 324
	kimi.offset_top = -12 - 380
	kimi.offset_bottom = -12
	kimi.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(kimi)


func _build_lights() -> void:
	lights = StartLights.new()
	lights.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lights.offset_left = -240
	lights.offset_right = 240
	lights.offset_top = 70
	lights.offset_bottom = 240
	lights.visible = false
	_root.add_child(lights)


func _build_banner() -> void:
	_banner = Ui.label("", 110, Ui.WHITE)
	_banner.add_theme_font_override("font", Ui.title)
	_banner.add_theme_constant_override("outline_size", 16)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = -90
	_banner.offset_bottom = 90
	_banner.modulate.a = 0.0
	_root.add_child(_banner)


func _build_buttons() -> void:
	_skip = Button.new()
	_skip.text = "Salta  »"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skip.offset_left = -90
	_skip.offset_right = 90
	_skip.offset_top = -70
	_skip.offset_bottom = -16
	_skip.pressed.connect(func() -> void: skip_intro.emit())
	_root.add_child(_skip)
	var pause := Button.new()
	pause.text = "II"
	pause.tooltip_text = "Pausa (Esc)"
	pause.focus_mode = Control.FOCUS_NONE
	pause.position = Vector2(12, 10)
	pause.custom_minimum_size = Vector2(64, 52)
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	_root.add_child(pause)


func intro_done() -> void:
	_skip.visible = false


func flash(color: Color) -> void:
	_flash.color = color
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)


func banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(0.6, 0.6)
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.35)


## Клики и касания проходят сквозь табло к гонке (выбор полосы); ловят их только кнопки.
func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control and not child is BaseButton:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)
