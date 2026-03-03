"""
PZClone Furniture Sprite Sheet Generator — Batch 2
Generates 256×256 sheets for:
  stove, wardrobe, dresser, medicine_cabinet, filing_cabinet, locker
"""

from PIL import Image, ImageDraw
import os

OUT_DIR = r"C:\Users\And0t\PZClone\assets\furniture"
os.makedirs(OUT_DIR, exist_ok=True)
CELL = 128

# ── Colour helpers ─────────────────────────────────────────────────────────────

def rgb(r, g, b): return (int(r*255), int(g*255), int(b*255))
def lerp_c(c1, c2, t): return tuple(int(c1[i]*(1-t)+c2[i]*t) for i in range(3))
def darken(c, a): return tuple(max(0, int(v*(1-a))) for v in c)
def lighten(c, a): return tuple(min(255, int(v+(255-v)*a)) for v in c)

COLD_BLUE = rgb(0.32, 0.36, 0.50)
WARM_LAMP = rgb(0.92, 0.82, 0.52)

def cool_shadow(c, a): return lerp_c(c, COLD_BLUE, a)
def warm_highlight(c, a): return lerp_c(c, WARM_LAMP, a)
def outline_col(c): return darken(cool_shadow(c, 0.55), 0.35)

# ── Palette ────────────────────────────────────────────────────────────────────

C_WOOD_DARK  = rgb(0.46, 0.34, 0.20)
C_WOOD_SOFT  = rgb(0.58, 0.46, 0.28)
C_APPLI      = rgb(0.22, 0.20, 0.18)   # dark appliance
C_APPLI_G    = rgb(0.26, 0.28, 0.30)   # grey appliance
C_METAL      = rgb(0.38, 0.40, 0.44)   # metal / locker
C_METAL_DARK = rgb(0.26, 0.28, 0.32)   # dark metal
C_METAL_LT   = rgb(0.52, 0.54, 0.58)   # light metal
C_FILING     = rgb(0.22, 0.20, 0.18)   # filing cabinet charcoal
C_LOCKER_G   = rgb(0.26, 0.30, 0.26)   # locker green-grey
C_LOCKER_DK  = rgb(0.18, 0.22, 0.18)
C_MED_CAB    = rgb(0.80, 0.84, 0.80)   # medicine cabinet light
C_MED_DARK   = rgb(0.60, 0.65, 0.60)
C_BURNER     = rgb(0.14, 0.13, 0.12)   # stove burner

# ── Drawing primitives ─────────────────────────────────────────────────────────

def px(v): return (int(round(v[0])), int(round(v[1])))
def poly(draw, pts, fill): draw.polygon([px(p) for p in pts], fill=fill)
def outline(draw, pts, col, w=1):
    closed = [px(p) for p in pts] + [px(pts[0])]
    draw.line(closed, fill=col, width=w)

def iso_box(draw, cx, cy, ex, ey, nx, ny, h, top_c, side_c, do_ol=True):
    gN = (cx+nx, cy+ny); gE = (cx+ex, cy+ey)
    gS = (cx-nx, cy-ny); gW = (cx-ex, cy-ey)
    gNu=(gN[0],gN[1]-h); gEu=(gE[0],gE[1]-h)
    gSu=(gS[0],gS[1]-h); gWu=(gW[0],gW[1]-h)

    w_c = darken(cool_shadow(side_c, 0.20), 0.28)
    t_c = lighten(warm_highlight(top_c, 0.06), 0.15)

    poly(draw, [gW,gS,gSu,gWu], w_c)
    poly(draw, [gE,gS,gSu,gEu], side_c)
    poly(draw, [gNu,gEu,gSu,gWu], t_c)
    if do_ol:
        ol = outline_col(side_c)
        outline(draw, [gW,gS,gSu,gWu], ol)
        outline(draw, [gE,gS,gSu,gEu], ol)
        outline(draw, [gNu,gEu,gSu,gWu], ol)
    return {'N':gN,'E':gE,'S':gS,'W':gW,'Nu':gNu,'Eu':gEu,'Su':gSu,'Wu':gWu}

def make_sheet(name, fn_S, fn_E, fn_N, fn_W):
    sheet = Image.new("RGBA", (256,256), (0,0,0,0))
    for fn, ox, oy in [(fn_S,0,0),(fn_E,128,0),(fn_N,0,128),(fn_W,128,128)]:
        cell = Image.new("RGBA", (128,128), (0,0,0,0))
        fn(ImageDraw.Draw(cell))
        sheet.paste(cell, (ox,oy))
    sheet.save(os.path.join(OUT_DIR, name))
    print(f"  saved {name}")

