"""
PZClone Furniture Sprite Sheet Generator — Batch 1
Generates 256×256 sheets (2×2 grid of 128×128 cells) for:
  double_bed, sofa, nightstand, dining_table, side_table, bookshelf

Cell layout (matches existing fridge/counter/chair pattern):
  (0,0)   = South  VIEW_S
  (128,0) = East   VIEW_E
  (0,128) = North  VIEW_N
  (128,128)= West  VIEW_W

Iso projection in sprite space:
  East unit  → screen (48, 24)   [right-and-down]
  North unit → screen (0, -24)   [straight up]
  Height     → screen (0, -1) per pixel
"""

from PIL import Image, ImageDraw
import os, math

OUT_DIR = r"C:\Users\And0t\PZClone\assets\furniture"
os.makedirs(OUT_DIR, exist_ok=True)

CELL = 128

# ── Colour helpers ────────────────────────────────────────────────────────────

def rgb(r, g, b):
    return (int(r * 255), int(g * 255), int(b * 255))

def lerp_c(c1, c2, t):
    return tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3))

def darken(c, amt):
    return tuple(max(0, int(v * (1 - amt))) for v in c)

def lighten(c, amt):
    return tuple(min(255, int(v + (255 - v) * amt)) for v in c)

COLD_BLUE = rgb(0.32, 0.36, 0.50)
WARM_LAMP = rgb(0.92, 0.82, 0.52)

def cool_shadow(c, amt):
    return lerp_c(c, COLD_BLUE, amt)

def warm_highlight(c, amt):
    return lerp_c(c, WARM_LAMP, amt)

def outline_col(side_c):
    return darken(cool_shadow(side_c, 0.55), 0.35)

# ── Palette ────────────────────────────────────────────────────────────────────

C_WOOD_DARK  = rgb(0.46, 0.34, 0.20)   # dark wood
C_WOOD_SOFT  = rgb(0.58, 0.46, 0.28)   # soft wood
C_MATTRESS_T = rgb(0.64, 0.60, 0.54)   # mattress top
C_MATTRESS_S = rgb(0.52, 0.48, 0.42)   # mattress sides
C_PILLOW     = rgb(0.82, 0.78, 0.72)   # pillow
C_SHEET      = rgb(0.72, 0.68, 0.60)   # bed sheet
C_HEADBOARD  = rgb(0.36, 0.22, 0.12)   # brown headboard
C_SOFA_F     = rgb(0.30, 0.25, 0.36)   # sofa fabric
C_SOFA_LEG   = rgb(0.28, 0.20, 0.12)   # sofa leg
C_SHELF      = rgb(0.34, 0.26, 0.16)   # shelf board
C_SHELF_DARK = rgb(0.22, 0.16, 0.09)   # shelf dark
C_TABLE_TOP  = rgb(0.56, 0.44, 0.28)   # table top (lighter wood)
C_TABLE_SIDE = rgb(0.40, 0.30, 0.18)   # table side

# ── Drawing primitives ─────────────────────────────────────────────────────────

def px(v):
    return (int(round(v[0])), int(round(v[1])))

def add2(a, b):
    return (a[0] + b[0], a[1] + b[1])

def scale2(v, s):
    return (v[0] * s, v[1] * s)

def poly(draw, pts, fill):
    draw.polygon([px(p) for p in pts], fill=fill)

def outline(draw, pts, col, w=1):
    closed = [px(p) for p in pts] + [px(pts[0])]
    draw.line(closed, fill=col, width=w)

