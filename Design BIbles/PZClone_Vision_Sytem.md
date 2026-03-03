GODOT VISION SYSTEM v1 (HYBRID C)
Cone-Directed Vision + Wall/Door Occlusion (Upgrade Path to B)
GOALS

Vision depends on facing direction (cone).

Vision is blocked by walls and CLOSED doors.

Vision reveals only what is actually visible (no “cone through walls”).

System supports interiors, tight corridors, and door gameplay.

Later upgrade to pure LoS polygon (B) with minimal refactor.

CORE IDEA

Render a visibility mask each frame:

Cone defines intent (where player is looking).

Rays define occlusion (where player can actually see).

Result is a clipped visibility polygon (or wedge polygon with occlusion edges).

Use it as a screen/world mask: visible inside, dark outside.

This starts as “cone + rays” (C) and naturally becomes full 360° rays (B).

DATA + COLLISION SETUP
Physics layers (must be consistent)

Layer: VISION_BLOCKER

Walls: ON

Closed doors: ON

Open doors: OFF

Large blocking furniture: optional ON (if you want furniture to block sight)

Movement blockers can be separate. Vision blockers are specifically what occludes sight.

Door toggle must change collision layer membership or enable/disable the occluder collider.

INPUTS

Player world position origin

Facing direction unit vector dir

Vision range R (pixels or world units)

Vision cone angle θ (e.g. 90°–120°)

Ray count N (start at 64; tune to 96/128 if needed)

Optional “hearing reveal” is separate (not part of this doc)

OUTPUTS

A polygon (list of points) describing visible area

A mask texture / polygon drawn to Viewport (SubViewport) used for shading/visibility

ALGORITHM (HYBRID C)
Step 1: Build cone rays

Compute cone start angle and end angle around dir.

Generate N ray angles evenly in that range.

For each ray:

Cast physics ray from origin to origin + ray_dir * R

If hit something on VISION_BLOCKER:

endpoint = hit position (slightly inset along normal to avoid z-fighting)

else:

endpoint = max range point

Collect endpoints in angular order.

Step 2: Add “edge refinement” rays (important)

To avoid seeing through thin wall edges:

For each ray hit:

Cast 2 extra rays at angle ±ε (epsilon like 0.5°–1.0°)
This catches corners and makes doorways look correct.

Step 3: Construct visibility polygon

Polygon points:

First point: origin

Then append endpoints in sorted angular order

This yields a wedge-shaped visibility polygon that respects occlusion.

Step 4: Render mask

Render the polygon into a mask layer:

White = visible

Black = unseen
Then composite:

World outside mask darkened + grain/vignette

World inside mask normal brightness (or lightly graded)

RENDERING OPTIONS IN GODOT (PRACTICAL)
Option A (simple): DrawPolygon2D as mask

Use a SubViewport + ColorRect shader that uses the SubViewport texture as mask.

Render visibility polygon into SubViewport each frame.

Option B (fast): Use Light2D with occluders (future-friendly)

Godot 2D lights + LightOccluder2D can do occlusion.

BUT you want a directional cone + custom reveal rules.

This can still work, but is less controllable for “seen stays visible” rules.
Recommended only if you want quick wins and accept constraints.

Preferred for your game: Option A (custom mask), because you already have special visibility rules.

DOORS IN VISION SYSTEM

Each door has:

state OPEN/CLOSED

when CLOSED:

collider belongs to VISION_BLOCKER

when OPEN:

collider removed from VISION_BLOCKER (or disabled)
Vision polygon will automatically reveal through open doorways.

“SEEN STAYS VISIBLE” RULE (YOUR PRIOR SPEC)

Maintain a fog-of-war memory:

If a pickup/consumable is seen once, it remains visible after turning away.

Zombies fade out after leaving cone unless audible/close enough.

Implementation note:

The vision mask controls “currently visible area.”

A second “memory mask” or per-entity visibility state handles “previously seen.”

So don’t bake memory into the mask—track it per entity:

if entity enters current visible polygon => set seen=true and last_seen_time=now

pickups: render if seen==true

zombies: render at alpha based on time since last_seen AND hearing checks

PERFORMANCE NOTES

Start with N=64 + corner refinement rays only when hits occur.

Update at 20–30 Hz (timer) instead of every frame if needed.

Recompute immediately on:

player moved > small threshold

facing changed > small threshold

door toggled

Otherwise reuse last polygon.

UPGRADE PATH TO PURE B (FULL LoS)

To transition from C → B:

Change ray angles from “cone only” to “full 360°”

Keep the same raycast + polygon build system

Optionally add more edge refinement around every hit

The renderer and entity “seen memory” logic remains unchanged

So the only thing that changes is the ray angle sampling domain:

C: angles in [dir-θ/2, dir+θ/2]

B: angles in [0, 2π)

VISUAL TUNING FOR ANALOG HORROR

Outside mask: darker + grain + slight vignette

Inside mask: normal with subtle grading

Boundary: soft feather (1–3px blur) to avoid harsh aliasing

Doors/corners should produce strong readable shadows (structural dread)

DELIVERABLES (IMPLEMENTATION CHECKLIST)

Create VISION_BLOCKER collision layer.

Mark walls and CLOSED doors as blockers.

Implement cone raycasting + epsilon corner rays.

Construct polygon points and render into SubViewport mask.

Composite world using mask.

Add per-entity memory for pickups and fading for zombies.

Add recompute throttling.