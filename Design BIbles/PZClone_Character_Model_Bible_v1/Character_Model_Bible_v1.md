# PZClone — Character Model & Sprite System Bible v1

## Core Philosophy

All characters (Players, NPCs, Zombies) share a unified base body system.

Design goals:
- Modular layering
- Consistent animation alignment
- Directional readability (isometric)
- Performance stability
- Easy clothing & gear expansion

---

# 1. Base Model Structure

Each character consists of:

1. Base Body (underwear only)
2. Clothing layers
3. Gear layers (bags, weapons, tools)
4. State overlays (blood, dirt, wounds)

The base body sprite must exist independently of all equipment.

---

# 2. Directional Sprite Requirements

All character types require 8 directional sprites:

- N
- NE
- E
- SE
- S
- SW
- W
- NW

Each direction must have consistent:
- Foot placement
- Shoulder alignment
- Head orientation

Directional consistency is critical for layering clothes and gear.

---

# 3. Animation States

## Universal States (All Characters)

- Idle
- Walk
- Run
- Attack
- Hit/Stagger
- Death

## Player & NPC Exclusive States

- Sneak (crouched walk)
- Sneak Idle
- Rest (sitting or kneeling)
- Interaction (looting, crafting)
- Aim (optional future)

## Zombie Exclusive Variants

- Slow Walk
- Aggressive Lunge
- Idle Sway
- Collapse Death

---

# 4. Sneaking Animation Requirements

Sneaking must:

- Lower body center of gravity
- Reduce stride length
- Reduce arm swing
- Maintain 8-direction support

Sneak silhouette should clearly differ from normal walk.

---

# 5. Resting Pose Requirements

Resting may include:

- Sitting on floor
- Leaning against wall
- Kneeling

Rest state is static or low-frame animation.
Used for stamina recovery and immersion.

---

# 6. Clothing Layer System

Clothing layers stack in this order:

1. Base body
2. Underwear (optional cosmetic)
3. Pants
4. Shirt
5. Jacket/Outerwear
6. Armor (future)
7. Backpack / Bags
8. Held items (weapons/tools)

Each clothing item must:

- Match 8-direction sprite set
- Match animation frame count
- Align to base body anchor points

---

# 7. Anchor & Alignment System

Each sprite direction must define anchor points:

- Head
- Torso
- Left hand
- Right hand
- Back mount (for backpack)
- Waist

These anchors ensure:

- Clothing aligns correctly
- Weapons appear correctly in hands
- Backpacks sit naturally

---

# 8. Zombie Clothing System

Zombies use same base model system,
but clothing may:

- Appear torn
- Be partially missing
- Show blood overlays

Zombie clothing variations increase world realism.

---

# 9. Sprite Sheet Organization

Each character state stored as:

character_type/state/direction/frame.png

Example:

player/walk/N/frame_01.png

Maintain consistent naming convention.

---

# 10. Performance Guidelines

- Use atlas packing per state
- Avoid oversized textures
- Maintain consistent pixel density
- Reuse animation frames when possible

---

# 11. Visual Consistency Rules

Characters must:

- Be readable at gameplay zoom
- Have clear silhouette differences (walk vs sneak)
- Avoid excessive animation noise
- Maintain grounded realism

---

# 12. Future Expansion Hooks

System must support:

- Body type variations
- Gender variations
- Injury overlays
- Dynamic blood accumulation
- Clothing degradation states

---

# Design North Star

Characters should feel:

Readable.
Grounded.
Modular.
Expandable.

If adding new clothing requires modifying base sprites,
the system is incorrect.

---

# End of Character Model Bible v1
