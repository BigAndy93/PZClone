
# SimZombie / PZClone – Technical Implementation Bible
*Godot Engineering Blueprint*
Generated: 2026-03-07

---

## Engine Standards

Engine: **Godot**

Rendering Style:
Top‑down **isometric**

Tile Standard:
- Floor diamond: **64 x 32 pixels**

Sprite Creation Standard:
- Drawing tile: **128 x 128**
- Canvas: **256 x 256**
- Floor diamond positioned **¼ up from bottom**
- Space above for vertical objects
- Space below for shadows

Character Directions:
8 directions

N  
NE  
E  
SE  
S  
SW  
W  
NW  

System Design Goals:

• Massive maps  
• Chunk streaming  
• Persistent world simulation  
• Multiplayer compatibility later  
• Modular systems  

---

# World Grid Architecture

The world is divided into **chunks**.

Chunk Size:
**32 x 32 tiles**

Tile structure:

```
Tile
{
    terrain_type
    walkable
    building_id
    furniture_id
    light_level
    noise_level
}
```

Tiles reference objects rather than storing full objects directly.

Example:

```
building_id → building database
furniture_id → furniture database
```

Only **active chunks** simulate:

• AI  
• lighting  
• physics  
• NPC behavior  

Inactive chunks remain stored but paused.

---

# Chunk Streaming System

Chunk activation radius:

**2 chunks around player**

Streaming logic:

```
distance = chunk_distance(player_chunk, target_chunk)

if distance <= 2:
    load_chunk()
else:
    unload_chunk()
```

Chunks outside radius:

• AI paused  
• physics disabled  
• lighting static  
• entities serialized  

This allows extremely large maps.

---

# Tile‑Edge Building System

Buildings are created **tile‑by‑tile**.

Walls exist **between tiles**, not inside tiles.

Each tile stores wall data for its edges.

Tile Edge Structure:

```
TileEdges
{
    north_wall
    east_wall
    south_wall
    west_wall
}
```

Wall structure:

```
Wall
{
    type
    material
    health
    has_window
    has_door
}
```

Benefits:

• prevents double walls  
• simplifies room detection  
• enables easy wall destruction  

Example layout:

```
Tile A | Tile B
   │
   │ wall
   │
Tile C | Tile D
```

Dragging walls:

Player drags cursor across tile edges.

System creates **blueprint walls**.

Blueprint structure:

```
BlueprintWall
{
    start_tile
    end_tile
    material
}
```

Player confirms blueprint to construct.

---

# Automatic Room Detection

Rooms are detected using **flood‑fill algorithms**.

Process:

1. Detect closed wall loops
2. Flood fill interior tiles
3. Assign room ID
4. Mark tiles as indoor

Example:

```
Room
{
    id
    tile_list
    indoor = true
}
```

Indoor rooms enable:

• indoor lighting  
• temperature insulation  
• weather protection  

---

# Auto Roof Generation

Once a room is detected:

Roof tiles are automatically generated above the room.

Roof tiles hide when:

• player enters building  
• camera moves inside  

---

# Occlusion Rendering System

Occlusion hides walls and roofs that block the player view.

This works similarly to **Project Zomboid**.

Occlusion rules:

• Walls between camera and player become transparent  
• Roof hides when player enters building  
• Interior walls fade when blocking player view  

Occlusion detection:

```
if wall_between_camera_and_player:
    set_wall_transparent()
```

Wall transparency levels:

0.0 → invisible  
0.5 → faded  
1.0 → fully visible  

Objects affected by occlusion:

• walls  
• roofs  
• tall furniture  

Objects NOT occluded:

• floor tiles  
• items on ground  

---

# Vision & Line‑of‑Sight System

Player uses a **vision cone**.

Objects are visible when:

• inside vision cone  
• not blocked by walls  

Raycasting used for visibility checks.

Example:

```
if raycast(player, target).hits_wall:
    target.visible = false
```

Persistence rules:

• Items seen once remain visible  
• Zombies fade after leaving sight  

Zombie fade timer:

```
fade_time = 2 seconds
```

---

# Zombie AI State Machine

States:

Idle  
Wander  
InvestigateNoise  
ChaseTarget  
AttackTarget  
LostTarget  
ReturnToWander  

Example state flow:

Idle → Wander → InvestigateNoise → ChaseTarget → AttackTarget

Triggers:

• noise events  
• line of sight  
• damage taken  

Noise event structure:

```
NoiseEvent
{
    position
    radius
    intensity
}
```

Zombies move toward noise source.

---

# Inventory System (Grid)

Inventory is **grid based**.

Example item sizes:

Knife → 1x2  
Pistol → 2x2  
Rifle → 2x5  

Item structure:

```
Item
{
    width
    height
    weight
    durability
}
```

Containers:

• player inventory  
• backpacks  
• vehicle storage  
• furniture storage  

Backpacks expand available grid space.

---

# Lighting System

Light sources:

• sun  
• fire  
• flashlight  
• electric lights  

Lighting stored per tile:

```
light_level
```

Light propagation:

```
for tile in radius:
    tile.light_level -= distance_decay
```

Walls block light propagation.

---

# Character System

Characters use **layered sprites**.

Base sprite:

underwear only

Equipment layers:

• pants  
• shirt  
• jacket  
• backpack  
• weapon  

Rendering order:

```
base → clothes → gear → weapon
```

---

# Save System

World saved per chunk.

File structure:

```
chunk_x_y.save
```

Saved data:

• tiles  
• buildings  
• furniture  
• zombies  
• items  
• NPCs  

Chunk saves allow fast loading.

---

# Development Order

Recommended build sequence:

1. world grid + chunk streaming
2. tile‑edge building system
3. room detection
4. occlusion rendering
5. zombie AI
6. inventory grid
7. lighting propagation
8. save system

These form the **core simulation foundation**.

---

# AI Assistant Guidelines

When generating code:

• follow architecture exactly  
• keep systems modular  
• support multiplayer expansion  
• avoid expensive per‑frame calculations  

