extends SceneTree
## Проверка без окна: скрипты компилируются, все заезды и чемпионаты читаются,
## меню строится, гонка доходит до финиша и до схода, очки считаются верно.
##   godot --headless --path . -s res://tests/test_logic.gd

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


func _level(gd: Node, id: String) -> Dictionary:
	for l: Dictionary in gd.levels:
		if l["id"] == id:
			return l
	return {}


func _run() -> void:
	for path in _scripts("res://scripts"):
		var s := load(path) as GDScript
		_check(s != null and s.can_instantiate(), "compila " + path)
	var gd: Node = root.get_node("GameData")
	_check(gd.persist == false, "con -s non scrive i file del giocatore")

	# --- contenuti ---
	_check(gd.campionati.size() == 8, "8 campionati (%d)" % gd.campionati.size())
	_check(gd.levels.size() == 41, "41 gare (%d)" % gd.levels.size())
	var ids := {}
	var total := 0
	for l: Dictionary in gd.levels:
		var qs: Array = l["questions"]
		total += qs.size()
		_check(qs.size() >= 12, "%s: almeno 12 domande (%d)" % [l["id"], qs.size()])
		_check(l["campionato"] != "altro", "%s: campionato noto (%s)" % [l["id"], l["campionato"]])
		_check(not ids.has(l["id"]), "%s: id unico" % l["id"])
		ids[l["id"]] = true
		var seen := {}
		for q: Dictionary in qs:
			if seen.has(q["sentence"]):
				_check(false, "%s: frase ripetuta «%s»" % [l["id"], q["sentence"]])
			seen[q["sentence"]] = true
			if str(q.get("explain", "")) == "":
				_check(false, "%s: manca la spiegazione per «%s»" % [l["id"], q["sentence"]])
	print("domande in tutto: ", total)
	for c: Dictionary in gd.campionati:
		_check(gd.levels_of(c["id"]).size() >= 4, "%s: almeno 4 gare" % c["id"])
	_check(_level(gd, "preposizioni_semplici")["questions"].size() == 18, "semplici: 18 domande")

	var ui: GDScript = load("res://scripts/ui/Ui.gd")
	var filled: String = ui.filled("Oggi nessuno vive ___ isola.", "sull'")
	_check(filled.contains("[/b][/color]isola"), "sull' attaccato: " + filled)
	var wrong: String = ui.filled("Vado ___ Roma.", "a", "in")
	_check(wrong.contains("[s]in[/s]") and wrong.contains("[b]a[/b]"), "sbagliata barrata: " + wrong)
	var dlg: Node = root.get_node("Dialogue")
	_check(dlg.line("wrong", {"answer": "sul"}).contains("«sul»"), "battuta con {answer}")
	_check(dlg.sequence("intro").size() == 5, "intro di 5 battute")
	_check(dlg.line("nome") == "Leo Fulmine", "il pilota è Leo Fulmine")

	# --- menu: campionati → gare ---
	var menu: Node = load("res://scenes/Menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._show_levels()
	await process_frame
	_check(menu._page_name == "levels", "menu: pagina dei campionati")
	menu._show_races("c6")
	await process_frame
	_check(menu._page_name == "races" and gd.menu_group == "c6", "menu: gare del campionato 6")
	menu._back()
	await process_frame
	_check(menu._page_name == "levels", "menu: indietro ai campionati")
	menu.queue_free()
	await process_frame

	# --- gare ---
	Engine.time_scale = 10.0
	gd.pace = 2
	# 1) finale: errori alle domande 3 e 7
	var race := await _race(_level(gd, "preposizioni_semplici"), [3, 7])
	_check(race.answered == 18, "finale: 18 risposte (%d)" % race.answered)
	_check(race.right == 16, "finale: 16 giuste (%d)" % race.right)
	_check(race.lives == 1, "finale: 1 vita (%d)" % race.lives)
	_check(race.nitros == 5, "finale: 5 nitro (%d)" % race.nitros)
	_check(race.score == 4050, "finale: 4050 punti (%d)" % race.score)
	_check(race.mistakes.size() == 2, "finale: 2 errori da ripassare")
	_check(_has_results(race), "finale: schermata dei risultati")
	_check(not race.track.billboards.is_empty(), "cartelloni sulla pista")
	race.queue_free()
	await process_frame
	# 2) ritiro: tutto sbagliato, in una gara nuova
	race = await _race(_level(gd, "imperfetto"), range(100))
	_check(race.answered == 3 and race.lives == 0, "ritiro dopo 3 errori (%d, %d)" % [race.answered, race.lives])
	_check(_has_results(race), "ritiro: schermata dei risultati")
	race.queue_free()
	await process_frame
	# 3) gara infinita del campionato 1, vite illimitate
	gd.lives_option = 2
	race = await _race(gd.endless_level("c1"), [], 90)
	_check(race.answered == 90 and race.state != 4, "gara infinita c1: 90 domande e si continua (%d)" % race.answered)
	_check(race.questions.size() >= 90, "gara infinita: domande rimescolate di nuovo")
	race.queue_free()
	await process_frame
	gd.lives_option = 0
	Engine.time_scale = 1.0
	print("--- %s ---" % ("TUTTO OK" if _fails == 0 else "%d ERRORI" % _fails))
	quit(_fails)


func _has_results(race: Node) -> bool:
	for c in race.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("ResultsScreen.gd"):
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
		var t := 0
		while not _has_results(race) and t < 5000:
			t += 1
			await process_frame
	return race
