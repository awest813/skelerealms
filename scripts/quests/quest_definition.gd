class_name QuestDefinition
extends Resource
## Defines an entire quest as a graph of [QuestNodeDefinition]s.


## Unique ID for this quest.
@export var id: StringName
## Display name (can be a translation key).
@export var quest_name: String
## Optional description.
@export_multiline var description: String
## The objective nodes that make up this quest.
@export var nodes: Array[QuestNodeDefinition] = []
## Which nodes are activated when the quest starts. If empty, nodes with no prerequisites are used.
@export var start_node_ids: Array[StringName] = []
## Which nodes must be completed to finish the quest. If empty, all nodes must be completed.
@export var completion_node_ids: Array[StringName] = []
## XP awarded when the quest is completed.
@export var xp_reward: int = 0