def iso_box(draw, cx, cy, ex, ey, nx, ny, h, top_c, side_c, do_outline=True):
    """
    Draw an iso box.
    (cx,cy) = centre of floor diamond in cell-local pixels.
    ex,ey   = east  half-vector (right+down in screen).
    nx,ny   = north half-vector (up in screen → ny < 0 typically).
    h       = box height in screen pixels (drawn upward).
    """
    gN = (cx + nx, cy + ny)
    gE = (cx + ex, cy + ey)
    gS = (cx - nx, cy - ny)
    gW = (cx - ex, cy - ey)

    gNu = (gN[0], gN[1] - h)
    gEu = (gE[0], gE[1] - h)
    gSu = (gS[0], gS[1] - h)
    gWu = (gW[0], gW[1] - h)

    w_c = darken(cool_shadow(side_c, 0.20), 0.28)   # W/left face — darker
    t_c = lighten(warm_highlight(top_c, 0.06), 0.15) # top face — brighter

    poly(draw, [gW, gS, gSu, gWu], w_c)              # W face
    poly(draw, [gE, gS, gSu, gEu], side_c)           # E face
    poly(draw, [gNu, gEu, gSu, gWu], t_c)            # top face

    if do_outline:
        ol = outline_col(side_c)
        outline(draw, [gW, gS, gSu, gWu], ol)
        outline(draw, [gE, gS, gSu, gEu], ol)
        outline(draw, [gNu, gEu, gSu, gWu], ol)

    return {'N': gN, 'E': gE, 'S': gS, 'W': gW,
            'Nu': gNu, 'Eu': gEu, 'Su': gSu, 'Wu': gWu}

def iso_flat(draw, cx, cy, ex, ey, nx, ny, col, do_outline=False):
    """Draw a flat floor diamond."""
    gN = (cx + nx, cy + ny)
    gE = (cx + ex, cy + ey)
    gS = (cx - nx, cy - ny)
    gW = (cx - ex, cy - ey)
    poly(draw, [gN, gE, gS, gW], col)
    if do_outline:
        outline(draw, [gN, gE, gS, gW], outline_col(col))

# ── Sheet builder ──────────────────────────────────────────────────────────────

def make_sheet(name, fn_S, fn_E, fn_N, fn_W):
    """
    Create 256×256 RGBA sheet.
    fn_X(draw) draws into a 128×128 cell for view X.
    """
    sheet = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    for fn, ox, oy in [(fn_S, 0, 0), (fn_E, 128, 0), (fn_N, 0, 128), (fn_W, 128, 128)]:
        cell = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        fn(ImageDraw.Draw(cell))
        sheet.paste(cell, (ox, oy))
    path = os.path.join(OUT_DIR, name)
    sheet.save(path)
    print(f"  saved {name}")

# ═══════════════════════════════════════════════════════════════════════════════
# DOUBLE BED
# ═══════════════════════════════════════════════════════════════════════════════
# Queen mattress on boxspring, 2 pillows, brown headboard.
# Long axis = N-S.  Headboard at the indicated cardinal end of each view.
#
# Iso vectors (shared for all views):  ex=46 ey=23 nx=0 ny=-26
# Floor centre (cx,cy) adjusted per view to keep shape in frame.
# ──────────────────────────────────────────────────────────────────────────────

EX, EY = 46, 23     # east half-vector
NX, NY = 0, -26     # north half-vector

def _bed_base(draw, cx, cy, ex, ey, nx, ny):
    """Shared: boxspring + mattress + sheet stripe."""
    # Boxspring (slightly larger, h=6)
    iso_box(draw, cx, cy, ex+2, ey+1, nx, ny, 6,
            darken(C_MATTRESS_S, 0.12), darken(C_MATTRESS_S, 0.18))
    # Mattress body (h=20 total, on top of boxspring)
    iso_box(draw, cx, cy-6, ex, ey, nx, ny, 20,
            C_MATTRESS_T, C_MATTRESS_S)
    # Sheet stripe along the middle of the top face
    gN = (cx + nx, cy - 6 + ny - 20)
    gE = (cx + ex, cy - 6 + ey - 20)
    gS = (cx - nx, cy - 6 - ny - 20)
    gW = (cx - ex, cy - 6 - ey - 20)
    # Narrow stripe from W-side to E-side at N-third of top
    stripe_N = (gN[0] * 0.6 + gS[0] * 0.4, gN[1] * 0.6 + gS[1] * 0.4)
    stripe_S = (gN[0] * 0.3 + gS[0] * 0.7, gN[1] * 0.3 + gS[1] * 0.7)
    strip_col = lighten(C_SHEET, 0.08)
    poly(draw, [stripe_N, gE, stripe_S, gW], strip_col)