def mirror_fn(fn):
    """Return a new function that draws fn then flips horizontally."""
    def _w(draw):
        tmp = Image.new("RGBA", (128,128), (0,0,0,0))
        fn(ImageDraw.Draw(tmp))
        flipped = tmp.transpose(Image.FLIP_LEFT_RIGHT)
        draw._image.paste(flipped, (0,0), flipped)
    return _w


# ═══════════════════════════════════════════════════════════════════════════════
# STOVE  (kitchen range with 4 burners + control panel)
# ═══════════════════════════════════════════════════════════════════════════════

def _stove_NS(draw, cx, cy):
    """Stove facing S (control panel at S, burners on top)."""
    ex, ey = 38, 19
    nx, ny = 0, -26
    h = 30
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_APPLI_G, C_APPLI)
    # 4 burners on top face (2×2 grid of ellipses)
    top_ctr_x = cx
    top_ctr_y = cy - h + int(ny * 0.2)   # approx centre of top face
    # Build top face diamond midpoints
    Nu, Eu, Su, Wu = r['Nu'], r['Eu'], r['Su'], r['Wu']
    # Place 4 burners at N, E, S, W quarters of top
    burner_positions = [
        (Nu[0]*0.65+Su[0]*0.35, Nu[1]*0.65+Su[1]*0.35),   # NW-ish
        (Eu[0]*0.65+Su[0]*0.35, Eu[1]*0.65+Su[1]*0.35),   # NE-ish
        (Nu[0]*0.35+Su[0]*0.65, Nu[1]*0.35+Su[1]*0.65),   # SW-ish
        (Eu[0]*0.35+Su[0]*0.65, Eu[1]*0.35+Su[1]*0.65),   # SE-ish
    ]
    for bx, by in burner_positions:
        draw.ellipse([int(bx)-5, int(by)-3, int(bx)+5, int(by)+3], fill=C_BURNER)
        draw.ellipse([int(bx)-2, int(by)-1, int(bx)+2, int(by)+1],
                     fill=darken(C_BURNER, 0.3))
    # Control knobs on S (front) face — small circles on E face
    E, S, Su2, Eu2 = r['E'], r['S'], r['Su'], r['Eu']
    for i in range(4):
        t = (i + 0.5) / 4.0
        kx = int(S[0] * (1-t) + Eu2[0] * t)
        ky = int(S[1] * (1-t) + Eu2[1] * t)
        ky = int(ky * 0.3 + E[1] * 0.7)  # put knobs at mid-height
        draw.ellipse([kx-2, ky-2, kx+2, ky+2], fill=C_METAL_LT)

def _stove_EW(draw, cx, cy):
    """Stove rotated 90°."""
    ex, ey = 26, 13
    nx, ny = 0, -38
    h = 30
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_APPLI_G, C_APPLI)
    Nu, Eu, Su, Wu = r['Nu'], r['Eu'], r['Su'], r['Wu']
    for t1 in [0.3, 0.7]:
        for t2 in [0.35, 0.65]:
            bx = int(Nu[0]*(1-t1)+Su[0]*t1)*0.5 + int(Wu[0]*(1-t2)+Eu[0]*t2)*0.5
            by = int(Nu[1]*(1-t1)+Su[1]*t1)*0.5 + int(Wu[1]*(1-t2)+Eu[1]*t2)*0.5
            draw.ellipse([int(bx)-4, int(by)-2, int(bx)+4, int(by)+2], fill=C_BURNER)

print("Generating stove_sheet.png...")
def stv_S(d): _stove_NS(d, 64, 82)
def stv_N(d): _stove_NS(d, 64, 82)
def stv_E(d): _stove_EW(d, 66, 78)
make_sheet("stove_sheet.png", stv_S, stv_E, stv_N, mirror_fn(stv_E))


# ═══════════════════════════════════════════════════════════════════════════════
# WARDROBE  (tall closet, double doors)
# ═══════════════════════════════════════════════════════════════════════════════

C_WARD_TOP  = darken(C_WOOD_SOFT, 0.08)
C_WARD_SIDE = darken(C_WOOD_DARK, 0.05)

def _wardrobe_NS(draw, cx, cy):
    ex, ey = 50, 25
    nx, ny = 0, -16
    h = 56
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_WARD_TOP, C_WARD_SIDE)
    # Door seam (vertical centre line on E face)
    E, S, Su, Eu = r['E'], r['S'], r['Su'], r['Eu']
    mid_x = int((S[0] + Eu[0]) / 2)
    mid_y = int((S[1] + Su[1]) / 2)
    seam_col = darken(C_WARD_SIDE, 0.20)
    draw.line([(mid_x, int(S[1])), (mid_x, int(Su[1]))], fill=seam_col, width=1)
    # Two handles
    for side_t in [0.3, 0.7]:
        hx = int(S[0] * (1-side_t) + Eu[0] * side_t)
        hy = int(S[1] * (1-side_t) + Su[1] * side_t + (Su[1]-S[1]) * 0.3)
        draw.ellipse([hx-2, hy-2, hx+2, hy+2], fill=rgb(0.68, 0.58, 0.34))
    # Cornice moulding on top (thin extra layer)
    iso_box(draw, cx, cy-h, ex+2, ey+1, nx, ny, 4,
            lighten(C_WARD_TOP, 0.12), C_WARD_SIDE, do_ol=False)

