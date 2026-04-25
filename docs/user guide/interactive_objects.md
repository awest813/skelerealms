# Interactive Objects

This guide covers the concrete [InteractiveObject] subclasses that ship with Skelerealms. These are physical world objects (not entities) that react when the player or an NPC interacts with them.

All classes extend `InteractiveObject`, which itself extends `SKWorldObject → Node3D`. They are placed directly in world scenes, not in the entity manager.

---

## Common interaction model

Every interactive object:
- Has **`interactible: bool`** — can be set to `false` to disable interaction.
- Has **`interact_verb: String`** — shown on the interaction prompt (e.g. "Open", "Press").
- Has **`object_name: String`** — shown alongside the verb.
- Emits **`on_interact(id: String)`** when interacted with.
- Can receive messages via `receive_message(msg, args)` (used by `StatusEffect` broadcast).

The FPS puppet casts a ray and calls `interact(interactor_id)` on the hit `InteractiveObject`.

---

## SwingDoorObject

A physical door that opens in-place (swing or slide). Does **not** change worlds — for world-to-world transitions use the existing `Door` class.

```
SwingDoorObject (Node3D)
└── AudioStreamPlayer3D   (optional, for open/close/locked sounds)
```

### Key exports

| Export | Description |
|---|---|
| `door_type` | `ROTATING` (swings on Y axis) or `SLIDING` (translates along an axis) |
| `closed_rotation_deg` | Local Euler angles when closed |
| `open_rotation_deg` | Local Euler angles when open |
| `closed_position` / `open_position` | Local position when closed/open (sliding only) |
| `door_speed` | Tween duration in seconds |
| `auto_close_delay` | Seconds before the door closes itself (0 = disabled) |
| `is_locked` | Whether the door starts locked |
| `key_form_id` | FormID of the key item that unlocks. Leave blank for keypad/script-only lock |

### Programmatic API

```gdscript
door.open_door()
door.close_door()
door.lock()
door.unlock()    # bypass key check
```

### Connecting to a KeypadObject

```gdscript
# In the keypad's correct_code_entered signal:
keypad.correct_code_entered.connect(door.unlock)
keypad.correct_code_entered.connect(door.open_door)
```

---

## AnimatedInteractiveObject

Base class for objects driven by an `AnimationPlayer`. Subclass this for hatches, drawers with complex rigs, or any object with bespoke animation.

```
AnimatedInteractiveObject (Node3D)
├── AnimationPlayer
└── AudioStreamPlayer3D   (optional)
```

Override `_do_open()` and `_do_close()` in a subclass to add logic beyond playing the animation.

### Key exports

| Export | Description |
|---|---|
| `open_animation` | Animation name to play when opening |
| `close_animation` | Animation name to play when closing (blank = play open in reverse) |
| `starts_open` | Jump to end of open animation on `_ready` |
| `locked` | Block interaction |

---

## ButtonObject

A single-press (or repeatable) button that chains to other interactive objects.

```
ButtonObject (Node3D)
└── AudioStreamPlayer3D   (optional)
```

### Key exports

| Export | Description |
|---|---|
| `allows_repeat` | Allow pressing multiple times |
| `cooldown_time` | Seconds before re-press is allowed |
| `objects_to_trigger` | Array of NodePaths to call `interact(id)` on |
| `trigger_delay` | Delay before calling chained objects |
| `press_sound` | AudioStream to play on press |

### Signals

| Signal | When |
|---|---|
| `pressed` | Button was successfully pressed |
| `cooldown_changed(active)` | Cooldown started or ended |

### Example: button that opens a door after a delay

In the Inspector:
- `objects_to_trigger` → `[../SwingDoor]`
- `trigger_delay` → `1.0`

---

## KeypadObject

Logic-only code-entry component. Your game provides the UI; this class manages digit accumulation, validation, and signals.

```
KeypadObject (Node3D)
└── AudioStreamPlayer3D   (optional)
```

### Calling sequence (from your UI)

```gdscript
keypad.enter_digit("3")   # called by each number button
keypad.enter_digit("7")
keypad.submit_code()      # called by confirm button (or auto if auto_submit = true)
```

### Signals

| Signal | When |
|---|---|
| `correct_code_entered` | Entered code matches `passcode` |
| `wrong_code_entered(entered)` | Wrong code submitted |
| `code_display_changed(display)` | Digit added or code cleared — connect to a Label |
| `attempts_exhausted` | Max wrong attempts reached |

### Key exports

| Export | Description |
|---|---|
| `passcode` | The correct code string |
| `auto_submit` | Validate automatically when correct digit count is reached |
| `max_attempts` | Maximum wrong tries (0 = unlimited) |
| `mask_input` | Emit asterisks in `code_display_changed` instead of digits |

### Wiring to a door

```gdscript
# In the scene or via @onready in a parent script:
keypad.correct_code_entered.connect(door.unlock)
keypad.correct_code_entered.connect(door.open_door)
keypad.code_display_changed.connect(display_label.set_text)
```

---

## Receive message support

All world objects built on `SKWorldObject` can receive status-effect messages from `broadcast_message`. Override `receive_message(msg, args)` in any subclass to respond. Example:

```gdscript
# In a custom subclass
func receive_message(msg: StringName, args: Array = []) -> void:
    if msg == &"power_on":
        _do_open()
```

---

## Building your own interactive object

```gdscript
class_name MyTrigger
extends InteractiveObject

signal triggered(id: String)

func _init() -> void:
    object_name = "My Trigger"
    interact_verb = "Activate"

func interact(id: String) -> void:
    super.interact(id)   # emits on_interact
    triggered.emit(id)
    # ... do your thing
```
