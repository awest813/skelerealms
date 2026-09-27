# Space game readiness audit and starting plan

Audited 2026-09-24 at `b3f2e7d`. Scope: prepare Skelerealms for a single-player, preset-ship space combat and trading game. This is a source-level readiness audit, not certification that the framework runs correctly. No gameplay code was changed.

## Verdict

Skelerealms supplies useful persistence, quest, faction, inventory, and UI foundations. It does not yet supply a space game. Proceed with a small consuming game project and targeted framework repairs; avoid converting every existing character system into a spaceship system.

The proposed boundaries are sensible: preset hulls, fixed component slots, a small jump network, station menus, and explicit travel transitions. Treat a one-to-two-year release as an aspiration, not an estimate established by this audit. Flight feel, content production, UI, sound, testing, and performance remain substantial work. Use playable milestone gates before committing to a release schedule.

Working assumptions: desktop, single-player, keyboard/mouse first, placeholder art, assisted flight, and no mandatory surface gameplay in the first slice. These are reversible planning defaults.

## What exists and what must be built

| Capability | Evidence in this repository | Fit for the proposed game |
| --- | --- | --- |
| Persistent entities | `scripts/entities/entity.gd`, `entity_manager.gd` | Reuse stable identities and component persistence; add ship state and verify puppet lifecycle. |
| Saves | `scripts/system/save_system.gd` | Reuse slots, migrations, and serialization hooks after validating scene restoration and ship state round trips. |
| World transitions | `scripts/system/world_loader.gd` | Adapt after fixing scene ownership, overlapping loads, and failure recovery. |
| Inventory and currency | `scripts/components/inventory_component.gd` | Reuse wallet/unique equipment concepts; bulk cargo needs quantity and capacity accounting. |
| Barter | `scripts/barter/barter.gd`, `transaction.gd` | Trades unique entity references; not a commodity market with regional stock, quantities, and price quotes. |
| Quests | `scripts/quests/quest_system.gd`, `quest_graph_engine.gd` | Reuse event progression and saved state; write delivery/bounty generators and reward validation. |
| Factions | `scripts/covens/` | Candidate for faction relationships and hostility. Commodity legality and space policing need game rules. |
| Combat | `scripts/combat/`, `scripts/components/damageable_component.gd` | Reuse damage descriptions and delivery where appropriate; shields, ship weapons, targeting, and destruction are missing. |
| UI | `scripts/ui/` | Menu/HUD contracts and input routing exist. Concrete cockpit HUD, market, outfitting, mission board, and starmap screens are needed. |
| Flight and ship AI | Existing puppets are character/item oriented | New six-axis controller and steering AI. Ground navigation is not ship navigation. |
| World content | `example/worlds/`, `example/puppets/` | Ground RPG demonstration; no authored space slice. |

## Findings to resolve before relying on these systems

Priorities refer to the space-game work. Findings below are established by code inspection; runtime regressions still need reproduction tests.

### P1 — The example cannot resolve its plugin in this checkout

`example/addons/skelerealms` is a nine-byte regular file containing `../../../`. Git records it as a symlink (mode `120000`), but Windows has checked it out as text. Paths in `example/project.godot` therefore cannot resolve the expected plugin directory. The intended link also points back to a repository containing the example, so recursive copying of the whole repository into the example is inappropriate.

Preparation task: provide a reproducible host-project setup using a real plugin directory or supported link, with an explicit file selection if copying. Verify every autoload and plugin path before testing. Keep the framework independently usable.

### P1 — World unload leaks detached scenes

`scripts/system/world_loader.gd:95` removes its first child but does not free or retain it under a managed cache. Repeated jumps leave orphan scene instances allocated.

Preparation task: define scene ownership, retain the current scene until the destination is validated, and dispose of replaced scenes explicitly. Test repeated A/B transitions using orphan-node and memory observations after warm-up.

### P1 — Transition requests can overlap and failure can duplicate a world

`WorldLoader.load_world()` has no in-flight request guard and yields before setting `GameInfo.is_loading`. A second request can overwrite the shared loading state. If `load_threaded_request()` fails before `_unload_world()`, `_abort()` instantiates the previous world even though its original scene is still attached.

Preparation task: use one transition state machine with request identity, destination validation, and a single commit point. Failed or duplicate requests must preserve exactly one active world and restore input. Progress also currently travels through an `int` signal despite a documented 0–1 fraction; make the loading-screen contract consistent.

### P1 — Existing hitscan misses Area3D hurtboxes