def _pillow(draw, px_c, py_c, ex, ey, nx, ny, h):
    """Draw a flat pillow."""
    iso_box(draw, px_c, py_c, ex, ey, nx, ny, h, C_PILLOW, darken(C_PILLOW, 0.15))

def _headboard(draw, hcx, hcy, ex, ey, nx, ny, h):
    """Headboard panel (brown, taller, thin depth)."""
    # Thin box behind the head end
    iso_box(draw, hcx, hcy, ex, ey, int(nx * 0.12), int(ny * 0.12), h,
            C_HEADBOARD, darken(C_HEADBOARD, 0.20))

# S view: headboard at S (near viewer, bottom of diamond)
def bed_S(draw):
    cx, cy = 64, 76
    _bed_base(draw, cx, cy, EX, EY, NX, NY)
    # Headboard at S end (cy - NY = cy+26 = 102 → gS on floor)
    hcx = cx
    hcy = cy - NY - 2   # just below gS (= cy+26 ≈ 102 → go to cy+24)
    hcy = cy + abs(NY) - 3
    _headboard(draw, hcx, hcy, EX, EY, 0, -2, 38)
    # Pillows near headboard (on mattress top)
    mattress_top_y = cy - 6 - 20   # top surface y-offset of mattress (centre)
    p_off_n = abs(NY) * 0.45       # offset toward headboard
    pcx = cx
    pcy = mattress_top_y + int(p_off_n)  # shifted toward S
    # Left pillow
    _pillow(draw, pcx - int(EX * 0.32), pcy + int(EY * 0.32 - 2),
            int(EX * 0.35), int(EY * 0.35), 0, -4, 4)
    # Right pillow
    _pillow(draw, pcx + int(EX * 0.32), pcy + int(EY * 0.32 - 2),
            int(EX * 0.35), int(EY * 0.35), 0, -4, 4)

# N view: headboard at N (far viewer, top of diamond)
def bed_N(draw):
    cx, cy = 64, 76
    _bed_base(draw, cx, cy, EX, EY, NX, NY)
    # Headboard at N end (gN corner = cy + NY = cy-26 = 50)
    hcx = cx
    hcy = cy + NY - 3   # just above gN
    _headboard(draw, hcx, hcy - 2, EX, EY, 0, -2, 38)
    # Pillows near headboard (N end, far from viewer)
    mattress_top_y = cy - 6 - 20
    p_off_n = abs(NY) * 0.45
    pcx = cx
    pcy = mattress_top_y - int(p_off_n)  # shifted toward N
    _pillow(draw, pcx - int(EX * 0.32), pcy + int(EY * 0.32 - 2),
            int(EX * 0.35), int(EY * 0.35), 0, -4, 4)
    _pillow(draw, pcx + int(EX * 0.32), pcy + int(EY * 0.32 - 2),
            int(EX * 0.35), int(EY * 0.35), 0, -4, 4)

