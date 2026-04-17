class_name ModManifest
extends Resource
## Declares all content a mod contributes to the game.
##
## Place one or more [ModManifest] resources (as [code].tres[/code] files) inside
## the directory configured by [code]skelerealms/mods_path[/code] (default
## [code]res://mods[/code]).  [ModLoader] scans that directory at game-start and
## calls [method ModLoader.load_mod] for each manifest it finds.
##
## Supported contribution types:
## [br]• New [Coven] resources — registered with [CovenSystem].
## [br]• New [QuestDefinition] resources — registered with [QuestSystem].
## [br]• New [DialogueDefinition] resources — registered with [DialogueSystem].
## [br]• [CovenOpinionOverride] entries — applied via [CovenSystem.change_opinion].


## Unique identifier for this mod.  Used to prevent loading the same mod twice.
@export var mod_id: StringName
## Human-readable display name shown in debug output.
@export var mod_name: String

@export_category("Covens")
## New [Coven] resources to register with [CovenSystem].
@export var covens: Array[Coven] = []
## Opinion adjustments between existing and/or new covens.
@export var coven_opinion_overrides: Array[CovenOpinionOverride] = []

@export_category("Quests")
## New [QuestDefinition] resources to register with [QuestSystem].
@export var quests: Array[QuestDefinition] = []

@export_category("Dialogue")
## New [DialogueDefinition] resources to register with [DialogueSystem].
@export var dialogues: Array[DialogueDefinition] = []
