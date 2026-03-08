# SimZombie / PZClone – Master Game Design Bible
*Consolidated Design Document – Generated 2026-03-07*


## Table of Contents

1. Vision & Game Pillars
2. Core Gameplay Loop
3. World Simulation
4. Player Systems
5. Survival Needs System
6. Inventory System (Grid-Based)
7. Zombie AI System
8. NPC Survivors
9. Factions & Territory
10. Safehouses & Settlement Management
11. Building & Construction System
12. Crafting & Resource Processing
13. Vision & Occlusion System
14. Lighting & Atmosphere
15. Combat System
16. Character Models & Animation
17. Procedural World Generation
18. Multiplayer / Co‑op
19. User Interface Systems
20. Art Direction & Visual Style
21. Technical Architecture (Godot)
22. Performance & Optimization
23. Future Expansion Systems

---

# Vision & Game Pillars

SimZombie is a simulation‑driven zombie survival game inspired by systems‑heavy survival sandboxes.

Primary pillars:

• Scarcity creates tension  
• Systems create emergent stories  
• The world evolves without the player  
• Safehouses grow into settlements  
• Survival is about logistics as much as combat


# Core Gameplay Loop

Spawn → Scavenge → Manage needs → Avoid or fight zombies → Secure shelter → Craft & build → Expand territory → Survive longer.

Long‑term loop:

Solo survivor → Safehouse → Recruit survivors → Build settlement → Control territory.


# World Simulation

The world persists and evolves.

Key simulated elements:

• Loot scarcity
• Time progression
• Weather
• Noise propagation
• Zombie migration
• Settlement growth
• Resource depletion


# Player Systems

Player attributes:

Health  
Stamina  
Hunger  
Thirst  
Fatigue  
Morale  

Skills:

• Carpentry
• Mechanics
• Combat
• Cooking
• Medicine
• Scavenging


# Survival Needs System

Needs decay over time.

Example decay rates:

Hunger: slow decay (hours)  
Thirst: medium decay  
Fatigue: tied to activity  
Morale: influenced by events and environment


# Inventory System (Grid-Based)

Inventory uses a grid layout.

Items occupy different tile sizes.

Example:

• Knife – 1x2
• Pistol – 2x2
• Rifle – 2x5
• Backpack – expands inventory space

Containers:

• Player inventory
• Backpacks
• Vehicles
• Storage furniture


# Zombie AI System

Zombie behavior states:

Idle  
Wander  
Investigate noise  
Chase target  
Attack  
Lose target  

Zombies respond strongly to:

• sound
• light
• movement


# NPC Survivors

NPCs are autonomous agents with:

Needs  
Morale  
Skills  
Loyalty  

NPC roles may include:

• guard
• scavenger
• builder
• medic


# Factions & Territory

Survivor groups may claim territory.

Territory benefits:

• safer zones
• resource control
• NPC recruitment

Conflicts between factions may occur.


# Safehouses & Settlement Management

Players can claim buildings.

Safehouse upgrades:

• barricades
• storage
• crafting stations
• power generation
• farming


# Building & Construction System

Construction occurs tile‑by‑tile.

Examples:

Walls  
Doors  
Windows  
Floors  
Roofs

Structures may be damaged or destroyed.


# Crafting & Resource Processing

Resources include:

Wood  
Metal  
Cloth  
Electronics

Processing steps:

Tree → Logs → Planks → Furniture / Structures


# Vision & Occlusion System

Objects render based on player visibility.

Rules:

• Items seen once remain visible
• Zombies fade when leaving vision
• Noise can reveal zombies


# Lighting & Atmosphere

Lighting sources:

Sunlight  
Flashlights  
Torches  
Electric lights

Darkness increases danger.


# Combat System

Combat styles:

Melee  
Firearms  
Thrown weapons

Noise from weapons attracts zombies.


# Character Models & Animation

Characters use layered sprite systems.

Base model:
Underwear only

Clothing layers:

• pants
• shirts
• jackets
• backpacks

Directional sprites:

N, NE, E, SE, S, SW, W, NW


# Procedural World Generation

Map generation uses chunks.

Features:

• towns
• roads
• forests
• abandoned vehicles
• zombie density zones


# Multiplayer / Co‑op

Optional co‑op play.

Players may:

• share safehouses
• coordinate scavenging
• build settlements


# User Interface Systems

Key UI elements:

Inventory grid  
Health / needs HUD  
Map interface  
Crafting menu  
Settlement management panels


# Art Direction & Visual Style

Top‑down isometric perspective.

Tile standard:

64x32 floor diamonds.

Sprites typically drawn on:

128x128 tiles within 256x256 canvases.


# Technical Architecture (Godot)

Engine: Godot

Core systems:

• TileMap for world grid
• Node‑based entity system
• Chunk streaming
• Save system for world persistence


# Performance & Optimization

Performance techniques:

• occlusion rendering
• chunk loading
• entity pooling
• AI update throttling


# Future Expansion Systems

Potential features:

Vehicles  
Farming  
Electric grid simulation  
Trade networks  
Large faction wars

