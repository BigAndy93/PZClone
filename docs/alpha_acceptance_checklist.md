# Alpha Gameplay Acceptance Checklist

Use this checklist for internal QA sign-off against Step 1 implementation constraints.

## Core Loop
- [ ] Player spawn is deterministic and places character into a playable zone.
- [ ] Player can move, sprint, and interact with world objects.
- [ ] Player can loot at least one container and transfer items to inventory.
- [ ] Needs decay applies pressure during normal exploration.
- [ ] Player can evade or engage zombies and recover into gameplay.

## Streaming / World Runtime
- [ ] Chunk IDs remain deterministic between runs with same seed.
- [ ] Chunk transitions emit expected lifecycle sequence (load → activate → deactivate → unload).
- [ ] Crossing chunk boundaries does not duplicate entities or reset nearby state.
- [ ] Debug overlay can show active/loaded chunk counts and transitions.

## Buildings / Interiors
- [ ] Buildings use edge-owned wall topology only.
- [ ] Doors/windows occupy canonical edges and register ownership consistently.
- [ ] Room detection rejects open/gapped spaces as enclosed rooms.
- [ ] Room metadata includes bounds, ID, door/window adjacency, and floor index.
- [ ] Entering/leaving interiors triggers expected roof/occlusion hooks.

## Technical Contracts
- [ ] Runtime module responsibilities match `docs/alpha_interface_contracts.md`.
- [ ] No unresolved ownership conflicts between world/building/visibility/save managers.
- [ ] Core APIs used by downstream systems are documented and stable.