# E view: bed rotated 90° — long axis now E-W, headboard at E (right)
def bed_E(draw):
    # Swap N and E extents
    cx, cy = 60, 78
    ex2, ey2 = abs(NY), 0        # was N → now E (but screen E=(48,24), scale to match)
    ex2 = int(EX * 1.12)         # slightly longer east
    ey2 = int(EY * 1.12)
    nx2 = 0
    ny2 = -int(abs(EY) * 0.95)  # shorter north
    _bed_base(draw, cx, cy, ex2, ey2, nx2, ny2)
    # Headboard at E end
    _headboard(draw, cx + ex2 + 2, cy + ey2 + 1, int(ex2 * 0.09), int(ey2 * 0.09), 0, ny2, 38)
    # Pillows near headboard (E end)
    mtop_y = cy - 6 - 20
    _pillow(draw, cx + int(ex2 * 0.58), mtop_y + int(ny2 * 0.25),
            int(ex2 * 0.25), int(ey2 * 0.25), 0, -4, 4)
    _pillow(draw, cx + int(ex2 * 0.58), mtop_y - int(ny2 * 0.15),
            int(ex2 * 0.25), int(ey2 * 0.25), 0, -4, 4)

# W view: mirror of E
def bed_W(draw):
    # Draw into a temporary cell, then flip
    tmp = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    bed_E(ImageDraw.Draw(tmp))
    flipped = tmp.transpose(Image.FLIP_LEFT_RIGHT)
    draw._image.paste(flipped, (0, 0), flipped)

print("Generating double_bed_sheet.png...")
make_sheet("double_bed_sheet.png", bed_S, bed_E, bed_N, bed_W)


# ═══════════════════════════════════════════════════════════════════════════════
# SOFA
# ═══════════════════════════════════════════════════════════════════════════════
# 3-seat couch. Back faces the "named" direction.  Seat cushions on top.
# ──────────────────────────────────────────────────────────────────────────────

C_SOFA_DARK = darken(cool_shadow(C_SOFA_F, 0.20), 0.28)
C_SOFA_TOP  = lighten(warm_highlight(C_SOFA_F, 0.06), 0.15)
C_SOFA_CUSHION = lighten(C_SOFA_F, 0.12)

def _sofa_NS(draw, cx, cy, back_at_S=True):
    """Sofa with long axis E-W, back toward S or N."""
    ex, ey = 54, 27    # wide east extent
    nx, ny = 0, -18    # narrow north

    # Seat base (low, wide)
    iso_box(draw, cx, cy, ex, ey, nx, ny, 14, C_SOFA_F, C_SOFA_F)

    # Seat cushions (3 side by side on top)
    cush_top_y = cy - 14
    for i in range(3):
        off_e = int(ex * (-0.62 + i * 0.62))
        off_ey = int(ey * (-0.62 + i * 0.62))
        cush_cx = cx + off_e
        cush_cy = cush_top_y + off_ey
        iso_box(draw, cush_cx, cush_cy,
                int(ex * 0.28), int(ey * 0.28), int(nx * 0.7), int(ny * 0.7),
                6, C_SOFA_CUSHION, C_SOFA_F)

    # Backrest (tall, on the appropriate side)
    back_ny = -int(abs(ny) * 0.15)  # thin depth
    if back_at_S:
        back_cx = cx - nx  # S side = cx + abs(ny) direction
        back_cy = cy + abs(ny) - 2
    else:
        back_cx = cx + nx
        back_cy = cy - abs(ny) - 2

    iso_box(draw, back_cx, back_cy, ex, ey, 0, back_ny, 26,
            lighten(C_SOFA_F, 0.08), C_SOFA_F)

    # Arm rests (two end blocks)
    arm_h = 18
    for side in [-1, 1]:
        arm_cx = cx + side * (ex + 2)
        arm_cy = cy + side * (ey + 1)
        iso_box(draw, arm_cx, arm_cy,
                int(ex * 0.10) + 2, int(ey * 0.10) + 1, nx, ny, arm_h,
                lighten(C_SOFA_F, 0.06), C_SOFA_F)