def _wardrobe_EW(draw, cx, cy):
    ex, ey = 18, 9
    nx, ny = 0, -50
    h = 56
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_WARD_TOP, C_WARD_SIDE)
    iso_box(draw, cx, cy-h, ex+2, ey+1, nx, ny, 4,
            lighten(C_WARD_TOP, 0.12), C_WARD_SIDE, do_ol=False)

print("Generating wardrobe_sheet.png...")
def wd_S(d): _wardrobe_NS(d, 62, 90)
def wd_N(d): _wardrobe_NS(d, 62, 90)
def wd_E(d): _wardrobe_EW(d, 66, 82)
make_sheet("wardrobe_sheet.png", wd_S, wd_E, wd_N, mirror_fn(wd_E))


# ═══════════════════════════════════════════════════════════════════════════════
# DRESSER  (low chest of drawers, 3 drawers)
# ═══════════════════════════════════════════════════════════════════════════════

def _dresser_NS(draw, cx, cy):
    ex, ey = 46, 23
    nx, ny = 0, -20
    h = 34
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_WOOD_SOFT, C_WOOD_DARK)
    E, S, Su, Eu = r['E'], r['S'], r['Su'], r['Eu']
    # 3 drawer horizontal dividers on E face
    for t in [0.33, 0.66]:
        dy = int(S[1] * (1-t) + Su[1] * t)
        draw.line([(int(S[0]), dy), (int(Eu[0]), dy)],
                  fill=darken(C_WOOD_DARK, 0.15), width=1)
    # 3 knobs
    for t in [0.17, 0.50, 0.83]:
        kx = int((S[0]+Eu[0])/2)
        ky = int(S[1]*(1-t) + Su[1]*t)
        draw.ellipse([kx-2, ky-2, kx+2, ky+2], fill=rgb(0.70, 0.58, 0.34))

def _dresser_EW(draw, cx, cy):
    ex, ey = 22, 11
    nx, ny = 0, -44
    h = 34
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_WOOD_SOFT, C_WOOD_DARK)
    W, S, Su, Wu = r['W'], r['S'], r['Su'], r['Wu']
    for t in [0.33, 0.66]:
        dy = int(S[1]*(1-t)+Su[1]*t)
        draw.line([(int(W[0]),dy),(int(Su[0]),dy)], fill=darken(C_WOOD_DARK,0.15), width=1)

print("Generating dresser_sheet.png...")
def dr_S(d): _dresser_NS(d, 63, 84)
def dr_N(d): _dresser_NS(d, 63, 84)
def dr_E(d): _dresser_EW(d, 64, 80)
make_sheet("dresser_sheet.png", dr_S, dr_E, dr_N, mirror_fn(dr_E))


# ═══════════════════════════════════════════════════════════════════════════════
# MEDICINE CABINET  (small wall-hung cabinet, pharmacy)
# ═══════════════════════════════════════════════════════════════════════════════

def _med_cab_NS(draw, cx, cy):
    ex, ey = 34, 17
    nx, ny = 0, -18
    h = 28
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_MED_CAB, C_MED_DARK)
    E, S, Su, Eu = r['E'], r['S'], r['Su'], r['Eu']
    # Vertical centre seam (double door)
    mid_x = int((S[0]+Eu[0])/2)
    draw.line([(mid_x, int(S[1])),(mid_x, int(Su[1]))],
              fill=darken(C_MED_DARK, 0.10), width=1)
    # Cross (+) symbol  — medical icon
    face_cx = int((S[0] + Eu[0]) * 0.25 + 0.5)
    face_cy = int((S[1] + Su[1]) * 0.50)
    cross_col = rgb(0.60, 0.20, 0.20)
    draw.line([(face_cx-4, face_cy), (face_cx+4, face_cy)], fill=cross_col, width=2)
    draw.line([(face_cx, face_cy-4), (face_cx, face_cy+4)], fill=cross_col, width=2)

def _med_cab_EW(draw, cx, cy):
    ex, ey = 20, 10
    nx, ny = 0, -32
    h = 28
    iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_MED_CAB, C_MED_DARK)

print("Generating medicine_cabinet_sheet.png...")
def mc_S(d): _med_cab_NS(d, 64, 82)
def mc_N(d): _med_cab_NS(d, 64, 82)
def mc_E(d): _med_cab_EW(d, 64, 80)
make_sheet("medicine_cabinet_sheet.png", mc_S, mc_E, mc_N, mirror_fn(mc_E))


