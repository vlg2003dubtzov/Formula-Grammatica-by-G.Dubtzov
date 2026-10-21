class_name ResultsScreen
extends CanvasLayer
## Итоги гонки: место на подиуме, цифры и фразы, которые стоит повторить.

signal retry
signal other_level
signal to_menu


## r: finished, level, score, right, answered, best_streak, nitros, record, mistakes.
func show_results(r: Dictionary) -> void:
	layer = 20
	var finished := bool(r["finished"])
	var right := int(r["right"])
	var answered := int(r["answered"])
	var accuracy := float(right) / maxf(1.0, float(answered))

	var root := Ui.layer_root(self)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -330
	panel.offset_bottom = 330
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := Ui.box(Color(0.06, 0.07, 0.09, 0.97), Ui.GREEN if finished else Ui.RED, 0, 0.0, 8)
	style.border_width_top = 8
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var title := Ui.label("TRAGUARDO!" if finished else "Hai perso! Riprova?", 50, Ui.WHITE)
	title.add_theme_font_override("font", Ui.title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var level: Dictionary = r["level"]
	var sub := Ui.label("%s · %s" % [level.get("title", ""), level.get("topic", "")], 18, Ui.GREY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	if finished:
		var podium := Ui.label(_podium(accuracy), 28, Ui.AMBER, true)
		podium.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(podium)

	col.add_child(Ui.label("RISULTATI", 15, Ui.GREY, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 2)
	col.add_child(grid)
	var rows := [
		["Punti", str(r["score"])],
		["Risposte corrette", "%d / %d" % [right, answered]],
		["Precisione", "%d %%" % roundi(accuracy * 100.0)],
		["Serie migliore", str(r["best_streak"])],
		["Nitro", str(r["nitros"])],
	]
	for row: Array in rows:
		var name_label := Ui.label(str(row[0]), 22, Ui.GREY)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		grid.add_child(Ui.label(str(row[1]), 22, Ui.WHITE, true))
	if bool(r["record"]):
		var rec := Ui.label("Nuovo record!", 24, Ui.AMBER, true)
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(rec)

	var mistakes: Array = r["mistakes"]
	col.add_child(Ui.label("DA RIPASSARE" if not mistakes.is_empty() else "NESSUN ERRORE: GARA PERFETTA!", 15, Ui.GREY, true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := Ui.rich(20)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.text = _mistakes_text(mistakes)
	scroll.add_child(list)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 22)
	col.add_child(buttons)
	var again := Ui.button("Riprova", func() -> void: retry.emit())
	buttons.add_child(again)
	buttons.add_child(Ui.button("Altro Gran Premio", func() -> void: other_level.emit()))
	buttons.add_child(Ui.button("Menu", func() -> void: to_menu.emit()))
	again.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		to_menu.emit()


func _podium(accuracy: float) -> String:
	if accuracy >= 0.9:
		return "1° posto: vittoria!"
	if accuracy >= 0.75:
		return "2° posto: ottimo podio!"
	if accuracy >= 0.6:
		return "3° posto: sul podio!"
	return "Fuori dal podio: ripassa e riprova!"


func _mistakes_text(mistakes: Array) -> String:
	var seen: Array[String] = []
	var out := ""
	for m: Dictionary in mistakes:
		var sentence := str(m["sentence"])
		if sentence in seen:
			continue
		seen.append(sentence)
		out += "• %s  [color=#%s](non «%s»)[/color]\n" % [
			Ui.filled(sentence, str(m["answer"])), Ui.WRONG.to_html(false), str(m["chosen"]).replace("[", "[lb]")]
		var why := str(m.get("explain", ""))
		if why != "":
			out += "   [font_size=16][color=#%s]%s[/color][/font_size]\n" % [Ui.GREY.to_html(false), why.replace("[", "[lb]")]
	return out
