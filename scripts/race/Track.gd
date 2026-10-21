class_name Track
extends Node2D
## Трасса сверху: асфальт в три полосы, поребрики, газон и всё, что вдоль трассы.
## Гонка (или меню) двигает её, увеличивая travelled — пройденный путь в
## пикселях. Координаты — в макете 1280×720.
##
## Ради скорости (браузер, телефон) ничего не перерисовывается каждый кадр:
## узор полотна повторяется через PERIOD и нарисован один раз — его узел
## только сдвигается; обстановка рисуется кусками по SEGMENT, каждый кусок —
## один раз, когда въезжает на экран.

const LANES := 3
const LANE_W := 190.0
const LEFT := 355.0
const WIDTH := LANE_W * LANES
const RIGHT := LEFT + WIDTH
## Где на экране стоит машина: всё остальное едет мимо неё.
const CAR_Y := 590.0
const KERB := 24.0
const RUNOFF := 110.0
## Через столько пикселей пути меняется обстановка вдоль трассы.
const SEGMENT := 300.0
## Узор полотна (газон, поребрики, разметка) повторяется через столько пикселей.
const PERIOD := 1600.0

const GRASS := Color("2e7a34")
const GRASS_LIGHT := Color("358a3b")
const ASPHALT := Color("3b3e45")
const RUNOFF_COLOR := Color("4a4c52")
const KERB_RED := Color("d7261e")
const LINE := Color(1, 1, 1, 0.85)
const CROWD := [Color("e10600"), Color("f5f6f8"), Color("00a651"), Color("ffc400"), Color("2f6fd6"), Color("222222")]

var travelled := 0.0:
	set(value):
		travelled = value
		_scroll()
var nitro := false:
	set(value):
		nitro = value
		if _streaks:
			_streaks.visible = value
## Где лежит финишная черта (−1 — ещё не видна).
var finish_world := -1.0:
	set(value):
		finish_world = value
		if _finish:
			_finish.visible = value >= 0.0
		_scroll()
var view_top := -300.0:
	set(value):
		view_top = value
		_repaint()
var view_bottom := 1020.0:
	set(value):
		view_bottom = value
		_repaint()
var billboards: Array[String] = ["FORMULA GRAMMATICA", "FORZA!", "PREPOSIZIONI", "ANDIAMO!"]:
	set(value):
		billboards = value
		_clear_decor()
		_scroll()

var _ground: Node2D
var _decor_root: Node2D
var _grid: Node2D
var _finish: Node2D
var _streaks: Node2D
## Номер куска обстановки → его узел.
var _decor: Dictionary = {}


static func lane_x(lane: int) -> float:
	return LEFT + LANE_W * (lane + 0.5)


## Экранный y точки пути world (машина — в world = travelled).
func screen_y(world: float) -> float:
	return CAR_Y - (world - travelled)


func _ready() -> void:
	_ground = _layer(_paint_ground)
	_decor_root = Node2D.new()
	add_child(_decor_root)
	_grid = _layer(_paint_grid)
	_finish = _layer(_paint_finish)
	_finish.visible = finish_world >= 0.0
	_streaks = _layer(_paint_streaks)
	_streaks.visible = nitro
	_scroll()


func _layer(painter: Callable) -> Node2D:
	var n := Node2D.new()
	n.draw.connect(painter.bind(n))
	add_child(n)
	return n


func _repaint() -> void:
	if _ground:
		_ground.queue_redraw()
		_streaks.queue_redraw()
		_scroll()


func _scroll() -> void:
	if _ground == null:
		return
	var shift := fposmod(travelled, PERIOD)
	_ground.position.y = shift
	_streaks.position.y = shift
	_grid.position.y = screen_y(0.0)
	if finish_world >= 0.0:
		_finish.position.y = screen_y(finish_world)
	_update_decor()


# --- Полотно: рисуется один раз, потом только сдвигается ----------------------

