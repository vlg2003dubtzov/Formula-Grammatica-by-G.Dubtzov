extends Node
## Уровни, настройки и рекорды.
##
## Уровень — JSON-файл в res://data/levels (формат — в README). Уровни собраны в
## чемпионаты (data/campionati.json, поле «campionato» уровня). В собранной игре
## учитель может положить свои уровни в папку «livelli» рядом с .exe; уровни без
## известного чемпионата попадают в «Altre gare».

const LEVELS_DIR := "res://data/levels"
const CAMPIONATI_PATH := "res://data/campionati.json"
const OTHER := "altro"
const EXTRA_DIR := "livelli"
const SETTINGS_PATH := "user://impostazioni.cfg"
const RECORDS_PATH := "user://record.json"

const PACE_NAMES := ["Lenta · 10 secondi per frase", "Normale · 7 secondi per frase", "Veloce · 5 secondi per frase"]
const PACE_SECONDS := [10.0, 7.0, 5.0]
const LIVES_NAMES := ["3 vite", "5 vite", "Illimitate (allenamento)"]
const LIVES_VALUES := [3, 5, -1]

var levels: Array[Dictionary] = []
var campionati: Array[Dictionary] = []
## Уровень, который выбран в меню; гонка берёт его отсюда.
var selected: Dictionary = {}
## Какую страницу меню открыть при возврате из гонки и какой чемпионат в ней.
var menu_page := "title"
var menu_group := ""

var pace := 1
var lives_option := 0
var volume := 0.8
var fullscreen := false
var records: Dictionary = {}

## Запуски с -s (тесты, инструменты) читают файлы игрока, но не пишут их.
var persist := true


func _ready() -> void:
	var args := OS.get_cmdline_args()
	persist = not ("-s" in args or "--script" in args)
	Ui.setup()
	get_tree().root.theme = Ui.theme
	ThemeDB.fallback_font = Ui.font
	_setup_input()
	load_settings()
	_load_records()
	load_levels()
	apply_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		fullscreen = not fullscreen
		apply_settings()
		save_settings()


## Кнопка «назад» на Android работает как Esc: пауза в гонке, шаг назад в меню.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for pressed: bool in [true, false]:
			var ev := InputEventAction.new()
			ev.action = &"pause"
			ev.pressed = pressed
			Input.parse_input_event(ev)


func pace_seconds() -> float:
	return float(PACE_SECONDS[pace])


## −1 — жизни не кончаются (тренировка).
func start_lives() -> int:
	return int(LIVES_VALUES[lives_option])


# --- Уровни -------------------------------------------------------------------

func load_levels() -> void:
	levels.clear()
	var paths := _json_in(LEVELS_DIR)
	if not OS.has_feature("editor"):
		paths.append_array(_json_in(OS.get_executable_path().get_base_dir().path_join(EXTRA_DIR)))
	for path in paths:
		var level := read_level(path)
		if not level.is_empty():
			levels.append(level)
	_load_campionati()


func _load_campionati() -> void:
	campionati.clear()
	var data: Variant = null
	if FileAccess.file_exists(CAMPIONATI_PATH):
		data = JSON.parse_string(FileAccess.get_file_as_string(CAMPIONATI_PATH))
	if data is Dictionary:
		for c: Variant in (data as Dictionary).get("campionati", []):
			if c is Dictionary and (c as Dictionary).has("id"):
				campionati.append(c)
	var known: Array[String] = []
	for c in campionati:
		known.append(str(c["id"]))
	var orphans := false
	for level in levels:
		if not str(level["campionato"]) in known:
			level["campionato"] = OTHER
			orphans = true
	if orphans:
		campionati.append({"id": OTHER, "title": "Altre gare", "subtitle": "Livelli aggiunti dall'insegnante"})


