extends Control
## Главное меню: заставка, выбор Гран-при, настройки. Позади едет трасса —
## те же Track и Car, что в гонке.

const RACE_SCENE := "res://scenes/Race.tscn"

var _backdrop: Node2D
var _track: Track
var _car: Car
var _page: Control
var _page_name := ""
var _wander := 2.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop = Node2D.new()
	add_child(_backdrop)
	_track = Track.new()
	_backdrop.add_child(_track)
	_car = Car.new()
	_car.position = Vector2(Track.lane_x(1), Track.CAR_Y)
	_backdrop.add_child(_car)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	get_viewport().size_changed.connect(_fit)
	_fit()
	Sfx.engine(false)
	if GameData.menu_page == "levels" and GameData.menu_group != "":
		_show_races(GameData.menu_group)
	elif GameData.menu_page == "levels":
		_show_levels()
	else:
		_show_title()
	GameData.menu_page = "title"


func _process(delta: float) -> void:
	_track.travelled += 300.0 * delta
	_wander -= delta
	if _wander <= 0.0:
		_wander = randf_range(1.5, 3.5)
		_car.set_lane(randi() % Track.LANES)


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		return
	get_viewport().set_input_as_handled()
	if _page_name != "title":
		_back()
	elif OS.has_feature("android"):
		get_tree().quit()


func _fit() -> void:
	var view := get_viewport_rect().size
	var origin := ((view - Vector2(1280, 720)) * 0.5).floor()
	_backdrop.position = origin
	_track.view_top = -origin.y - 200.0
	_track.view_bottom = view.y - origin.y + 200.0


func _back() -> void:
	if _page_name == "settings":
		GameData.save_settings()
	if _page_name == "races":
		_show_levels()
	else:
		_show_title()


# --- Страницы -----------------------------------------------------------------

func _new_page(page_name: String, width: float) -> VBoxContainer:
	if _page:
		_page.queue_free()
	_page_name = page_name
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_page = center
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(width, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	return col


func _heading(col: VBoxContainer, text: String, size := 46) -> void:
	var l := Ui.label(text, size, Ui.WHITE)
	l.add_theme_font_override("font", Ui.title)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)