def _sofa_EW(draw, cx, cy, back_at_E=True):
    """Sofa rotated 90° — long axis N-S, back toward E or W."""
    ex, ey = 20, 10    # narrow east (was N extent)
    nx, ny = 0, -52    # tall north (was E extent)

    iso_box(draw, cx, cy, ex, ey, nx, ny, 14, C_SOFA_F, C_SOFA_F)

    # 3 cushions stacked N-S
    for i in range(3):
        off_n = int(abs(ny) * (-0.62 + i * 0.62))
        cush_cy = cy - 14 + off_n
        iso_box(draw, cx, cush_cy,
                int(ex * 0.7), int(ey * 0.7), int(abs(ny) * 0.22), -int(abs(ny) * 0.22),
                6, C_SOFA_CUSHION, C_SOFA_F)

    # Backrest on E or W
    if back_at_E:
        back_cx = cx + ex + 2
        back_cy = cy + ey + 1
    else:
        back_cx = cx - ex - 2
        back_cy = cy - ey - 1
    iso_box(draw, back_cx, back_cy, int(ex * 0.14) + 2, int(ey * 0.14) + 1, nx, ny, 26,
            lighten(C_SOFA_F, 0.08), C_SOFA_F)

    # Arm rests
    for side in [-1, 1]:
        arm_cy = cy + side * (abs(ny) + 2) - int(side * abs(ny))
        arm_cx = cx
        arm_ny2 = -int(abs(ny) * 0.10) - 2
        iso_box(draw, arm_cx, cy + side * abs(ny) - side * int(abs(ny) * 0.05),
                ex, ey, 0, arm_ny2, 18, lighten(C_SOFA_F, 0.06), C_SOFA_F)

def sofa_S(draw): _sofa_NS(draw, 64, 82, back_at_S=True)
def sofa_N(draw): _sofa_NS(draw, 64, 82, back_at_S=False)
def sofa_E(draw): _sofa_EW(draw, 68, 72, back_at_E=True)
def sofa_W(draw):
    tmp = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    sofa_E(ImageDraw.Draw(tmp))
    flipped = tmp.transpose(Image.FLIP_LEFT_RIGHT)
    draw._image.paste(flipped, (0, 0), flipped)

print("Generating sofa_sheet.png...")
make_sheet("sofa_sheet.png", sofa_S, sofa_E, sofa_N, sofa_W)


# ═══════════════════════════════════════════════════════════════════════════════
# NIGHTSTAND
# ═══════════════════════════════════════════════════════════════════════════════
# Small bedside table with 1 drawer, wood grain detail.
# Symmetric — all 4 views are equivalent (just recolour lighting).
# ──────────────────────────────────────────────────────────────────────────────

def _nightstand(draw, cx, cy, ex=30, ey=15, nx=0, ny=-22):
    # Main body
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, 24,
                C_WOOD_SOFT, C_WOOD_DARK)
    # Drawer line on E face (horizontal groove)
    E, S, Su, Eu = r['E'], r['S'], r['Su'], r['Eu']
    groove_y_lo = int(S[1] * 0.55 + Su[1] * 0.45)
    groove_y_hi = int(S[1] * 0.35 + Su[1] * 0.65)
    groove_col = darken(C_WOOD_DARK, 0.15)
    draw.line([(int(S[0]), groove_y_lo), (int(Eu[0]), groove_y_lo)], fill=groove_col, width=1)
    draw.line([(int(S[0]), groove_y_hi), (int(Eu[0]), groove_y_hi)], fill=groove_col, width=1)
    # Small knob
    knob_x = int((E[0] + S[0]) / 2 + 1)
    knob_y = int((groove_y_lo + groove_y_hi) / 2)
    draw.ellipse([knob_x - 2, knob_y - 2, knob_x + 2, knob_y + 2],
                 fill=rgb(0.70, 0.56, 0.34))

def ns_S(draw): _nightstand(draw, 64, 80)
def ns_E(draw): _nightstand(draw, 64, 80, ex=22, ey=11, nx=0, ny=-30)
def ns_N(draw): _nightstand(draw, 64, 80)
def ns_W(draw):
    tmp = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    ns_E(ImageDraw.Draw(tmp))
    flipped = tmp.transpose(Image.FLIP_LEFT_RIGHT)
    draw._image.paste(flipped, (0, 0), flipped)

