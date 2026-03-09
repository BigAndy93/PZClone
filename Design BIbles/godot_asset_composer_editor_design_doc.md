
# Godot Asset Composer / Editor
## Comprehensive Feature List & Design Document

Author: Andrew
Engine Target: Godot 4.x

---

# 1. Purpose

The Asset Composer / Editor is an in‑engine Godot tool designed to:

• View and organize art assets  
• Edit and preview spritesheets  
• Assemble structures from tiles and props  
• Build reusable building templates  
• Save composed structures for procedural world generation

The goal is to eliminate manual scene assembly and allow rapid creation of reusable building blueprints for the game world.

---

# 2. Core Tool Philosophy

The editor should function similarly to a **map editor + prefab builder**.

Key principles:

• Everything is **tile-aligned**
• Buildings are saved as **data templates**
• Assets are organized by **category**
• Composition occurs in **layers**
• Structures can be **exported and reused during procedural generation**

---

# 3. Major Features

## Asset Browser

Browse all assets inside the game directory.

Features:

• Folder navigation
• Thumbnail previews
• Asset tagging
• Asset search
• Drag‑and‑drop placement
• Favorites system

Supported asset types:

• spritesheets
• tile textures
• props/furniture
• walls
• floors
• doors/windows
• roof assets

---

# Spritesheet Editor

Allows viewing and editing sprite sheets directly in the tool.

Capabilities:

• grid overlay
• tile slicing
• frame animation preview
• directional sprite previews
• tile pivot editing
• collision preview
• shadow preview

Settings:

Tile width
Tile height
Rows
Columns
Offset alignment

Export options:

• sliced tileset
• animation strip
• directional flip variants

---

# Structure Composer

Main building assembly workspace.

Users can:

• place floors
• place walls
• place doors/windows
• place props
• define rooms

Supports multi‑layer building composition.

Layers:

1 Floor layer  
2 Wall layer  
3 Object layer  
4 Roof layer  
5 Collision layer  
6 Metadata layer

---

# Tile Placement Tools

Paint style tools for building construction.

Tools:

Brush  
Rectangle tool  
Line tool  
Fill tool  
Eraser  
Eyedropper

Tile snapping options:

• grid snapping
• wall-edge snapping
• object anchor snapping

---

# Wall Construction System

Walls are placed along tile edges instead of occupying tiles.

Features:

• edge snapping
• automatic corner detection
• door/window insertion
• interior/exterior wall types

Wall orientations:

North
South
East
West

---

# Room Definition Tool

Rooms define interior zones for gameplay systems.

Room metadata:

Room type
Lighting type
Spawn points
Loot tables

Example room types:

Kitchen
Bedroom
Office
Classroom
Bathroom
Storage

---

# Asset Placement Rules

Assets define placement constraints.

Examples:

Desk → floor only  
Wall TV → wall only  
Window → wall segment  
Bed → floor + wall proximity

Rule system prevents invalid placements.

---

# Template Saving

Buildings can be saved as reusable templates.

Template contains:

floor tiles
walls
doors/windows
props
metadata

Saved as:

/buildings/templates/

Example file:

house_small_01.tres  
school_classroom_01.tres  
gas_station_01.tres

---

# Template Metadata

Each building template includes metadata.

Fields:

Name  
Category  
Size  
Room count  
Spawn weight  
Tags

Example:

Name: Small Suburban House  
Category: residential  
Size: 10x12  
Rooms: 4  
Tags: house, suburban

---

# Validation System

The editor should validate buildings before saving.

Checks include:

• closed wall loops
• door accessibility
• room detection
• collision overlap
• unreachable areas

Errors highlight visually in the editor.

---

# Preview Mode

Simulates the building in‑game.

Preview features:

• player movement test
• occlusion preview
• lighting preview
• zombie spawn preview

---

# 4. Data Structures

## Asset Definition

class AssetDefinition
{
    id
    name
    category
    sprite_path
    tile_size
    placement_rules
}

---

# Building Template

class BuildingTemplate
{
    id
    width
    height

    floor_tiles[]
    walls[]
    props[]
    rooms[]

    metadata
}

---

# Tile Placement

class TilePlacement
{
    tile_id
    position_x
    position_y
    rotation
}

---

# Wall Segment

class WallSegment
{
    start_tile
    end_tile
    orientation
    wall_type
}

---

# 5. Folder Structure

Recommended project layout:

/assets
    /floors
    /walls
    /props
    /spritesheets

/buildings
    /templates
    /generated

/tools
    asset_composer_plugin

---

# 6. Godot Implementation

Use a custom **EditorPlugin**.

Main UI nodes:

DockContainer
SplitContainer
PanelContainer
ItemList
TileMapLayer
GridContainer

Key scenes:

AssetBrowser.tscn  
SpritesheetEditor.tscn  
StructureComposer.tscn  
TemplatePreview.tscn

---

# Core Systems

Asset Manager  
Spritesheet Parser  
Tile Composer  
Template Serializer  
Validation System

---

# 7. Workflow

Typical workflow for designers:

1 Import assets  
2 Slice spritesheets  
3 Open Structure Composer  
4 Paint floors  
5 Place walls  
6 Insert doors/windows  
7 Place props  
8 Define rooms  
9 Validate structure  
10 Save template

Template becomes available for world generation.

---

# 8. MVP Development Phases

Phase 1

Asset browser  
Tile placement  
Save template

Phase 2

Spritesheet editor  
Wall system  
Room detection

Phase 3

Validation tools  
Preview mode

Phase 4

Procedural integration

---

# 9. Integration With World Generation

The game can spawn buildings using templates.

Example:

load template  
place at world position  
spawn props  
spawn loot  
spawn zombies

Templates become building modules for procedural towns.

---

# 10. Future Enhancements

Blueprint sharing

Procedural room filling

Auto roof generation

Damage states

Furniture randomization

Interior lighting baking
