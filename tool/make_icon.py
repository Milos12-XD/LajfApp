"""Generate the flat LajfApp launcher icon and Android density variants."""

from pathlib import Path
import math
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024
SCALE = 2
BG = "#10151f"


def point(x, y):
    return round(x * SCALE), round(y * SCALE)


def bezier(start, c1, c2, end, steps=24):
    points = []
    for n in range(steps + 1):
        t = n / steps
        u = 1 - t
        x = u**3 * start[0] + 3 * u**2 * t * c1[0] + 3 * u * t**2 * c2[0] + t**3 * end[0]
        y = u**3 * start[1] + 3 * u**2 * t * c1[1] + 3 * u * t**2 * c2[1] + t**3 * end[1]
        points.append(point(x, y))
    return points


def rounded_arc(draw, radius, start, end, color, thickness):
    outer = radius + thickness / 2
    box = (point(512 - outer, 512 - outer), point(512 + outer, 512 + outer))
    draw.arc(box, start=start, end=end, fill=color, width=thickness * SCALE)
    for angle in (start, end):
        radians = math.radians(angle)
        x = 512 + radius * math.cos(radians)
        y = 512 + radius * math.sin(radians)
        half = thickness / 2
        draw.ellipse((point(x - half, y - half), point(x + half, y + half)), fill=color)


def main():
    image = Image.new("RGB", (SIZE * SCALE, SIZE * SCALE), BG)
    draw = ImageDraw.Draw(image)
    # Equal-width arcs have different lengths and partially cover one another.
    rounded_arc(draw, 346, 215, 475, "#9ef0c0", 56)
    rounded_arc(draw, 316, 325, 520, "#b7a7ff", 56)
    rounded_arc(draw, 286, 120, 285, "#ffbd82", 56)

    # A small stem and leaf keep the apple legible at launcher-icon sizes.
    draw.line([point(511, 420), point(534, 344)], fill="#8b684f", width=20 * SCALE)
    leaf = []
    leaf += bezier((530, 366), (552, 317), (609, 308), (622, 320))
    leaf += bezier((622, 320), (594, 364), (555, 385), (530, 366))
    draw.polygon(leaf, fill="#73c892")

    apple = []
    apple += bezier((510, 420), (463, 384), (398, 389), (371, 440))
    apple += bezier((371, 440), (335, 503), (369, 602), (430, 642))
    apple += bezier((430, 642), (463, 664), (490, 642), (510, 652))
    apple += bezier((510, 652), (540, 642), (561, 666), (594, 642))
    apple += bezier((594, 642), (665, 589), (678, 484), (640, 438))
    apple += bezier((640, 438), (607, 392), (550, 385), (510, 420))
    draw.polygon(apple, fill="#ed5a61")
    draw.ellipse((point(402, 435), point(445, 476)), fill="#f8787d")

    image = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    asset = ROOT / "assets" / "icon"
    asset.mkdir(parents=True, exist_ok=True)
    image.save(asset / "lajf_icon.png", optimize=True)
    density_sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for density, size in density_sizes.items():
        image.resize((size, size), Image.Resampling.LANCZOS).save(
            res / f"mipmap-{density}" / "ic_launcher.png", optimize=True
        )


if __name__ == "__main__":
    main()
