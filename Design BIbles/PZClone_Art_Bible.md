PROJECT: ZOMBOID-STYLE SURVIVAL GAME
VISUAL DIRECTION & ART PIPELINE DOCUMENT
Style: Soft-Grainy Analog Horror (Stylized Indie)
1. VISUAL IDENTITY LOCK
1.1 Core Tone

Emotional direction:

Quiet dread

Faded reality

VHS decay

Subtle loneliness

Slow rot, not explosive chaos

This is not:

Cartoon horror

Neon gore

Hyper-saturated survival arcade

World mood:
“The world did not end loudly. It decayed quietly.”

2. ART STYLE RULES (NON-NEGOTIABLE)
2.1 Palette Discipline

Use:

Desaturated greens

Sickly browns

Cold blue shadows

Dusty warm lamp glows

Avoid:

Pure black (#000000)

Pure white (#FFFFFF)

High-saturation primaries

Darkest value:
Deep navy or green-charcoal

Brightest value:
Soft bone or dusty yellow

All procedural and AI assets must map into this controlled palette.

2.2 Lighting Rules

Primary light source:

Top-left cool moonlight

Secondary light source:

Warm interior practical lights

Shadows:

Cool-toned

Never fully black

All sprites must obey:

Top edges lighter

Bottom/right edges darker

Subtle drop shadow baked in

2.3 Grain & Analog Effects (Post-Process Layer)

Global screen overlay:

5–8% static grain

Subtle vignette

Very faint scanline pattern

Optional micro chromatic offset

These are not baked into sprites.
They are post-process layers applied to entire render.

3. TECHNICAL ART SPECIFICATIONS
3.1 Tile System

Tile size: 64x64
Character height: 112–128px
Sprite directions: 8 (N, NE, E, SE, S, SW, W, NW)

Minimum animation:

Idle

Walk (4 frames)

Future:

Sneak

Rest

Attack

3.2 Character Model Architecture

All characters (players, NPCs, zombies) follow modular layering:

Base Model (underwear only)

Clothing overlay

Bag overlay

Damage overlay

Dirt overlay

Shadow overlay

No full baked characters.
Everything must layer.

Zombie differentiation:

Slight shoulder slump

Slightly longer arms

Desaturated gray-green skin shift

Subtle darker eye sockets

No exaggerated monster anatomy.

4. PROCEDURAL ART SYSTEM (PATH B)

Goal:
High-quality rule-driven procedural sprite generation.

4.1 Procedural Asset Pipeline

Instead of:

Generate shape → render

Use:

Generate base silhouette
→ Apply controlled palette color
→ Apply vertical gradient
→ Apply shadow mask (top-left lighting)
→ Apply grime mask
→ Apply edge highlight
→ Export sprite
→ Global grain applied at runtime

4.2 Constrained Randomization

All randomness must operate within defined style bounds.

Example:

Chair:

Base template A/B/C

Leg style short/angled

Palette limited to approved swatches

Damage probability: 20%

Dirt intensity: 0–30%

Never allow:
Unbounded color generation.
Unbounded shape distortion.

Style consistency > maximum variation.

4.3 Building Generation Pipeline

Generate layout grid
→ Apply structural tileset
→ Apply window rules
→ Apply damage mask
→ Apply dirt overlay
→ Apply lighting overlay
→ Apply ambient shadow mask

Windows must be darker than walls.
Walls must have subtle vertical gradient.

5. AI-ASSET PIPELINE (PATH C)

Goal:
Use AI for base sprite production, then normalize to style.

5.1 AI Role

AI generates:

Base body sprite sheets

Clothing overlays

Furniture bases

Environmental props

AI does NOT define final palette.
All outputs must be post-processed.

5.2 AI Generation Rules

When generating sprites:

Neutral lighting

Minimal strong highlights

Clear silhouette

Transparent background

Front-facing orthographic or isometric consistency

No baked heavy grain

Prompt tone:
“desaturated, analog horror, muted tones, soft lighting, indie pixel art, top-down isometric”

5.3 Post-Processing Pipeline (Mandatory)

All AI assets must pass through:

Palette remap → Style normalization
Shadow overlay pass
Highlight pass
Grime overlay
Export
Runtime grain overlay

AI is a base generator.
Final look is system-controlled.

6. ATMOSPHERIC SYSTEM INTEGRATION

To reinforce analog horror mood:

Add runtime systems:

Slow-moving fog layers

Subtle parallax haze

Flickering interior lights

Soft flashlight cone with grain visible inside beam

Zombie fade-to-grain when leaving sight cone

When occlusion hides zombies:
They should dissolve into grain, not pop out.

7. QUALITY CONTROL CHECKLIST

Before approving any asset:

Does it obey palette constraints?

Does it obey lighting direction?

Does it avoid pure black/white?

Does it maintain strong silhouette?

Does it feel faded, not vibrant?

Does it look consistent beside existing assets?

If any answer is no:
Reprocess asset.

8. PRODUCTION STRATEGY

Hybrid model:

Core assets:

AI-assisted base generation

Hand-cleaned key sprites

Variation:

Procedural overlays (dirt, damage, palette shifts)

Global:

Post-process grain & analog filters unify everything

Goal:
System-driven cohesion.
Not hand-drawn chaos.

9. LONG-TERM STYLE GUIDELINE

This world should always feel:

Slightly cold

Slightly dusty

Slightly quiet

Slightly deteriorated

Never glossy.
Never neon.
Never heroic.

Survival is mundane.
Horror is subtle.

END OF DOCUMENT.