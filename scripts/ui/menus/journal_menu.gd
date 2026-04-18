class_name SKJournalMenu
extends Control
## Contract for a quest journal menu page.
##
## Subclass and override [method populate_quests] to display active
## and completed quests. Wired to [signal QuestSystem.quest_updated].


## Populate the journal with active and completed quest data.
func populate_quests(active:Array, completed:Array) -> void:
	pass


## Called when the player selects a quest entry.
func on_quest_selected(quest_id:StringName) -> void:
	pass
