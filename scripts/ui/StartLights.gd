class_name StartLights
extends Control
## Стартовый светофор, как в формульных гонках: пять пар красных огней загораются по
## одному, держатся случайную паузу и гаснут разом — старт.

signal finished

const STEP := 0.7
const PODS := 5

var _on := 0
var _t := 0.0
var _hold := 1.0
var _running := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func start() -> void:
	visible = true
	modulate.a = 1.0
	_on = 0
	_t = 0.0
	_hold = randf_range(0.5, 1.3)
	_running = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	if _on < PODS:
		if _t >= STEP:
			_t = 0.0
			_on += 1
			Sfx.play("beep")
			queue_redraw()
	elif _t >= _hold:
		_running = false
		_on = 0
		queue_redraw()
		finished.emit()
		var tw := create_tween()
		tw.tween_interval(0.15)
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(hide)


func _draw() -> void:
	var pod := Vector2(64, 150)
	var gap := 18.0
	var x0 := (size.x - (pod.x * PODS + gap * (PODS - 1))) * 0.5
	draw_rect(Rect2(x0 - 20, 18, pod.x * PODS + gap * (PODS - 1) + 40, 14), Color(0.12, 0.12, 0.14))
	for i in PODS:
		var x := x0 + i * (pod.x + gap)
		draw_rect(Rect2(x + 4, 6, pod.x, pod.y), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(x, 0, pod.x, pod.y), Color(0.05, 0.05, 0.06))
		for row in 2:
			var c := Vector2(x + pod.x * 0.5, 42 + row * 64)
			if i < _on:
				draw_circle(c, 30.0, Color(1, 0.1, 0.05, 0.25))
				draw_circle(c, 24.0, Color("ff1a0d"))
				draw_circle(c + Vector2(-7, -7), 7.0, Color(1, 0.7, 0.6, 0.8))
			else:
				draw_circle(c, 24.0, Color(0.18, 0.05, 0.05))