print("Generating nightstand_sheet.png...")
make_sheet("nightstand_sheet.png", ns_S, ns_E, ns_N, ns_W)


# ═══════════════════════════════════════════════════════════════════════════════
# DINING TABLE
# ═══════════════════════════════════════════════════════════════════════════════
# Rectangular dining table. Long axis E-W in S/N views.
# ──────────────────────────────────────────────────────────────────────────────

def _dtable_EW(draw, cx, cy):
    """Wide dining table (long axis E-W)."""
    ex, ey = 54, 27
    nx, ny = 0, -18
    h = 26
    # Main tabletop
    iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_TABLE_TOP, C_TABLE_SIDE)
    # Four legs (small boxes at corners)
    leg_h = 20
    leg_ex = int(ex * 0.08)
    leg_ey = int(ey * 0.08)
    for se in [-1, 1]:
        for sn in [-1, 1]:
            lcx = cx + se * int(ex * 0.80)
            lcy = cy + se * int(ey * 0.80) + sn * int(abs(ny) * 0.75)
            iso_box(draw, lcx, lcy, leg_ex, leg_ey, 0, int(ny * 0.06), leg_h,
                    C_TABLE_SIDE, darken(C_TABLE_SIDE, 0.15))

def _dtable_NS(draw, cx, cy):
    """Narrow dining table (long axis N-S)."""
    ex, ey = 20, 10
    nx, ny = 0, -50
    h = 26
    iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_TABLE_TOP, C_TABLE_SIDE)
    leg_h = 20
    for se in [-1, 1]:
        for sn_f in [0.75, -0.75]:
            lcx = cx + se * int(ex * 0.80)
            lcy = cy + se * int(ey * 0.80) + int(ny * sn_f)
            iso_box(draw, lcx, lcy, int(ex * 0.35), int(ey * 0.35), 0, int(ny * 0.06), leg_h,
                    C_TABLE_SIDE, darken(C_TABLE_SIDE, 0.15))

def dt_S(draw):  _dtable_EW(draw, 62, 84)
def dt_N(draw):  _dtable_EW(draw, 62, 84)
def dt_E(draw):  _dtable_NS(draw, 64, 76)
def dt_W(draw):
    tmp = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    dt_E(ImageDraw.Draw(tmp))
    flipped = tmp.transpose(Image.FLIP_LEFT_RIGHT)
    draw._image.paste(flipped, (0, 0), flipped)

print("Generating dining_table_sheet.png...")
make_sheet("dining_table_sheet.png", dt_S, dt_E, dt_N, dt_W)


# ═══════════════════════════════════════════════════════════════════════════════
# SIDE TABLE / ACCENT TABLE
# ═══════════════════════════════════════════════════════════════════════════════
# Small square table next to sofa.
# ──────────────────────────────────────────────────────────────────────────────

def _side_table(draw, cx, cy, ex=28, ey=14, nx=0, ny=-24):
    # Top surface
    iso_box(draw, cx, cy, ex, ey, nx, ny, 22,
            lighten(C_WOOD_SOFT, 0.10), C_WOOD_DARK)
    # Thin legs visible beneath
    leg_h = 16
    for se in [-1, 1]:
        lcx = cx + se * int(ex * 0.76)
        lcy = cy + se * int(ey * 0.76)
        iso_box(draw, lcx, lcy, int(ex * 0.10) + 1, int(ey * 0.10) + 1,
                0, int(ny * 0.12), leg_h, C_WOOD_DARK, darken(C_WOOD_DARK, 0.20))