# ═══════════════════════════════════════════════════════════════════════════════
# FILING CABINET  (2-drawer metal cabinet, office)
# ═══════════════════════════════════════════════════════════════════════════════

def _filing_NS(draw, cx, cy):
    ex, ey = 32, 16
    nx, ny = 0, -24
    h = 34
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_FILING, darken(C_FILING, 0.15))
    E, S, Su, Eu = r['E'], r['S'], r['Su'], r['Eu']
    # 2 drawer dividers
    mid_y = int((S[1] + Su[1]) / 2)
    draw.line([(int(S[0]), mid_y), (int(Eu[0]), mid_y)],
              fill=darken(C_METAL, 0.20), width=1)
    # 2 drawer pulls (horizontal bars)
    for t in [0.25, 0.75]:
        ky = int(S[1]*(1-t)+Su[1]*t)
        kx_l = int(S[0]*0.7+Eu[0]*0.3) - 3
        kx_r = int(S[0]*0.3+Eu[0]*0.7) + 3
        draw.rectangle([kx_l, ky-2, kx_r, ky+2], fill=C_METAL_LT)
    # Label slot (thin rectangle) on each drawer
    for t in [0.20, 0.70]:
        ky = int(S[1]*(1-t)+Su[1]*t)
        lx = int((S[0]+Eu[0])/2)
        draw.rectangle([lx-8, ky+3, lx+8, ky+7], fill=rgb(0.78, 0.78, 0.74))

def _filing_EW(draw, cx, cy):
    ex, ey = 24, 12
    nx, ny = 0, -30
    h = 34
    iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_FILING, darken(C_FILING, 0.15))

print("Generating filing_cabinet_sheet.png...")
def fc_S(d): _filing_NS(d, 64, 82)
def fc_N(d): _filing_NS(d, 64, 82)
def fc_E(d): _filing_EW(d, 64, 80)
make_sheet("filing_cabinet_sheet.png", fc_S, fc_E, fc_N, mirror_fn(fc_E))


# ═══════════════════════════════════════════════════════════════════════════════
# LOCKER  (tall metal locker, warehouse / storage)
# ═══════════════════════════════════════════════════════════════════════════════

def _locker_NS(draw, cx, cy):
    ex, ey = 30, 15
    nx, ny = 0, -18
    h = 64
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_LOCKER_G, C_LOCKER_DK)
    E, S, Su, Eu = r['E'], r['S'], r['Su'], r['Eu']
    # Locker door seam (divide 2 lockers side by side)
    mid_x = int((S[0]+Eu[0])/2)
    draw.line([(mid_x,int(S[1])),(mid_x,int(Su[1]))],
              fill=darken(C_LOCKER_DK,0.15), width=1)
    # Ventilation slots (3 horizontal lines on each door)
    for door_t in [0.25, 0.75]:
        for slot_t in [0.15, 0.30, 0.45]:
            sx = int(S[0]*(1-door_t)+Eu[0]*door_t)
            sy = int(S[1]*(1-slot_t)+Su[1]*slot_t)
            draw.line([(sx-8, sy),(sx+8, sy)],
                      fill=darken(C_LOCKER_DK,0.25), width=1)
    # Handles
    for door_t in [0.25, 0.75]:
        hx = int(S[0]*(1-door_t)+Eu[0]*door_t)
        hy = int(S[1]*0.45+Su[1]*0.55)
        draw.ellipse([hx-2,hy-3,hx+2,hy+3], fill=C_METAL_LT)
    # Ventilation gap at bottom
    iso_box(draw, cx, cy, ex-2, ey-1, nx, ny, 4,
            darken(C_LOCKER_G, 0.20), darken(C_LOCKER_DK, 0.20), do_ol=False)

def _locker_EW(draw, cx, cy):
    ex, ey = 20, 10
    nx, ny = 0, -28
    h = 64
    r = iso_box(draw, cx, cy, ex, ey, nx, ny, h, C_LOCKER_G, C_LOCKER_DK)
    W, S, Su, Wu = r['W'], r['S'], r['Su'], r['Wu']
    # Ventilation slots on W face
    for slot_t in [0.15, 0.30, 0.45]:
        sy = int(S[1]*(1-slot_t)+Su[1]*slot_t)
        draw.line([(int(W[0]),sy),(int(Su[0]),sy)],
                  fill=darken(C_LOCKER_DK,0.25), width=1)

print("Generating locker_sheet.png...")
def lk_S(d): _locker_NS(d, 64, 88)
def lk_N(d): _locker_NS(d, 64, 88)
def lk_E(d): _locker_EW(d, 65, 84)
make_sheet("locker_sheet.png", lk_S, lk_E, lk_N, mirror_fn(lk_E))

print("\nBatch 2 complete.")
