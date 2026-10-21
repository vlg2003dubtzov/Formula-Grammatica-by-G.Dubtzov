extends Node2D
## Гонка — один уровень. Каждая арка на трассе задаёт один вопрос уровня.
## Машина едет сама; игрок только выбирает полосу с верным ответом.
## Ход гонки: вступление Кими → светофор → вопросы → финиш (или сход) → итоги.

enum State { INTRO, LIGHTS, RACING, FINISHING, OVER }

const GATE_SCENE := preload("res://scenes/race/AnswerGate.tscn")
const MENU_SCENE := "res://scenes/Menu.tscn"

## Скорость в пикселях в секунду; спидометр показывает половину как км/ч.
const BASE_SPEED := 380.0
const KMH := 0.5
const ACCEL := 240.0
const BRAKE := 160.0
## Каждый верный ответ подряд прибавляет 8 % скорости, до четырёх раз.
const BOOST_STEP := 0.08
const MAX_BOOST := 4
## После ошибки машина падает до 45 % обычной скорости.
const CRASH_SPEED := 0.45
## Нитро — каждые три верных подряд: прибавка скорости, бонус очков, пламя.
const NITRO_EVERY := 3
const NITRO_TIME := 3.0
const NITRO_EXTRA := 0.45
const NITRO_BONUS := 250
const MAX_MULT := 4
## Столько секунд на карточке висит разобранная фраза, прежде чем придёт следующая.
const FEEDBACK_TIME := 1.6

@onready var world: Node2D = $World
@onready var track: Track = $World/Track
@onready var gates: Node2D = $World/Gates
@onready var car: Car = $World/Car
@onready var fx: Node2D = $World/Fx
@onready var hud: Hud = $Hud

var level: Dictionary = {}
var endless := false
var questions: Array[Dictionary] = []
var q_index := -1
var question: Dictionary = {}
var gate: AnswerGate = null
var state := State.INTRO
var speed := 0.0
var boost := 0
var nitro_left := 0.0
var score := 0
var lives := 3
var streak := 0
var best_streak := 0
var right := 0
var answered := 0
var nitros := 0
var mistakes: Array[Dictionary] = []

var _intro: Array[String] = []
var _intro_i := 0
var _feedback_left := 0.0
var _shake := 0.0
var _origin := Vector2.ZERO
var _finish_world := -1.0


func _ready() -> void:
	level = GameData.selected
	if level.is_empty():
		level = GameData.levels[0]
	endless = bool(level.get("endless", false))
	lives = GameData.start_lives()
	questions = _shuffled(level["questions"])
	var boards: Variant = level.get("billboards")
	if boards is Array and not (boards as Array).is_empty():
		var list: Array[String] = []
		list.assign(boards)
		track.billboards = list
	get_viewport().size_changed.connect(_fit)
	_fit()
	car.position = Vector2(Track.lane_x(car.lane), Track.CAR_Y)
	car.lane_changed.connect(hud.set_lane)
	hud.setup(level, questions.size(), lives, endless)
	hud.set_lane(car.lane)
	hud.skip_intro.connect(_start_lights)
	hud.pause_pressed.connect(_pause)
	hud.lights.finished.connect(_go)
	_intro = Dialogue.sequence("intro")
	var own := str(level.get("intro", ""))
	if own != "":
		_intro.insert(1, own)
	hud.kimi.say(_intro[0], true)


func _exit_tree() -> void:
	Sfx.engine(false)


## На широком или высоком экране мир — в центре, а газон тянется до краёв.
func _fit() -> void:
	var view := get_viewport_rect().size
	_origin = ((view - Vector2(1280, 720)) * 0.5).floor()
	world.position = _origin
	track.view_top = -_origin.y - 200.0
	track.view_bottom = view.y - _origin.y + 200.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state != State.OVER:
			_pause()
		get_viewport().set_input_as_handled()
		return
	var mouse := event as InputEventMouseButton
	var tap := mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if state == State.INTRO:
		if event.is_action_pressed("advance") or tap:
			_next_intro()
			get_viewport().set_input_as_handled()
		return
	if state != State.LIGHTS and state != State.RACING:
		return
	var lane := car.lane
	if event.is_action_pressed("lane_left"):
		lane -= 1
	elif event.is_action_pressed("lane_right"):
		lane += 1
	elif event.is_action_pressed("lane_1"):
		lane = 0
	elif event.is_action_pressed("lane_2"):
		lane = 1
	elif event.is_action_pressed("lane_3"):
		lane = 2
	elif tap:
		lane = _lane_at(world.get_local_mouse_position().x)
	else:
		return
	car.set_lane(lane)
	get_viewport().set_input_as_handled()


## Касание полосы — на неё; касание сбоку от трассы — на соседнюю в ту сторону.
func _lane_at(x: float) -> int:
	if x < Track.LEFT:
		return car.lane - 1
	if x > Track.RIGHT:
		return car.lane + 1
	return int((x - Track.LEFT) / Track.LANE_W)


