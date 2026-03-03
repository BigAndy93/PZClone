# PZClone — Zombie AI Deep Spec v2

## AI Philosophy
Zombies are simple individually but dangerous collectively.
Emergent swarm behavior > complex individual intelligence.

## State Machine

Idle → Roam → Investigate Noise → Chase → Attack → Search → Disengage

### Perception
- Vision cone (angle + distance)
- Hearing radius (noise-based)
- Memory timer (last known position)

### Aggro Rules
- Highest intensity noise wins
- Line-of-sight boosts priority
- Losing target triggers Search state

### Horde Logic (v2)
- Noise clustering pulls nearby zombies
- Migration pulses move idle groups
- Optional late-game aggression scaling

Host authoritative simulation only.