## В узле полотна y = CAR_Y − w: узел сдвинут на travelled mod PERIOD, а узор
## повторяется через PERIOD, поэтому это то же самое, что сдвиг на travelled.
func _paint_ground(c: Node2D) -> void:
	var w_lo := CAR_Y - view_bottom
	var w_hi := CAR_Y - view_top + PERIOD
	var top := CAR_Y - w_hi
	var h := w_hi - w_lo
	c.draw_rect(Rect2(-2400, top, 6080, h), GRASS)
	for i in range(floori(w_lo / 160.0), ceili(w_hi / 160.0) + 1):
		if posmod(i, 2) == 0:
			c.draw_rect(Rect2(-2400, CAR_Y - (i + 1) * 160.0, 6080, 160), GRASS_LIGHT)
	# зона безопасности и отбойники
	c.draw_rect(Rect2(LEFT - RUNOFF, top, RUNOFF - KERB, h), RUNOFF_COLOR)
	c.draw_rect(Rect2(RIGHT + KERB, top, RUNOFF - KERB, h), RUNOFF_COLOR)
	var rail := Color(0.78, 0.8, 0.83)
	c.draw_rect(Rect2(LEFT - RUNOFF - 6, top, 6, h), rail)
	c.draw_rect(Rect2(RIGHT + RUNOFF, top, 6, h), rail)
	for i in range(floori(w_lo / 80.0), ceili(w_hi / 80.0) + 1):
		var y := CAR_Y - i * 80.0
		c.draw_rect(Rect2(LEFT - RUNOFF - 9, y, 12, 5), Color(0.3, 0.31, 0.34))
		c.draw_rect(Rect2(RIGHT + RUNOFF - 3, y, 12, 5), Color(0.3, 0.31, 0.34))
	# поребрики
	for i in range(floori(w_lo / 40.0), ceili(w_hi / 40.0) + 1):
		var col := KERB_RED if posmod(i, 2) == 0 else Color.WHITE
		var y := CAR_Y - (i + 1) * 40.0
		c.draw_rect(Rect2(LEFT - KERB, y, KERB, 40), col)
		c.draw_rect(Rect2(RIGHT, y, KERB, 40), col)
	# асфальт, накатанные полосы и крапины — по ним видна скорость
	c.draw_rect(Rect2(LEFT, top, WIDTH, h), ASPHALT)
	for lane in LANES:
		c.draw_rect(Rect2(lane_x(lane) - 34, top, 68, h), Color(0, 0, 0, 0.07))
	for i in range(floori(w_lo / 50.0), ceili(w_hi / 50.0) + 1):
		var y := CAR_Y - i * 50.0
		var seed_i := posmod(i, int(PERIOD / 50.0))
		for k in 3:
			var x := LEFT + 10.0 + _rand(seed_i, k) * (WIDTH - 20.0)
			var col := Color(1, 1, 1, 0.06) if k == 0 else Color(0, 0, 0, 0.13)
			c.draw_rect(Rect2(x, y, 3.0 + _rand(seed_i, k + 5) * 6.0, 2), col)
	# разметка
	c.draw_rect(Rect2(LEFT + 6, top, 5, h), LINE)
	c.draw_rect(Rect2(RIGHT - 11, top, 5, h), LINE)
	for i in range(floori(w_lo / 100.0), ceili(w_hi / 100.0) + 1):
		var y := CAR_Y - (i * 100.0 + 55.0)
		for k in range(1, LANES):
			c.draw_rect(Rect2(LEFT + LANE_W * k - 3, y, 6, 55), LINE)


func _paint_streaks(c: Node2D) -> void:
	var w_lo := CAR_Y - view_bottom
	var w_hi := CAR_Y - view_top + PERIOD
	for i in range(floori(w_lo / 40.0), ceili(w_hi / 40.0) + 1):
		var x := LEFT - 300.0 + _rand(posmod(i, int(PERIOD / 40.0)), 40) * (WIDTH + 600.0)
		c.draw_rect(Rect2(x, CAR_Y - i * 40.0, 2, 110), Color(0.6, 0.9, 1.0, 0.3))


## Стартовая решётка; узел стоит в точке пути 0, вверх — отрицательный y.
func _paint_grid(c: Node2D) -> void:
	_chequer(c, -150.0, 2)
	for lane in LANES:
		var x := lane_x(lane)
		c.draw_rect(Rect2(x - 48, -80, 96, 5), LINE)
		c.draw_rect(Rect2(x - 48, -80, 5, 46), LINE)
		c.draw_rect(Rect2(x + 43, -80, 5, 46), LINE)


func _paint_finish(c: Node2D) -> void:
	_chequer(c, 0.0, 3)
	c.draw_string(Ui.title, Vector2(LEFT, 80), "TRAGUARDO", HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 64, Color(1, 1, 1, 0.55))


## Шахматка шириной в трассу; нижний край — на y.
func _chequer(c: Node2D, y: float, rows: int) -> void:
	var count := 30
	var sq := WIDTH / count
	for r in rows:
		for col in count:
			var colour := Color.WHITE if (r + col) % 2 == 0 else Color(0.08, 0.08, 0.08)
			c.draw_rect(Rect2(LEFT + col * sq, y - (r + 1) * sq, sq, sq), colour)


# --- Обстановка вдоль трассы: кусок рисуется, когда въезжает на экран ---------

func _update_decor() -> void:
	var lo := floori((travelled + CAR_Y - view_bottom) / SEGMENT) - 1
	var hi := ceili((travelled + CAR_Y - view_top) / SEGMENT)
	for k: int in _decor.keys():
		if k < lo or k > hi:
			(_decor[k] as Node2D).queue_free()
			_decor.erase(k)
	for k in range(lo, hi + 1):
		if not _decor.has(k):
			var n := Node2D.new()
			n.draw.connect(_paint_segment.bind(n, k))
			_decor_root.add_child(n)
			_decor[k] = n
		(_decor[k] as Node2D).position.y = screen_y((k + 1) * SEGMENT)


