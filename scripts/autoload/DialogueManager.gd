extends Node
## Реплики Кими — в data/dialogues/kimi.json. Ключ хранит список фраз: line()
## берёт случайную (не ту же, что в прошлый раз), sequence() — все по порядку.
## {answer} и другие подстановки — через String.format.

const PATH := "res://data/dialogues/kimi.json"

var lines: Dictionary = {}
var _last: Dictionary = {}


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary:
		lines = data
	else:
		push_error("kimi.json не читается как JSON")


func sequence(key: String, vars: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var list: Variant = lines.get(key, [])
	if list is Array:
		for l: Variant in list:
			out.append(str(l).format(vars))
	return out


func line(key: String, vars: Dictionary = {}) -> String:
	var list := sequence(key, vars)
	if list.is_empty():
		return ""
	var i := randi() % list.size()
	if list.size() > 1 and i == int(_last.get(key, -1)):
		i = (i + 1) % list.size()
	_last[key] = i
	return list[i]
