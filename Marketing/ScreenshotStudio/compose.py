#!/usr/bin/env python3
"""Composes the App Store screenshots for Dipwise.

Each image is 1320 × 2868 (Apple's 6.9-inch iPhone size): the app's navy, a short headline,
and a real screen from the app in an iPhone frame that matches the one in the app's intro.

Usage: python3 compose.py <raw screenshots folder> <output folder>
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
NAVY = (12, 36, 56)
GREEN = (18, 184, 115)
AMBER = (255, 178, 36)
WHITE = (255, 255, 255)

ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
TEXT = "/System/Library/Fonts/SFNS.ttf"


def font(path, size, weight):
    f = ImageFont.truetype(path, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


# Each slide: the raw capture, what kind of hero it is, and the words on it.
SLIDES = [
    ("iphone-home.png", "app", "DIPWISE", "Buy the dip.\nCalmly.", "Dippy watches your stocks day and night, and tells you when it's time."),
    ("iphone-zones.png", "app", "BUY ZONES", "Draw where\nyou'd buy", "Drag two handles. Dippy alerts you the moment the price gets there."),
    ("scene-lock.png", "scene", "ALERTS", "Never miss\nyour moment", "An alert the second a stock enters your zone, with your plan inside."),
    ("iphone-stock.png", "app", "ODDS", "Know your\nodds", "See how likely every plan is to trigger in the next 30 days."),
    ("iphone-smart.png", "app", "SMART ALERTS", "27 smart alerts,\nin plain English", "RSI, golden crosses, trailing stops and more, each explained by Dippy."),
    ("scene-widgets.png", "scene", "WIDGETS", "Your plans,\nalways in sight", "Living widgets for your plans, movers, the flock, and your streak."),
    ("intro-watch.png", "watch-crop", "APPLE WATCH", "A glance\nis enough", "Your portfolio, closest plans, and today's movers on your wrist."),
    ("iphone-flock.png", "app", "THE FLOCK", "See where the\ncrowd buys", "Anonymous buy and sell zones from the Dipwise community."),
    ("iphone-import.png", "app", "IMPORT", "Bring your portfolio\nin seconds", "Robinhood, Fidelity, Schwab, Vanguard, Trading 212, DEGIRO, and more."),
    ("iphone-watchlist.png", "app", "WATCHLIST", "Every stock,\none calm list", "Prices, trends, and how close each plan is, at a glance."),
]


def background():
    """Flat navy, so cropped intro scenes blend in, with a soft glow behind the headline only."""
    image = Image.new("RGB", (W, H), NAVY)
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((-200, -520, W + 200, 620), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    tint = Image.new("RGB", (W, H), (22, 74, 84))
    return Image.composite(tint, image, glow)


def draw_text(image, eyebrow, headline, subline):
    """Returns the y where the text ends."""
    draw = ImageDraw.Draw(image)
    eyebrow_font = font(ROUNDED, 40, "Bold")
    head_font = font(ROUNDED, 108, "Bold")
    sub_font = font(TEXT, 46, "Medium")

    y = 170
    spaced = " ".join(eyebrow)  # gentle letter spacing for the label
    w = draw.textlength(spaced, font=eyebrow_font)
    draw.text(((W - w) / 2, y), spaced, font=eyebrow_font, fill=GREEN)
    y += 78

    for line in headline.split("\n"):
        w = draw.textlength(line, font=head_font)
        draw.text(((W - w) / 2, y), line, font=head_font, fill=WHITE)
        y += 124
    y += 22

    for line in balanced_lines(draw, subline, sub_font, 1060):
        w = draw.textlength(line, font=sub_font)
        draw.text(((W - w) / 2, y), line, font=sub_font, fill=(196, 205, 214))
        y += 62
    return y


def balanced_lines(draw, text, text_font, max_width):
    """Wraps text into the fewest lines, with line lengths as even as possible, so no word is left alone."""
    words = text.split()
    if draw.textlength(text, font=text_font) <= max_width:
        return [text]
    best = None
    for split in range(1, len(words)):
        first, second = " ".join(words[:split]), " ".join(words[split:])
        widths = (draw.textlength(first, font=text_font), draw.textlength(second, font=text_font))
        if max(widths) <= max_width and (best is None or max(widths) < best[0]):
            best = (max(widths), [first, second])
    return best[1] if best else [text]


def fix_status_clock(screen):
    """The simulator's status bar override shows 09:41; US iPhones show 9:41."""
    screen = screen.convert("RGB")
    draw = ImageDraw.Draw(screen)
    background = screen.getpixel((70, 96))
    draw.rectangle((150, 50, 400, 140), fill=background)
    luminance = sum(background) / 3
    clock_font = font(TEXT, 51, "Semibold")
    text = "9:41"
    w = draw.textlength(text, font=clock_font)
    draw.text((273 - w / 2, 66), text, font=clock_font, fill=(0, 0, 0) if luminance > 128 else (255, 255, 255))
    return screen


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def vertical_gradient(size, top, bottom):
    gradient = Image.new("RGB", size)
    draw = ImageDraw.Draw(gradient)
    for y in range(size[1]):
        t = y / max(size[1] - 1, 1)
        draw.line([(0, y), (size[0], y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return gradient


def iphone(screen, width):
    """Frames a raw 1320 × 2868 capture as an iPhone: metal case, black border, Dynamic Island, buttons."""
    s = width / 1320
    screen = screen.convert("RGB").resize((width, round(2868 * s)), Image.LANCZOS)
    radius = round(55 * 3 * s)
    border = round(11 * 3 * s)
    metal = round(5 * 3 * s)
    button = round(4 * 3 * s)

    case_w = width + (border + metal) * 2
    case_h = screen.height + (border + metal) * 2
    total = Image.new("RGBA", (case_w + button * 2, case_h), (0, 0, 0, 0))

    # Buttons first, so the case sits over their inner edge.
    draw = ImageDraw.Draw(total)
    for top, height in [(170, 34), (234, 64), (322, 64)]:
        y, h = round(top * 3 * s), round(height * 3 * s)
        draw.rounded_rectangle((0, y, button * 2, y + h), radius=button, fill=(70, 70, 70, 255))
    y, h = round(236 * 3 * s), round(104 * 3 * s)
    draw.rounded_rectangle((case_w, y, case_w + button * 2 - 1, y + h), radius=button, fill=(70, 70, 70, 255))

    case = vertical_gradient((case_w, case_h), (61, 61, 61), (26, 26, 26))
    total.paste(case, (button, 0), rounded_mask((case_w, case_h), radius + border + metal))
    # A thin highlight along the edge.
    edge = Image.new("RGBA", (case_w, case_h), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((1, 1, case_w - 2, case_h - 2), radius=radius + border + metal, outline=(255, 255, 255, 70), width=3)
    total.alpha_composite(edge, (button, 0))

    bezel = Image.new("RGB", (width + border * 2, screen.height + border * 2), (0, 0, 0))
    total.paste(bezel, (button + metal, metal), rounded_mask(bezel.size, radius + border))
    total.paste(screen, (button + metal + border, metal + border), rounded_mask(screen.size, radius))

    island_w, island_h = round(126 * 3 * s), round(37 * 3 * s)
    ix = button + metal + border + (width - island_w) // 2
    iy = metal + border + round(11 * 3 * s)
    ImageDraw.Draw(total).rounded_rectangle((ix, iy, ix + island_w, iy + island_h), radius=island_h // 2, fill=(0, 0, 0, 255))
    return total


def drop_shadow(image, layer, x, y, blur=60, opacity=150):
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    alpha = layer.split()[3].point(lambda a: min(a, opacity))
    shadow.paste((0, 0, 0, 255), (x, y + 40), alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    image.alpha_composite(shadow)


def place_crop(image, raw, box, text_bottom, target_width, centered):
    """Places a device scene cropped from the intro: phones line up with the framed screens, the watch is centered."""
    crop = raw.crop(box).convert("RGBA")
    scale = target_width / crop.width
    crop = crop.resize((target_width, round(crop.height * scale)), Image.LANCZOS)
    space_top = text_bottom + 40
    y = space_top + max(0, (H - space_top - crop.height) // 2) if centered else text_bottom + 10
    image.alpha_composite(crop, ((W - crop.width) // 2, y))


def compose(raw_dir, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    for index, (name, kind, eyebrow, headline, subline) in enumerate(SLIDES, start=1):
        raw = Image.open(raw_dir / name)
        image = background().convert("RGBA")
        bottom = draw_text(image, eyebrow, headline, subline)
        if kind in ("app", "scene"):
            # Scenes draw their own status bar; app captures need the clock fixed.
            screen = fix_status_clock(raw) if kind == "app" else raw
            phone = iphone(screen, 1060)
            x, y = (W - phone.width) // 2, bottom + 70
            drop_shadow(image, phone, x, y)
            image.alpha_composite(phone, (x, y))
        elif kind == "watch-crop":
            place_crop(image, raw, (240, 640, 1080, 1600), bottom, 1180, centered=True)
        path = out_dir / f"{index:02d}-{Path(name).stem.replace('iphone-', '').replace('intro-', '').replace('scene-', '')}.png"
        image.convert("RGB").save(path, optimize=True)
        print(path)


if __name__ == "__main__":
    compose(Path(sys.argv[1]), Path(sys.argv[2]))
