extends SceneTree
## Проверка без окна: скрипты компилируются, уровни читаются, гонка доходит
## до финиша и до схода, очки считаются как задумано.

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("OK   ", what)
	else:
		_fails += 1
		printerr("FAIL ", what)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


func _run() -> void:
	for path in _scripts("res://scripts"):
		var s := load(path) as GDScript
		_check(s != null and s.can_instantiate(), "compila " + path)
	var gd: Node = root.get_node("GameData")
	_check(gd.persist == false, "con -s non scrive i file del giocatore")
	_check(gd.levels.size() == 4, "4 livelli (%d)" % gd.levels.size())
	var expected := {"preposizioni_semplici": 18, "preposizioni_articolate": 18, "fusione": 23, "preposizioni_complesse": 18}
	for l: Dictionary in gd.levels:
		_check(l["questions"].size() == expected.get(l["id"], -1), "%s: %d domande" % [l["id"], l["questions"].size()])
	var ui: GDScript = load("res://scripts/ui/Ui.gd")
	var filled: String = ui.filled("Oggi nessuno vive ___ isola.", "sull'")
	_check(filled.contains("[/b][/color]isola"), "sull' attaccato: " + filled)
	var wrong: String = ui.filled("Vado ___ Roma.", "a", "in")
	_check(wrong.contains("[s]in[/s]") and wrong.contains("[b]a[/b]"), "sbagliata barrata: " + wrong)
	var dlg: Node = root.get_node("Dialogue")
	_check(dlg.line("wrong", {"answer": "sul"}).contains("«sul»"), "battuta con {answer}")
	_check(dlg.sequence("intro").size() == 5, "intro di 5 battute")

	Engine.time_scale = 10.0
	gd.pace = 2
	# 1) finish: wrong at questions 3 and 7, all others right
	var race := await _race(gd.levels[0], [3, 7])
	_check(race.answered == 18, "finale: 18 risposte (%d)" % race.answered)
	_check(race.right == 16, "finale: 16 giuste (%d)" % race.right)
	_check(race.lives == 1, "finale: 1 vita (%d)" % race.lives)
	_check(race.nitros == 5, "finale: 5 nitro (%d)" % race.nitros)
	_check(race.score == 4050, "finale: 4050 punti (%d)" % race.score)
	_check(race.mistakes.size() == 2, "finale: 2 errori da ripassare")
	_check(race.get_node_or_null("ResultsScreen") != null or _has_results(race), "finale: schermata dei risultati")
	race.queue_free()
	await process_frame
	# 2) game over: everything wrong
	race = await _race(gd.levels[3], range(100))
	_check(race.answered == 3 and race.lives == 0, "ritiro dopo 3 errori (%d, %d)" % [race.answered, race.lives])
	_check(_has_results(race), "ritiro: schermata dei risultati")
	race.queue_free()
	await process_frame
	# 3) endless with unlimited lives keeps going past the total
	gd.lives_option = 2
	race = await _race(gd.endless_level(), [], 80)
	_check(race.answered == 80 and race.state != 4, "gara infinita: 80 domande e si continua (%d)" % race.answered)
	_check(race.questions.size() >= 80, "gara infinita: domande rimescolate di nuovo")
	race.queue_free()
	await process_frame
	gd.lives_option = 0
	Engine.time_scale = 1.0
	print("--- %s ---" % ("TUTTO OK" if _fails == 0 else "%d ERRORI" % _fails))
	quit(_fails)


func _has_results(race: Node) -> bool:
	for c in race.get_children():
		if c.get_class() == "CanvasLayer" and c.get_script() and str(c.get_script().resource_path).ends_with("ResultsScreen.gd"):
			return true
	return false


## Гонит гонку: wrong — номера вопросов, где ехать в неверную полосу.
## stop_after > 0 — остановиться после стольких ответов.
func _race(level: Dictionary, wrong: Array, stop_after := 0) -> Node:
	var gd: Node = root.get_node("GameData")
	gd.selected = level
	var race: Node = load("res://scenes/Race.tscn").instantiate()
	root.add_child(race)
	await process_frame
	race._start_lights()
	var guard := 0
	while race.state == 1 and guard < 20000:
		guard += 1
		await process_frame
	while race.state != 4 and guard < 200000:
		guard += 1
		if stop_after > 0 and race.answered >= stop_after:
			break
		if race.gate != null:
			var correct: int = race.question["correct"]
			var lane := correct if not race.q_index in wrong else (correct + 1) % 3
			race.car.set_lane(lane)
		await process_frame
	if race.state == 4:
		for i in 60:
			await process_frame
		var t := 0
		while not _has_results(race) and t < 5000:
			t += 1
			await process_frame
	return race
