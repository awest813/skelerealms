class_name RadiantTemplate
extends Resource
## One repeatable quest recipe for the Radiant Story Manager.
##
## A template pairs a [QuestDefinition] (instanced fresh per issuance, so
## parallel instances never share state) with a trigger: any game event of
## [member trigger_type] — optionally restricted to [member trigger_target] —
## evaluates issuance, gated by per-template cooldowns and active-instance
## caps. Alias slots on the quest template fill normally at activation, so
## radiant quests can target live entities like any handcrafted quest.


## Stable id; instances are named "<id>_001", "<id>_002", ...
@export var id: StringName
## The quest instanced per issuance. Never register this directly —
## only instances enter the quest engine.
@export var quest_template: QuestDefinition
## QuestEvent type that evaluates this template ("kill", "pickup", "talk", "custom").
@export var trigger_type: String = "kill"
## Required event target ref-ID, or empty for any target of the type.
@export var trigger_target: StringName
## Game minutes before this template may issue again.
@export var cooldown_minutes: int = 60
## Max simultaneously active instances of this template.
@export var max_active: int = 1
## Static template params merged at activation (explicit params win).
@export var extra_params: Dictionary = {}
