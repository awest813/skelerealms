# Flight Lab

A standalone Godot **4.4.1** flight sandbox. Open `project.godot` in Godot and press **F6** on `main.tscn`, or **F5** to run the project. It has no plugin or art dependencies.

In this prepared workspace, you can also run `./tools/run_flight.ps1` from the repository root. It uses the locally downloaded engine, or accepts `-GodotPath` for another installation.

![Flight Lab](preview.png)

Fly the six gates in order. The HUD marks the next gate, shows its distance, and points toward it when it leaves view. Course timing starts when you move and stops after the last gate. Use the obstacles and reference grid to judge acceleration, drift, braking, and roll. The ship and its wings have physical collisions. A hostile drone patrols the course: it approaches, orbits and fires when aimed, and breaks off after heavy damage or to avoid ramming. Shields absorb damage first and regenerate after 3 s without hits; hull damage is permanent until repair. Kills respawn a fresh drone after 5 s. Two systems (Training Sector, Outer Reach) form a jump network: fly to the glowing jump ring and press J. Jumping unloads the zone and rebuilds the destination with coordinates reset to the origin; ship durability and kills persist, and each zone spawns a fresh drone. Each system has a station: approach slowly and press X to dock, opening Market, Outfitting, and Missions tabs. Three commodities trade at fixed per-station prices with finite stock (buy ore and medi-gel in the Reach, sell in Alpha); outfitting sells a shield booster and a cargo expansion; the mission board offers an ore delivery and a drone bounty, each paying once. The drone holds a standoff while docked. The pause menu offers ship save/load (system, hull, durability, economy, missions, pose, velocities) via `user://flight_ship_save.json`; loading a save from the other system jumps back there. Saves are versioned (v3 adds hulls; v1/v2 still load with defaults). Press M for the starmap: system intel with live market prices, jump links, and course plotting that marks the HUD. Press L at the amber beacon to land at Meridian Flats, a surface zone with free flight, a spaceport trading the same markets, and a return gate to orbit. Engine hum tracks throttle; lasers, explosions, jumps, docks, and purchases all sound. The shipyard sells a second hull, the Mule freighter (slower, tankier, +20 cargo), swappable dockside with all references rewired. Markets breathe: every jump drifts prices ±10% and restocks shelves toward opening levels. Dreamspike is contraband — banned in Alpha, where customs confiscates it on docking plus a 100 + 50/unit fine. Station Contacts (Rook, Sable, Doc Ilsa, Prospector Jeb) talk through a templated dialogue system quoting live prices and handing out missions. The mission board also prints seeded procedural contracts (scaled deliveries and bounties, capped at 4 active generated). Three factions (Meridian Authority, Reach Collective, Flats Union) track standing: +8/+12 on mission claims buys cheaper and sells dearer (±20% at ±100), while customs busts cost −15 and scale fines. Vex the fence sells single-use customs blind eyes (300 cr). Claiming the ore delivery pins a follow-up ambush bounty. Medi-gel spoils one unit per jump; cargo insurance (200 cr) saves the hold from exactly one wreck — otherwise destruction loses everything. Bethesda-style progression runs underneath: Piloting/Mercantile/Speechcraft XP with Novice–Master ranks (handling, sell prices, persuade odds), NPC disposition moving station prices, speech checks with success/fail branches, bribes, pardons, discounts, freebies, and admiring. Heat per faction draws hunters at 50+ (or −25 standing) and can be pardoned, paid off, or cooled by travel. Outfitting repairs hulls for credits (allies 25% off) with free shield top-ups on every dock. The station terminal carries four lore entries. Saves are v6 (skills, disposition, heat; older still load).

| Control | Action |
| --- | --- |
| W / S | Forward / reverse thrust |
| A / D | Strafe left / right |
| Space / Ctrl | Vertical thrust up / down |
| Mouse or arrow keys | Pitch / yaw |
| Q / E | Roll left / right |
| Left mouse | Fire laser |
| J | Jump (near the jump ring) |
| X | Dock / undock (slow, near a station) |
| M | Starmap |
| L | Land (near the amber beacon) |
| Shift | Brake; overrides held thrust |
| F | Toggle linear flight assistance; off preserves drift |
| R | Restart course; reset pose and both velocities |
| Escape | Pause / resume and release / capture mouse |

Angular stabilization stays active in both assistance modes, with inertia-compensated pitch/yaw/roll response. Mouse motion commands a turn rate that returns to center when the mouse stops. The HUD shows speed, assistance, estimated stopping distance, and distance from the origin. Switching away automatically pauses the game; use the pause menu or Escape to resume. That menu also supports restarting and exiting.

Crossing the 2 km zone boundary resets the ship and course. It is a compact test area, not an infinite flight model. Window resizing is supported down to 960×600.

`ship_controller.gd` exposes acceleration, turn rate, response, speed, and boundary settings. Its command interface also accepts AI or test input independently of the keyboard. The physics body is independent of the framework's character puppet lifecycle; a persistent ship/entity adapter is future work.

Run the real-physics checks from the repository root:

```powershell
godot --headless --path flight_sandbox -s res://test_flight.gd
```

The 355 checks cover flight physics, course timing, pause and focus handling, combat, travel, economy, missions, hull swaps, starmap and landing, audio and visual effects, customs and insurance, progression, NPC dialogue and disposition, faction heat, repairs, and save compatibility through v6. This is automated correctness validation; flight feel still needs playtesting.
