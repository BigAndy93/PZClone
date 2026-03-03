## SpriteSheet — Resource describing a character sprite sheet.
## Follows the Sprite_Template_Bible.md layout:
##   Walk: 512×1024  (4 frames × 8 directions, 128×128 per frame)
##   Idle: 256×1024  (2 frames × 8 directions, 128×128 per frame)
##
## Direction row order (locked per bible §2):
##   Row 0=N  1=NE  2=E  3=SE  4=S  5=SW  6=W  7=NW
##
## Usage: assign to Player.sprite_sheets[] (one per Layer enum index in
##   CharacterSpriteController) to enable sprite rendering for that layer.
##   Leave empty or assign no texture to keep the procedural fallback.

class_name SpriteSheet
extends Resource

## 512×1024 walk animation (4 cols × 8 rows, 128×128 per frame).
@export var walk_texture: Texture2D = null
## 256×1024 idle animation (2 cols × 8 rows, 128×128 per frame).
@export var idle_texture: Texture2D = null

## Size of each frame canvas in pixels.
@export var frame_size: Vector2i = Vector2i(128, 128)

## Playback speeds.
@export var fps_walk: int = 7
@export var fps_idle: int = 3

## Number of animation frames per direction.
@export var walk_frame_count: int = 4
@export var idle_frame_count: int = 2

## Foot contact pixel offset from canvas top-left corner.
## This is the pivot that gets anchored to the character's ground position.
@export var foot_pivot: Vector2 = Vector2(64.0, 108.0)
