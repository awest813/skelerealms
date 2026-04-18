class_name SKPauseMenu
extends Control
## Contract for a pause menu page.
##
## Subclass to provide resume, save, load, settings, and quit options.


## Called when the player requests to resume the game.
func on_resume() -> void:
	pass


## Called when the player requests to save the game.
func on_save() -> void:
	pass


## Called when the player requests to load a saved game.
func on_load() -> void:
	pass


## Called when the player opens the settings screen.
func on_settings() -> void:
	pass


## Called when the player requests to quit.
func on_quit() -> void:
	pass
