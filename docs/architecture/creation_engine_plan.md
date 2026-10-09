# Skelerealms: Creation Engine for Godot — Full Plan

## 1. Vision

**One sentence:** Skelerealms becomes the framework a small team uses to ship an
*Elder Scrolls / Fallout / Outer Worlds*-style first-person RPG in Godot —
persistent simulated worlds, systemic NPCs, branching quests and dialogue,
moddable data — without building the engine layer themselves.

**Design principles (constraints that keep this shippable):**

- **Framework, not game.** No lore, no story, no art. Every system ends at a
  data contract + default implementation.
- **Godot-native, not an emulation.** Use Godot's scene tree, resources,
  navigation, and editor — don't rebuild Papyrus or the CK render window.
  The "Creation Kit" is a set of Godot editor tools, not a separate app.
- **Single-player, desktop-first.** Multiplayer was audited as not-ready;
  Creation Engine games are single-player. Keep that boundary.
- **Data-driven + moddable from day one.** Every new system ships with its
  resource format, validation, and mod-merge story.
- **Testable gates.** Every milestone ends in automated checks + a playable
  slice.

## 2. Honest inventory: what exists vs. what a CE needs

| CE subsystem | Skelerealms today | Verdict |
|---|---|---|
| Persistent entities, saves/migrations/checksums | Entity manager, save system, spawn persistence | **Strong** |
| NPC AI (packages, perception, factions, crime) | GOAP, schedules, BT, covens, CrimeMaster, guard challenge | **Strong** |
| Dialogue trees + conditions/effects | Engine, sessions, editor | **Strong, needs depth** |
| Quest graphs + validation | Graph engine, params, ANY-join, editor | **Strong, needs aliases/stages** |
| Inventory/loot/barter/crafting data | Components, loot tables, recipes, stations (data) | **Partial** |
| Combat (melee/hitscan, poise, states) | Hitboxes, pipeline, state machine | **Partial** |
| FPS controller, interaction, stealth | Puppets, prompts, stealth provider | **Strong** |
| UI framework (HUD + menus) | Manager, shells, 6 menu contracts | **Partial** |
| World streaming | WorldLoader, doors, generic chunk manager | **Partial** |
| Mods | Manifests, loader | **Early** |
| Editor tools | Quest/dialogue/coven/save/schedule editors | **Partial** |
| Character progression | Attributes/skills components | **Early** |
| Magic delivery | Spell/effect/projectile scripts | **Early** |
| Crime resolution | Tracking, fines, theft | **Partial** |
| Map, weather, music direction, perks, jail flow, quest aliases, radiant director, companions/affinity, scenes, animation graphs | — | **Missing** |

**The short version:** AI/simulation/persistence/dialogue/quests are genuinely
ahead. The gaps cluster in five places: **world scale**, **story runtime**
(aliases, scenes, radiant), **character progression**, **kit/editor unification**,
and **atmosphere** (map, music, weather).

## 3. The work — 12 workstreams

### WS-A — World & streaming (cells, not just scenes)

- Formalize **cells**: exterior worldspaces (large, streamed) vs. interiors
  (small, atomic loads). Extend `WorldLoader` with cell descriptors: bounds,
  neighbors, interior flag.
- **Streaming policy**: radius-based preload around player (built on
  `SKChunkManager`), interior doors as hard loads, exteriors as soft stream.
- **LOD/occlusion conventions** (Godot does the heavy lifting): documented
  setup plus a validation tool that flags violations.
- **Distant encounters**: extend fade/simulation distances to worldspace scale
  with profiling budgets.
- *Gate:* 3×3 exterior cell grid streams around the player with zero hitches
  >100ms on target hardware; interior↔exterior round trip preserves state.

### WS-B — Actors & AI depth

- **AI packages v2**: ordered package stacks (eat → work → sleep → patrol)
  evaluated from needs/schedules. GOAP stays for combat/objectives.
- **Dialogue scenes**: multi-actor coordinated conversations with phases.
- **Force-greet + AI hellos**: radius/event-driven barks and confrontations.
- **Companion framework**: follow/wait, affinity events, companion quests.
- **Creatures**: generalize puppets beyond humanoid `CharacterBody3D`.
- **Animation conventions**: AnimationTree templates every game can target.
- *Gate:* a town of 12 scheduled NPCs + 1 companion + 1 creature runs a full
  day cycle, observable in a debug overlay.

### WS-C — Story runtime (the biggest Bethesda gap)

- **Quest aliases**: named slots filled at quest start (nearest X, faction
  member, etc.). THE Creation Kit mechanic we're missing.
- **Quest stages + journal**: stage-indexed log entries, objectives,
  done/failed states, journal menu wiring.
