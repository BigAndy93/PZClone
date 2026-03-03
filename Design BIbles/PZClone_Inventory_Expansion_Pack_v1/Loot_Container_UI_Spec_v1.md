# PZClone — Loot Container UI Spec v1

## Layout Structure

Left Panel: Player Inventory Grid  
Right Panel: Container Inventory Grid  
Center/Top: Container Name + Weight + Capacity  
Bottom: Action Bar (Rotate, Transfer, Drop, Equip)

## Interaction Rules

- Drag and drop between grids
- Right-click for context menu
- Shift-click for quick transfer
- R key rotates item
- Highlight invalid placement (red overlay)

## Visual Feedback

- Green highlight: valid placement
- Red highlight: collision/out of bounds
- Yellow highlight: overweight warning
- Flash grid briefly on successful placement

## Multiplayer Consideration

- Grid state updates from host
- Show lock icon if container in use by another player
