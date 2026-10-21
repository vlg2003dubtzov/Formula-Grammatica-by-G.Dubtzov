class_name PauseMenu
extends CanvasLayer
## Пауза: останавливает дерево сцены, сама работает и на паузе.

signal restart
signal to_menu


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Sfx.engine(false)
	var root := Ui.layer_root(self)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(380, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var title := Ui.label("Pausa", 64, Ui.WHITE)
	title.add_theme_font_override("font", Ui.title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var go_on := Ui.button("Continua", _resume)
	col.add_child(go_on)
	col.add_child(Ui.button("Ricomincia", func() -> void: _leave(restart)))
	col.add_child(Ui.button("Menu principale", func() -> void: _leave(to_menu)))
	go_on.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_resume()


func _resume() -> void:
	get_tree().paused = false
	queue_free()


func _leave(what: Signal) -> void:
	get_tree().paused = false
	what.emit()
