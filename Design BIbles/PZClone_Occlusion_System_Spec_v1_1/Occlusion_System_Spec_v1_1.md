# PZClone — Visual Occlusion & Visibility Culling Spec v1.1
(Project Zomboid–Inspired with Persistent Item Memory & Fading Zombies)

---
## Core Update Summary (v1.1)

1. Consumables and pick-ups that the player has already seen remain visible
   even after the player turns away (memory persistence).
2. Zombies that leave the player's sight cone slowly fade out instead of
   instantly disappearing.
3. If a zombie is making noise and the player is within hearing range,
   the zombie becomes visible again (rendered).

---
# 1. Visibility Categories

Each entity is evaluated per-player with the following states:

### A. VISIBLE
- In current line-of-sight (LOS).
- Fully rendered.

### B. MEMORY_VISIBLE (Items Only)
- Previously seen.
- Currently outside LOS.
- Still rendered normally (no fade).
- Cleared only if:
  - Item is picked up
  - Item despawns
  - Item moves outside loaded chunk

### C. FADING (Zombies Only)
- Previously visible.
- Currently outside LOS.
- Slowly fades opacity over time.
- If fade timer expires → becomes HIDDEN.

### D. HEARD_VISIBLE (Zombies Only)
- Outside LOS.
- Within valid hearing range of noise event.
- Immediately rendered at full opacity.
- Overrides fading state.

### E. HIDDEN
- Not visible and not heard.
- Not rendered.

---
# 2. Item Memory System (Consumables & Pickups)

## Rule
If a player has seen a consumable or pickup at least once,
it remains rendered even when outside LOS.

## Rationale
- Prevents frustrating "loot popping"
- Reinforces player spatial memory
- Reduces UI confusion

## Data Requirement

Each item must track:
- seen_by_players[] (bool per player)

When an item enters VISIBLE:
- Mark seen_by_players[player_id] = true

Rendering Rule:
If seen_by_players[player_id] == true → render item regardless of LOS
(unless outside loaded chunk).

---
# 3. Zombie Fade System

## Fade Behavior

When zombie leaves LOS:

State transitions:
VISIBLE → FADING → HIDDEN

Fade Duration:
0.5–2.0 seconds (tunable)

Opacity Curve:
Linear or smoothstep fade to 0.

## Design Goals

- Prevent sudden pop-out.
- Maintain tension.
- Communicate loss of visual certainty.

---
# 4. Hearing Override (Zombies)

If zombie generates or is associated with a noise event:

Conditions:
- Player within effective hearing radius
- Attenuation through walls allowed but reduced

Then:
Zombie state becomes HEARD_VISIBLE
Rendered at full opacity.

When noise decay ends:
Zombie returns to FADING if still not in LOS.

---
# 5. Noise System Integration

Noise events include:
- Footsteps
- Groans
- Smashing doors/windows
- Gunshots
- Chainsaw use

Each noise event has:
- position
- radius
- intensity
- decay time

Hearing calculation occurs at noise trigger time and periodic update ticks.

---
# 6. Multiplayer Rendering Rules

Host:
- Simulates zombie AI and noise events.

Client:
- Computes visibility state locally.
- Applies fade and memory rules.
- Does not affect authoritative world state.

Each client may see different zombie fade states based on their LOS.

---
# 7. Performance Considerations

Visibility sets recalculated at fixed interval (5–10 Hz).
Fade handled client-side without re-running LOS.

Items:
Memory persistence does not increase simulation cost —
only rendering decision flag.

---
# 8. Edge Cases

If zombie re-enters LOS during fade:
- Immediately restore to VISIBLE (opacity 1.0)

If zombie is both heard and fading:
- HEARD_VISIBLE overrides fade.

If item moves while outside LOS:
- Update world position but remain MEMORY_VISIBLE.

---
# 9. Debug Requirements

Add overlays for:
- Visible entities
- Fading zombies
- Memory-visible items
- Heard-visible zombies
- LOS grid

---
# Design Intent

Players remember where loot is.
Zombies feel threatening and uncertain.
Nothing pops unrealistically.

---
# End of Spec v1.1
