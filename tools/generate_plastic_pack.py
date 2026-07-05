#!/usr/bin/env python3
"""Generate the "PlasticPack" texture pack for Voxelcraft.

Simplistic molded-plastic / toy style: 16x16 RGBA PNGs, hard pixels, 2-3
colors per tile derived from one base color (highlight = lightened, shadow =
darkened), a consistent plastic bevel (light top/left, dark bottom/right, a
small gloss dot) that also makes block edges read as distinct tiles.

Idempotent: re-running overwrites the same files. Output goes to
  <project>/resource_packs/PlasticPack/
which is the res:// bundled search path, so it's selectable in
  Settings -> Resource pack -> PlasticPack.

The authoritative filename list mirrors BlockTypes.tile_names()
(blocks/block_types.gd). Only files in that list are generated.

Run:  python3 tools/generate_plastic_pack.py
"""

import os
from PIL import Image

SIZE = 16
TRANSPARENT = (0, 0, 0, 0)

# --- PALETTE (tweak here) ---------------------------------------------------
# One base RGB per material. Highlights/shadows are derived, never stored.
PALETTE = {
    "grass":        (96, 168, 72),
    "dirt":         (134, 96, 67),
    "stone":        (128, 128, 132),
    "sand":         (226, 214, 160),
    "wood":         (178, 140, 88),    # planks + log side
    "log_top":      (198, 164, 112),   # lighter, with ring hint
    "leaves":       (70, 140, 70),
    "water":        (70, 120, 210),
    "bedrock":      (46, 46, 52),
    "cobble":       (120, 120, 124),
    "wool":         (238, 238, 238),
    "bed":          (190, 54, 54),
    "craft":        (170, 128, 78),
    "furnace":      (98, 98, 104),
    "glass":        (182, 216, 236),
    # items / materials
    "stick":        (150, 108, 60),
    "coal":         (42, 42, 46),
    "iron":         (212, 212, 216),
    "gold":         (240, 200, 60),
    "diamond":      (104, 224, 220),
    "gloom":        (150, 80, 190),
    "mutton_raw":   (224, 132, 150),
    "mutton_cooked": (150, 96, 58),
    "bone":         (236, 232, 214),
}

# Ore stud colors (the mineral fleck on a stone base).
ORE_STUD = {
    "coal_ore":    PALETTE["coal"],
    "iron_ore":    (208, 176, 138),  # beige
    "gold_ore":    PALETTE["gold"],
    "diamond_ore": PALETTE["diamond"],
}

# Tier -> accent color (tool heads); armor material -> color.
TIER_COLOR = {
    "wooden":  PALETTE["wood"],
    "stone":   PALETTE["stone"],
    "iron":    PALETTE["iron"],
    "golden":  PALETTE["gold"],
    "diamond": PALETTE["diamond"],
}
MATERIAL_COLOR = {
    "iron":    PALETTE["iron"],
    "golden":  PALETTE["gold"],
    "diamond": PALETTE["diamond"],
}

# Authoritative name sets (must match BlockTypes.tile_names()).
TIERS = ["wooden", "stone", "iron", "golden", "diamond"]
TOOL_CLASSES = ["pickaxe", "axe", "shovel", "sword"]
ARMOR_MATERIALS = ["iron", "golden", "diamond"]
ARMOR_PIECES = ["helmet", "chestplate", "leggings", "boots"]


# --- Color helpers ----------------------------------------------------------

def lighten(c, amt):
    return tuple(min(255, int(v + (255 - v) * amt)) for v in c[:3])


def darken(c, amt):
    return tuple(max(0, int(v * (1 - amt))) for v in c[:3])


def new_tile():
    return Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)


def put(img, x, y, rgb, a=255):
    if 0 <= x < SIZE and 0 <= y < SIZE:
        img.putpixel((x, y), (rgb[0], rgb[1], rgb[2], a))


def fill_rect(img, x0, y0, x1, y1, rgb, a=255):
    for y in range(max(0, y0), min(SIZE, y1 + 1)):
        for x in range(max(0, x0), min(SIZE, x1 + 1)):
            img.putpixel((x, y), (rgb[0], rgb[1], rgb[2], a))


