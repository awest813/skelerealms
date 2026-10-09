class_name DialogueNode
extends Resource
## A single node (line of dialogue) in a dialogue tree.


## Unique ID for this node within the dialogue.
@export var id: StringName
## Who is speaking (entity ref-ID or display name / translation key).
@export var speaker: String
## The dialogue text (can be a translation key).
@export_multiline var text: String
## If true, the dialogue ends after this node regardless of choices.
@export var terminal: bool = false
## Voice line id for dubbed audio. Empty means unvoiced (subtitle only).
@export var voice_id: StringName
## Seconds to hold the subtitle. 0 means the game decides (line length).
@export var display_seconds: float = 0.0
## Choices the player can make from this node.
@export var choices: Array[DialogueChoice] = []
## Editor-only graph layout position, maintained by the dialogue tree editor.
## Ignored at runtime; safe to leave at the default for grid auto-layout.
@export var editor_position: Vector2 = Vector2.ZERO
