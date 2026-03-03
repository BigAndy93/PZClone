class_name NPCDialogue
extends RefCounted

## Loads and resolves dialogue trees from JSON for a given faction disposition.

const DIALOGUE_PATH: String = "res://resources/dialogue/survivors_dialogue.json"

var _data: Dictionary = {}


func _init() -> void:
	var file := FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	if file:
		_data = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		push_error("NPCDialogue: could not open %s" % DIALOGUE_PATH)


func get_dialogue_key(faction_id: String, disposition: String) -> String:
	return "%s_%s" % [faction_id, disposition]


func get_dialogue(key: String) -> Dictionary:
	return _data.get(key, {})


## Returns filtered choices based on player reputation.
func get_choices(key: String, rep: float) -> Array:
	var dialogue := get_dialogue(key)
	var choices: Array = dialogue.get("choices", [])
	return choices.filter(func(c): return rep >= c.get("min_rep", -100))


func get_lines(key: String) -> Array:
	return get_dialogue(key).get("lines", [])


func get_speaker(key: String) -> String:
	return get_dialogue(key).get("speaker", "???")
