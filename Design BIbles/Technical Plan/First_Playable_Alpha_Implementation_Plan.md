# PZClone First Playable Alpha – 10-Step Implementation Plan

This plan synthesizes the design and technical documentation in `Design BIbles/` into a practical path to a **first playable Alpha**.

Alpha target: a stable single-player slice where the player can spawn, move through a streamed/isometric world, scavenge and manage needs, survive zombie pressure, secure a basic safehouse, and save/load progress.

---

## Step 1 — Lock Alpha Scope, Contracts, and “Definition of Playable”

### Objective
Create a strict Alpha scope baseline to prevent system creep while preserving the core game loop.

### Tasks
- Translate the core loop (spawn → scavenge → needs → avoid/fight → shelter → improve base → survive) into explicit in-engine acceptance checks.
- Freeze Alpha feature flags: include core survival/inventory/zombie/building loop; defer advanced faction diplomacy, co-op scaling, and high-tier settlement systems.
- Define module boundaries and ownership (`ChunkManager`, `BuildingManager`, `VisibilityManager`, `SaveManager`) as implementation constraints for all subsequent work.
- Produce an Alpha “vertical slice matrix” mapping each pillar to at least one testable gameplay scenario.

### Deliverables
- `docs/alpha_scope.md` with in-scope/out-of-scope table.
- Gameplay acceptance checklist for internal QA.
- Interface contracts for world/building/visibility/save modules.

### Exit Criteria
- Team alignment on a single Alpha scope.
- No unresolved ownership conflicts across core runtime managers.

---

## Step 2 — World Foundation: Grid, Chunks, and Streaming Runtime

### Objective
Ship the runtime substrate all other systems depend on.

### Tasks
- Finalize canonical world coordinate conversion (tile grid ↔ isometric render space).
- Implement chunk lifecycle (load, activate, simulate, unload) with deterministic IDs and boundaries.
- Partition simulation responsibility so expensive systems run only in active chunks.
- Add debug overlays for chunk boundaries, active state, and streaming transitions.

### Deliverables
- Production-ready chunk streaming in world scene.
- Chunk state telemetry and debug UI toggles.

### Exit Criteria
- Player can traverse large map continuously with stable frame pacing.
- Chunk activation/deactivation preserves entity state without duplication.

---

## Step 3 — Building Core: Tile-Edge Walls, Doors/Windows, and Room Detection

### Objective
Implement structural world logic that supports interiors, navigation, and occlusion.

### Tasks
- Build edge-based wall placement (no tile-center wall model).
- Implement door/window edge ownership and open/closed collision behavior.
- Implement closed-space room detection (flood-fill/graph approach) with robust “gap means not a room” logic.
- Store room metadata (bounds, ID, connected doors, floor index) for downstream systems.

### Deliverables
- Edge wall/door/window runtime with debug visualizers.
- Room detection service with event hooks for roof/occlusion/furniture systems.

### Exit Criteria
- Interior spaces are discovered consistently.
- Doors correctly alter path/visibility blocking states.

---

## Step 4 — Roofs, Occlusion, and Vision/LOS Integration

### Objective
Make interiors readable and tactically meaningful.

### Tasks
- Auto-generate roof data from validated room topology.
- Add camera-to-player occlusion fading rules for walls/objects.
- Integrate directional vision cone + ray occlusion checks (walls and closed doors block sight).
- Add memory behavior for recently seen entities and hearing-based zombie visibility override.

### Deliverables
- Occlusion/visibility manager connected to building and entity systems.
- Tunable vision parameters (range, cone angle, ray count, fade timings).

### Exit Criteria
- Entering buildings produces clear, non-jarring cutaway behavior.
- Visibility outcomes are consistent with wall/door state.

---

## Step 5 — Itemization + Grid Inventory (Host-Authoritative Ready)

### Objective
Deliver tactile scavenging logistics central to survival pacing.

### Tasks
- Finalize item and container data models (shape masks, rotation state, weight limits, IDs).
- Implement inventory placement validator (bounds, collision, mask application, recalculation).
- Connect world loot containers and player inventory transfer UX.
- Keep validation architecture host-authoritative compatible, even for single-player Alpha.

### Deliverables
- Fully playable grid inventory with rotation and shape-aware placement.
- Deterministic inventory transaction pipeline and rollback-safe validation.

