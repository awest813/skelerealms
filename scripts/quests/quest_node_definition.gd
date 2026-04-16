class_name QuestNodeDefinition
extends Resource
## Defines a single objective node within a quest graph.


## Unique ID for this node within the quest.
@export var id: StringName
## Human-readable description of the objective (can be a translation key).
@export var description: String
## What kind of event completes this node.
@export_enum("kill", "pickup", "talk", "custom") var trigger_type: String = "custom"
## The target entity/item ref-ID that the trigger applies to.
@export var target_id: StringName
## How many times the trigger must fire to complete this node.
@export var required_count: int = 1
## Nodes that must be completed before this node can become active.
@export var prerequisites: Array[StringName] = []
## Explicit next nodes to activate when this node completes.
## If empty, the engine activates any node whose prerequisites are now met.
@export var next_node_ids: Array[StringName] = []