- **Radiant Story Manager**: event-driven quest dispenser — templates +
  aliases + cooldowns.
- *Gate:* one handcrafted quest using 3 aliases + one radiant template issuing
  10 consecutive bug-free quests across save/load.

### WS-D — Dialogue depth

- **Persuasion framework**: skill/disposition checks as first-class choice
  conditions with success/fail branches.
- **Voice pipeline hooks**: per-line audio IDs, subtitle timing.
- **Bark system**: combat/idle/event one-liners with cooldowns.
- *Gate:* a 20-node tree with persuasion, barks, and voice IDs validates
  clean and plays end-to-end.

### WS-E — Character progression

- **Leveling flow**: XP sources → level-ups → attribute/perk picks.
- **Perk/trait trees**: data resources + effect hooks into existing APIs.
- **Character creation**: race/background menu flow with testable generator.
- *Gate:* new character → level 5 purely through documented XP sources,
  save-stable.

### WS-F — Magic & crafting

- **Spell delivery hardening**: projectile/beam/AoE/concentration with
  friendly-fire, crime, and resistance integration.
- **Enchantment**: effect-on-strike/worn system reusing spell effects.
- **Crafting stations + UI**: alchemy/cooking/smithing with recipe discovery.
- *Gate:* brew a potion from gathered ingredients, enchant a weapon, both
  persist and function.

### WS-G — Crime & punishment completion

- **Jail flow**: serve time (skill decay + time advance) vs. pay vs. resist.
- **Stolen-goods fencing**: fence vendors + guard item searches.
- **Heat/wanted levels** per faction driving guard aggression.
- *Gate:* steal → confronted → all three resolutions work; fenced goods
  launder correctly.

### WS-H — UI shell completion

- **World map**: fog of war, discovered markers, fast travel.
- **Quest compass**: markers from active quest aliases/objectives.
- **Menu contracts**: magic/perk/map additions to the existing six.
- *Gate:* full menu loop operable controller + mouse, legible at 720p.

### WS-I — Audio & atmosphere

- **Music director**: explore/combat/sneak/night layers with crossfade rules.
- **Weather + time**: region weather types, transitions, time-scale control.
- **Reverb/ambience zones**: interior/exterior audio volumes.
- *Gate:* 24-hour cycle with weather shifts, music state changes, and NPC
  schedule reactions.

### WS-J — The Creation Kit (editor unification)

- **Kit window**: one panel hosting world/entity/quest/dialogue/coven/schedule
  tools with shared services (dirty tracking, resource wizards).
- **New editors**: leveled-list editor, spell/magic-effect editor, perk-tree
  editor, alias picker (quest editor enhancement).
- **Validation suite**: "Verify world" — dangling refs, navmesh gaps,
  unlinked doors — one report across all tools.
- **Cook/pack**: one-click mod packaging from manifests.
- *Gate:* a new user builds room → NPC → quest → dialogue → loot entirely
  inside the kit, verified by the suite.

### WS-K — Mods 2.0

- Load order, override chains (last-writer-wins with conflict flags),
  dependency declarations, in-game mod menu.
- *Gate:* two conflicting mods load in declared order with conflicts listed.

### WS-L — The proving game

- A **playable vertical slice** in `example/`: character creation → tutorial
  dungeon → town (12 NPCs, shops, 3 quests incl. one branch, one radiant
  chain) → wilderness cell → boss encounter.
- Performance budgets published from measured runs.
- *Gate:* 45-minute playthrough, zero script errors, save/load mid-dungeon.

## 4. Phased roadmap

| Phase | Focus | Ships when… |
|---|---|---|
| **1 — Story runtime** (WS-C, WS-D) | Aliases, stages/journal, radiant manager, scenes, persuasion | Handcrafted + radiant quests run save-stable |
| **2 — People** (WS-B, WS-E) | Packages v2, companions+affinity, creatures, leveling/perks/chargen | Town day-cycle + companion + level 1→5 proven |
| **3 — World** (WS-A, WS-I) | Cells/streaming, LOD conventions, weather, music director | 3×3 streaming grid + 24h atmosphere cycle |
| **4 — Systems closure** (WS-F, WS-G, WS-H) | Magic/enchanting, crafting UI, jail/fencing, map/compass | Full loop: fight → loot → craft → enchant → jailed → released |
| **5 — Kit & mods** (WS-J, WS-K) | Unified kit, new editors, verify-world, load order | New user builds room→NPC→quest→loot guided only by UI |
| **6 — Proving game** (WS-L) | Vertical slice + budgets + docs | 45-min playthrough gates pass |

Deliberate ordering: story runtime first because aliases unblock quest
design; world streaming waits until the slice needs it; kit/mods last
because they package what exists.

## 5. Non-goals (explicit)

