# PZClone — Technical Bible v1
Godot | Authoritative Host | Steam Co-op

## Network Model
- Authoritative Host
- Direct IP (dev)
- Steam Invites (release)
- 1–4 player cap

## Authority
Host owns:
- Zombie AI
- Loot generation
- Containers
- Time/weather
- Save/load

Clients may predict:
- Own movement only

## Replication
Players: 20Hz
Zombies: 8–12Hz
World: 1–2Hz

## Entity Rules
Every entity must have:
- entity_id
- replication_policy
- owner_type

No client may mutate authoritative state.