func levels_of(campionato: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for level in levels:
		if campionato == "" or str(level["campionato"]) == campionato:
			out.append(level)
	return out


func campionato(id: String) -> Dictionary:
	for c in campionati:
		if str(c["id"]) == id:
			return c
	return {}


## Бесконечная гонка: все вопросы чемпионата (или всей игры) вперемешку.
func endless_level(id := "") -> Dictionary:
	var all: Array[Dictionary] = []
	for level in levels_of(id):
		var list: Array = level["questions"]
		for q: Dictionary in list:
			all.append(q)
	var c := campionato(id)
	return {
		"id": "gara_infinita" + ("_" + id if id != "" else ""),
		"title": "Gara infinita",
		"topic": str(c.get("subtitle", "Tutta la grammatica")) if not c.is_empty() else "Tutta la grammatica",
		"intro": Dialogue.line("endless"),
		"questions": all,
		"campionato": id,
		"endless": true,
	}


func _json_in(dir: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var names := DirAccess.get_files_at(dir)
	names.sort()
	for n in names:
		if n.get_extension().to_lower() == "json":
			out.append(dir.path_join(n))
	return out


## Читает и проверяет один файл уровня. Сломанный вопрос пропускается с
## предупреждением, чтобы одна опечатка не роняла всю гонку.
func read_level(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("%s: файл не читается как JSON" % path)
		return {}
	if OS.has_feature("web"):
		data = _web_safe(data)
	var level: Dictionary = data
	var good: Array[Dictionary] = []
	var list: Variant = level.get("questions", [])
	if list is Array:
		for q: Variant in list:
			var problem := question_problem(q)
			if problem == "":
				var item: Dictionary = q
				item["correct"] = int(item["correct"])
				good.append(item)
			else:
				push_warning("%s: %s" % [path.get_file(), problem])
	if good.is_empty():
		push_warning("%s: ни одного годного вопроса" % path)
		return {}
	level["questions"] = good
	level["id"] = str(level.get("level_id", path.get_file().get_basename()))
	level["title"] = str(level.get("title", level["id"]))
	level["topic"] = str(level.get("topic", ""))
	level["campionato"] = str(level.get("campionato", OTHER))
	return level


## В браузере нет системных шрифтов, а во встроенном нет стрелки «→».
func _web_safe(v: Variant) -> Variant:
	if v is String:
		return (v as String).replace("→", "—")
	if v is Array:
		return (v as Array).map(_web_safe)
	if v is Dictionary:
		var d: Dictionary = v
		for k: Variant in d.keys():
			d[k] = _web_safe(d[k])
		return d
	return v


## Пустая строка — вопрос годен; иначе — что с ним не так.
func question_problem(q: Variant) -> String:
	if not q is Dictionary:
		return "вопрос — не объект {...}"
	var d: Dictionary = q
	var sentence := str(d.get("sentence", ""))
	if sentence.count("___") != 1:
		return "«%s»: нужен ровно один пропуск ___" % sentence
	var options: Variant = d.get("options")
	if not options is Array or (options as Array).size() != 3:
		return "«%s»: нужно ровно 3 ответа" % sentence
	var seen: Array[String] = []
	for o: Variant in options:
		var word := str(o).strip_edges()
		if word == "" or word in seen:
			return "«%s»: ответы пустые или повторяются" % sentence
		seen.append(word)
	var c: Variant = d.get("correct")
	if not (c is int or c is float) or int(c) < 0 or int(c) > 2:
		return "«%s»: correct должен быть 0, 1 или 2" % sentence
	return ""


# --- Настройки ----------------------------------------------------------------

func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) != OK:
		return
	pace = clampi(int(c.get_value("gara", "velocita", pace)), 0, PACE_SECONDS.size() - 1)
	lives_option = clampi(int(c.get_value("gara", "vite", lives_option)), 0, LIVES_VALUES.size() - 1)
	volume = clampf(float(c.get_value("audio", "volume", volume)), 0.0, 1.0)
	fullscreen = bool(c.get_value("video", "schermo_intero", fullscreen))


func save_settings() -> void:
	if not persist:
		return
	var c := ConfigFile.new()
	c.set_value("gara", "velocita", pace)
	c.set_value("gara", "vite", lives_option)
	c.set_value("audio", "volume", volume)
	c.set_value("video", "schermo_intero", fullscreen)
	c.save(SETTINGS_PATH)


func apply_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))
	# на телефоне окном управляет система
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# --- Рекорды ------------------------------------------------------------------

func record(id: String) -> int:
	return int(records.get(id, 0))


## true — новый рекорд.
func submit_score(id: String, score: int) -> bool:
	if score <= record(id):
		return false
	records[id] = score
	if persist:
		var f := FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(records, "  "))
	return true


func _load_records() -> void:
	if not FileAccess.file_exists(RECORDS_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECORDS_PATH))
	if data is Dictionary:
		records = data


# --- Управление ---------------------------------------------------------------

func _setup_input() -> void:
	_bind("lane_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT])
	_bind("lane_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT])
	_bind("lane_1", [KEY_1, KEY_KP_1], [])
	_bind("lane_2", [KEY_2, KEY_KP_2], [])
	_bind("lane_3", [KEY_3, KEY_KP_3], [])
	_bind("advance", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_A])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_bind("fullscreen", [KEY_F11], [])


## Физические клавиши: A и D работают и при русской раскладке.
func _bind(action: StringName, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b: JoyButton in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
