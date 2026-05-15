extends Node

const QUEST_PATH := "res://quests/demo_quest.tres"
const DIALOGUE_PATH := "res://dialogue/guard_greeting.tres"
const QUICK_SLOT := "quicksave"
const GUARD_INTERACT_DISTANCE := 2.5
const PICKUP_TARGET := &"chest"

@onready var world_loader: WorldLoader = $WorldLoader
@onready var entity_manager: SKEntityManager = $SKEntityManager
@onready var world_origin: Node3D = $WorldOrigin

var _quest_done := false
var _dialogue_triggered := false
var _quest_id: StringName = &""
var _dialogue_id: StringName = &""


func _ready() -> void:
    GameInfo.world_origin = world_origin
    _register_content()
    _ensure_core_entities()
    GameInfo.start_game()
    _load_default_world()


func _process(_delta: float) -> void:
    if Input.is_action_just_pressed(&"quick_save"):
        SaveSystem.save(QUICK_SLOT)
    if Input.is_action_just_pressed(&"quick_load"):
        SaveSystem.load_slot(QUICK_SLOT)

    if not _quest_done:
        _try_complete_fetch_quest()
    if not _dialogue_triggered:
        _try_trigger_guard_greeting()


func _register_content() -> void:
    var quest_def := load(QUEST_PATH) as QuestDefinition
    if quest_def:
        QuestSystem.register_quest(quest_def)
        _quest_id = quest_def.id
        QuestSystem.activate_quest(_quest_id)

    var dialogue_def := load(DIALOGUE_PATH) as DialogueDefinition
    if dialogue_def:
        DialogueSystem.register_dialogue(dialogue_def)
        _dialogue_id = dialogue_def.id


func _load_default_world() -> void:
    var default_world := "demo_world"
    if SkeleRealmsGlobal.config and not SkeleRealmsGlobal.config.default_world.is_empty():
        default_world = SkeleRealmsGlobal.config.default_world
    GameInfo.world = StringName(default_world)
    world_loader.load_world(default_world)


func _ensure_core_entities() -> void:
    var player := entity_manager.get_entity(&"player")
    if player:
        player.world = "demo_world"
        player.position = Vector3(0.0, 1.2, 0.0)
    entity_manager.get_entity(&"guard")
    entity_manager.get_entity(&"chest")


func _try_complete_fetch_quest() -> void:
    var player := entity_manager.get_entity(&"player")
    if not player:
        return
    var inv := player.get_component("InventoryComponent") as InventoryComponent
    if not inv:
        return
    if inv.has_item(String(PICKUP_TARGET)):
        QuestSystem.report_pickup(PICKUP_TARGET)
        _quest_done = true


func _try_trigger_guard_greeting() -> void:
    if _dialogue_id == &"":
        return
    var player := entity_manager.get_entity(&"player")
    var guard := entity_manager.get_entity(&"guard")
    if not player or not guard:
        return
    if player.position.distance_to(guard.position) > GUARD_INTERACT_DISTANCE:
        return
    var node := DialogueSystem.start_dialogue(_dialogue_id)
    if node and node.choices.size() > 0:
        DialogueSystem.choose(node.choices[0].id)
    _dialogue_triggered = true
