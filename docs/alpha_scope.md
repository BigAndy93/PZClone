# Alpha Scope Baseline

This document locks the **first playable Alpha** feature boundary so implementation stays focused on the core loop.

## In-Scope vs Out-of-Scope

| Pillar | In Scope (Alpha) | Out of Scope (Post-Alpha) |
|---|---|---|
| Core Loop | Spawn → scavenge → manage needs → avoid/fight zombies → secure shelter → survive | Late-game settlement macro loops |
| World Runtime | Deterministic seeded world generation, isometric map, chunk lifecycle (load/activate/simulate/unload), streaming debug telemetry | Planet-scale map sharding, distant simulation heuristics for dozens of regions |
| Buildings | Edge-owned walls, runtime doors/windows, room detection metadata, cutaway/roof integration hooks | Full structural destruction, advanced vertical multi-floor simulation |
| Survival | Player needs decay + restoration interactions + HUD warnings | Deep medical simulation and trait/perk trees |
| Inventory/Loot | Grid inventory, loot containers, deterministic validation pipeline | Crafting graph optimizer, economy balancing layers |
| Zombies | State-machine baseline, vision/hearing integration, noise pressure | Horde migration simulation at regional scale |
| Networking | Host-authoritative compatible architecture in single-player-first implementation | Co-op matchmaking, anti-cheat transport hardening |
| Persistence | Save/load for core world + entities + inventory | Cloud sync, rollback netcode persistence |
| Factions/NPCs | Minimal runtime-compatible stubs where needed | Advanced diplomacy, settlement policy AI, faction wars |

## Alpha Vertical Slice Matrix

| Slice | Scenario | Pass Condition |
|---|---|---|
| S1 Traversal + Streaming | Player crosses multiple chunk boundaries continuously | No duplicate entities, chunk telemetry transitions are valid |
| S2 Building Entry | Player enters/exits building through doors/windows | Room/cutaway state updates correctly; collision state is coherent |
| S3 Scavenge Loop | Player loots interior containers under zombie pressure | Inventory remains valid, no container corruption |
| S4 Survival Pressure | Player remains alive through a daytime cycle by scavenging + resting | Needs penalties/restoration are observable and tunable |
| S5 Shelter Loop | Player secures an initial safehouse | Claimed shelter affects survivability perception and persistence |
| S6 Save/Load Roundtrip | Save in active play, reload, continue | World/entity/player state restores without critical divergence |

## Definition of Playable (Alpha)

A build is considered playable when all of the following are true:

1. A player can spawn, move, loot, and survive in-session without fatal blockers.
2. Streaming + building traversal remain stable for extended play sessions.
3. Zombie pressure creates meaningful movement/stealth tradeoffs.
4. Save/load preserves enough world and player state to continue progress.
5. Known issues are documented and none violate core loop continuity.
