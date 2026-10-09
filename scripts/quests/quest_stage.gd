class_name QuestStage
extends Resource
## One journaled beat of a quest, in the Bethesda stage tradition.
##
## Nodes are the quest's mechanics; stages are its narrative. A stage becomes
## current either explicitly via [method QuestGraphEngine.set_stage] or
## automatically when every node in [member trigger_nodes] completes (stages
## with empty triggers only fire as the initial stage or explicitly).
## Each new current stage appends its [member log_entry] to the quest journal.
## Several stages may be current over a quest's life, but only one at a time;
## parallel branches should use one stage per branch.


## Stage number, e.g. 10, 20, 30. Unique within the quest.
@export var index: int = 10
## Journal line written when this stage becomes current. Supports
## [code]{AliasId}[/code] placeholders, resolved against quest fills at log time.
@export_multiline var log_entry: String
## Short objective line shown while this stage is current.
@export var objective: String
## Node IDs whose joint completion advances to this stage automatically.
## Empty means explicit-only (plus the initial-stage rule at activation).
@export var trigger_nodes: Array[StringName] = []
## When true, reaching this stage completes the quest (XP as usual).
@export var completes_quest: bool = false
## When true, reaching this stage fails the quest (no XP, terminal).
@export var fails_quest: bool = false