# THE bevel: fill a rectangle in base, light the top/left edges, shade the
# bottom/right edges, and drop a 2x2 gloss dot near the top-left. Used for
# every tile so the whole pack shares one "plastic" light direction.
def bevel_rect(img, x0, y0, x1, y1, base, a=255, gloss=True):
    hi = lighten(base, 0.38)
    sh = darken(base, 0.32)
    fill_rect(img, x0, y0, x1, y1, base, a)
    for x in range(x0, x1 + 1):
        put(img, x, y0, hi, a)       # top edge
        put(img, x, y1, sh, a)       # bottom edge
    for y in range(y0, y1 + 1):
        put(img, x0, y, hi, a)       # left edge
        put(img, x1, y, sh, a)       # right edge
    # keep the shaded corner readable
    put(img, x1, y1, sh, a)
    if gloss and (x1 - x0) >= 4 and (y1 - y0) >= 4 and a >= 200:
        g = lighten(base, 0.6)
        put(img, x0 + 1, y0 + 1, g, a)
        put(img, x0 + 2, y0 + 1, g, a)
        put(img, x0 + 1, y0 + 2, g, a)


def thick_diag(img, x0, y0, x1, y1, rgb, a=255, thick=2):
    """Beveled-ish thick diagonal (Bresenham) for handles/blades/shards."""
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    x, y = x0, y0
    hi = lighten(rgb, 0.35)
    sh = darken(rgb, 0.3)
    while True:
        for t in range(thick):
            put(img, x + t, y, rgb, a)
        put(img, x, y - 1, hi, a)          # highlight on the upper side
        put(img, x + thick - 1, y + 1, sh, a)  # shadow on the lower side
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy


# --- Block builders ---------------------------------------------------------

def block(base):
    img = new_tile()
    bevel_rect(img, 0, 0, 15, 15, base)
    return img


def grass_top():
    img = block(PALETTE["grass"])
    # a couple of darker blades for a hint of texture (still 3 colors total)
    sh = darken(PALETTE["grass"], 0.22)
    for (x, y) in [(4, 6), (9, 4), (11, 10), (6, 11)]:
        put(img, x, y, sh)
    return img


def grass_side():
    img = block(PALETTE["dirt"])
    # green turf cap with its own bevel on the top strip
    bevel_rect(img, 0, 0, 15, 4, PALETTE["grass"], gloss=False)
    sh = darken(PALETTE["grass"], 0.3)
    for x in range(0, 16, 2):  # ragged bottom of the turf
        put(img, x, 5, sh)
    return img


def planks():
    img = block(PALETTE["wood"])
    sh = darken(PALETTE["wood"], 0.3)
    for x in range(1, 15):
        put(img, x, 7, sh)          # plank seam
    for y in [3, 11]:               # short vertical seams, offset per row
        put(img, 8 if y == 3 else 5, y, sh)
    return img


def log_side():
    img = block(PALETTE["wood"])
    sh = darken(PALETTE["wood"], 0.28)
    for x in [3, 8, 12]:            # vertical bark grooves
        for y in range(1, 15):
            put(img, x, y, sh)
    return img


def log_top():
    img = block(PALETTE["log_top"])
    sh = darken(PALETTE["log_top"], 0.28)
    # concentric ring hint (two square outlines)
    for x in range(4, 12):
        put(img, x, 4, sh); put(img, x, 11, sh)
    for y in range(4, 12):
        put(img, 4, y, sh); put(img, 11, y, sh)
    put(img, 8, 8, sh)              # core
    return img


def leaves():
    img = block(PALETTE["leaves"])
    sh = darken(PALETTE["leaves"], 0.28)
    for (x, y) in [(3, 5), (7, 3), (11, 6), (5, 10), (10, 11), (13, 9)]:
        put(img, x, y, sh)          # little gaps
    return img


def water():
    img = new_tile()
    bevel_rect(img, 0, 0, 15, 15, PALETTE["water"], a=150, gloss=False)
    hi = lighten(PALETTE["water"], 0.4)
    for x in range(2, 8):           # a gentle wave glint
        put(img, x, 4, hi, 170)
    return img


def cobblestone():
    img = block(PALETTE["cobble"])
    sh = darken(PALETTE["cobble"], 0.3)
    for (x, y) in [(3, 3), (10, 4), (5, 9), (11, 10)]:   # darker cobble studs
        fill_rect(img, x, y, x + 1, y + 1, sh)
    return img