func _clear_decor() -> void:
	for n: Node2D in _decor.values():
		n.queue_free()
	_decor.clear()


## Кусок k, слева и справа от трассы; верх куска — y = 0.
func _paint_segment(c: Node2D, k: int) -> void:
	_decor_side(c, k, 0, LEFT - RUNOFF - 20.0 - 230.0)
	_decor_side(c, k, 1, RIGHT + RUNOFF + 20.0)


## Обстановка в прямоугольнике 230 × SEGMENT; x — его левый край.
func _decor_side(c: Node2D, k: int, side: int, x: float) -> void:
	var kind := int(_rand(k, side * 11 + 1) * 6.0)
	var near := x + 230.0 if side == 0 else x
	match kind:
		0:
			_tyres(c, near + (-40.0 if side == 0 else 12.0), 40.0)
		1:
			_billboard(c, x + 15.0, 110.0, billboards[posmod(k * 2 + side, billboards.size())])
		2:
			for t in 3:
				_tree(c, Vector2(x + 30.0 + _rand(k, side + t * 3) * 170.0, 50.0 + t * 80.0), 26.0 + _rand(k, t + 9) * 14.0)
		3:
			_stand(c, x + 5.0, 30.0, k * 2 + side)
		4:
			_marshal(c, near + (-70.0 if side == 0 else 30.0), 120.0)
		_:
			_flag(c, x + 55.0, 100.0)


func _tyres(c: Node2D, x: float, y: float) -> void:
	for row in 6:
		for col in 2:
			var p := Vector2(x + col * 26.0 + 13.0, y + row * 26.0 + 13.0)
			c.draw_circle(p, 13.0, Color(0.09, 0.09, 0.1))
			c.draw_circle(p, 6.0, Color(0.32, 0.33, 0.36))


func _billboard(c: Node2D, x: float, y: float, text: String) -> void:
	c.draw_rect(Rect2(x + 4, y + 6, 200, 60), Color(0, 0, 0, 0.25))
	c.draw_rect(Rect2(x, y, 200, 60), Color.WHITE)
	c.draw_rect(Rect2(x, y, 200, 10), KERB_RED)
	c.draw_rect(Rect2(x, y + 50, 200, 10), Color("00a651"))
	var size := Ui.fit_size(text, 184.0, 26, 10)
	c.draw_string(Ui.bold, Vector2(x, y + 30 + size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, 200, size, Color(0.1, 0.1, 0.12))


func _tree(c: Node2D, p: Vector2, r: float) -> void:
	c.draw_circle(p + Vector2(6, 8), r, Color(0, 0, 0, 0.22))
	c.draw_circle(p, r, Color("1f5d26"))
	c.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.55, Color("2b7a33"))


## Трибуна с болельщиками; цвета — по номеру куска k.
func _stand(c: Node2D, x: float, y: float, k: int) -> void:
	c.draw_rect(Rect2(x + 6, y + 8, 220, 230), Color(0, 0, 0, 0.25))
	c.draw_rect(Rect2(x, y, 220, 230), Color(0.36, 0.37, 0.4))
	for row in 8:
		c.draw_rect(Rect2(x + 8, y + 10 + row * 27, 204, 20), Color(0.24, 0.25, 0.28))
		for col in 10:
			if _rand(k, row * 10 + col) < 0.8:
				var p := Vector2(x + 18 + col * 20.0, y + 20 + row * 27.0)
				var colour: Color = CROWD[int(_rand(k, row * 31 + col * 7) * CROWD.size())]
				c.draw_circle(p, 6.0, colour)


func _marshal(c: Node2D, x: float, y: float) -> void:
	c.draw_rect(Rect2(x, y, 40, 32), Color("f08c00"))
	c.draw_rect(Rect2(x + 4, y + 4, 32, 10), Color(0.15, 0.15, 0.17))
	c.draw_circle(Vector2(x + 20, y + 52), 8.0, Color("f08c00"))
	c.draw_rect(Rect2(x + 30, y + 40, 4, 34), Color(0.2, 0.2, 0.2))
	c.draw_rect(Rect2(x + 34, y + 40, 26, 18), Color("00a651"))


func _flag(c: Node2D, x: float, y: float) -> void:
	c.draw_rect(Rect2(x + 5, y + 6, 120, 80), Color(0, 0, 0, 0.22))
	c.draw_rect(Rect2(x, y, 40, 80), Color("009246"))
	c.draw_rect(Rect2(x + 40, y, 40, 80), Color("f4f5f0"))
	c.draw_rect(Rect2(x + 80, y, 40, 80), Color("ce2b37"))


## Псевдослучайное 0…1, всегда одно и то же для (k, salt).
static func _rand(k: int, salt: int) -> float:
	var v := sin(float(k) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floorf(v)
