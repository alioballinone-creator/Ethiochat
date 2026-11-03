#!/usr/bin/env python3
"""Regenerate Android launcher icons from the brand assets.

This is the reproducible equivalent of `flutter_launcher_icons` for this
project. It writes legacy, round and adaptive icon layers for every density.

Usage:
    python3 tool/generate_android_icons.py

Requires Pillow (`python3 -m pip install pillow`).
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets" / "brand"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

# Android launcher icon sizes in pixels.
DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

# Adaptive icon layers are 108dp; the inner 72dp is the safe zone.
ADAPTIVE_DENSITIES = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}


def resize(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.Resampling.LANCZOS)


def circular_icon(image: Image.Image) -> Image.Image:
    """Apply an antialiased circular mask to a square legacy icon."""
    size = image.width
    scale = 4
    mask = Image.new("L", (size * scale, size * scale), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size * scale - 1, size * scale - 1), fill=255)
    mask = mask.resize((size, size), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(image, (0, 0), mask)
    return out


def fit_safe_zone(image: Image.Image, canvas_size: int = 1024) -> Image.Image:
    """Center the visible foreground inside the 72/108 adaptive safe zone."""
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return image

    content = image.crop(bbox)
    target = canvas_size * 72 / 108
    factor = min(target / content.width, target / content.height, 1.0)
    content = content.resize(
        (
            max(1, round(content.width * factor)),
            max(1, round(content.height * factor)),
        ),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.alpha_composite(
        content,
        ((canvas_size - content.width) // 2, (canvas_size - content.height) // 2),
    )
    return canvas


def write_adaptive_xml(name: str) -> None:
    directory = RES / "mipmap-anydpi-v26"
    directory.mkdir(parents=True, exist_ok=True)
    xml = f"""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
"""
    (directory / name).write_text(xml, encoding="utf-8")


def main() -> None:
    legacy = Image.open(BRAND / "app-icon-1024.png").convert("RGBA")
    foreground = Image.open(BRAND / "adaptive-foreground.png").convert("RGBA")
    background = Image.open(BRAND / "adaptive-background.png").convert("RGBA")
    monochrome = Image.open(BRAND / "adaptive-monochrome.png").convert("RGBA")

    foreground = fit_safe_zone(foreground)
    monochrome = fit_safe_zone(monochrome)

    for density, size in DENSITIES.items():
        directory = RES / f"mipmap-{density}"
        directory.mkdir(parents=True, exist_ok=True)
        resize(legacy, size).save(directory / "ic_launcher.png", optimize=True)
        circular_icon(resize(legacy, size)).save(
            directory / "ic_launcher_round.png", optimize=True
        )

    for density, size in ADAPTIVE_DENSITIES.items():
        directory = RES / f"mipmap-{density}"
        directory.mkdir(parents=True, exist_ok=True)
        resize(foreground, size).save(
            directory / "ic_launcher_foreground.png", optimize=True
        )
        resize(background, size).save(
            directory / "ic_launcher_background.png", optimize=True
        )
        resize(monochrome, size).save(
            directory / "ic_launcher_monochrome.png", optimize=True
        )

    write_adaptive_xml("ic_launcher.xml")
    write_adaptive_xml("ic_launcher_round.xml")
    print("Regenerated Android launcher icons and adaptive layers.")


if __name__ == "__main__":
    main()