### Exit Criteria
- Looting loop works end-to-end from world to inventory to container.
- Invalid placement never corrupts container state.

---

## Step 6 — Survival Needs Loop (Player First, NPC-Compatible Data)

### Objective
Create constant survival pressure and force logistical decision-making.

### Tasks
- Implement needs schema (`hunger`, `thirst`, `fatigue`, `health`, `stress`, `morale`, `pain`) on a 0–100 scale.
- Add decay scheduler and threshold effects (movement/stamina/combat penalties, health loss at critical values).
- Integrate consumable/rest interactions (eat, drink, rest/sleep, treatment).
- Expose HUD bars and warning states tied to gameplay thresholds.

### Deliverables
- Tick-driven needs system with configurable rates.
- Player interaction hooks for all primary restoration actions.

### Exit Criteria
- A complete in-session loop exists where scavenging and resting directly determine survivability.
- Threshold penalties are noticeable but tunable.

---

## Step 7 — Zombie Simulation: State Machine, Noise, and Combat Pressure

### Objective
Add the primary antagonistic force that drives movement, stealth, and resource tradeoffs.

### Tasks
- Implement zombie state machine (idle/wander/investigate/chase/attack/search/lost-target).
- Add noise event propagation with local agitation/group pull behavior.
- Integrate vision/hearing sensing with occlusion-aware world data.
- Implement minimal combat resolution (hit, stagger/damage, player injury/death handling).

### Deliverables
- Stable zombie AI runtime with configurable behavior tuning.
- Noise debug tools (event source, radius, attracted entities).

### Exit Criteria
- Stealth/noise choices materially affect zombie encounters.
- Zombie pressure creates emergent “scavenge fast, retreat safe” behavior.

---

## Step 8 — Interior Believability Pass: Furniture Footprints, Anchors, and Thematic Dressing

### Objective
Make generated spaces functional, navigable, and visually coherent for Alpha immersion.

### Tasks
- Implement furniture metadata-driven placement (footprint, anchor, rotation, clearance, zone preference).
- Enforce hard/soft footprint rules and doorway/path clearance.
- Apply wall-bound/center/modular furniture class logic and placement scoring.
- Normalize asset naming/metadata ingestion to support theme-consistent building dressing.

### Deliverables
- Multi-tile furniture placement pipeline integrated with room data.
- Asset validation checks for anchor mismatch, footprint mismatch, and boundary violations.

### Exit Criteria
- Furniture no longer clips through walls or blocks critical traversal paths.
- Interiors read as coherent room types (residential/commercial/etc.).

---

## Step 9 — Safehouse + Basic Craft/Build Loop

### Objective
Close the early meta-loop beyond pure scavenging.

### Tasks
- Implement safehouse claim conditions and ownership marker.
- Support core fortification interactions (barricade, door/window reinforcement, basic storage placement).
- Add minimal crafting/resource conversion chain needed for shelter improvement.
- Connect day/night and weather pressure to shelter value perception.

### Deliverables
- Working “secure and improve shelter” feature set.
- Basic persistence of safehouse state and built objects.

### Exit Criteria
- Player can establish defensible shelter and feel progression from first spawn.
- Shelter upgrades measurably affect survival outcomes.

---

## Step 10 — Save/Load, Stability, and Alpha Gate Validation

### Objective
Deliver a trustworthy playable build with repeatable progression.

### Tasks
- Implement chunk-based serialization for tiles/buildings/furniture/zombies/items/NPC placeholders.
- Add world-state restoration ordering (chunks first, then entities, then runtime links/events).
- Create automated smoke tests for spawn, traversal, loot, needs decay, zombie chase, safehouse claim, and save/load roundtrip.
- Profile and optimize hot paths (AI updates, visibility rays, chunk transitions, inventory checks).

### Deliverables
- Alpha candidate build checklist and pass/fail dashboard.
- Regression suite for core loop breakpoints.

### Exit Criteria
- Save/load roundtrip preserves playable state without corruption.
- Core loop is stable for extended sessions and ready for external Alpha testing.

---

## Cross-Step Governance (applies to all 10 steps)

- Keep systems modular and data-driven; avoid mixing room logic with rendering logic.
- Protect frame time by limiting expensive updates to active chunks and event-driven recomputation.
- Preserve multiplayer expansion compatibility (authority-friendly data flows, deterministic validation paths).
- Require debug visualizations for each foundational system before declaring it “done.”