def st_S(draw): _side_table(draw, 64, 80)
def st_E(draw): _side_table(draw, 64, 80, ex=24, ey=12, nx=0, ny=-28)
def st_N(draw): _side_table(draw, 64, 80)
def st_W(draw):
    tmp = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    st_E(ImageDraw.Draw(tmp))
    flipped = tmp.transpose(Image.FLIP_LEFT_RIGHT)
    draw._image.paste(flipped, (0, 0), flipped)

print("Generating side_table_sheet.png...")
make_sheet("side_table_sheet.png", st_S, st_E, st_N, st_W)


# ═══════════════════════════════════════════════════════════════════════════════
# BOOKSHELF
# ═══════════════════════════════════════════════════════════════════════════════
# Tall wall bookcase with 3 visible shelf levels and coloured book spines.
# ──────────────────────────────────────────────────────────────────────────────

BOOK_COLORS = [
    rgb(0.60, 0.20, 0.18),   # red
    rgb(0.20, 0.36, 0.55),   # blue
    rgb(0.55, 0.48, 0.16),   # yellow
    rgb(0.24, 0.42, 0.24),   # green
    rgb(0.48, 0.26, 0.44),   # purple
    rgb(0.62, 0.38, 0.18),   # orange
]

def _bookshelf_NS(draw, cx, cy):
    """Shelf with long axis E-W, faces S/N."""
    ex, ey = 50, 25
    nx, ny = 0, -14
    # Frame
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, 62, C_SHELF, C_SHELF_DARK)
    # 3 shelf planks (horizontal lines on E face)
    E, S, Su, Eu = r['E'], r['S'], r['Su'], r['Eu']
    shelf_heights = [0.28, 0.55, 0.78]
    for sh in shelf_heights:
        sy_lo = int(S[1] * (1 - sh) + Su[1] * sh)
        sy_hi = sy_lo - 2
        shelf_col = darken(C_SHELF, 0.08)
        draw.line([(int(S[0]), sy_lo), (int(Eu[0]), sy_lo)], fill=shelf_col, width=1)
        draw.line([(int(S[0]), sy_hi), (int(Eu[0]), sy_hi)], fill=shelf_col, width=1)
    # Book spines on top face — small coloured rectangles
    top = [r['Nu'], r['Eu'], r['Su'], r['Wu']]
    # Draw 5 book spines along the top
    for i, bc in enumerate(BOOK_COLORS[:5]):
        t = (i + 0.5) / 5.0
        bx = int(r['Nu'][0] * (1 - t) + r['Eu'][0] * t)
        by = int(r['Nu'][1] * (1 - t) + r['Eu'][1] * t)
        # tiny rectangle
        draw.rectangle([bx - 3, by - 5, bx + 2, by - 1], fill=bc)

def _bookshelf_EW(draw, cx, cy):
    """Shelf rotated — long axis N-S."""
    ex, ey = 16, 8
    nx, ny = 0, -48
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, 62, C_SHELF, C_SHELF_DARK)
    # Shelf planks on W face
    W, S, Su, Wu = r['W'], r['S'], r['Su'], r['Wu']
    for sh in [0.28, 0.55, 0.78]:
        sy_lo = int(S[1] * (1 - sh) + Su[1] * sh)
        draw.line([(int(W[0]), sy_lo), (int(Su[0]), sy_lo)], fill=darken(C_SHELF, 0.08), width=1)

def bk_S(draw):  _bookshelf_NS(draw, 62, 88)
def bk_N(draw):  _bookshelf_NS(draw, 62, 88)
def bk_E(draw):  _bookshelf_EW(draw, 68, 82)
def bk_W(draw):
    tmp = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    bk_E(ImageDraw.Draw(tmp))
    flipped = tmp.transpose(Image.FLIP_LEFT_RIGHT)
    draw._image.paste(flipped, (0, 0), flipped)

print("Generating bookshelf_sheet.png...")
make_sheet("bookshelf_sheet.png", bk_S, bk_E, bk_N, bk_W)

print("\nBatch 1 complete.")
