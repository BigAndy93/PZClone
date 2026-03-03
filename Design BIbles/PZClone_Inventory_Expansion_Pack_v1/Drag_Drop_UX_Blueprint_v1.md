# PZClone — Drag-and-Drop UX Blueprint v1

## Core UX Principles

- Responsive placement preview
- Clear collision indicators
- No hidden rules
- Immediate feedback

## Drag Behavior

- Item follows cursor at grid cell resolution
- Ghosted preview shows shape_mask footprint
- Rotation preview updates live

## Cancel Rules

- Esc cancels drag
- Dropping outside UI returns item to origin

## Accessibility

- Controller-friendly grid navigation
- Auto-snap toggle option
- Optional auto-arrange assist (off by default)

## Error Handling

- If host rejects placement:
  - Item snaps back
  - Display short error message
