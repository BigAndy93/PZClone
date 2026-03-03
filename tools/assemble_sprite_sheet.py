#!/usr/bin/env python3
"""assemble_sprite_sheet.py — Assemble layered character sprites into PZClone sheet format.

Input directory structure expected:
    <source_dir>/
        walk/
            N_0.png  N_1.png  N_2.png  N_3.png   (4 walk frames per direction)
            NE_0.png ... NW_3.png
        idle/
            N_0.png  N_1.png              (2 idle frames per direction)
            NE_0.png ... NW_1.png

Output:
    <out_dir>/walk_sheet.png   — 512 × 1024  (4 cols × 8 rows, 128×128 each)
    <out_dir>/idle_sheet.png   — 256 × 1024  (2 cols × 8 rows, 128×128 each)

Direction row order (matches CharacterSpriteController §2):
    Row 0 = N   Row 1 = NE  Row 2 = E   Row 3 = SE
    Row 4 = S   Row 5 = SW  Row 6 = W   Row 7 = NW

Requirements:
    pip install pillow

Optional palette normalisation pass (--palette):
    Remaps each pixel to the nearest swatch from ArtPalette using RGB Euclidean distance.
    Useful for ComfyUI outputs that drift off-palette.

Usage:
    python assemble_sprite_sheet.py <source_dir> <out_dir>
    python assemble_sprite_sheet.py <source_dir> <out_dir> --palette
    python assemble_sprite_sheet.py <source_dir> <out_dir> --frame-size 128 --foot-y 108
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow not installed.  Run:  pip install pillow")
    sys.exit(1)


# ── Art palette swatches (matches autoloads/ArtPalette.gd) ───────────────────
_ART_PALETTE: list[tuple[int, int, int]] = [
    (26,  28,  41),   # SHADOW_BASE
    (219, 214, 189),  # BONE_WHITE
    (82,  92,  128),  # COLD_BLUE
    (235, 209, 133),  # WARM_LAMP
    (66,  87,  51),   # SICK_GREEN
    (112, 92,  61),   # DUSTY_BROWN
    (64,  97,  48),   # TILE_GRASS
    (77,  79,  87),   # TILE_ROAD
    (117, 92,  59),   # TILE_DIRT
    (102, 87,  74),   # TILE_FLOOR
    (92,  94,  105),  # TILE_PAVEMENT
    (235, 196, 133),  # WARM_LAMP (duplicate; kept for LUT density)
    (31,  51,  26),   # FOLIAGE_LARGE
    (41,  66,  31),   # FOLIAGE_MEDIUM
    (51,  77,  36),   # FOLIAGE_BUSH
    (71,  51,  28),   # BARK_BASE
]


# ── Direction / frame helpers ─────────────────────────────────────────────────
DIR_ORDER = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
FRAME_SIZE_DEFAULT = 128


def _nearest_palette(r: int, g: int, b: int) -> tuple[int, int, int]:
    """Return the closest ArtPalette swatch to (r, g, b) by Euclidean distance."""
    best_dist = math.inf
    best      = _ART_PALETTE[0]
    for swatch in _ART_PALETTE:
        dr = r - swatch[0]
        dg = g - swatch[1]
        db = b - swatch[2]
        d  = dr * dr + dg * dg + db * db
        if d < best_dist:
            best_dist = d
            best      = swatch
    return best


def _apply_palette_normalisation(img: Image.Image) -> Image.Image:
    """Remap every opaque pixel to the nearest art-palette swatch."""
    out  = img.convert("RGBA")
    data = list(out.getdata())
    remapped = []
    for r, g, b, a in data:
        if a < 16:          # keep transparent pixels untouched
            remapped.append((r, g, b, a))
        else:
            nr, ng, nb = _nearest_palette(r, g, b)
            remapped.append((nr, ng, nb, a))
    out.putdata(remapped)
    return out


def _load_frame(path: Path, frame_size: int, foot_y: int) -> Image.Image:
    """Load a sprite frame, crop/pad to frame_size × frame_size centred on foot_y."""
    img = Image.open(path).convert("RGBA")
    w, h = img.size

    # Target canvas
    canvas = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))

    # Centre horizontally; align foot_y to bottom-ish of canvas
    foot_row_in_src  = foot_y                    # foot pixel row in source
    dest_foot_row    = int(frame_size * 0.84)    # where foot lands in the 128px canvas
    dx               = (frame_size - w) // 2
    dy               = dest_foot_row - foot_row_in_src

    canvas.paste(img, (dx, dy), img)
    return canvas


def _build_sheet(
    source_dir: Path,
    state: str,
    n_frames: int,
    frame_size: int,
    foot_y: int,
    use_palette: bool,
) -> Image.Image:
    """Assemble a state sheet (walk or idle) for all 8 directions."""
    sheet_w = frame_size * n_frames
    sheet_h = frame_size * 8   # 8 directions
    sheet   = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    for row, direction in enumerate(DIR_ORDER):
        for col in range(n_frames):
            filename = f"{direction}_{col}.png"
            fpath    = source_dir / state / filename
            if not fpath.exists():
                print(f"  WARNING: missing {fpath} — blank frame used")
                frame = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
            else:
                frame = _load_frame(fpath, frame_size, foot_y)
                if use_palette:
                    frame = _apply_palette_normalisation(frame)

            x = col * frame_size
            y = row * frame_size
            sheet.paste(frame, (x, y), frame)

    return sheet


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Assemble PZClone character sprite sheets")
    parser.add_argument("source_dir", type=Path, help="Root directory containing walk/ and idle/ sub-dirs")
    parser.add_argument("out_dir",    type=Path, help="Output directory (created if missing)")
    parser.add_argument("--palette",     action="store_true", help="Remap pixels to ArtPalette swatches")
    parser.add_argument("--frame-size",  type=int, default=FRAME_SIZE_DEFAULT, help="Frame size in pixels (default: 128)")
    parser.add_argument("--foot-y",      type=int, default=108, help="Foot pixel row in source images (default: 108)")
    parser.add_argument("--walk-frames", type=int, default=4,   help="Walk frame count (default: 4)")
    parser.add_argument("--idle-frames", type=int, default=2,   help="Idle frame count (default: 2)")
    args = parser.parse_args()

    if not args.source_dir.is_dir():
        print(f"ERROR: source directory not found: {args.source_dir}")
        sys.exit(1)

    args.out_dir.mkdir(parents=True, exist_ok=True)

    for state, n_frames, filename in [
        ("walk", args.walk_frames, "walk_sheet.png"),
        ("idle", args.idle_frames, "idle_sheet.png"),
    ]:
        state_dir = args.source_dir / state
        if not state_dir.is_dir():
            print(f"  SKIP: {state_dir} does not exist — {filename} not generated")
            continue

        print(f"Building {filename}  ({n_frames} frames × 8 dirs × {args.frame_size}px) …")
        sheet = _build_sheet(
            source_dir  = args.source_dir,
            state       = state,
            n_frames    = n_frames,
            frame_size  = args.frame_size,
            foot_y      = args.foot_y,
            use_palette = args.palette,
        )
        out_path = args.out_dir / filename
        sheet.save(out_path, "PNG")
        w, h = sheet.size
        print(f"  Saved {out_path}  ({w}×{h})")

    print("Done.")


if __name__ == "__main__":
    main()
