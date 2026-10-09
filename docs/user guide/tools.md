# Tools

Skelerealms offers a few tools to help with your development.

## Components

Components will tell you if any other components they depend on are absent, using the ditor warnings feature.

## Node Bundles

If you want to compose a set of AI Modules, Loot table items, etc. the `NodeBundle` class aims to help with that. All it does is take all of its children and reparent them to be siblings of itself, and then removes itself afterwards. Since some systems rely on a tree's structure to determine functionality, this is handy for having a scene you can drag in while making an entity, helping for composability. Simply make a scene with a NodeBundle as a root and all your items below it, and it will flatten out during runtime.

## SKWorldEntity

The premiere way to spawn unique entities into the world is by using an SKWorldEntity. Put your entity in, and do with it as you wish.  

There is a work-in-progress tool you can use to create entities based on an archetype (see [entities](entities.md)). You can add paths to each archetype you want to use in the project settings, and then create new ones using the menu in the inspector. It's not perfect, but it will get better support once instancing scenes directly within code gets supported (an active PR).  

You can sync the position of any unique entity by hitting the button in the inspector. This will edit the attached entity to make its position the **global** position of the World Entity node, and set its world to the current edited world (Internally, this is determined to be the name of the root node of the currently edited scene).

## Doors

The easiest way to allow the player to move between scenes is the Door. Add a door into the scene. Whenever any entity with a `TeleportComponent` interacts with the door, they will be teleported to the door's other side. To set up a door, do as follows: 

1. Create a Door node, and position it. You can also add any colliders or whatever you use to determine when to interact with something, as well as your mesh instance.
2. Create a resource in the `instance` field, and save it to disk somewhere. press the "Sync position" button to sync the door resource.
3. Create a new door in a different (or the same) scene, and repeat the process. Grab the resource of the door you already have, (or, if you already have a door resource you'd like to link to, grab that instead), and drag it into the `destination_instance` field. You must do this on both sides (a bit tedious, but it allows for more flexible/non-euclidean door layouts).
4. You now have a door.

At any time, once you have a `destination_instance`, you can press the "Jump to destination" button to navigate the editor's camera to the other side of the door, opening the destination scene in the editor if necessary (providing that the destination world is in the proper folder).

## Quest Graph Editor

Select a `QuestDefinition` resource to open its graph: drag between nodes to link `next_node_ids`, select nodes (Delete key) to remove them — references from other nodes are scrubbed automatically. New nodes get the first unused `node_N` id. Node positions persist in the resource (`editor_position`); resources without stored layout open in grid auto-layout. Validate checks reachability, dead ends, cycles, and links to unknown nodes; press Save Resource to write the `.tres`.

## Dialogue Tree Editor

Select a `DialogueDefinition` resource to open its tree: each choice row has its own output port, so drag from a choice to its target node to set `next_node_id`. Deleting a node clears the choices that pointed at it; deleting a choice re-indexes the remaining ports. Properties (speaker, text, terminal flag, choices, conditions/effects counts) edit in the right-hand panel. Node layout persists like the quest editor. Validate reports duplicate ids, missing start nodes, dangling choices, and dead ends.

## Coven Relationship Matrix

Select any `Coven` resource to open the full opinion grid (rows/columns sorted by coven id). Edit scores inline — cells recolour by disposition — then Save All Covens to write every `.tres`.

## Save Inspector

The bottom-panel Save Inspector opens `user://saves/*.dat` files, verifies the checksum (honouring the `savegame_indents` project setting), and browses the full JSON tree with schema version and entity counts in the status bar.

## Schedule Editor

Select a `Schedule` resource to open the timeline: Add Event creates a box for any `ScheduleEvent` subclass, drag the edges to resize (snaps to the hour, then the minute), drag boxes between overlap tracks — extra tracks open automatically when more events overlap than fit. Delete boxes with Remove. Layout and tracking state reset cleanly each time a schedule is opened.