def metal_block(base):
    img = block(base)
    inner = darken(base, 0.22)      # inset frame -> "solid block" look
    for x in range(3, 13):
        put(img, x, 3, inner); put(img, x, 12, inner)
    for y in range(3, 13):
        put(img, 3, y, inner); put(img, 12, y, inner)
    return img


def furnace_top():
    img = block(PALETTE["furnace"])
    dark = darken(PALETTE["furnace"], 0.45)
    fill_rect(img, 5, 5, 10, 10, dark)   # central vent
    return img


def furnace_front():
    img = block(PALETTE["furnace"])
    fill_rect(img, 4, 8, 11, 13, darken(PALETTE["furnace"], 0.7))  # opening
    for x in range(5, 11):               # ember line
        put(img, x, 12, (232, 122, 32))
    put(img, 6, 11, (245, 170, 60)); put(img, 9, 11, (245, 170, 60))
    return img


def bed_top():
    img = block(PALETTE["bed"])
    bevel_rect(img, 2, 1, 13, 5, PALETTE["wool"], gloss=False)   # pillow
    return img


def bed_side():
    img = new_tile()
    bevel_rect(img, 0, 6, 15, 15, PALETTE["wood"], gloss=False)  # frame
    bevel_rect(img, 0, 0, 15, 6, PALETTE["bed"], gloss=False)    # blanket
    fill_rect(img, 1, 13, 2, 15, darken(PALETTE["wood"], 0.4))   # leg
    fill_rect(img, 13, 13, 14, 15, darken(PALETTE["wood"], 0.4))
    return img


def crafting_top():
    img = block(PALETTE["craft"])
    sh = darken(PALETTE["craft"], 0.4)
    for x in range(1, 15):          # 2x2 worktop grid
        put(img, x, 8, sh)
    for y in range(1, 15):
        put(img, 8, y, sh)
    return img


def crafting_side():
    img = block(PALETTE["craft"])
    sh = darken(PALETTE["craft"], 0.4)
    fill_rect(img, 4, 5, 6, 10, sh)     # "saw" mark
    fill_rect(img, 9, 4, 10, 11, sh)    # "hammer" mark
    return img


def glass():
    img = new_tile()
    fill_rect(img, 1, 1, 14, 14, PALETTE["glass"], a=90)         # pane
    frame = lighten(PALETTE["glass"], 0.25)
    for i in range(16):                                          # solid frame
        put(img, i, 0, frame); put(img, i, 15, frame)
        put(img, 0, i, frame); put(img, 15, i, frame)
    for i in range(3, 8):                                        # gloss streak
        put(img, i, i + 1, lighten(PALETTE["glass"], 0.5), 150)
    return img


def ore(stud):
    img = block(PALETTE["stone"])
    for (x, y) in [(3, 3), (10, 4), (5, 10), (11, 11), (7, 7)]:  # 2x2 studs
        bevel_rect(img, x, y, x + 1, y + 1, stud, gloss=False)
    return img


# --- Item builders (transparent background, centered silhouette) -----------

def stick():
    img = new_tile()
    thick_diag(img, 4, 12, 11, 4, PALETTE["stick"], thick=2)
    return img


def blob(base, x0, y0, x1, y1):
    img = new_tile()
    bevel_rect(img, x0, y0, x1, y1, base)
    # trim the four corners so it reads rounded
    for (cx, cy) in [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]:
        img.putpixel((cx, cy), TRANSPARENT)
    return img


def ingot(base):
    img = new_tile()
    bevel_rect(img, 3, 4, 12, 6, base, gloss=False)   # top bar
    bevel_rect(img, 3, 9, 12, 11, base, gloss=False)  # bottom bar
    return img


def diamond_gem(base):
    img = new_tile()
    # rhombus by rows: half-width per row centered on x=8
    spans = [(8, 8), (7, 9), (6, 10), (5, 11), (6, 10), (7, 9), (8, 8)]
    hi = lighten(base, 0.4)
    sh = darken(base, 0.3)
    for i, (a, b) in enumerate(spans):
        y = 3 + i
        for x in range(a, b + 1):
            img.putpixel((x, y), (base[0], base[1], base[2], 255))
        put(img, a, y, hi)      # left facet light
        put(img, b, y, sh)      # right facet shade
    return img