func _process(delta: float) -> void:
	if state == State.RACING or state == State.FINISHING:
		_drive(delta)
	elif state == State.OVER:
		speed = move_toward(speed, 0.0, BRAKE * delta)
	track.travelled += speed * delta
	for child in gates.get_children():
		var g := child as AnswerGate
		g.position.y = track.screen_y(g.world_pos)
		if g != gate and g.position.y > track.view_bottom + 100.0:
			g.queue_free()
	_shake = maxf(_shake - delta, 0.0)
	world.position = _origin + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 16.0 * _shake
	var top := BASE_SPEED * (1.0 + BOOST_STEP * MAX_BOOST) * (1.0 + NITRO_EXTRA)
	hud.set_speed(speed * KMH, speed / top)
	hud.set_nitro(streak % NITRO_EVERY, nitro_left / NITRO_TIME)
	Sfx.engine(true, speed / top)


func _drive(delta: float) -> void:
	var target := BASE_SPEED * (1.0 + BOOST_STEP * boost)
	var accel := ACCEL
	if nitro_left > 0.0:
		nitro_left = maxf(nitro_left - delta, 0.0)
		target *= 1.0 + NITRO_EXTRA
		accel *= 2.5
		if nitro_left == 0.0:
			car.nitro = false
			track.nitro = false
	speed = move_toward(speed, target, (accel if speed < target else BRAKE) * delta)
	if _feedback_left > 0.0:
		_feedback_left -= delta
		if _feedback_left <= 0.0:
			if question.is_empty():
				hud.hide_card()
			else:
				hud.show_question(question)
	if state == State.RACING and gate != null:
		var ahead := gate.world_pos - track.travelled
		hud.set_distance(ahead / 10.0)
		if ahead <= 0.0:
			_resolve()
	elif state == State.FINISHING and track.travelled >= _finish_world:
		_finish()


# --- Вступление и старт -------------------------------------------------------

func _next_intro() -> void:
	if hud.kimi.is_typing():
		hud.kimi.finish_typing()
		return
	_intro_i += 1
	if _intro_i < _intro.size():
		hud.kimi.say(_intro[_intro_i], true)
	else:
		_start_lights()


func _start_lights() -> void:
	if state != State.INTRO:
		return
	state = State.LIGHTS
	hud.intro_done()
	hud.kimi.say(Dialogue.line("lights"), false, 3.0)
	hud.lights.start()


func _go() -> void:
	state = State.RACING
	Sfx.play("go")
	hud.banner("VIA!", Ui.GREEN_LIGHT)
	hud.kimi.say(Dialogue.line("go"), false, 2.0)
	_next_question()


# --- Вопросы ------------------------------------------------------------------