func _show_title() -> void:
	var col := _new_page("title", 520)
	var flag := HBoxContainer.new()
	flag.alignment = BoxContainer.ALIGNMENT_CENTER
	flag.add_theme_constant_override("separation", 0)
	for c: Color in [Color("009246"), Color("f4f5f0"), Color("ce2b37")]:
		var stripe := ColorRect.new()
		stripe.color = c
		stripe.custom_minimum_size = Vector2(70, 10)
		flag.add_child(stripe)
	col.add_child(flag)
	var top := Ui.label("FORMULA", 92, Ui.WHITE)
	top.add_theme_font_override("font", Ui.title)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(top)
	top.add_child(SplashText.new("Developed by Grigory Dubtzov"))
	var bottom := Ui.label("GRAMMATICA", 92, Ui.RED)
	bottom.add_theme_font_override("font", Ui.title)
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_theme_constant_override("line_spacing", -20)
	col.add_child(bottom)
	var sub := Ui.label("Il Gran Premio della grammatica italiana", 24, Ui.GREY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(_spacer(18))
	var start := Ui.button("Inizia la Corsa", _show_levels, 28)
	start.custom_minimum_size.y = 66
	col.add_child(start)
	col.add_child(Ui.button("Impostazioni", _show_settings))
	if not OS.has_feature("web"):
		col.add_child(Ui.button("Esci", get_tree().quit))
	col.add_child(_spacer(10))
	var hint := "Frecce o A D: cambia corsia   ·   Esc: pausa   ·   F11: schermo intero"
	if Ui.touch:
		hint = "Tocca una corsia per cambiarla   ·   II: pausa"
	var keys := Ui.label(hint, 16, Ui.GREY)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(keys)
	start.grab_focus.call_deferred()


## Первая ступень выбора: чемпионаты (разделы грамматики).
func _show_levels() -> void:
	var col := _new_page("levels", 720)
	_heading(col, "Scegli il campionato")
	var sub := Ui.label("Ogni campionato è una parte della grammatica, ogni gara è un argomento.", 18, Ui.GREY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var list := _scroll_list(col, GameData.campionati.size() + 1)
	var first: Button = null
	for c in GameData.campionati:
		var id := str(c["id"])
		var races := GameData.levels_of(id)
		if races.is_empty():
			continue
		var done := 0
		for r in races:
			if GameData.record(str(r["id"])) > 0:
				done += 1
		var b := _row_button(str(c["title"]), str(c.get("subtitle", "")),
			"%d gare\nfinite: %d" % [races.size(), done], _show_races.bind(id))
		list.add_child(b)
		if first == null:
			first = b
	if not GameData.levels.is_empty():
		var all := GameData.endless_level()
		list.add_child(_row_button("Gara infinita", "Tutta la grammatica, senza fine", _record_text(all), _start.bind(all)))
	else:
		list.add_child(Ui.label("Nessun livello trovato in data/levels.", 20, Ui.WRONG))
	var back := Ui.button("Indietro", _back)
	col.add_child(back)
	if first:
		first.grab_focus.call_deferred()
	else:
		back.grab_focus.call_deferred()


## Вторая ступень: заезды одного чемпионата.
func _show_races(id: String) -> void:
	var races := GameData.levels_of(id)
	if races.is_empty():
		_show_levels()
		return
	GameData.menu_group = id
	var c := GameData.campionato(id)
	var col := _new_page("races", 720)
	_heading(col, str(c.get("title", "Gare")), 40)
	var sub := Ui.label(str(c.get("subtitle", "")), 18, Ui.GREY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var list := _scroll_list(col, races.size() + 1)
	var first: Button = null
	for level in races:
		var b := _level_button(level)
		list.add_child(b)
		if first == null:
			first = b
	list.add_child(_level_button(GameData.endless_level(id)))
	col.add_child(Ui.button("Indietro", _back))
	first.grab_focus.call_deferred()


## Прокручиваемый список кнопок; поля — чтобы скошенные углы не обрезались.
func _scroll_list(col: VBoxContainer, rows: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(720, mini(440, rows * 86))
	col.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	scroll.add_child(margin)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	margin.add_child(list)
	return list


func _level_button(level: Dictionary) -> Button:
	var count: Array = level["questions"]
	var endless := bool(level.get("endless", false))
	var info := ("senza fine" if endless else "%d domande" % count.size()) + "\n" + _record_text(level)
	return _row_button(str(level["title"]), str(level["topic"]), info, _start.bind(level))


func _record_text(level: Dictionary) -> String:
	var best := GameData.record(str(level["id"]))
	return "Record: %d" % best if best > 0 else "Record: —"


## Широкая кнопка: слева заголовок и подпись, справа сведения.
func _row_button(title: String, topic: String, info_text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(680, 76)
	b.pressed.connect(func() -> void: Sfx.play("click"))
	b.pressed.connect(on_press)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 30
	row.offset_right = -30
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)
	names.add_child(Ui.label(title, 24, Ui.WHITE, true))
	var topic_label := Ui.label(topic, 18, Color(1, 1, 1, 0.72))
	topic_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(topic_label)
	var info := Ui.label(info_text, 16, Color(1, 1, 1, 0.72))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	return b


func _show_settings() -> void:
	var col := _new_page("settings", 640)
	_heading(col, "Impostazioni")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 16)
	col.add_child(grid)

	var pace := OptionButton.new()
	for n: String in GameData.PACE_NAMES:
		pace.add_item(n)
	pace.selected = GameData.pace
	pace.item_selected.connect(func(i: int) -> void: GameData.pace = i)
	_setting(grid, "Velocità di gara", pace)

	var lives := OptionButton.new()
	for n: String in GameData.LIVES_NAMES:
		lives.add_item(n)
	lives.selected = GameData.lives_option
	lives.item_selected.connect(func(i: int) -> void: GameData.lives_option = i)
	_setting(grid, "Vite", lives)

	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = GameData.volume
	volume.custom_minimum_size = Vector2(340, 32)
	volume.value_changed.connect(func(v: float) -> void:
		GameData.volume = v
		GameData.apply_settings())
	volume.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("correct"))
	_setting(grid, "Volume", volume)

	if not OS.has_feature("mobile"):
		var full := OptionButton.new()
		full.add_item("No")
		full.add_item("Sì")
		full.selected = 1 if GameData.fullscreen else 0
		full.item_selected.connect(func(i: int) -> void:
			GameData.fullscreen = i == 1
			GameData.apply_settings())
		_setting(grid, "Schermo intero", full)

	var note := Ui.label("La velocità decide quanto tempo hai per leggere ogni frase.\nCon le vite illimitate la gara non finisce mai per un errore.", 16, Ui.GREY)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)
	var back := Ui.button("Indietro", _back)
	col.add_child(back)
	pace.grab_focus.call_deferred()


func _setting(grid: GridContainer, text: String, control: Control) -> void:
	var l := Ui.label(text, 22, Ui.WHITE, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _start(level: Dictionary) -> void:
	GameData.selected = level
	get_tree().change_scene_to_file(RACE_SCENE)