def gloom_shard():
    img = new_tile()
    thick_diag(img, 4, 13, 12, 3, PALETTE["gloom"], thick=2)
    thick_diag(img, 7, 11, 10, 6, lighten(PALETTE["gloom"], 0.4), thick=1)
    return img


def mutton(base):
    img = blob(base, 3, 6, 11, 13)      # meaty chop
    bevel_rect(img, 11, 3, 13, 5, PALETTE["bone"], gloss=False)  # bone knob
    return img


def stairs_icon(base):
    img = new_tile()
    bevel_rect(img, 2, 8, 13, 13, base, gloss=False)   # bottom step
    bevel_rect(img, 8, 3, 13, 8, base, gloss=False)    # upper step
    return img


# --- Tools ------------------------------------------------------------------

def tool(tier_color, cls):
    img = new_tile()
    handle = PALETTE["stick"]
    if cls == "sword":
        thick_diag(img, 6, 9, 12, 3, tier_color, thick=2)   # blade
        bevel_rect(img, 3, 9, 7, 10, handle, gloss=False)   # guard
        thick_diag(img, 3, 12, 6, 9, handle, thick=2)       # grip
        put(img, 2, 13, darken(handle, 0.2))                # pommel
        return img

    # pick / axe / shovel share a diagonal handle + a tier-colored head
    thick_diag(img, 4, 12, 9, 6, handle, thick=2)
    if cls == "pickaxe":
        bevel_rect(img, 3, 2, 12, 3, tier_color, gloss=False)   # cross bar
        bevel_rect(img, 3, 4, 4, 5, tier_color, gloss=False)    # tips
        bevel_rect(img, 11, 4, 12, 5, tier_color, gloss=False)
    elif cls == "axe":
        bevel_rect(img, 8, 1, 12, 6, tier_color, gloss=False)   # blade block
    elif cls == "shovel":
        bevel_rect(img, 8, 1, 11, 4, tier_color, gloss=False)   # spade
        bevel_rect(img, 9, 4, 10, 6, tier_color, gloss=False)   # neck
    return img


# --- Armor ------------------------------------------------------------------

def armor(mat_color, piece):
    img = new_tile()
    if piece == "helmet":
        bevel_rect(img, 4, 4, 11, 7, mat_color, gloss=False)    # dome
        bevel_rect(img, 4, 8, 5, 10, mat_color, gloss=False)    # cheeks
        bevel_rect(img, 10, 8, 11, 10, mat_color, gloss=False)
    elif piece == "chestplate":
        bevel_rect(img, 3, 3, 5, 5, mat_color, gloss=False)     # shoulders
        bevel_rect(img, 10, 3, 12, 5, mat_color, gloss=False)
        bevel_rect(img, 5, 5, 10, 12, mat_color, gloss=False)   # torso
    elif piece == "leggings":
        bevel_rect(img, 4, 3, 11, 5, mat_color, gloss=False)    # belt
        bevel_rect(img, 4, 6, 6, 13, mat_color, gloss=False)    # legs
        bevel_rect(img, 9, 6, 11, 13, mat_color, gloss=False)
    elif piece == "boots":
        bevel_rect(img, 3, 7, 6, 12, mat_color, gloss=False)    # left boot
        bevel_rect(img, 3, 11, 7, 12, darken(mat_color, 0.2), gloss=False)  # sole
        bevel_rect(img, 9, 7, 12, 12, mat_color, gloss=False)   # right boot
        bevel_rect(img, 9, 11, 13, 12, darken(mat_color, 0.2), gloss=False)
    return img


# --- Registry: filename -> zero-arg builder --------------------------------

