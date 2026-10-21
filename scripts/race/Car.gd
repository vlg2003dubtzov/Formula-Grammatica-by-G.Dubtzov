class_name Car
extends Node2D
## Болид игрока сверху, в цветах флага Италии. Плавно переходит с полосы на
## полосу; гонка велит ему врезаться, крутиться или включить нитро.

signal lane_changed(lane: int)

## Чем больше, тем резче переход между полосами.
const GLIDE := 14.0

const BODY := Color("d4110a")
const CARBON := Color("2a2c31")
const TYRE := Color("1b1b1d")
const SHAPE := [
	Vector2(-5, -66), Vector2(5, -66), Vector2(10, -30), Vector2(13, -18), Vector2(15, -6),
	Vector2(27, 2), Vector2(28, 30), Vector2(16, 40), Vector2(10, 54), Vector2(-10, 54),
	Vector2(-16, 40), Vector2(-28, 30), Vector2(-27, 2), Vector2(-15, -6), Vector2(-13, -18),
	Vector2(-10, -30),
]

var lane := 1
var nitro := false:
	set(value):
		nitro = value
		queue_redraw()
var _crash := 0.0
var _spin := 0.0
var _spin_angle := 0.0
var _t := 0.0


func set_lane(value: int) -> void:
	value = clampi(value, 0, Track.LANES - 1)
	if value == lane:
		return
	lane = value
	lane_changed.emit(lane)


func crash() -> void:
	_crash = 0.7


func spin() -> void:
	_spin = 1.0


func _process(delta: float) -> void:
	_t += delta
	var dx := Track.lane_x(lane) - position.x
	position.x += dx * (1.0 - exp(-GLIDE * delta))
	var angle := clampf(dx / Track.LANE_W, -1.0, 1.0) * 0.22
	if _crash > 0.0:
		_crash = maxf(_crash - delta, 0.0)
		angle += sin(_crash * 38.0) * 0.4 * _crash
	if _spin > 0.0:
		_spin = maxf(_spin - delta * 0.6, 0.0)
		_spin_angle += delta * 11.0 * _spin
	rotation = angle + _spin_angle
	# перерисовка нужна только пламени нитро; наклоны и сдвиги — это трансформ
	if nitro:
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(5, 8))
	_silhouette(Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	if nitro:
		_flame()
	for r: Rect2 in [Rect2(-38, -52, 14, 26), Rect2(24, -52, 14, 26), Rect2(-41, 18, 17, 32), Rect2(24, 18, 17, 32)]:
		draw_rect(r, TYRE)
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.5 - 2), Vector2(r.size.x, 3)), Color(0.3, 0.3, 0.32))
	for s: float in [-1.0, 1.0]:
		draw_line(Vector2(9 * s, -44), Vector2(26 * s, -40), CARBON, 3.0)
		draw_line(Vector2(9 * s, -34), Vector2(26 * s, -37), CARBON, 3.0)
		draw_line(Vector2(16 * s, 26), Vector2(28 * s, 32), CARBON, 3.0)
	# переднее крыло
	draw_rect(Rect2(-40, -72, 80, 10), CARBON)
	draw_rect(Rect2(-40, -72, 80, 3), Color("f2f2f2"))
	draw_rect(Rect2(-43, -75, 5, 16), CARBON)
	draw_rect(Rect2(38, -75, 5, 16), CARBON)
	# кузов и полосы триколора
	draw_colored_polygon(PackedVector2Array(SHAPE), BODY)
	draw_colored_polygon(PackedVector2Array([Vector2(-2, -66), Vector2(2, -66), Vector2(3, -18), Vector2(-3, -18)]), Color("f2f2f2"))
	for s: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(19 * s, 5), Vector2(25 * s, 7), Vector2(25 * s, 28), Vector2(19 * s, 31)]), Color("009246"))
	draw_rect(Rect2(-4, 8, 8, 30), Color(0.55, 0.05, 0.03))
	# кокпит, шлем и «гало»
	draw_circle(Vector2(0, -6), 10.0, Color(0.06, 0.06, 0.08))
	draw_circle(Vector2(0, -4), 6.5, Color("ffd400"))
	draw_arc(Vector2(0, -4), 12.0, PI * 1.12, PI * 1.88, 12, CARBON, 3.0)
	draw_line(Vector2(0, -16), Vector2(0, -24), CARBON, 3.0)
	# заднее крыло
	draw_rect(Rect2(-31, 54, 62, 11), CARBON)
	draw_rect(Rect2(-29, 56, 19, 7), Color("009246"))
	draw_rect(Rect2(-10, 56, 20, 7), Color("f2f2f2"))
	draw_rect(Rect2(10, 56, 19, 7), BODY)


func _silhouette(c: Color) -> void:
	draw_colored_polygon(PackedVector2Array(SHAPE), c)
	draw_rect(Rect2(-40, -72, 80, 10), c)
	draw_rect(Rect2(-31, 54, 62, 11), c)
	for r: Rect2 in [Rect2(-38, -52, 14, 26), Rect2(24, -52, 14, 26), Rect2(-41, 18, 17, 32), Rect2(24, 18, 17, 32)]:
		draw_rect(r, c)


func _flame() -> void:
	var length := 36.0 + sin(_t * 47.0) * 8.0 + sin(_t * 31.0) * 5.0
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 64), Vector2(10, 64), Vector2(0, 64 + length)]), Color(0.2, 0.75, 1.0, 0.8))
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 64), Vector2(4, 64), Vector2(0, 64 + length * 0.6)]), Color(1, 1, 1, 0.95))
