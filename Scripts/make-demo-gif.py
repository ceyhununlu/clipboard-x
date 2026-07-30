#!/usr/bin/env python3
"""
Synthesize a README demo GIF of the ClipboardX popup.

Uses only fictional sample clipboard rows — no screen capture, no personal data.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 560
HEIGHT = 420
RADIUS = 18
HEADER_H = 40
FOOTER_H = 28
ROW_H = 54
MAX_ROWS = 5

BG = (28, 28, 30, 255)
PANEL = (44, 44, 46, 245)
SEPARATOR = (255, 255, 255, 28)
TEXT = (245, 245, 247, 255)
SECONDARY = (174, 174, 178, 255)
TERTIARY = (120, 120, 128, 255)
ACCENT = (10, 132, 255, 255)
ACCENT_TEXT = (255, 255, 255, 255)
SEARCH_BG = (58, 58, 60, 255)

# Fictional sample history — nothing personal.
ITEMS = [
    ("Meeting notes — Q3 roadmap draft", "2m · Plain text · 1.2 KB", "text"),
    ("https://example.com/docs/api", "5m · Plain text · 86 B", "link"),
    ("Image 640 × 360", "12m · 640 × 360 · 48 KB", "image"),
    ("export PATH=\"$HOME/bin:$PATH\"", "18m · Plain text · 32 B", "code"),
    ("Thanks — that fix worked perfectly.", "1h · Plain text · 34 B", "text"),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size, index=0)
        except OSError:
            continue
    return ImageFont.load_default()


FONT_TITLE = font(13)
FONT_SUB = font(11)
FONT_UI = font(12)
FONT_HINT = font(10)
FONT_SEARCH = font(13)


def round_rect(draw: ImageDraw.ImageDraw, box, radius: int, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_icon(draw: ImageDraw.ImageDraw, kind: str, box, selected: bool):
    x0, y0, x1, y1 = box
    bg = (255, 255, 255, 40) if selected else (120, 120, 128, 50)
    round_rect(draw, box, 6, bg)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    color = ACCENT_TEXT if selected else SECONDARY
    if kind == "image":
        draw.rectangle([cx - 8, cy - 6, cx + 8, cy + 6], outline=color, width=2)
        draw.ellipse([cx - 3, cy - 3, cx + 1, cy + 1], fill=color)
    elif kind == "link":
        draw.arc([cx - 7, cy - 5, cx - 1, cy + 5], 40, 320, fill=color, width=2)
        draw.arc([cx + 1, cy - 5, cx + 7, cy + 5], 220, 140, fill=color, width=2)
    elif kind == "code":
        draw.text((cx - 7, cy - 7), "</>", font=FONT_HINT, fill=color)
    else:
        draw.rectangle([cx - 6, cy - 7, cx + 6, cy + 7], outline=color, width=2)
        draw.line([(cx - 3, cy - 3), (cx + 3, cy - 3)], fill=color, width=1)
        draw.line([(cx - 3, cy), (cx + 3, cy)], fill=color, width=1)


def render(query: str, selected: int, caret_on: bool, paste_flash: bool) -> Image.Image:
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Soft backdrop
    for i in range(HEIGHT):
        t = i / HEIGHT
        c = int(22 + 10 * t)
        draw.line([(0, i), (WIDTH, i)], fill=(c, c, c + 4, 255))

    panel = (40, 36, WIDTH - 40, HEIGHT - 36)
    round_rect(draw, panel, RADIUS, PANEL)
    # Inner highlight
    draw.rounded_rectangle(panel, radius=RADIUS, outline=(255, 255, 255, 30), width=1)

    px0, py0, px1, py1 = panel
    # Magnifying-glass affordance (drawn, not emoji — fonts vary)
    gx, gy = px0 + 22, py0 + 18
    draw.ellipse([gx, gy, gx + 10, gy + 10], outline=SECONDARY, width=2)
    draw.line([(gx + 8, gy + 8), (gx + 14, gy + 14)], fill=SECONDARY, width=2)
    search_box = (px0 + 44, py0 + 8, px1 - 90, py0 + HEADER_H - 6)
    round_rect(draw, search_box, 8, SEARCH_BG)
    placeholder = "Type to search"
    shown = query if query else placeholder
    color = TEXT if query else TERTIARY
    draw.text((search_box[0] + 10, search_box[1] + 6), shown, font=FONT_SEARCH, fill=color)
    if query or True:
        # Caret at end of query (or start of placeholder when empty — only when focused look)
        if query or not query:
            text_w = draw.textlength(query, font=FONT_SEARCH) if query else 0
            caret_x = search_box[0] + 10 + int(text_w)
            if caret_on:
                draw.line([(caret_x, search_box[1] + 6), (caret_x, search_box[3] - 6)], fill=TEXT, width=1)
    visible = filtered(query)
    count = f"{len(ITEMS)} items" if not query else f"{len(visible)} of {len(ITEMS)}"
    draw.text((px1 - 78, py0 + 14), count, font=FONT_HINT, fill=TERTIARY)

    # Separator
    sep_y = py0 + HEADER_H
    draw.line([(px0 + RADIUS, sep_y), (px1 - RADIUS, sep_y)], fill=SEPARATOR, width=1)

    rows = filtered(query)
    body_top = sep_y + 4
    for i, (title, subtitle, kind) in enumerate(rows[:MAX_ROWS]):
        y = body_top + i * ROW_H
        selected_row = i == selected
        if selected_row:
            round_rect(
                draw,
                (px0 + 10, y + 4, px1 - 10, y + ROW_H - 4),
                10,
                ACCENT if not paste_flash else (48, 176, 100, 255),
            )
        icon_box = (px0 + 24, y + 10, px0 + 58, y + 44)
        draw_icon(draw, kind, icon_box, selected_row)
        title_c = ACCENT_TEXT if selected_row else TEXT
        sub_c = (255, 255, 255, 190) if selected_row else SECONDARY
        draw.text((px0 + 68, y + 10), title, font=FONT_TITLE, fill=title_c)
        draw.text((px0 + 68, y + 28), subtitle, font=FONT_SUB, fill=sub_c)
        if i < 9:
            draw.text((px1 - 42, y + 18), f"⌘{i+1}", font=FONT_HINT, fill=sub_c)

    # Footer
    foot_y = py1 - FOOTER_H
    draw.line([(px0 + RADIUS, foot_y), (px1 - RADIUS, foot_y)], fill=SEPARATOR, width=1)
    hints = "↑↓ move   ⏎ paste   ⌥⏎ plain   esc close"
    draw.text((px0 + 18, foot_y + 8), hints, font=FONT_HINT, fill=TERTIARY)

    # Brand caption outside panel
    draw.text((px0 + 4, 10), "ClipboardX", font=FONT_UI, fill=SECONDARY)
    draw.text((px0 + 100, 12), "⇧⌘V", font=FONT_HINT, fill=TERTIARY)

    return img.convert("P", palette=Image.ADAPTIVE, colors=64)


def filtered(query: str):
    q = query.lower().strip()
    if not q:
        return ITEMS
    return [it for it in ITEMS if q in it[0].lower()]


def main():
    out = Path(__file__).resolve().parents[1] / "docs" / "demo.gif"
    out.parent.mkdir(parents=True, exist_ok=True)

    frames: list[Image.Image] = []
    durations: list[int] = []

    def add(img: Image.Image, ms: int):
        frames.append(img)
        durations.append(ms)

    # Idle open
    for blink in range(6):
        add(render("", 0, caret_on=blink % 2 == 0, paste_flash=False), 180)

    # Type search "api"
    typed = ""
    for ch in "api":
        typed += ch
        add(render(typed, 0, caret_on=True, paste_flash=False), 220)
        add(render(typed, 0, caret_on=False, paste_flash=False), 120)

    # Clear search
    add(render("", 0, caret_on=True, paste_flash=False), 280)

    # Move selection down
    for sel in range(0, 3):
        add(render("", sel, caret_on=True, paste_flash=False), 320)

    # Paste flash on selection
    add(render("", 2, caret_on=False, paste_flash=True), 450)
    add(render("", 2, caret_on=False, paste_flash=False), 200)

    # Hold final frame
    for _ in range(4):
        add(render("", 2, caret_on=True, paste_flash=False), 250)

    frames[0].save(
        out,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=True,
        disposal=2,
    )
    size_kb = out.stat().st_size / 1024
    print(f"Wrote {out} ({size_kb:.1f} KB, {len(frames)} frames)")


if __name__ == "__main__":
    main()
