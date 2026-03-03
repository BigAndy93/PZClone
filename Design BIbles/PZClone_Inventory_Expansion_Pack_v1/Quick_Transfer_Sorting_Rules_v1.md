# PZClone — Quick Transfer & Sorting Ruleset v1

## Quick Transfer

Shift-click:
- Moves item to opposite inventory
- Attempts first-fit placement
- If no space, denies transfer

Ctrl-click:
- Moves stackable items only

## Auto-Sort (Optional Button)

Sorting Priority:
1. Ammo
2. Medical
3. Food
4. Tools
5. Weapons
6. Misc

Sorting respects:
- Shape compatibility
- Rotation optimization
- Container identity

## Stacking Rules

- Only identical items stack
- Stack size capped by item definition
- Stacks still consume grid space based on footprint

## Multiplayer

Sorting is client-predicted but host-validated.
