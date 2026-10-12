#!/usr/bin/env python3
"""Builds the macOS app icon set from the Petit logo.

macOS (unlike iOS) does not mask icons, so the icon itself must be the familiar
rounded plate: an 824 px rounded square centred on a 1024 px canvas, with a soft
shadow. The logo is drawn on top of the plate.

    pip install pillow
    python3 packaging/macos/make_icon.py

Writes the PNGs listed in macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json.
(icons_launcher does not generate macOS icons here: it is disabled in icons_launcher.yaml.)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
LOGO = ROOT / "assets" / "images" / "app_logo.png"
OUT = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

CANVAS = 1024
PLATE = 824                     # Apple's macOS icon grid
MARGIN = (CANVAS - PLATE) // 2  # 100
RADIUS = 185                    # ~22.4% of the plate
LOGO_SCALE = 1.12               # how much the logo is enlarged inside the plate
SS = 4                          # supersampling for smooth edges

# Plate colours: a barely-there vertical gradient so it does not look flat.
TOP = (255, 255, 255)
BOTTOM = (242, 238, 248)

# File name -> pixel size, as referenced by Contents.json.
SIZES = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}


def rounded_mask(size: int, radius: int) -> Image.Image:
    big = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, size * SS - 1, size * SS - 1), radius=radius * SS, fill=255
    )
    return big.resize((size, size), Image.LANCZOS)


def gradient(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        colour = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
        for x in range(size):
            px[x, y] = colour
    return img


def extract_drawing(source: Image.Image) -> Image.Image:
    """The logo is a purple drawing on a white background (the file is not
    transparent). Turn it into the drawing alone: purple, with smooth edges."""
    flat = Image.new("RGBA", source.size, (255, 255, 255, 255))
    flat.alpha_composite(source.convert("RGBA"))
    rgb = flat.convert("RGB")

    # The centre of the logo is a filled square, which gives the ink colour.
    ink = rgb.getpixel((rgb.width // 2, rgb.height // 2))
    if ink[1] > 200:
        raise SystemExit("could not find the logo's ink colour at its centre")

    # How far each pixel is from white towards the ink (green has the most contrast).
    span = 255 - ink[1]
    alpha = rgb.getchannel("G").point(
        lambda v: max(0, min(255, round((255 - v) * 255 / span)))
    )
    drawing = Image.new("RGBA", source.size, ink + (255,))
    drawing.putalpha(alpha)
    return drawing


def build_master() -> Image.Image:
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    plate_mask = rounded_mask(PLATE, RADIUS)

    # Soft shadow under the plate.
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow_alpha = Image.new("L", (CANVAS, CANVAS), 0)
    shadow_alpha.paste(plate_mask.point(lambda v: v * 0.30), (MARGIN, MARGIN + 12))
    shadow_alpha = shadow_alpha.filter(ImageFilter.GaussianBlur(14))
    shadow.putalpha(shadow_alpha)
    canvas = Image.alpha_composite(canvas, shadow)

    # The plate.
    plate = gradient(PLATE).convert("RGBA")
    plate.putalpha(plate_mask)
    canvas.alpha_composite(plate, (MARGIN, MARGIN))

    # The logo's drawing, centred on the plate.
    logo = extract_drawing(Image.open(LOGO))
    box = logo.getchannel("A").getbbox()
    if box is None:
        raise SystemExit(f"nothing to draw in {LOGO}")
    logo = logo.crop(box)
    side = round(max(logo.size) * LOGO_SCALE)
    scale = side / max(logo.size)
    logo = logo.resize((round(logo.width * scale), round(logo.height * scale)), Image.LANCZOS)
    x = MARGIN + (PLATE - logo.width) // 2
    y = MARGIN + (PLATE - logo.height) // 2
    canvas.alpha_composite(logo, (x, y))
    return canvas


def main() -> None:
    master = build_master()
    for name, size in SIZES.items():
        image = master if size == CANVAS else master.resize((size, size), Image.LANCZOS)
        image.save(OUT / name, optimize=True)
        print(f"wrote {OUT / name} ({size}x{size})")


if __name__ == "__main__":
    main()
