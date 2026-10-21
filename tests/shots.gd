extends SceneTree
## Снимки экрана: меню, вступление, светофор, вопрос, ошибка, нитро, итоги.
## Запуск в окне: --resolution 1280x720 -s shots.gd -- <папка>

var _dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join(name + ".png"))
	print("shot ", name)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _run() -> void:
	var gd: Node = root.get_node("GameData")
	var menu: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	await _wait(0.8)
	await _shot("01_menu")
	menu._show_levels()
	await _wait(0.4)
	await _shot("02_livelli")
	menu._show_settings()
	await _wait(0.4)
	await _shot("03_impostazioni")
	menu.queue_free()

	gd.selected = gd.levels[0]
	var race: Node = load("res://scenes/Race.tscn").instantiate()
	root.add_child(race)
	await _wait(0.5)
	race.hud.guide.finish_typing()
	await _shot("04_intro")
	race._start_lights()
	await _wait(2.6)
	await _shot("05_semaforo")
	while race.state == 1:
		await process_frame
	# вопрос: ждём, пока арка выедет на экран
	while race.gate == null or race.gate.position.y < 260.0:
		await process_frame
	race.car.set_lane(race.question["correct"])
	await _wait(0.15)
	await _shot("06_domanda")
	# три верных подряд — нитро
	while race.right < 3:
		if race.gate != null:
			race.car.set_lane(race.question["correct"])
		await process_frame
	await _wait(0.35)
	await _shot("07_nitro")
	# ошибка
	while race.answered < 4:
		if race.gate != null:
			race.car.set_lane((int(race.question["correct"]) + 1) % 3)
		await process_frame
	await _wait(0.25)
	race.hud.guide.finish_typing()
	await _shot("08_errore")
	await _wait(1.6)
	await _shot("09_dopo_errore")
	# доезжаем до финиша быстро
	Engine.time_scale = 8.0
	while race.state != 4:
		if race.gate != null:
			var c: int = race.question["correct"]
			race.car.set_lane(c if race.answered != 11 else (c + 1) % 3)
		await process_frame
	Engine.time_scale = 1.0
	await _wait(3.0)
	await _shot("10_risultati")
	race.queue_free()

	# слияние: подсказка под фразой
	gd.selected = gd.levels[2]
	race = load("res://scenes/Race.tscn").instantiate()
	root.add_child(race)
	await _wait(0.3)
	race._start_lights()
	while race.state == 1:
		await process_frame
	await _wait(1.0)
	await _shot("11_fusione")
	# сход: все неверно
	Engine.time_scale = 8.0
	while race.state != 4:
		if race.gate != null:
			race.car.set_lane((int(race.question["correct"]) + 2) % 3)
		await process_frame
	Engine.time_scale = 1.0
	await _wait(3.0)
	await _shot("12_ritiro")
	race._pause() # не должно открыться после схода
	race.queue_free()

	gd.selected = gd.levels[3]
	race = load("res://scenes/Race.tscn").instantiate()
	root.add_child(race)
	await _wait(0.3)
	race._start_lights()
	while race.state == 1:
		await process_frame
	await _wait(0.6)
	race._pause()
	await _wait(0.3)
	await _shot("13_pausa")
	paused = false
	quit()
