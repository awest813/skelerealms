extends RefCounted
## Lightweight dialogue trees for station contacts. Definitions are plain
## Dictionaries (JSON-safe) built in code: each has a start node id and a
## node map. Nodes carry speaker, text with {placeholders}, and choices with
## goto ids plus effect strings the game layer interprets.
##
## Pure logic, no scene-tree access. choose() returns the next node and any
## effect; rendering substitutes context values into text.

var definitions := {}
## Template values (e.g. live market prices) substituted into node text.
var context := {}
var _current_def := ""
var _current_node := ""


## Register a tree: nodes is an Array of {id, speaker, text, choices}.
## Each choice is {text, to, do} where "do" is an effect string or "".
static func make_definition(start: String, nodes: Array) -> Dictionary:
	var by_id := {}
	for node in nodes:
		by_id[str(node.get("id", ""))] = node
	return {"start": start, "nodes": by_id}


func add_definition(id: String, definition: Dictionary) -> void:
	definitions[id] = definition


func start(id: String) -> Dictionary:
	if not definitions.has(id):
		return {}
	_current_def = id
	_current_node = str(definitions[id].get("start", ""))
	return current()


func current() -> Dictionary:
	if _current_def.is_empty() or _current_node.is_empty():
		return {}
	var nodes: Dictionary = definitions[_current_def].get("nodes", {})
	if not nodes.has(_current_node):
		return {}
	return _rendered(nodes[_current_node])


## Jump to a node without rolling (failed checks, scripted redirects).
func go(node_id: String) -> Dictionary:
	var nodes: Dictionary = definitions.get(_current_def, {}).get("nodes", {})
	if nodes.has(node_id):
		_current_node = node_id
	return current()


## Pick choice index. Returns {"node": next, "effect": do-string}.
func choose(index: int) -> Dictionary:
	var node := current()
	var choices: Array = node.get("choices", [])
	if index < 0 or index >= choices.size():
		return {"node": node, "effect": ""}
	var choice: Dictionary = choices[index]
	_current_node = str(choice.get("to", _current_node))
	return {"node": current(), "effect": str(choice.get("do", ""))}


func _rendered(node: Dictionary) -> Dictionary:
	var copy := node.duplicate(true)
	copy["text"] = _render(str(node.get("text", "")))
	var rendered_choices := []
	for choice in (node.get("choices", []) as Array):
		var choice_copy := (choice as Dictionary).duplicate()
		choice_copy["text"] = _render(str(choice.get("text", "")))
		rendered_choices.append(choice_copy)
	copy["choices"] = rendered_choices
	return copy


func _render(text: String) -> String:
	var out := text
	for key in context:
		out = out.replace("{%s}" % str(key), str(context[key]))
	return out