## Вопросы в случайном порядке, и в каждом ответы тоже перемешаны.
func _shuffled(source: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q: Dictionary in source:
		var options: Array[String] = []
		options.assign(q["options"])
		var answer := options[int(q["correct"])]
		options.shuffle()
		var item := q.duplicate()
		item["options"] = options
		item["correct"] = options.find(answer)
		out.append(item)
	out.shuffle()
	return out


func _next_question() -> void:
	q_index += 1
	if q_index >= questions.size():
		if endless:
			questions.append_array(_shuffled(level["questions"]))
		else:
			question = {}
			gate = null
			state = State.FINISHING
			_finish_world = track.travelled + BASE_SPEED * (FEEDBACK_TIME + 1.0)
			track.finish_world = _finish_world
			return
	question = questions[q_index]
	# время на чтение — по обычной скорости; кто разогнался, тому его меньше
	var lead := BASE_SPEED * GameData.pace_seconds()
	if q_index > 0:
		lead += BASE_SPEED * FEEDBACK_TIME
	gate = GATE_SCENE.instantiate() as AnswerGate
	gate.world_pos = track.travelled + lead
	gates.add_child(gate)
	var options: Array[String] = []
	options.assign(question["options"])
	gate.setup(options, int(question["correct"]))
	gate.position.y = track.screen_y(gate.world_pos)
	hud.set_progress(q_index + 1, 0 if endless else questions.size())
	if _feedback_left <= 0.0:
		hud.show_question(question)


func _resolve() -> void:
	var chosen := car.lane
	var correct := int(question["correct"])
	var options: Array = question["options"]
	gate.resolve(chosen)
	gate = null
	answered += 1
	if chosen == correct:
		_on_right()
	else:
		_on_wrong(str(options[correct]), str(options[chosen]))
	hud.show_answer(question, chosen)
	hud.set_score(score)
	hud.set_streak(streak, _multiplier())
	hud.set_lives(lives)
	_feedback_left = FEEDBACK_TIME
	if lives == 0:
		_game_over()
	else:
		_next_question()


## ×1 за первые три подряд, ×2 за следующие три и так далее, не больше ×4.
func _multiplier() -> int:
	if streak <= 0:
		return 1
	return mini(1 + int((streak - 1) / float(NITRO_EVERY)), MAX_MULT)


func _on_right() -> void:
	right += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	boost = mini(boost + 1, MAX_BOOST)
	var mult := _multiplier()
	var points := 100 * mult
	score += points
	Sfx.play("correct")
	_burst([Ui.GREEN_LIGHT, Color.WHITE], 36)
	_popup("+%d" % points + ("  ×%d" % mult if mult > 1 else ""), Ui.GREEN_LIGHT)
	if streak % NITRO_EVERY == 0:
		_nitro()
	else:
		hud.kimi.say(Dialogue.line("correct"), false, 2.0)


func _on_wrong(answer: String, chosen_word: String) -> void:
	streak = 0
	boost = maxi(boost - 2, 0)
	speed = minf(speed, BASE_SPEED * CRASH_SPEED)
	nitro_left = 0.0
	car.nitro = false
	track.nitro = false
	if lives > 0:
		lives -= 1
	car.crash()
	_shake = 0.45
	Sfx.play("crash")
	_smoke()
	hud.flash(Color(Ui.WRONG, 0.35))
	var why := str(question.get("explain", ""))
	mistakes.append({"sentence": question["sentence"], "answer": answer, "chosen": chosen_word, "explain": why})
	var text := Dialogue.line("wrong", {"answer": answer})
	if why != "":
		text += " " + why
	if lives == 1:
		text += " " + Dialogue.line("last_life")
	hud.kimi.say(text, false, 6.0)


func _nitro() -> void:
	nitros += 1
	nitro_left = NITRO_TIME
	score += NITRO_BONUS
	car.nitro = true
	track.nitro = true
	Sfx.play("nitro")
	hud.banner("NITRO!", Ui.NITRO)
	hud.flash(Color(Ui.NITRO, 0.22))
	_popup("NITRO +%d" % NITRO_BONUS, Ui.NITRO, -46.0)
	hud.kimi.say(Dialogue.line("nitro"), false, 2.5)


# --- Конец гонки --------------------------------------------------------------

func _game_over() -> void:
	state = State.OVER
	question = {}
	car.spin()
	hud.set_distance(-1.0)
	hud.kimi.say(Dialogue.line("game_over"), false, 30.0)
	get_tree().create_timer(2.2).timeout.connect(_show_results.bind(false))


func _finish() -> void:
	state = State.OVER
	Sfx.play("finish")
	hud.banner("TRAGUARDO!", Ui.WHITE)
	_burst([Color("009246"), Color.WHITE, Color("ce2b37")], 90)
	hud.kimi.say(Dialogue.line("finish"), false, 30.0)
	get_tree().create_timer(2.4).timeout.connect(_show_results.bind(true))


func _show_results(finished: bool) -> void:
	var screen := ResultsScreen.new()
	add_child(screen)
	screen.retry.connect(_restart)
	screen.other_level.connect(_to_menu.bind("levels"))
	screen.to_menu.connect(_to_menu.bind("title"))
	screen.show_results({
		"finished": finished,
		"level": level,
		"score": score,
		"right": right,
		"answered": answered,
		"best_streak": best_streak,
		"nitros": nitros,
		"record": GameData.submit_score(str(level.get("id", "")), score),
		"mistakes": mistakes,
	})


func _pause() -> void:
	if get_tree().paused or state == State.OVER:
		return
	var menu := PauseMenu.new()
	add_child(menu)
	menu.restart.connect(_restart)
	menu.to_menu.connect(_to_menu.bind("title"))


func _restart() -> void:
	get_tree().reload_current_scene()


func _to_menu(page: String) -> void:
	GameData.menu_page = page
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Эффекты ------------------------------------------------------------------

func _burst(colors: Array, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = car.position + Vector2(0, -40)
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 520)
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 400.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([colors[0], colors[-1]])
	if colors.size() > 2:
		ramp.add_point(0.5, colors[1])
	p.color_initial_ramp = ramp
	fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


func _smoke() -> void:
	var p := CPUParticles2D.new()
	p.position = car.position
	p.amount = 40
	p.one_shot = true
	p.explosiveness = 0.8
	p.lifetime = 1.2
	p.spread = 180.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 140.0
	p.scale_amount_min = 10.0
	p.scale_amount_max = 22.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(0.75, 0.75, 0.75, 0.75), Color(0.5, 0.5, 0.5, 0.0)])
	p.color_ramp = ramp
	fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.8).timeout.connect(p.queue_free)


func _popup(text: String, color: Color, dy := 0.0) -> void:
	var l := Ui.label(text, 34, color, true)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.position = car.position + Vector2(54, -100 + dy)
	fx.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 80.0, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)