def build_registry():
    reg = {
        # simple full-bevel blocks
        "dirt": lambda: block(PALETTE["dirt"]),
        "stone": lambda: block(PALETTE["stone"]),
        "sand": lambda: block(PALETTE["sand"]),
        "planks": planks,
        "log_side": log_side,
        "log_top": log_top,
        "leaves": leaves,
        "water": water,
        "bedrock": lambda: block(PALETTE["bedrock"]),
        "cobblestone": cobblestone,
        "wool": lambda: block(PALETTE["wool"]),
        "grass_top": grass_top,
        "grass_side": grass_side,
        # ores
        "coal_ore": lambda: ore(ORE_STUD["coal_ore"]),
        "iron_ore": lambda: ore(ORE_STUD["iron_ore"]),
        "gold_ore": lambda: ore(ORE_STUD["gold_ore"]),
        "diamond_ore": lambda: ore(ORE_STUD["diamond_ore"]),
        # mineral blocks
        "iron_block": lambda: metal_block(PALETTE["iron"]),
        "gold_block": lambda: metal_block(PALETTE["gold"]),
        "diamond_block": lambda: metal_block(PALETTE["diamond"]),
        # machines / furniture
        "furnace_top": furnace_top,
        "furnace_front": furnace_front,
        "bed_top": bed_top,
        "bed_side": bed_side,
        "crafting_table_top": crafting_top,
        "crafting_table_side": crafting_side,
        "glass": glass,
        # items
        "stick": stick,
        "coal": lambda: blob(PALETTE["coal"], 4, 4, 11, 11),
        "iron_ingot": lambda: ingot(PALETTE["iron"]),
        "gold_ingot": lambda: ingot(PALETTE["gold"]),
        "diamond": lambda: diamond_gem(PALETTE["diamond"]),
        "gloom_shard": gloom_shard,
        "mutton_raw": lambda: mutton(PALETTE["mutton_raw"]),
        "mutton_cooked": lambda: mutton(PALETTE["mutton_cooked"]),
        "plank_stairs_icon": lambda: stairs_icon(PALETTE["wood"]),
        "cobblestone_stairs_icon": lambda: stairs_icon(PALETTE["cobble"]),
    }
    # tools: <tier>_<class>
    for tier in TIERS:
        for cls in TOOL_CLASSES:
            reg["%s_%s" % (tier, cls)] = (
                lambda tc=TIER_COLOR[tier], c=cls: tool(tc, c)
            )
    # armor: <material>_<piece>
    for mat in ARMOR_MATERIALS:
        for piece in ARMOR_PIECES:
            reg["%s_%s" % (mat, piece)] = (
                lambda mc=MATERIAL_COLOR[mat], p=piece: armor(mc, p)
            )
    return reg


def authoritative_names():
    """The exact set BlockTypes.tile_names() produces."""
    named = [
        "grass_top", "grass_side", "dirt", "stone", "sand", "log_side",
        "log_top", "leaves", "water", "bedrock", "cobblestone", "planks",
        "coal_ore", "iron_ore", "gold_ore", "diamond_ore", "furnace_front",
        "furnace_top", "iron_block", "gold_block", "diamond_block", "stick",
        "coal", "iron_ingot", "gold_ingot", "diamond", "gloom_shard", "wool",
        "bed_top", "bed_side", "crafting_table_top", "crafting_table_side",
        "glass", "plank_stairs_icon", "cobblestone_stairs_icon", "mutton_raw",
        "mutton_cooked",
    ]
    tools = ["%s_%s" % (t, c) for c in TOOL_CLASSES for t in TIERS]
    armor_pieces = ["%s_%s" % (m, p) for p in ARMOR_PIECES for m in ARMOR_MATERIALS]
    return named + tools + armor_pieces


def main():
    project = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(project, "resource_packs", "PlasticPack")
    os.makedirs(out_dir, exist_ok=True)

    reg = build_registry()
    names = authoritative_names()

    generated, missing, extra = [], [], []
    for name in names:
        builder = reg.get(name)
        if builder is None:
            missing.append(name)
            continue
        builder().save(os.path.join(out_dir, name + ".png"))
        generated.append(name)
    for name in reg:
        if name not in names:
            extra.append(name)  # in registry but not in tile_names() -> skip

    # --- coverage report ---
    print("PlasticPack -> %s" % out_dir)
    print("=" * 52)
    for name in names:
        mark = "✓" if name in generated else "✗"
        print("  [%s] %s.png" % (mark, name))
    print("-" * 52)
    print("generated: %d / %d" % (len(generated), len(names)))
    if missing:
        print("MISSING (no builder): %s" % ", ".join(missing))
    else:
        print("MISSING: none ✓")
    if extra:
        print("registry entries not in tile_names() (not written): %s"
              % ", ".join(extra))


if __name__ == "__main__":
    main()
