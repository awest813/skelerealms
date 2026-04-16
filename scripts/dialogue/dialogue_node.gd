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
## Choices the player can make from this node.
@export var choices: Array[DialogueChoice] = []
