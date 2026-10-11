"""Generates this app's logo and launcher-icon artwork.

Run from the project root (needs `pip install pillow numpy`):

    python tool/generate_logo.py

Writes into assets/images/:
    logo.png                 512 x 512  rounded-square logo (README + in-app)
    launcher_icon.png        1024 x 1024  full-bleed icon (iOS / legacy Android)
    launcher_foreground.png  1024 x 1024  transparent glyph (Android adaptive icon)
    launcher_background.png  1024 x 1024  background (Android adaptive icon)

Then regenerate the platform icons with:

    dart run flutter_launcher_icons

Artwork is drawn at 2x and scaled down, so edges are smooth. Coordinates in
the drawing code use a 1024 x 1024 design space.
"""
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

DESIGN = 1024          # design-space size
K = 2                  # supersampling factor
S = DESIGN * K         # working canvas size
OUT_DIR = os.path.join("assets", "images")


def P(points):
    """Design-space points -> working-canvas points."""
    return [(x * K, y * K) for x, y in points]


def lin_gradient(c1, c2, angle=45, size=S):
    """Linear gradient from c1 to c2. angle 45 = top-left to bottom-right."""
    a = math.radians(angle)
    ys, xs = np.mgrid[0:size, 0:size]
    dx, dy = math.cos(a), math.sin(a)
    half = size / 2
    t = ((xs - half) * dx + (ys - half) * dy) / (abs(half * dx) + abs(half * dy))
    t = np.clip(t * 0.5 + 0.5, 0, 1)[..., None]
    c1 = np.array(c1[:3], dtype=float)
    c2 = np.array(c2[:3], dtype=float)
    rgb = c1 * (1 - t) + c2 * t
    out = np.dstack([rgb, np.full((size, size, 1), 255.0)])
    return Image.fromarray(out.astype("uint8"), "RGBA")


def radial_glow(center, radius, color, strength=0.35):
    """Soft circular highlight (RGBA layer)."""
    ys, xs = np.mgrid[0:S, 0:S]
    cx, cy = center[0] * K, center[1] * K
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / (radius * K)
    a = np.clip(1 - d, 0, 1) ** 2 * strength * 255
    out = np.zeros((S, S, 4), dtype="uint8")
    out[..., 0], out[..., 1], out[..., 2] = color[:3]
    out[..., 3] = a.astype("uint8")
    return Image.fromarray(out, "RGBA")


def blank():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def mask_from(draw_fn):
    """Build an 'L' mask by drawing white shapes with draw_fn(ImageDraw)."""
    m = Image.new("L", (S, S), 0)
    draw_fn(ImageDraw.Draw(m))
    return m


def paint(canvas, mask, fill, opacity=1.0):
    """Composite `fill` (RGBA tuple or image) onto canvas through `mask`.

    The mask only drives the alpha channel, so colours are never darkened by
    partial transparency.
    """
    if isinstance(fill, tuple):
        src = Image.new("RGBA", (S, S), fill if len(fill) == 4 else fill + (255,))
    else:
        src = fill.copy()
    if opacity < 1.0:
        mask = mask.point(lambda v: int(v * opacity))
    src.putalpha(ImageChops.multiply(src.getchannel("A"), mask))
    canvas.alpha_composite(src)


def drop_shadow(canvas, mask, offset=(0, 18), blur=26, opacity=0.35, color=(0, 0, 0)):
    shadow = mask.filter(ImageFilter.GaussianBlur(blur * K))
    shadow = ImageChops.offset(shadow, offset[0] * K, offset[1] * K)
    paint(canvas, shadow, color, opacity)


def rounded_rect(draw, box, radius, fill=255):
    x0, y0, x1, y1 = box
    draw.rounded_rectangle([x0 * K, y0 * K, x1 * K, y1 * K], radius * K, fill=fill)


def ellipse(draw, cx, cy, rx, ry=None, fill=255):
    ry = rx if ry is None else ry
    draw.ellipse([(cx - rx) * K, (cy - ry) * K, (cx + rx) * K, (cy + ry) * K], fill=fill)


def polygon(draw, pts, fill=255):
    draw.polygon(P(pts), fill=fill)


def thick_line(draw, pts, width, fill=255):
    """Smooth stroke with round caps and joins (dots stamped along the path)."""
    pts = P(pts)
    r = width * K / 2
    step = max(r / 4, 1.0)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(int(math.hypot(x1 - x0, y1 - y0) / step), 1)
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            y = y0 + (y1 - y0) * i / n
            draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def bezier(p0, p1, p2, n=48):
    out = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1]
        out.append((x, y))
    return out


