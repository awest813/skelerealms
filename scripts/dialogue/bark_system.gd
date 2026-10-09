extends Node
## Autoload singleton: one-liner barks for game events.
##
## Game code triggers barks (combat start, kills, greetings, custom beats)
## and displays/voices the winner; all picking logic lives in BarkEngine.
## Cooldowns are ephemeral by design, so this system keeps no save state.
## NOTE: intentionally no class_name — like GameInfo and SaveSystem, the
## autoload instance is referenced dynamically by name.


## Emitted when a bark fires: speaker, text, voice id, hold seconds.
signal bark_said(speaker: StringName, text: String, voice_id: StringName, display_seconds: float)


## The underlying bark engine.
var engine := BarkEngine.new()


## Register a [DialogueBark].
func register_bark(bark: DialogueBark) -> void:
	engine.register_bark(bark)


## Remove a bark.
func unregister_bark(bark_id: StringName) -> void:
	engine.unregister_bark(bark_id)


## Returns true if a bark is registered.
func has_bark(bark_id: StringName) -> bool:
	return engine.has_bark(bark_id)


## Fire a bark for a trigger channel and speaker. Returns the bark payload
## ({bark_id, speaker, text, voice_id, display_seconds}) or {} when nothing
## is eligible. Pass a custom DialogueContext subclass for gated barks.
func say(trigger: StringName, speaker: StringName, context: DialogueContext = null) -> Dictionary:
	if not context:
		context = DialogueContext.new()
	var bark := engine.query(trigger, speaker, context)
	if bark == null:
		return {}
	bark_said.emit(speaker, bark.text, bark.voice_id, bark.display_seconds)
	return {
		"bark_id": bark.id,
		"speaker": speaker,
		"text": bark.text,
		"voice_id": bark.voice_id,
		"display_seconds": bark.display_seconds,
	}


## Validate a bark without registering it. See BarkEngine.validate_bark.
func validate_bark(bark: DialogueBark) -> Array:
	return engine.validate_bark(bark)
