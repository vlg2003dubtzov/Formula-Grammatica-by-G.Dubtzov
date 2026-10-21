class_name AnswerGate
extends Node2D
## Арка поперёк трассы: по ответу над каждой полосой. Все три табло выглядят
## одинаково, пока машина не проедет. Тогда верное загорается зелёным (бонус:
## очки и скорость), а выбранное неверное становится барьером (препятствие).

enum Look { CLOSED, BOOST, BARRIER, FADED }

const BOARD := Vector2(170, 58)

## Точка пути, где стоит арка; экранный y считает гонка.
var world_pos := 0.0
var words: Array[String] = []
var correct := 0
var looks: Array[int] = [Look.CLOSED, Look.CLOSED, Look.CLOSED]
var _sizes: Array[int] = []
var _t := 0.0
var _resolved := false


func setup(options: Array[String], right: int) -> void:
	words = options
	correct = right
	_sizes.clear()
	for w in words:
		_sizes.append(Ui.fit_size(w, BOARD.x - 16.0, 30, 13))
	queue_redraw()


func resolve(chosen: int) -> void:
	_resolved = true
	for i in Track.LANES:
		if i == correct:
			looks[i] = Look.BOOST
		elif i == chosen:
			looks[i] = Look.BARRIER
		else:
			looks[i] = Look.FADED


func _process(delta: float) -> void:
	if _resolved and _t < 3.0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var beam := Color(0.16, 0.17, 0.2)
	draw_rect(Rect2(Track.LEFT, 16, Track.WIDTH, 12), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(Track.LEFT - 40, -6, Track.WIDTH + 80, 12), beam)
	draw_rect(Rect2(Track.LEFT - 54, -15, 26, 30), beam)
	draw_rect(Rect2(Track.RIGHT + 28, -15, 26, 30), beam)
	for i in words.size():
		_board(i)


func _board(i: int) -> void:
	var center := Vector2(Track.lane_x(i), 0)
	var r := Rect2(center - BOARD * 0.5, BOARD)
	var bg := Color(0.09, 0.1, 0.13)
	var border := Color(1, 1, 1, 0.85)
	var ink := Ui.WHITE
	match looks[i]:
		Look.BOOST:
			var glow := 0.5 + 0.5 * sin(_t * 12.0)
			draw_rect(r.grow(8.0 + glow * 5.0), Color(Ui.GREEN_LIGHT, 0.35))
			bg = Ui.GREEN
		Look.BARRIER:
			r.position.x += sin(_t * 50.0) * 5.0 * maxf(0.0, 1.0 - _t * 1.5)
			bg = Ui.WRONG.darkened(0.25)
			for k in 5:
				var a := float(k) * 1.3 + 0.4
				draw_circle(center + Vector2(cos(a) * 70.0, 44.0 + sin(a) * 16.0), 12.0, Color(0.09, 0.09, 0.1))
		Look.FADED:
			bg = Color(0.09, 0.1, 0.13, 0.45)
			border = Color(1, 1, 1, 0.25)
			ink = Color(1, 1, 1, 0.4)
	draw_rect(r, bg)
	draw_rect(r, border, false, 3.0)
	var size := _sizes[i]
	draw_string(Ui.bold, Vector2(r.position.x, center.y + size * 0.36), words[i], HORIZONTAL_ALIGNMENT_CENTER, BOARD.x, size, ink)
