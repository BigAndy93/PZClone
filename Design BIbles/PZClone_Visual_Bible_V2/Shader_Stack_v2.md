# PZClone — Shader Stack & Material System Bible v2

## Shader Philosophy
Shaders must support:
- Performance stability in 4-player co-op
- Layered material variation
- Subtle realism
- World aging progression

## Standard Shader Layers
1. Base Albedo Texture
2. Color Tint (HSV modifier)
3. Grime Overlay Mask
4. Damage Overlay Mask
5. Ambient Occlusion (baked)
6. Optional Subtle Normal Map

Avoid:
- Heavy bloom
- Glossy specular highlights
- Overly complex PBR stacks

## Tint System
Every building and prop should support runtime tint variation:
- Wall tint
- Roof tint
- Trim tint

## Damage States
Support 3 visual states:
- Clean
- Worn
- Damaged

Damage overlay intensity must be adjustable via shader parameter.
