PZClone — Procedural World Generation Bible v1
Towns, Buildings, Scenery, Foliage & Fauna
1. World Generation Philosophy

The world must feel:

Lived in

Believable

Structurally logical

Risk-layered

System-supportive

Procedural does NOT mean random chaos.

It means:

Structured randomness guided by systemic rules.

2. World Structure Model
2.1 Macro World Layout (Layer 1)

World divided into:

Regions

Districts

Blocks

Lots

Tiles

Region Types

Residential suburb

Commercial strip

Industrial zone

Rural farmland

Forest outskirts

Highway / road network

Each region defines:

Building density

Zombie density modifier

Loot rarity bias

Foliage density

Fauna density

Sightline complexity

3. Generation Order (Critical)

Generation must happen in layered passes:

Terrain height + biome

Road network

District zoning

Lot subdivision

Building placement

Building interior generation

Scenery props

Foliage

Fauna spawn tables

Loot seeding

Never mix layers.

4. Terrain & Biomes
4.1 Terrain

Keep mostly flat (urban realism), but support:

Slight elevation differences

Drainage dips

Forest density shifts

Water bodies (future)

Noise-based heightmap:

Low amplitude

Smoothed

Limited vertical variation

4.2 Biome Types

Suburban grassland

Dense woodland

Light woodland

Roadside scrub

Abandoned lot overgrowth

Biome influences:

Tree density

Grass density

Zombie wander behavior

Fauna types

5. Road Network Generation

Roads define civilization.

5.1 Road Hierarchy

Main roads (arteries)

Secondary roads

Side streets

Driveways

Dirt paths (rural)

Use:

Grid-based for suburban

Slight variation offsets to avoid rigid repetition

Intersections must:

Align with zoning rules

Create logical traffic flow

6. Zoning System

Each block assigned zoning:

Residential Low Density

Residential Medium

Commercial Small

Commercial Large

Industrial

Rural

Zoning determines:

Lot size

Building templates

Prop density

Loot bias

Zombie density bias

7. Building Generation System
7.1 Building Archetypes

Each building type defined by:

Footprint size range

Room layout patterns

Prop sets

Loot table link

Structural integrity value

Residential

Small house

Medium house

Duplex

Apartment (future)

Commercial

Convenience store

Pharmacy

Hardware store

Restaurant

Office

Industrial

Warehouse

Storage yard

Garage

7.2 Building Footprint Placement

Must not overlap roads

Must respect lot bounds

Must align with driveway rules

Maintain setback from street

7.3 Interior Layout Generation

Interior generated from:

Predefined room modules

Procedural room connectors

Weighted adjacency rules

Example adjacency rules:

Bathroom adjacent to bedroom or hallway

Kitchen near exterior wall

Commercial storage in back room

Office near front entrance

Interior must be navigable and readable from isometric camera.

8. Prop & Scenery Placement

After building placement:

8.1 Exterior Props

Trash cans

Mailboxes

Fences

Vehicles (future)

Dumpsters (commercial)

Rules:

Must not block doorways

Must respect collision grid

Clutter increases stealth complexity

8.2 Interior Props

Furniture

Shelving

Counters

Fridges

Cabinets

Placement rules:

Maintain pathing lanes

Avoid unreachable loot spots

Respect room type

9. Foliage System

Foliage must serve gameplay:

Break line-of-sight

Affect stealth

Affect zombie pathing (optional slowdown)

9.1 Tree Types

Large tree (blocks vision fully)

Medium tree

Bush (partial vision block)

Tall grass (stealth modifier)

9.2 Growth Model (Optional Future)

Over time:

Grass spreads

Abandoned lots overgrow

Roads crack

This reinforces world decay.

10. Fauna System (Future Layer)

Fauna is NOT cosmetic.

Animals should:

Move in herds or pairs

React to noise

Potentially attract zombies

Provide survival resource (food)

Initial fauna types:

Deer

Stray dog

Crows

Fauna states:

Idle graze

Flee noise

Wander

Dead carcass (lootable)

11. Loot Seeding Integration

Loot seeded AFTER building and prop placement.

Each container:

Uses deterministic seed based on:

World seed

Chunk coordinates

Container ID

This prevents:

Loot duplication

Desync between sessions

12. Zombie Density Mapping

Zombie spawn density influenced by:

Region type

Noise history

Player activity heatmap

Time since world start

Urban core > suburbs > rural.

13. Performance Considerations
Chunk System

World divided into chunks.

Each chunk stores:

Terrain

Buildings

Containers

Props

Zombie instances

Fauna instances

Chunks:

Load on proximity

Unload outside radius

Persist diffs only

14. Emergent Map Goals

The map must allow:

Safehouse strategy

Chokepoints

Ambushes

Long sightlines

Dense blind corners

Forest escape routes

If terrain prevents tactical decisions, redesign generation rules.

15. Replayability Rules

Avoid:

Identical block repetition

Symmetry across regions

Overuse of rare building types

Use:

Weighted distribution

Regional personality

Seed-based variety

16. World Personality System (Optional Advanced)

Each world seed generates:

Slight economic bias

Slight zombie density bias

Slight weather pattern bias

Slight building condition bias

This makes worlds feel different without extreme changes.

17. Testing Requirements

World generation must support:

Seed override input

Debug overlays for:

Zoning

Pathing grid

Zombie density map

Loot rarity heatmap

Foliage density map

18. What Not To Do

Do not:

Randomly scatter buildings without zoning

Place loot before finalizing building placement

Overload map with clutter early

Generate navmesh after every small prop

19. Long-Term Vision

Eventually:

Vehicles integrated with road logic

Wildlife hunting

Seasonal changes

Migration events

Procedural small towns stitched together

End of World Generation Bible v1