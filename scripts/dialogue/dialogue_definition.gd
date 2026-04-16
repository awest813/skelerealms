class_name DialogueDefinition
extends Resource
## Defines an entire dialogue tree.


## Unique ID for this dialogue.
@export var id: StringName
## The ID of the first node shown when the dialogue starts.
@export var start_node_id: StringName
## All nodes in this dialogue tree.
@export var nodes: Array[DialogueNode] = []
