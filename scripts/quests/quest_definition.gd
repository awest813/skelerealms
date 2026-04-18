class_name QuestDefinition
extends Resource
## Defines an entire quest as a graph of [QuestNodeDefinition]s.
##
## Quest definitions can act as reusable templates.  Set [member parameters]
## to define default placeholder values (e.g. [code]{"target": "wolf"}[/code]).
## When the quest is activated via
## [method QuestGraphEngine.activate_quest_with_params], any [code]{key}[/code]
## placeholder in [member quest_name], [member description], and each node's
## [member QuestNodeDefinition.description] and
## [member QuestNodeDefinition.target_id] will be replaced with the
## corresponding parameter value.


## Unique ID for this quest.
@export var id: StringName
## Display name (can be a translation key).  Supports [code]{variable}[/code] placeholders.
@export var quest_name: String
## Optional description.  Supports [code]{variable}[/code] placeholders.
@export_multiline var description: String
## The objective nodes that make up this quest.
@export var nodes: Array[QuestNodeDefinition] = []
## Which nodes are activated when the quest starts. If empty, nodes with no prerequisites are used.
@export var start_node_ids: Array[StringName] = []
## Which nodes must be completed to finish the quest. If empty, all nodes must be completed.
@export var completion_node_ids: Array[StringName] = []
## XP awarded when the quest is completed.
@export var xp_reward: int = 0
## Default template parameter values.  Keys are placeholder names (without braces),
## values are the default substitution strings.  Override at activation time via
## [method QuestGraphEngine.activate_quest_with_params].
@export var parameters: Dictionary = {}
