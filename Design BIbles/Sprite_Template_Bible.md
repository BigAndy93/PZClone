SPRITE SHEET LAYOUT TEMPLATE
Soft-Grainy Analog Horror – Isometric 8 Direction
1. GLOBAL SPRITE RULES

Tile Size: 64x64
Character Height: 120px target
Canvas per frame: 128x128
Padding per frame: 8px safe margin

All sprites centered consistently on:

Foot pivot point (ground anchor)

Same Y alignment across frames

2. DIRECTION ORDER (LOCK THIS)

Always use this order:

Row 1: N
Row 2: NE
Row 3: E
Row 4: SE
Row 5: S
Row 6: SW
Row 7: W
Row 8: NW

Never change this order.
Your animation system will depend on it.

3. BASIC WALK CYCLE SHEET
Sheet Dimensions

Directions: 8
Frames per direction: 4

Grid layout:

Columns: 4 (frames)
Rows: 8 (directions)

Total canvas:

Width: 4 × 128 = 512px
Height: 8 × 128 = 1024px

Final sheet size:
512x1024

4. FRAME TIMING

Walk cycle:
Frame 1 – Contact
Frame 2 – Passing
Frame 3 – Opposite Contact
Frame 4 – Passing

Playback speed:
6–8 frames per second

Keep motion subtle.
No exaggerated limb swing.

5. IDLE SHEET

Frames per direction: 2
Subtle breathing animation.

Sheet layout:

Columns: 2
Rows: 8

Canvas:
256x1024

6. LAYERED CHARACTER SYSTEM

Each layer must follow identical sheet structure.

Required layers:

base_body.png
shirt_overlay.png
pants_overlay.png
bag_overlay.png
damage_overlay.png
shadow_overlay.png

Each sheet:
Same dimensions
Same pivot alignment
Same frame ordering

No exceptions.

7. PIVOT & ALIGNMENT RULES

The ground contact pixel must:

Be identical position in every frame

Match across every layer

Match across every direction

Recommended anchor:
Center bottom third of canvas.

If pivot drifts:
Animation will wobble.

8. ZOMBIE VARIANT SHEET

Same structure.

Differences:

Slight forward hunch

Lower arm resting position

Slightly slower walk cycle (5–6 fps)

Optional:
1 extra frame for stagger effect.

9. FURNITURE SHEETS

Furniture does NOT animate (initially).

Single-frame per orientation.

Recommended:

64x64 for small objects
128x128 for large objects

Directional rule:
Only render additional angles if gameplay requires rotation.

Otherwise:
Use baked lighting.

10. EXPORT SETTINGS

PNG

Transparent background

No baked grain

No baked vignette

No compression artifacts

Grain is applied at runtime.

11. OPTIONAL FUTURE EXPANSION

Sneak animation:
Same sheet structure as walk.

Attack animation:
6-frame sheet.
Same 8-direction layout.

Death animation:
Can break structure (separate sheet allowed).

PRODUCTION RECOMMENDATION FOR YOU

Since you're using:

Local models

ComfyUI

Procedural system

Best setup:

Generate single clean base pose.

Use ControlNet openpose for consistent directional turns.

Generate each direction separately.

Assemble into sheet via script.

Run through palette normalization tool.

I can even generate you a:

Python script that auto-assembles directional PNGs into sheets.

Now — next decision:

Do you want me to:

A) Generate a visual diagram of the sprite sheet layout
B) Generate a starter base-body sprite sheet example
C) Write a sheet-assembly Python script
D) Design your AI prompt pack for consistent sprite generation

Pick one and we build your art pipeline properly.