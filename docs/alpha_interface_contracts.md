# Alpha Interface Contracts

This document defines ownership boundaries for core runtime managers during Alpha.

## ChunkManager (`scripts/world/ChunkManager.gd`)

**Owns**
- Chunk coordinate conversion and deterministic IDs.
- Chunk lifecycle state transitions (load/activate/deactivate/unload).
- Streaming telemetry snapshot for debug UI.

**Does not own**
- Entity AI logic, inventory, or building internals.
- Save serialization format decisions.

**Inputs**
- Player/world tile position updates.
- Radius policy (active/loaded radii).

**Outputs**
- Lifecycle signals: loaded, activated, deactivated, unloaded.
- Debug state snapshot for overlays.

## BuildingManager (`scenes/world/World.gd` + `scripts/world/RoomDetectionService.gd`)

**Owns**
- Building blueprint runtime instantiation (walls/doors/windows/roofs).
- Room detection and structural metadata generation.
- Building-level hooks for occlusion and downstream systems.

**Does not own**
- Rendering style for all game entities.
- Save file orchestration.

**Inputs**
- Generated `MapData` wall/door/window edge maps.
- Building bounds/floor cell sets.

**Outputs**
- Room metadata: IDs, bounds, floor index, connected openings.
- Signals for room rebuild completion.

## VisibilityManager (current owner: `BuildingTileRenderer` + `World` cutaway logic)

**Owns**
- Interior/exterior cutaway state.
- Room exploration alpha state and entity occlusion decisions.

**Does not own**
- Structural room detection.
- Chunk lifecycle policy.

**Inputs**
- Player tile + current building/room.
- Room metadata and door/window connectivity.

**Outputs**
- Per-sprite alpha and entity visibility toggles.

## SaveManager (future implementation boundary)

**Owns**
- Persistence orchestration order: chunks → entities → runtime links.
- Versioned save payload boundaries.

**Does not own**
- Runtime simulation updates.
- Rendering or UI concerns.

**Inputs**
- Snapshot providers from Chunk/Building/Visibility/Entity systems.

**Outputs**
- Serialized world and player state suitable for deterministic reload.