Multiplayer. Voxel terrain/building. Console certification. Engine-level
rendering features (Godot's job). Voice synthesis. Any shipped lore/content
— the proving slice uses throwaway placeholder content only.

## 6. Risks

- **Scope creep into game content** → every slice uses greybox content;
  content PRs rejected unless they prove a framework contract.
- **Editor scope explosion (kit)** → kit = host panel + shared services
  first; new editors only for data types that prove painful without them.
- **Performance unknowns at worldspace scale** → budgets measured from
  Phase 3's streaming gate and enforced by the verify-world tool.
- **API churn vs. 1.0 stability promise** → all new APIs start Beta tier
  per `api_stability.md`; Stable tier untouched.

## 7. Work log

- **Task 1 (done): quest aliases** — `QuestAlias` resource, injectable finder
  (`QuestSystem` default backed by `SKEntityManager`), ordered fill with
  nearest/exclude/optional semantics, match-time `{Alias}` resolution,
  save-stable fills, `validate_aliases`, alias demo quest
  (`example/quests/alias_demo_quest.tres`), GUT suite, user-guide section.
- **Task 2 (done): quest stages + journal** — `QuestStage` resource
  (log/objective/trigger/completes/fails), explicit `set_stage` plus
  node-triggered auto-advance, alias-resolved journal entries, journal and
  HUD-objective APIs, `quest_failed` signal, `validate_stages`, staged demo
  flow, GUT suite, user-guide section, journal menu contract.
- **Task 3 (done): radiant story manager** — `RadiantTemplate` resource,
  pure `RadiantEngine` (match/cooldown/cap planning, numbering, snapshots),
  `RadiantSystem` autoload (game clock, execution, signals, order-proof
  save/load, loading guards), auto-forward from quest events,
  `unregister_quest` support, GUT suite, user guide, plan + roadmap updates.
- **Task 4 (done): dialogue scenes + persuasion** — `DialogueScene`
  resource (cast, participants, greet radius), pure `DialogueSceneRunner`
  (perform/advance/block/save), `DialogueSystem` scene hosting with speaker
  override, persuasion attempts on choices (skill/disposition rolls,
  fail branches, fail effects, seeded RNG), disposition context hook, scene
  + persuasion validation, GUT suite, user-guide sections.
- **Task 5 (done): barks + voice hooks** — `DialogueBark` resource reusing
  tree-choice conditions, pure `BarkEngine` (priority/speaker/condition/
  cooldown/chance picking, injected clock + RNG), `BarkSystem` autoload with
  payload signal, shared `DialogueConditions` evaluator (session refactored
  onto it), voice id + hold time on nodes/views/barks, GUT suite,
  user-guide sections.
- **Task 6 (done): companion framework** — `CompanionComponent` (recruit/
  follow/affinity/home/carry/perk data with save/load),
  `CompanionFollowModule` steering (walk/catch-up/cross-world teleport,
  busy + anchor guards), `CompanionSystem` autoload (roster, orders, party
  cap, affinity bands + milestones + fracture walk-aways, no save state to
  drift), dialogue recruit/dismiss effects and companion conditions, GUT
  suite, user guide.
- **Task 7 (done): AI packages v2** — `AIPackage` resource (priority, time
  windows with overnight wrap, need gates, entity/fixed targets, furniture
  tags), `PackageComponent` evaluation (need-urgency scoring, change-only
  signals, save/load, validation), `PackageMovementModule` execution
  (steering, nearby-only seating, switch release, companion/busy yields),
  GUT suite, user guide.
- **Task 8 (done): character progression** — XP crash fix + carryover +
  null-config guards + perk rate hook in `SkillsComponent`, `Perk`/
  `PerkEffect` resources, `PerkComponent` (grants, level-funded points),
  `PerkSystem` autoload (registry, requirement matrix, grants, live
  queries, validation), `Origin` starting packages, GUT suite, user guide.
- **Task 9 (done): creatures** — `CreatureProfile` body plans,
  `CreaturePuppet` (navmesh ground mode + self-steered flight, live target
  store, one-shot sense/collision application), `DefaultMovement`
  zero-vector fix with tested steering helper, full NPC-stack composition
  (companions, packages, combat untouched), GUT suite, user guide.
- **Task 10 (done): world streaming (WS-A)** — `CellDefinition` grid cells
  + `WorldspaceDefinition` (radii, fade policy, validation),
  `CellChunkSource` (threaded loads, null=error vs empty-wilderness
  protocol) + `CellChunkAdapter` (center mounts) over `SKChunkManager`,
  `CellStreamer` lifecycle with fade apply/restore, per-entity fade-cache
  invalidation, `WorldValidator` (doors/cells/budgets), GUT suite,
  user guide.
