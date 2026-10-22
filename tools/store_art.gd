extends SceneTree
## Картинки для страницы в магазине: значок 512×512, баннер 1024×500 и
## скриншоты 1920×1080 из настоящей игры в «телефонном» виде (крупный текст,
## подсказки про касания). Запуск в окне:
##   godot --path . -s res://tools/store_art.gd -- store
##
## Классы игры (Ui, Track, Car) берутся через load() уже после старта: при
## компиляции этого файла автозагрузки (Sfx, GameData) ещё не доступны.

const SIZE := Vector2i(1920, 1080)

var _dir := ""
var _gd: Node
var UiS: GDScript
var TrackS: GDScript
var CarS: GDScript


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "store"
	if _dir.is_relative_path():
		_dir = ProjectSettings.globalize_path("res://").path_join(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	_run.call_deferred()


func _run() -> void:
	UiS = load("res://scripts/ui/Ui.gd")
	TrackS = load("res://scripts/race/Track.gd")
	CarS = load("res://scripts/race/Car.gd")
	UiS.touch = true
	_gd = root.get_node("GameData")
	_gd.persist = false
	# окно без рамки ровно SIZE, иначе Windows урежет его под панель задач
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_position(Vector2i.ZERO)
	DisplayServer.window_set_size(SIZE)
	for i in 10:
		await process_frame
	_icon()
	await _banner()
	await _screens()
	print("store art -> ", _dir)
	quit()


func _save(img: Image, name: String) -> void:
	img.save_png(_dir.path_join(name))
	print("  %s  %dx%d" % [name, img.get_width(), img.get_height()])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_save(root.get_texture().get_image(), name)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _icon() -> void:
	var img := Image.new()
	img.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"), 4.0)
	_save(img, "icona_512.png")


## Баннер 1024×500: слева название, справа трасса с аркой ответов и болидом.
func _banner() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 500)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var world := Node2D.new()
	var right: float = TrackS.RIGHT
	world.scale = Vector2(0.78, 0.78)
	world.position = Vector2(1024.0 - right * 0.78 - 30.0, -70.0)
	vp.add_child(world)
	var track: Node2D = TrackS.new()
	world.add_child(track)
	track.travelled = 237.0
	var gate: Node2D = (load("res://scenes/race/AnswerGate.tscn") as PackedScene).instantiate()
	world.add_child(gate)
	var words: Array[String] = ["a", "in", "da"]
	gate.setup(words, 0)
	gate.position.y = 255.0
	var car: Node2D = CarS.new()
	world.add_child(car)
	car.position = Vector2(TrackS.lane_x(0) + 70.0, TrackS.CAR_Y)
	car.lane = 0
	car.nitro = true

	var ui := Control.new()
	ui.theme = UiS.theme
	ui.size = Vector2(1024, 500)
	vp.add_child(ui)
	var fade := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.width = 640
	grad.height = 8
	grad.fill_to = Vector2(1, 0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.66, 1.0])
	g.colors = PackedColorArray([Color(0.04, 0.05, 0.07, 1.0), Color(0.04, 0.05, 0.07, 0.97), Color(0.04, 0.05, 0.07, 0.0)])
	grad.gradient = g
	fade.texture = grad
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.size = Vector2(640, 500)
	ui.add_child(fade)
	var stripe_x := 64.0
	for c: Color in [Color("009246"), Color("f4f5f0"), Color("ce2b37")]:
		var s := ColorRect.new()
		s.color = c
		s.position = Vector2(stripe_x, 108)
		s.size = Vector2(56, 9)
		ui.add_child(s)
		stripe_x += 56.0
	_text(ui, "FORMULA", Vector2(56, 118), 88, UiS.WHITE, UiS.title)
	_text(ui, "GRAMMATICA", Vector2(56, 208), 88, UiS.RED, UiS.title)
	_text(ui, "Le preposizioni italiane a tutta velocità", Vector2(62, 318), 26, UiS.GREY, UiS.font)
	_text(ui, "Developed by Grigory Dubtzov", Vector2(62, 410), 22, Color("ffff00"), UiS.title)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	_save(vp.get_texture().get_image(), "banner_1024x500.png")
	vp.queue_free()


func _text(parent: Control, text: String, pos: Vector2, size: int, colour: Color, font: Font) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	parent.add_child(l)


func _level(id: String) -> Dictionary:
	for l: Dictionary in _gd.levels:
		if l["id"] == id:
			return l
	return _gd.levels[0]


## Скриншоты из настоящей игры.
func _screens() -> void:
	var menu: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	await _wait(0.9)
	await _shot("screen_1_menu.png")
	menu._show_levels()
	await _wait(0.4)
	await _shot("screen_2_campionati.png")
	menu.queue_free()

	_gd.selected = _gd.levels[0]
	var race: Node = load("res://scenes/Race.tscn").instantiate()
	root.add_child(race)
	await _wait(0.4)
	race._start_lights()
	while race.state == 1:
		await process_frame
	# вопрос: машина перестраивается к верному ответу, арка на подходе
	while race.gate == null or race.gate.position.y < 300.0:
		await process_frame
	race.car.set_lane(race.question["correct"])
	await _wait(0.12)
	await _shot("screen_3_domanda.png")
	# три верных подряд — нитро
	while race.right < 3:
		if race.gate != null:
			race.car.set_lane(race.question["correct"])
		await process_frame
	await _wait(0.3)
	await _shot("screen_4_nitro.png")
	# ошибка: ведущий объясняет правило
	while race.answered < 4:
		if race.gate != null:
			race.car.set_lane((int(race.question["correct"]) + 1) % 3)
		await process_frame
	await _wait(0.3)
	race.hud.guide.finish_typing()
	await _shot("screen_5_errore.png")
	# до финиша — без ошибок
	Engine.time_scale = 8.0
	while race.state != 4:
		if race.gate != null:
			race.car.set_lane(race.question["correct"])
		await process_frame
	Engine.time_scale = 1.0
	await _wait(3.0)
	await _shot("screen_7_traguardo.png")
	race.queue_free()

	_gd.selected = _level("fusione")
	race = load("res://scenes/Race.tscn").instantiate()
	root.add_child(race)
	await _wait(0.3)
	race._start_lights()
	while race.state == 1:
		await process_frame
	while race.gate == null or race.gate.position.y < 250.0:
		await process_frame
	race.car.set_lane(race.question["correct"])
	await _wait(0.12)
	await _shot("screen_6_fusione.png")
	race.queue_free()
