# PZClone — Technical Bible v3.1 (Grid Inventory Spec)

## Inventory Data Model

Each inventory container contains:

- container_id
- grid_width
- grid_height
- slot_matrix (2D array)
- weight_limit
- owner_id

Each item contains:

- item_guid
- width
- height
- shape_mask (2D boolean array)
- weight
- rotation_state

## Placement Rules

To place item:

1. Check bounds
2. Check collision with slot_matrix
3. Apply shape_mask
4. Update matrix
5. Recalculate weight

Host-authoritative placement validation required in multiplayer.

## Networking

All item move requests must include:

- container_id
- item_guid
- target_x
- target_y
- rotation_state

Host validates and broadcasts updated grid state.
