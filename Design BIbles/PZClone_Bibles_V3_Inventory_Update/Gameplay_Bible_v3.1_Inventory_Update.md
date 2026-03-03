# PZClone — Gameplay Bible v3.1 (Inventory Update)

## Grid-Based Inventory System

The inventory system is grid-based.

### Core Rules

- Each inventory has a 2D grid.
- Items occupy multiple grid squares.
- Items have unique shapes (not only rectangles).
- Rotation is allowed (90° increments).
- Placement must respect collision within grid.

### Item Size Categories

Small:
- Bandages
- Ammunition boxes
- Tools

Medium:
- Pistols
- Food containers
- Medical kits

Large:
- Rifles
- Toolboxes
- Crowbars

### Unique Shape Containers

Certain container items have custom shapes:
- Guitar case → asymmetrical layout
- Backpack → rectangular with partition bonus
- Duffel bag → wide rectangular
- Toolbox → compact square layout

These container shapes affect:
- What items can fit
- Packing efficiency
- Strategic loadout decisions

Encumbrance is calculated based on weight,
but spatial constraints are equally important.
