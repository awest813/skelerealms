# Behaviour Trees

Skelerealms includes a standalone behaviour tree (BT) framework under
`scripts/ai/behaviour_tree/`.  It is designed to complement the GOAP system:
**GOAP selects the high-level goal; BTs execute the detailed action logic**.

---

## Class overview

| Class | File | Role |
|---|---|---|
| `SKBTNode` | `sk_bt_node.gd` | Abstract base. Defines `Status` enum (`SUCCESS`, `FAILURE`, `RUNNING`). |
| `SKBTLeaf` | `sk_bt_leaf.gd` | Leaf node — override `tick(delta, actor, blackboard)` for custom behaviour. |
| `SKBTComposite` | `sk_bt_composite.gd` | Base for multi-child nodes (Sequence, Selector, Parallel, Random). |
| `SKBTDecorator` | `sk_bt_decorator.gd` | Base for single-child wrapper nodes. |
| `SKBTRoot` | `sk_bt_root.gd` | Entry-point that drives the tree each frame. |
| `SKBTSequence` | `composites/sk_bt_sequence.gd` | AND: runs children left-to-right; fails on first `FAILURE`. |
| `SKBTSelector` | `composites/sk_bt_selector.gd` | OR: runs children left-to-right; succeeds on first `SUCCESS`. |
| `SKBTParallel` | `composites/sk_bt_parallel.gd` | Runs all children simultaneously. Policy controls success/failure. |
| `SKBTRandom` | `composites/sk_bt_random.gd` | Picks one child at random each activation. |
| `SKBTInverter` | `decorators/sk_bt_inverter.gd` | Flips `SUCCESS` ↔ `FAILURE`; passes `RUNNING` unchanged. |
| `SKBTAlwaysSucceed` | `decorators/sk_bt_always_succeed.gd` | Returns `SUCCESS` regardless of child result. |
| `SKBTAlwaysFail` | `decorators/sk_bt_always_fail.gd` | Returns `FAILURE` regardless. |
| `SKBTRepeat` | `decorators/sk_bt_repeat.gd` | Repeats child N times then returns `on_limit` status. |
| `SKBTLimiter` | `decorators/sk_bt_limiter.gd` | Allows the child to run at most N times; blocks after that. |
| `SKBlackboard` | `sk_blackboard.gd` | Shared key-value store passed through the tree. Serializable. |

---

## Blackboard

`SKBlackboard` is a `Resource` used as runtime scratchpad for BT nodes.

```gdscript
var bb := SKBlackboard.new()
bb.set_value(&"target", enemy_node)
var target = bb.get_value(&"target", null)  # null default if missing
bb.has_value(&"target")   # true
bb.erase_value(&"target") # true — returns false if not found
bb.clear()                # remove everything
```

Blackboards can be saved and restored:

```gdscript
var data := bb.serialize()   # returns Dictionary
bb.deserialize(data)         # restores state
```

---

## Writing a leaf node

Override `SKBTLeaf` and implement `tick`:

```gdscript
class_name PatrolLeaf
extends SKBTLeaf

func tick(delta: float, actor: Node, blackboard: SKBlackboard) -> Status:
    var npc := actor as NPCComponent
    if not npc:
        return Status.FAILURE
    var target := blackboard.get_value(&"patrol_point", null)
    if not target:
        return Status.FAILURE
    npc.set_destination(target)
    if npc._puppet and npc._puppet.target_reached:
        return Status.SUCCESS
    return Status.RUNNING
```

---

## Building a tree in code

```gdscript
var root := SKBTRoot.new()
root.tick_interval = 0.1  # tick every 100 ms

var seq := SKBTSequence.new()
var patrol := PatrolLeaf.new()
var idle   := IdleLeaf.new()

seq.add_child(patrol)
seq.add_child(idle)
root.add_child(seq)

add_child(root)
root.actor = npc_component
root.blackboard = SKBlackboard.new()
```

---

## Building a tree in the scene

1. Add an `SKBTRoot` node to your NPC puppet or entity.
2. Set `actor` (export-assigned in the Inspector) to the `NPCComponent`.
3. Add composite and leaf children in the scene tree.
4. The root calls `tick(delta, actor, blackboard)` automatically at `tick_interval` seconds.

---

## Parallel policy

`SKBTParallel` supports two modes via the `policy` export:

| Policy | Behaviour |
|---|---|
| `SUCCESS_ON_ALL` | Returns `SUCCESS` only when every child succeeds. Fails if any child fails. |
| `SUCCESS_ON_ONE` | Returns `SUCCESS` as soon as any child succeeds. |

---

## GOAP + BT integration pattern

GOAP plans *what* to do; BTs implement *how* to do it.

```gdscript
# In a GOAPAction:
func perform(delta: float) -> bool:
    # Delegate execution to the BT
    var result := _patrol_bt.tick(delta, _npc, _blackboard)
    return result == SKBTNode.Status.SUCCESS
```

The blackboard can be shared between the GOAP component and BT nodes:

```gdscript
# Store GOAP memory entries on the shared blackboard
_blackboard.set_value(&"target_entity", _npc.goap_memory.get("combat_target"))
```

---

## Tests

GUT tests live in `tests/test_behaviour_tree.gd` and cover all composite types,
all decorators, and the `SKBlackboard` API.
