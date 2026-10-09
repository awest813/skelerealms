class_name DialogueScene
extends Resource
## A coordinated multi-actor conversation in the Skyrim scene tradition.
##
## A scene plays a backing [DialogueDefinition] tree with a pinned cast:
## each tree node may name which participant speaks that line, so two NPCs
## (and the player) can hold a scripted exchange using the ordinary choice
## machinery — conditions, effects, and persuasion attempts all keep working.
## While running, participants are reported as blocked so the game layer can
## hold their AI packages; when the tree ends, the scene ends.


## Unique ID for this scene.
@export var id: StringName
## The dialogue tree this scene performs.
@export var dialogue_id: StringName
## Every actor that takes part, as entity ref-IDs. "player" is allowed.
@export var participants: Array[StringName] = []
## Actors that must be present to start. Empty means all participants.
@export var required_participants: Array[StringName] = []
## Node id -> speaking actor ref. Nodes missing here use their authored speaker.
@export var cast: Dictionary[StringName, StringName] = {}
## Proximity trigger radius in metres. 0 disables auto-greet (manual starts only).
@export var greet_radius: float = 0.0
