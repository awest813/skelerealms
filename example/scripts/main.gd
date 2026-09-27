extends Node

const QUEST_PATH := "res://quests/demo_quest.tres"
const DIALOGUE_PATH := "res://dialogue/guard_greeting.tres"
const QUICK_SLOT := "quicksave"
const GUARD_INTERACT_DISTANCE := 2.5
const PICKUP_TARGET := &"chest"

@onready var world_loader: WorldLoader = $WorldLoader
@onready var entity_manager: SKEntityManager = $SKEntityManager
@onready var world_origin: Node3D = $WorldOrigin

var _pending_save: Dictionary = {}
var _quest_done := false
var _dialogue_triggered := false
var _quest_id: StringName = &""
var _dialogue_id: StringName = &""


func _ready() -> void:
    GameInfo.world_origin = world_origin
    world_loader.world_loading_ready.connect(_on_world_ready)
    world_loader.world_loading_failed.connect(_on_world_failed)
    _register_content()
    _ensure_core_entities()
    GameInfo.start_game()
    _load_default_world()


func _process(_delta: float) -> void:
    if Input.is_action_just_pressed(&"quick_save"):
        SaveSystem.save(QUICK_SLOT)
    if Input.is_action_just_pressed(&"quick_load"):
        request_load_slot(QUICK_SLOT)

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


## Prepare the destination before changing live player, quest or economy state.
func request_load_slot(slot: String) -> bool:
    if GameInfo.is_loading or not _pending_save.is_empty():
        return false
    var file := FileAccess.open("user://saves/%s.dat" % slot, FileAccess.READ)
    if not file:
        return false
    var snapshot := SaveSystem._deserialize(file.get_as_text())
    if not SaveSystem._valid_snapshot(snapshot):
        return false
    var destination: Variant = snapshot["game_info"].get("GameInfo", {}).get("world", "")
    if not destination is String or not world_loader.world_paths.has(destination):
        return false
    _pending_save = snapshot
    if not world_loader.load_world(destination):
        _pending_save = {}
        return false
    return true


func _on_world_ready() -> void:
    if not _pending_save.is_empty():
        var prepared := _pending_save
        _pending_save = {}
        SaveSystem.restore_snapshot(prepared)
    _restore_player_pose()


func _on_world_failed(_message: String) -> void:
    _pending_save = {}


func _restore_player_pose() -> void:
    var player := entity_manager.get_entity(&"player")
    if not player:
        return
    var spawner := player.get_component("PuppetSpawnerComponent") as PuppetSpawnerComponent
    if spawner and is_instance_valid(spawner.puppet):
        var puppet := spawner.puppet as Node3D
        puppet.position = player.position
        puppet.quaternion = player.rotation
        GameInfo.world_origin = puppet