`scripts/combat/hit_pipeline.gd:108` constructs a default ray query, then expects its result to be `SKHurtbox`. That class extends `Area3D`, while the query never enables area collisions. Godot 4.4 defaults `collide_with_areas` to false ([official reference](https://docs.godotengine.org/en/4.4/classes/class_physicsrayqueryparameters3d.html)).

Preparation task: explicitly configure target/obstacle masks and area detection. Test hurtbox hits, blocking hull/world geometry, self-exclusion, and one damage event per shot. Merely enabling areas is insufficient if another collider intercepts the ray first.

### P1 — Save restoration does not restore the loaded world scene

`SaveSystem.load_game()` restores entity/global data and emits `load_complete`. The example has no subscriber that then loads the saved world; its quick-load only calls `load_slot()`. Loading a save from system A while in B would change `GameInfo.world` without replacing B's visible scene. Additionally, `load_slot()` returns true for an existing file even if `load_game()` returns early on parse/read failure.

Preparation task: make loading a coordinated transaction with an explicit success result, scene restoration, safe arrival, and puppet state restoration. Test cross-world loads and malformed saves. Never autosave a half-completed transition.

### P2 — Player/puppet transform contract is insufficient for ships

`scripts/components/player_component.gd:55` writes `parent_entity.quaternion`, but `SKEntity` extends `Node` and declares `rotation: Quaternion`. `PuppetSpawnerComponent.spawn()` restores position only. Player hookup subscribes to position once and does not establish a rotation or velocity persistence contract.

Preparation task: define one authoritative ship state, restore orientation and velocities explicitly, and reconnect when a puppet is recreated. Test nonidentity rotation, despawn/respawn, death, and save/load. Do not reuse the FPS player template wholesale.

### P2 — Entity activation uses ground-scale distance assumptions

`example/project.godot:93` sets actor fade distance to 100 units. `example/scripts/main.gd:20` assigns `GameInfo.world_origin` to a stationary marker. `SKEntity._should_be_in_scene()` uses that point to decide whether puppets exist. A ship flying away from it can despawn despite being the player's active vehicle.

Preparation task: track the active player ship as the simulation center, protect its lifecycle from distance culling, and choose encounter activation distances from the flight prototype. `world_origin` is a distance-query anchor, not an implementation of floating-origin coordinate shifting.

## Architecture decisions for the first slice

### Compact local zones, connected through travel

Represent a star system as data: stable ID, display information, stations, encounters, and jump links. Simulate only the current compact zone near the origin. Start with an approximately 2 km radius as a prototype constraint, then measure visual and collision quality. Treat planets and distant stars as visual backdrops. Travel between orbital/station zones and between systems uses explicit transitions.

Resetting coordinates only between systems does not solve precision loss during a long journey within one system. Precision depends on distance from the origin; see [Godot's large-world guidance](https://docs.godotengine.org/en/4.4/tutorials/physics/large_world_coordinates.html). This zone design deliberately limits that distance. If unrestricted intra-system cruising becomes a requirement, revisit floating origin or double precision as a separate architectural decision.

### Flight owns physics; persistent state survives scene replacement

Use a `RigidBody3D` ship puppet with gravity disabled, a collision shape, local thrust on three axes, and torque on three axes. Define forward as local `-Z`. The supplied snippet only covers two translation axes, and its forward action produces positive local Z; it needs an explicit sign convention, vertical thrust, and rotation controls.

Apply continuous forces once per physics tick without multiplying the force by delta. Use `_integrate_forces()` for controlled direct physics-state changes. See the [Godot 4.4 rigid-body reference](https://docs.godotengine.org/en/4.4/classes/class_rigidbody3d.html). Start with tunable linear/angular flight assistance and a braking command. Measure acceleration and stopping distance before choosing combat ranges.

Keep the wallet, cargo, equipment, missions, and owned ships outside the disposable zone scene. Store immutable definitions as Resources; mutable hull, shields, stock, and cargo belong to instance state. Do not mutate shared `.tres` assets as a save mechanism.

### Proposed game-owned modules

These names describe new work, not existing APIs:

| Module | Contract |
| --- | --- |
| `ShipDefinition` | Stable ID, scene, mass, thrust/torque limits, hull/shields, cargo capacity, typed hardpoints. |
| `ShipState` | Owned ship ID, definition ID, hull/shields, installed module IDs, cargo quantities, local transform and velocities. |
| `ShipController` | Translates player or AI commands into physics; does not implement trading or saving. |
| `ShipCombat` | Weapon cadence, energy/cooldown, target validation, shield-first damage, hull destruction once. |
| `SystemDefinition` / `StationDefinition` | Stable IDs, connected destinations, zone scene and arrival markers, station services. |
| `TravelCoordinator` | Validate → lock input → prepare destination → commit state/scene → restore input; rollback on failure. |
| `CommodityDefinition` / `MarketState` | Immutable baseline/legality data separate from per-station quantities and prices. |
| `MarketService` | Validate quantity, funds, stock, cargo space and quote; commit wallet/cargo/stock together. |
| `MissionService` | Issue bounded delivery/bounty instances; track progress and pay rewards exactly once. |
| `SpaceSaveAdapter` | Versioned snapshot of game state through framework save hooks; restore only after zone readiness. |

Use integer credits and integer commodity quantities. Begin with deterministic station prices and finite stock; add volatility only after basic trading and persistence work. Store IDs and numeric arrays in saves, not live node references. Newly added entity components must honor the framework's dirty-state save contract and be tested across multiple save slots.

Station menus may pause the single-player simulation through the existing UI manager. Flight input must remain disabled until the menu stack closes. First docking is an assisted interaction within a distance/speed envelope. Surface landing remains a later zone transition, with one small authored landing site before considering terrain plugins.

## First playable target

A player can undock, destroy a drone, jump to another system, sell cargo, buy one upgrade, and save/reload without losing progress.

- Two handcrafted systems, each with one station zone.
- One flyable preset hull; a second purchasable hull after the loop is stable.
- One enemy drone archetype, one laser weapon, hull and regenerating shields.
- Three commodities, one delivery template, and one bounty template.
- A compact HUD, docking menu, market, outfitting page, mission board, and simple starmap.
- Placeholder meshes and effects until controls and the economic loop pass playtesting.

Excluded from this slice: voxel mining/building, moving ship interiors, seamless planetary flight, full orbital simulation, procedural galaxies, multiplayer, survival needs, and on-foot combat. These boundaries keep the requested space loop testable.

## Work order and acceptance gates

1. **Establish a runnable baseline.** Resolve plugin layout, select and record the Godot version, install a compatible GUT dependency into the test host, and run the existing tests. Record failures before making repairs. Add focused regression tests for the loader, hitscan, and save restoration findings. Gate: clean import/startup and documented test results.
2. **Build the flight sandbox.** One greybox ship and obstacle field, six-axis input, mouse aim, braking, pause/input routing, speed readout and reset. Gate: understandable controls, repeatable acceleration/stopping behavior, and no player culling throughout the zone.
3. **Add combat and persistence early.** One pursuing drone with approach/attack/evade states, shield/hull feedback and destruction. Gate: no self-hits or duplicate kill rewards; restore a damaged, rotated ship and its loadout correctly.
4. **Add two-zone travel.** Loading presentation and named arrival markers. Gate: repeated travel does not accumulate orphan worlds; invalid destinations and failed loads recover; duplicate jump input cannot start a second transition; load a save from the other system successfully.
5. **Close the economy loop.** Assisted docking, quantities/capacity, deterministic prices, delivery/bounty payouts and one upgrade. Gate: reject negative/oversized trades; insufficient funds/stock/capacity leave all balances unchanged; cancelled trades and repeated mission claims cannot duplicate value.
6. **Playtest and budget content.** Run the complete loop, select a target machine and frame-time budget, profile the encounter and station screens, then estimate additional hulls, systems, sound, effects and optional landing sites from measured work.

The first implementation task is baseline repair plus the flight sandbox. Do not wait for a finished starmap or planetary surface to test the game's feel.

## Verification performed and limits

- Working tree was clean before this documentation change.
- Read project configuration, example bootstrap, world loading, entity/puppet lifecycle, player component, inventory/barter, combat ray resolution, UI routing, save implementation, and test setup documentation.
- Verified the broken plugin-link representation using both filesystem metadata and Git's tracked file mode.
- Searched for space-flight implementation and relevant integration tests; no ship controller or dedicated loader/hitscan regression suite was found in the inspected scripts/tests.
- No `godot*` executable was found on PATH. `example/addons/gut` is absent. Runtime, editor import, performance, and GUT results remain unverified; no tests are claimed to pass.
- Official Godot 4.4 references were checked for physics query defaults, rigid-body control, and coordinate precision. This audit does not establish which engine version is installed outside PATH.

This document prepares implementation; its proposed modules and milestone gates have not been implemented or completed.