def scale_points(pts, k, cx=512, cy=512):
    return [(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in pts]


def rotate_mask(mask, degrees, center=(512, 512)):
    """Rotate clockwise by `degrees` about a design-space point."""
    return mask.rotate(-degrees, center=(center[0] * K, center[1] * K), resample=Image.BICUBIC)


def hex_color(value):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def vertical_fill(c_top, c_bottom, y_top, y_bottom):
    """A fill image fading from c_top to c_bottom between two design y values."""
    ys = np.arange(S)[:, None]
    t = np.clip((ys - y_top * K) / ((y_bottom - y_top) * K), 0, 1)
    t = np.repeat(t, S, axis=1)[..., None]
    rgb = np.array(c_top[:3], dtype=float) * (1 - t) + np.array(c_bottom[:3], dtype=float) * t
    out = np.dstack([rgb, np.full((S, S, 1), 255.0)])
    return Image.fromarray(out.astype("uint8"), "RGBA")


def scale_canvas(img, k):
    """Zoom artwork about the centre (k > 1 enlarges, k < 1 shrinks)."""
    if k == 1:
        return img
    c = S / 2
    inv = 1 / k
    return img.transform(
        img.size, Image.AFFINE, (inv, 0, c * (1 - inv), 0, inv, c * (1 - inv)), resample=Image.BICUBIC
    )


def to_size(img, px):
    return img.resize((px, px), Image.LANCZOS)


def rounded_corners(img, radius_fraction=0.225):
    """Apply rounded-square transparency (like a store icon)."""
    px = img.size[0]
    mask = Image.new("L", (px * 4, px * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, px * 4 - 1, px * 4 - 1], radius=int(px * 4 * radius_fraction), fill=255
    )
    mask = mask.resize((px, px), Image.LANCZOS)
    out = img.copy()
    out.putalpha(ImageChops.multiply(out.getchannel("A"), mask))
    return out


def build_all():
    os.makedirs(OUT_DIR, exist_ok=True)
    background = draw_background()          # noqa: F821 (defined by the design)
    glyph = draw_glyph()                    # noqa: F821

    # Glyph is drawn inside the adaptive-icon safe zone; the full-bleed icon
    # can show it a little larger.
    full = background.copy()
    full.alpha_composite(scale_canvas(glyph, ICON_SCALE))  # noqa: F821

    to_size(full, 1024).convert("RGB").save(os.path.join(OUT_DIR, "launcher_icon.png"))
    to_size(background, 1024).convert("RGB").save(os.path.join(OUT_DIR, "launcher_background.png"))
    to_size(glyph, 1024).save(os.path.join(OUT_DIR, "launcher_foreground.png"))
    rounded_corners(to_size(full, 512)).save(os.path.join(OUT_DIR, "logo.png"))
    print("Wrote logo.png (512), launcher_icon.png, launcher_foreground.png, launcher_background.png")

# ---------------------------------------------------------------------------
# CredVault: a gold shield with a keyhole on midnight navy.
# ---------------------------------------------------------------------------
ICON_SCALE = 1.18
ADAPTIVE_BACKGROUND = "#101E44"
BG_TOP = (8, 14, 36)
BG_BOTTOM = (28, 54, 112)


def draw_background():
    bg = lin_gradient(BG_TOP, BG_BOTTOM, angle=60)
    bg.alpha_composite(radial_glow((512, 470), 520, (90, 140, 255), 0.30))
    return bg


def _shield_points(scale=1.0):
    cx, cy = 512, 520
    right = [(512, 232)]
    right += bezier((512, 232), (610, 262), (716, 262), 20)[1:]   # shoulder
    right += [(716, 520)]
    right += bezier((716, 520), (716, 700), (512, 806), 60)[1:]   # side down to the tip
    left = [(1024 - x, y) for x, y in reversed(right)][1:]
    return scale_points(right + left, scale, cx, cy)


def draw_glyph():
    g = blank()
    outer = mask_from(lambda d: polygon(d, _shield_points(1.0)))
    inner = mask_from(lambda d: polygon(d, _shield_points(0.86)))

    drop_shadow(g, outer, offset=(0, 28), blur=34, opacity=0.5, color=(0, 0, 20))
    # Light gold rim, darker gold face.
    paint(g, outer, vertical_fill((255, 236, 160), (234, 176, 52), 232, 806))
    paint(g, inner, vertical_fill((246, 202, 86), (196, 134, 24), 232, 806))

    # Subtle sheen on the left half of the face.
    sheen = mask_from(lambda d: polygon(d, [(512, 262), (512, 770), (330, 640), (330, 300)]))
    paint(g, ImageChops.multiply(sheen, inner), (255, 255, 255), 0.10)

    # Keyhole cut-out in navy.
    navy = (13, 24, 58)
    hole = mask_from(
        lambda d: (
            ellipse(d, 512, 492, 64),
            polygon(d, [(486, 530), (538, 530), (566, 660), (458, 660)]),
        )
    )
    paint(g, hole, navy)
    # Little glint inside the keyhole.
    glint = mask_from(lambda d: ellipse(d, 492, 474, 14))
    paint(g, glint, (120, 160, 255), 0.5)
    return g


if __name__ == "__main__":
    build_all()
