#!/usr/bin/env python3
"""Composes the Dipwise App Store screenshots for iPhone, iPad, and Apple Watch.

One idea per image, the way the best-converting listings do it:
- a short, benefit-first headline that reads at thumbnail size in search results,
- the real app on an upright device, large enough to read, bleeding off the bottom edge,
- one moment from that screen lifted out and enlarged, so the eye knows exactly where to look.

The first three images carry the promise (buy the dip, draw your zone, know your odds), because they're the
only ones people see in search results.

Usage: python3 compose.py <raw folder> <output folder>
Writes iPhone-6.9 (1320 × 2868), iPhone-6.5 (1284 × 2778), iPad-13 (2064 × 2752), and AppleWatch-Ultra
(422 × 514) folders into the output folder, plus a contact sheet of each set.
"""

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

NAVY_TOP = (15, 44, 68)
NAVY_BOTTOM = (5, 16, 29)
WATCH_NAVY = (12, 36, 56)
GREEN = (24, 196, 124)
WHITE = (255, 255, 255)
SOFT = (178, 192, 207)
INK = (10, 27, 46)

ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
TEXT = "/System/Library/Fonts/SFNS.ttf"


def font(path, size, weight):
    f = ImageFont.truetype(path, round(size))
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


# MARK: - Background

def backdrop(size, glow_y=0.62, seed=1):
    """Night navy with one soft green glow behind the device and a light dusting of stars up top."""
    width, height = size
    image = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        image.putpixel((0, y), tuple(int(NAVY_TOP[i] + (NAVY_BOTTOM[i] - NAVY_TOP[i]) * t) for i in range(3)))
    image = image.resize(size, Image.BICUBIC).convert("RGBA")

    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    r = width * 0.62
    cx, cy = width / 2, height * glow_y
    ImageDraw.Draw(glow).ellipse((cx - r, cy - r * 0.9, cx + r, cy + r * 0.9), fill=(24, 196, 124, 58))
    image.alpha_composite(glow.filter(ImageFilter.GaussianBlur(width * 0.16)))

    stars = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(stars)
    rng = random.Random(seed)
    unit = width / 1320
    for _ in range(int(70 * width / 1320)):
        x, y = rng.uniform(0, width), rng.uniform(0, height * 0.3)
        radius = rng.choice([1.4, 1.8, 2.2, 3]) * unit
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(255, 255, 255, rng.randint(30, 110)))
    image.alpha_composite(stars)
    return image


# MARK: - Text

def headline(canvas, title, subline, size=148, top=None):
    """A bold two-line headline with *highlighted* words in green and one short supporting line, centered.

    Returns the y just below the text."""
    width = canvas.width
    draw = ImageDraw.Draw(canvas)
    head_font = font(ROUNDED, size, "Heavy")
    widest = max(draw.textlength(line.replace("*", ""), font=head_font) for line in title.split("\n"))
    if widest > width * 0.9:
        # Shrinks to fit, keeping the line height and supporting line in proportion.
        size = size * width * 0.9 / widest
        head_font = font(ROUNDED, size, "Heavy")
    sub_font = font(TEXT, size * 0.36, "Medium")
    y = top if top is not None else round(size * 1.05)
    for line in title.split("\n"):
        parts = line.split("*")
        x = (width - sum(draw.textlength(part, font=head_font) for part in parts)) / 2
        for index, part in enumerate(parts):
            draw.text((x, y), part, font=head_font, fill=GREEN if index % 2 else WHITE)
            x += draw.textlength(part, font=head_font)
        y += round(size * 1.08)
    if subline:
        y += round(size * 0.2)
        for line in balanced(draw, subline, sub_font, width * 0.84):
            w = draw.textlength(line, font=sub_font)
            draw.text(((width - w) / 2, y), line, font=sub_font, fill=SOFT)
            y += round(size * 0.48)
    return y


def balanced(draw, text, text_font, max_width):
    """One line if it fits, otherwise two lines of similar length."""
    if draw.textlength(text, font=text_font) <= max_width:
        return [text]
    words, best = text.split(), None
    for split in range(1, len(words)):
        a, b = " ".join(words[:split]), " ".join(words[split:])
        widest = max(draw.textlength(a, font=text_font), draw.textlength(b, font=text_font))
        if widest <= max_width and (best is None or widest < best[0]):
            best = (widest, [a, b])
    return best[1] if best else [text]


# MARK: - Shapes

def rounded_mask(size, radius, supersample=4):
    """An antialiased rounded-rectangle mask."""
    big = Image.new("L", (size[0] * supersample, size[1] * supersample), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1), radius=radius * supersample, fill=255)
    return big.resize(size, Image.LANCZOS)


def gradient(size, top, bottom, horizontal=False):
    strip = Image.new("RGB", (256, 1) if horizontal else (1, 256))
    for i in range(256):
        t = i / 255
        strip.putpixel((i, 0) if horizontal else (0, i), tuple(int(top[c] + (bottom[c] - top[c]) * t) for c in range(3)))
    return strip.resize(size, Image.BICUBIC)


def shadowed(canvas, layer, x, y, blur=40, offset=30, opacity=150):
    """Pastes a layer at (x, y) with a soft drop shadow."""
    x, y = round(x), round(y)
    alpha = layer.split()[3].point(lambda a: a * opacity // 255)
    pad = blur * 3
    shade = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2), (0, 0, 0, 0))
    shade.paste((0, 0, 0, 255), (pad, pad), alpha)
    shade = shade.filter(ImageFilter.GaussianBlur(blur))
    paste_clipped(canvas, shade, x - pad, y - pad + offset)
    paste_clipped(canvas, layer, x, y)


def paste_clipped(canvas, layer, x, y):
    """alpha_composite that tolerates layers hanging off any edge."""
    left, top = max(0, -x), max(0, -y)
    right, bottom = min(layer.width, canvas.width - x), min(layer.height, canvas.height - y)
    if right <= left or bottom <= top:
        return
    canvas.alpha_composite(layer.crop((left, top, right, bottom)), (x + left, y + top))


# MARK: - Screens

def fix_iphone_clock(screen):
    """The simulator shows 09:41; a US iPhone shows 9:41."""
    screen = screen.convert("RGB")
    draw = ImageDraw.Draw(screen)
    background = screen.getpixel((120, 60))
    draw.rectangle((150, 50, 420, 140), fill=background)
    clock = font(TEXT, 52, "Semibold")
    w = draw.textlength("9:41", font=clock)
    draw.text((273 - w / 2, 66), "9:41", font=clock, fill=(0, 0, 0) if sum(background) / 3 > 128 else WHITE)
    return screen


def fix_ipad_status(screen):
    """US date format in the status bar, no window title, and no window-resize corner."""
    screen = screen.convert("RGB")
    draw = ImageDraw.Draw(screen)
    background = screen.getpixel((30, 30))
    draw.rectangle((30, 6, 560, 62), fill=background)
    status = font(TEXT, 30, "Semibold")
    draw.text((50, 16), "9:41 AM   Wed Oct 14", font=status, fill=(0, 0, 0) if sum(background) / 3 > 128 else WHITE)
    corner = screen.getpixel((screen.width - 110, screen.height - 20))
    draw.rectangle((screen.width - 96, screen.height - 96, screen.width, screen.height), fill=corner)
    return screen


def iphone(screen, width):
    """A capture inside a modern iPhone: titanium band, thin black border, Dynamic Island, side buttons."""
    s = width / screen.width
    screen = screen.convert("RGB").resize((width, round(screen.height * s)), Image.LANCZOS)
    radius = round(176 * s)
    border = round(22 * s)
    band = round(13 * s)
    button = round(10 * s)
    case = (width + (border + band) * 2, screen.height + (border + band) * 2)
    phone = Image.new("RGBA", (case[0] + button * 2, case[1]), (0, 0, 0, 0))
    draw = ImageDraw.Draw(phone)
    for top, height in [(520, 110), (720, 200), (980, 200)]:
        draw.rounded_rectangle((0, round(top * s), button * 2, round((top + height) * s)), radius=button, fill=(88, 90, 94, 255))
    draw.rounded_rectangle((case[0], round(760 * s), case[0] + button * 2 - 1, round(1100 * s)), radius=button, fill=(88, 90, 94, 255))
    metal = gradient(case, (124, 126, 130), (52, 54, 58), horizontal=True)
    phone.paste(metal, (button, 0), rounded_mask(case, radius + border + band))
    inner = (case[0] - 4, case[1] - 4)
    phone.paste(gradient(inner, (70, 72, 76), (30, 31, 34)), (button + 2, 2), rounded_mask(inner, radius + border + band - 2))
    bezel = (width + border * 2, screen.height + border * 2)
    phone.paste((0, 0, 0), (button + band, band), rounded_mask(bezel, radius + border))
    phone.paste(screen, (button + band + border, band + border), rounded_mask(screen.size, radius))
    iw, ih = round(372 * s), round(108 * s)
    ix, iy = button + band + border + (width - iw) // 2, band + border + round(34 * s)
    island = Image.new("RGBA", (iw, ih), (0, 0, 0, 255))
    phone.paste(island, (ix, iy), rounded_mask((iw, ih), ih // 2))
    return phone


def ipad(screen, width):
    """A capture inside an iPad Pro: thin aluminum band and an even black border."""
    s = width / screen.width
    screen = screen.convert("RGB").resize((width, round(screen.height * s)), Image.LANCZOS)
    radius = round(56 * s)
    border = round(48 * s)
    band = round(12 * s)
    case = (width + (border + band) * 2, screen.height + (border + band) * 2)
    tablet = Image.new("RGBA", case, (0, 0, 0, 0))
    tablet.paste(gradient(case, (150, 152, 156), (70, 72, 76), horizontal=True), (0, 0), rounded_mask(case, radius + border + band))
    bezel = (width + border * 2, screen.height + border * 2)
    tablet.paste((0, 0, 0), (band, band), rounded_mask(bezel, radius + border))
    tablet.paste(screen, (band + border, band + border), rounded_mask(screen.size, radius))
    return tablet


def watch(content, display_width, title="Dipwise", time="10:09", strap=0):
    """A high-resolution Apple Watch Ultra: the rendered page on the display under the watchOS title bar,
    in a titanium case with the Digital Crown and Action button, and optionally a band that fades away."""
    k = display_width / 422
    dw, dh = display_width, round(514 * k)
    display = Image.new("RGBA", (dw, dh), WATCH_NAVY + (255,))
    side = round(16 * k)
    page_top = round(116 * k)
    page = content.resize((dw - side * 2, round(content.height * (dw - side * 2) / content.width)), Image.LANCZOS)
    page = page.crop((0, 0, page.width, min(page.height, dh - page_top)))
    fade = Image.new("L", page.size, 255)
    fade_draw = ImageDraw.Draw(fade)
    fade_height = round(60 * k)
    for i in range(fade_height):
        fade_draw.line([(0, page.height - fade_height + i), (page.width, page.height - fade_height + i)], fill=255 - 255 * i // fade_height)
    page.putalpha(Image.composite(page.split()[3], Image.new("L", page.size, 0), fade))
    display.alpha_composite(page, (side, page_top))
    draw = ImageDraw.Draw(display)
    clock = font(ROUNDED, 34 * k, "Semibold")
    name = font(ROUNDED, 38 * k, "Semibold")
    draw.text((dw - round(48 * k) - draw.textlength(time, font=clock), round(22 * k)), time, font=clock, fill=WHITE)
    draw.text((dw - round(48 * k) - draw.textlength(title, font=name), round(62 * k)), title, font=name, fill=GREEN)

    radius = round(96 * k)
    border = round(20 * k)
    band = round(26 * k)
    crown_w = round(30 * k)
    case = (dw + (border + band) * 2, dh + (border + band) * 2)
    body = Image.new("RGBA", (case[0] + crown_w, case[1]), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle((case[0] - crown_w, round(case[1] * 0.22), case[0] + crown_w - 1, round(case[1] * 0.40)), radius=round(10 * k), fill=(150, 146, 140, 255))
    for i in range(9):
        y = round(case[1] * 0.235 + i * case[1] * 0.017)
        bd.line([(case[0] + 2, y), (case[0] + crown_w - 3, y)], fill=(105, 102, 98, 255), width=max(1, round(3 * k)))
    bd.rounded_rectangle((case[0] - crown_w, round(case[1] * 0.52), case[0] + crown_w // 2, round(case[1] * 0.68)), radius=round(8 * k), fill=(120, 116, 110, 255))
    body.paste(gradient(case, (196, 190, 180), (110, 106, 100), horizontal=True), (0, 0), rounded_mask(case, radius + border + band))
    inner = (case[0] - round(10 * k), case[1] - round(10 * k))
    body.paste(gradient(inner, (150, 145, 138), (84, 81, 77)), (round(5 * k), round(5 * k)), rounded_mask(inner, radius + border + band - round(5 * k)))
    bezel = (dw + border * 2, dh + border * 2)
    body.paste((0, 0, 0), (band, band), rounded_mask(bezel, radius + border))
    body.paste(display, (band + border, band + border), rounded_mask((dw, dh), radius))
    if not strap:
        return body
    # A sport band above and below the case, fading out at its far ends.
    strap_w = round(case[0] * 0.74)
    full = Image.new("RGBA", (body.width, body.height + strap * 2), (0, 0, 0, 0))
    for top in (0, strap + case[1] - round(80 * k)):
        piece = gradient((strap_w, strap + round(80 * k)), (58, 64, 74), (30, 34, 40), horizontal=True).convert("RGBA")
        fade = Image.new("L", piece.size, 255)
        fd = ImageDraw.Draw(fade)
        for i in range(strap):
            y = i if top == 0 else piece.height - 1 - i
            fd.line([(0, y), (piece.width, y)], fill=round(255 * (i / strap) ** 2.2))
        piece.putalpha(Image.composite(fade, Image.new("L", piece.size, 0), rounded_mask(piece.size, round(40 * k))))
        full.alpha_composite(piece, ((case[0] - strap_w) // 2, top))
    full.alpha_composite(body, (0, strap))
    return full


def card(raw, box, width, radius=46):
    """Lifts part of a screen out as an enlarged floating card with a hairline edge."""
    crop = raw.convert("RGB").crop(box)
    crop = crop.resize((round(width), round(crop.height * width / crop.width)), Image.LANCZOS)
    tile = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    tile.paste(crop, (0, 0), rounded_mask(crop.size, radius))
    edge = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((1, 1, crop.width - 2, crop.height - 2), radius=radius, outline=(255, 255, 255, 70), width=3)
    tile.alpha_composite(edge)
    return tile


def notification(width, icon, title, body):
    """An iOS notification banner, drawn crisp at any size."""
    k = width / 1100
    height = round(250 * k)
    banner = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    banner.paste((246, 247, 250), (0, 0), rounded_mask((width, height), round(64 * k)))
    draw = ImageDraw.Draw(banner)
    size = round(124 * k)
    app_icon = icon.convert("RGBA").resize((size, size), Image.LANCZOS)
    banner.paste(app_icon, (round(40 * k), (height - size) // 2), rounded_mask((size, size), round(28 * k)))
    x = round(40 * k) + size + round(34 * k)
    title_font = font(TEXT, 50 * k, "Semibold")
    body_font = font(TEXT, 46 * k, "Regular")
    time_font = font(TEXT, 40 * k, "Regular")
    draw.text((x, round(44 * k)), title, font=title_font, fill=(10, 10, 12))
    draw.text((width - round(44 * k) - draw.textlength("now", font=time_font), round(50 * k)), "now", font=time_font, fill=(130, 132, 138))
    y = round(110 * k)
    for line in body:
        draw.text((x, y), line, font=body_font, fill=(40, 42, 48))
        y += round(58 * k)
    return banner


def owl(raw_dir, pose, width):
    image = Image.open(raw_dir / f"owl-{pose}.png").convert("RGBA")
    return image.resize((round(width), round(image.height * width / image.width)), Image.LANCZOS)


def chips(canvas, cx, top, labels, columns, scale=1.0):
    """Labels as floating white pills, centered in rows."""
    draw = ImageDraw.Draw(canvas)
    chip_font = font(ROUNDED, 46 * scale, "Bold")
    height, gap = round(100 * scale), round(22 * scale)
    y = top
    for start in range(0, len(labels), columns):
        row = labels[start:start + columns]
        widths = [draw.textlength(label, font=chip_font) + 80 * scale for label in row]
        x = cx - (sum(widths) + gap * (len(row) - 1)) / 2
        for label, w in zip(row, widths):
            pill = Image.new("RGBA", (round(w), height), (0, 0, 0, 0))
            pill.paste((255, 255, 255), (0, 0), rounded_mask(pill.size, height // 2))
            ImageDraw.Draw(pill).text((40 * scale, height * 0.2), label, font=chip_font, fill=INK)
            shadowed(canvas, pill, x, y, blur=18, offset=12, opacity=110)
            x += w + gap
        y += height + gap


def checklist(canvas, cx, top, items, scale=1.0):
    """Everything Dipwise does, ticked off, on a frosted card."""
    item_font = font(ROUNDED, 56 * scale, "Bold")
    row = round(116 * scale)
    width = round(940 * scale)
    height = row * len(items) + round(64 * scale)
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    layer.paste((255, 255, 255, 20), (0, 0), rounded_mask((width, height), round(60 * scale)))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle((1, 1, width - 2, height - 2), radius=round(60 * scale), outline=(255, 255, 255, 46), width=3)
    for index, item in enumerate(items):
        y = round(32 * scale) + index * row
        d = round(64 * scale)
        draw.ellipse((round(56 * scale), y + round(24 * scale), round(56 * scale) + d, y + round(24 * scale) + d), fill=GREEN)
        cx0, cy0 = round(56 * scale), y + round(24 * scale)
        draw.line([(cx0 + 17 * scale, cy0 + 33 * scale), (cx0 + 28 * scale, cy0 + 44 * scale), (cx0 + 48 * scale, cy0 + 21 * scale)], fill=INK, width=round(8 * scale), joint="curve")
        draw.text((round(152 * scale), y + round(24 * scale)), item, font=item_font, fill=WHITE)
    canvas.alpha_composite(layer, (round(cx - width / 2), round(top)))


def pill(canvas, cx, top, label, scale=1.0):
    """A solid green call-to-action pill."""
    draw = ImageDraw.Draw(canvas)
    label_font = font(ROUNDED, 54 * scale, "Bold")
    w = draw.textlength(label, font=label_font) + 120 * scale
    h = round(120 * scale)
    layer = Image.new("RGBA", (round(w), h), (0, 0, 0, 0))
    layer.paste(GREEN, (0, 0), rounded_mask(layer.size, h // 2))
    ImageDraw.Draw(layer).text((60 * scale, h * 0.21), label, font=label_font, fill=INK)
    shadowed(canvas, layer, cx - w / 2, top, blur=30, offset=16, opacity=120)


# MARK: - iPhone

# Regions of the raw iPhone captures that get lifted out as cards: (left, top, right, bottom).
ZONE_CHART = (60, 1719, 1260, 2660)
ODDS_CARD = (60, 960, 1260, 1525)
SMART_LIST = (60, 1888, 1260, 2640)
STAT_TILES = (108, 1838, 1212, 2182)
# The NVDA plan card in the high-resolution watch render.
WATCH_PLAN = (0, 561, 1170, 1062)


class Raw:
    def __init__(self, folder):
        self.folder = folder

    def __call__(self, name):
        return Image.open(self.folder / f"{name}.png")


def place_phone(canvas, screen, top, width=1000, cx=None):
    phone = iphone(screen, width)
    x = (cx if cx is not None else canvas.width / 2) - phone.width / 2
    shadowed(canvas, phone, x, top, blur=60, offset=40, opacity=160)
    # Where the screen's top-left lands, and its scale, so cards can be lined up with what they enlarge.
    s = width / screen.width
    return x + round(10 * s) + round(13 * s) + round(22 * s), top + round(13 * s) + round(22 * s), s


def iphone_set(raw, raw_dir):
    W, H = 1320, 2868
    icon = Image.open(raw_dir / "app-icon.png")
    shots = []

    def frame(seed, glow=0.62):
        return backdrop((W, H), glow, seed)

    # 1 · The promise: set a price, get the tap. NVDA's page with the alert arriving and Dippy perched on it.
    c = frame(1)
    headline(c, "Buy the *dip*.\nNever miss it.", "Set your price. Dippy taps you the moment it gets there.")
    place_phone(c, fix_iphone_clock(raw("iphone-stock")), 900)
    banner = notification(1160, icon, "NVDA entered your buy zone", ["Now $209.35, inside $206.35–$217.80.", "Your plan: buy a little."])
    shadowed(c, banner, (W - banner.width) / 2, 1600, blur=40, offset=26, opacity=170)
    bird = owl(raw_dir, "idle", 220)
    c.alpha_composite(bird, (W - 150 - bird.width, 1600 - bird.height + 24))
    shots.append(("01-buy-the-dip", c))

    # 2 · Draw the zone: the editor, with its chart and handles enlarged.
    c = frame(2)
    headline(c, "Draw your\n*buy zone*", "Drag two handles. That's your whole plan.")
    zones = fix_iphone_clock(raw("iphone-zones"))
    ox, oy, s = place_phone(c, zones, 880)
    lift = card(zones, ZONE_CHART, 1180)
    shadowed(c, lift, (W - lift.width) / 2, oy + ZONE_CHART[1] * s - 40, blur=44, offset=30, opacity=170)
    shots.append(("02-buy-zone", c))

    # 3 · The odds: every plan with its chance, and the odds card enlarged.
    c = frame(3)
    headline(c, "Know your *odds*\nbefore you buy", "See how likely each plan is to trigger.")
    alerts = fix_iphone_clock(raw("iphone-alerts"))
    ox, oy, s = place_phone(c, alerts, 880)
    lift = card(fix_iphone_clock(raw("iphone-zones")), ODDS_CARD, 1180)
    shadowed(c, lift, (W - lift.width) / 2, 1960, blur=44, offset=30, opacity=170)
    shots.append(("03-odds", c))

    # 4 · Smart alerts in plain English.
    c = frame(4)
    headline(c, "*27* smart alerts,\nplain English", "Dips, trends, RSI, and stops, each explained.")
    smart = fix_iphone_clock(raw("iphone-smart"))
    ox, oy, s = place_phone(c, smart, 880)
    lift = card(smart, SMART_LIST, 1180)
    shadowed(c, lift, (W - lift.width) / 2, oy + SMART_LIST[1] * s - 40, blur=44, offset=30, opacity=170)
    shots.append(("04-smart-alerts", c))

    # 5 · Widgets, shown full size so every number reads.
    c = frame(5, 0.55)
    headline(c, "Your plans on\nyour *Home Screen*", "Live widgets with your zones, movers, and streak.")
    scene = raw("scene-widgets")
    big = card(scene, (155, 229, 1165, 699), 1180, radius=86)
    shadowed(c, big, (W - big.width) / 2, 900, blur=40, offset=28, opacity=170)
    small_w = 570
    left = card(scene, (155, 806, 626, 1277), small_w, radius=96)
    right = card(scene, (694, 806, 1165, 1277), small_w, radius=96)
    shadowed(c, left, W / 2 - 20 - small_w, 900 + big.height + 40, blur=40, offset=28, opacity=170)
    shadowed(c, right, W / 2 + 20, 900 + big.height + 40, blur=40, offset=28, opacity=170)
    movers = card(scene, (155, 1383, 1165, 1853), 1180, radius=86)
    shadowed(c, movers, (W - movers.width) / 2, 900 + big.height + 40 + left.height + 40, blur=40, offset=28, opacity=170)
    shots.append(("05-widgets", c))

    # 6 · Apple Watch, rendered sharp, with the closest plan lifted off the wrist.
    c = frame(6, 0.6)
    headline(c, "Your portfolio,\n*on your wrist*", "Plans, prices, and charts on Apple Watch.")
    strap = 300
    wrist = watch(raw("watch-today"), 680, strap=strap)
    shadowed(c, wrist, (W - wrist.width) / 2 + 20, 1020 - strap, blur=60, offset=40, opacity=190)
    plan = card(raw("watch-plans"), WATCH_PLAN, 900, radius=76)
    shadowed(c, plan, 60, 2260, blur=44, offset=30, opacity=190)
    bird = owl(raw_dir, "wink", 230)
    c.alpha_composite(bird, (W - 80 - bird.width, 2260 - bird.height + 30))
    shots.append(("06-apple-watch", c))

    # 7 · Import.
    c = frame(7)
    headline(c, "Your portfolio\nin *seconds*", "Import a CSV from any broker. No login needed.")
    place_phone(c, fix_iphone_clock(raw("iphone-import")), 880)
    chips(c, W / 2, 2160, ["Robinhood", "Fidelity", "Schwab", "Vanguard", "E*TRADE", "IBKR", "Trading 212", "DEGIRO"], 4)
    shots.append(("07-import", c))

    # 8 · Portfolio: Home with the stat tiles enlarged.
    c = frame(8)
    headline(c, "All your stocks,\n*one calm place*", "Value, returns, and dividends at a glance.")
    home = fix_iphone_clock(raw("iphone-home"))
    ox, oy, s = place_phone(c, home, 880)
    lift = card(home, STAT_TILES, 1200, radius=56)
    shadowed(c, lift, (W - lift.width) / 2, oy + STAT_TILES[1] * s - 30, blur=44, offset=30, opacity=180)
    shots.append(("08-portfolio", c))

    # 9 · The closer: Dippy asleep, everything ticked off, free to start.
    c = frame(9, 0.45)
    headline(c, "Sleep well.\n*Dippy's on watch.*", None)
    bird = owl(raw_dir, "sleep", 560)
    c.alpha_composite(bird, (round((W - bird.width) / 2), 660))
    checklist(c, W / 2, 1400, ["Buy and sell zones", "Instant price alerts", "27 smart alerts", "Odds for every plan", "Widgets & Apple Watch", "Import from any broker"], scale=1.12)
    pill(c, W / 2, 2420, "Start free", scale=1.15)
    shots.append(("09-start-free", c))
    return shots


# MARK: - iPad

def ipad_set(raw, raw_dir):
    W, H = 2064, 2752
    icon = Image.open(raw_dir / "app-icon.png")
    shots = []
    size = 176

    def place(c, screen, top=880, width=1740):
        tablet = ipad(fix_ipad_status(screen), width)
        shadowed(c, tablet, (W - tablet.width) / 2, top, blur=70, offset=44, opacity=160)
        return (W - tablet.width) / 2, top, width / screen.width

    # 1 · The promise.
    c = backdrop((W, H), 0.62, 11)
    headline(c, "Buy the *dip*.\nNever miss it.", "Set your price. Dippy taps you the moment it gets there.", size=size)
    place(c, raw("ipad-home"))
    banner = notification(1300, icon, "NVDA entered your buy zone", ["Now $209.35, inside $206.35–$217.80.", "Your plan: buy a little."])
    shadowed(c, banner, (W - banner.width) / 2, 1560, blur=44, offset=30, opacity=180)
    bird = owl(raw_dir, "idle", 270)
    c.alpha_composite(bird, ((W + banner.width) // 2 - bird.width - 60, 1560 - bird.height + 28))
    shots.append(("01-buy-the-dip", c))

    # 2 · Draw the zone, over the stock page.
    c = backdrop((W, H), 0.62, 12)
    headline(c, "Draw your\n*buy zone*", "Drag two handles. That's your whole plan.", size=size)
    place(c, raw("ipad-stock"))
    lift = card(fix_iphone_clock(raw("iphone-zones")), ZONE_CHART, 1300)
    shadowed(c, lift, (W - lift.width) / 2, 1700, blur=50, offset=34, opacity=180)
    shots.append(("02-buy-zone", c))

    # 3 · The odds.
    c = backdrop((W, H), 0.62, 13)
    headline(c, "Know your *odds*\nbefore you buy", "See how likely each plan is to trigger.", size=size)
    place(c, raw("ipad-alerts"))
    lift = card(fix_iphone_clock(raw("iphone-zones")), ODDS_CARD, 1300)
    shadowed(c, lift, (W - lift.width) / 2, 1900, blur=50, offset=34, opacity=180)
    shots.append(("03-odds", c))

    # 4 · Watchlist.
    c = backdrop((W, H), 0.62, 14)
    headline(c, "Every stock,\n*one calm list*", "Prices, trends, and how close each plan is.", size=size)
    place(c, raw("ipad-watchlist"))
    shots.append(("04-watchlist", c))

    # 5 · The closer.
    c = backdrop((W, H), 0.45, 16)
    headline(c, "Sleep well.\n*Dippy's on watch.*", None, size=size)
    bird = owl(raw_dir, "sleep", 520)
    c.alpha_composite(bird, (round((W - bird.width) / 2), 700))
    checklist(c, W / 2, 1370, ["Buy and sell zones", "Instant price alerts", "27 smart alerts", "Odds for every plan", "Widgets & Apple Watch", "Import from any broker"], scale=1.15)
    pill(c, W / 2, 2330, "Start free", scale=1.15)
    shots.append(("05-start-free", c))
    return shots


# MARK: - Apple Watch

def watch_set(raw):
    """Full-screen watch pages under a short caption, drawn at 6× and scaled down so every edge is crisp."""
    W, H = 422, 514
    k = 4
    shots = []
    for name, caption, page in [
        ("01-today", "Dippy on *your wrist*", "watch-today"),
        ("02-plans", "Your *closest plans*", "watch-plans"),
        ("03-stock", "Every *chart*, at a glance", "watch-stock"),
        ("04-watchlist", "Your *watchlist*", "watch-watchlist"),
    ]:
        c = Image.new("RGBA", (W * k, H * k), WATCH_NAVY + (255,))
        draw = ImageDraw.Draw(c)
        caption_font = font(ROUNDED, 34 * k, "Heavy")
        parts = caption.split("*")
        x = (c.width - sum(draw.textlength(p, font=caption_font) for p in parts)) / 2
        for index, part in enumerate(parts):
            draw.text((x, 30 * k), part, font=caption_font, fill=GREEN if index % 2 else WHITE)
            x += draw.textlength(part, font=caption_font)
        side, top = 16 * k, 92 * k
        content = raw(page).convert("RGBA")
        content = content.resize((c.width - side * 2, round(content.height * (c.width - side * 2) / content.width)), Image.LANCZOS)
        content = content.crop((0, 0, content.width, min(content.height, c.height - top)))
        fade = Image.new("L", content.size, 255)
        fd = ImageDraw.Draw(fade)
        span = 70 * k
        if content.height >= c.height - top:
            for i in range(span):
                fd.line([(0, content.height - span + i), (content.width, content.height - span + i)], fill=255 - 255 * i // span)
        content.putalpha(Image.composite(content.split()[3], Image.new("L", content.size, 0), fade))
        c.alpha_composite(content, (side, top))
        shots.append((name, c.resize((W, H), Image.LANCZOS)))
    return shots


# MARK: - Output

def save(shots, folder, size=None):
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.png"):
        old.unlink()
    for name, image in shots:
        image = image.convert("RGB")
        if size and image.size != size:
            # Same layout, scaled to width and trimmed evenly top and bottom.
            scaled = image.resize((size[0], round(image.height * size[0] / image.width)), Image.LANCZOS)
            trim = (scaled.height - size[1]) // 2
            image = scaled.crop((0, trim, size[0], trim + size[1]))
        path = folder / f"{name}.png"
        image.save(path, optimize=True)
        print(path)


def contact_sheet(shots, path, height=900):
    thumbs = [image.convert("RGB").resize((round(image.width * height / image.height), height), Image.LANCZOS) for _, image in shots]
    gap = 24
    sheet = Image.new("RGB", (sum(t.width for t in thumbs) + gap * (len(thumbs) + 1), height + gap * 2), (240, 242, 246))
    x = gap
    for thumb in thumbs:
        sheet.paste(thumb, (x, gap))
        x += thumb.width + gap
    sheet.save(path, optimize=True)


def main(raw_dir, out_dir):
    raw = Raw(raw_dir)
    phone = iphone_set(raw, raw_dir)
    save(phone, out_dir / "iPhone-6.9")
    save(phone, out_dir / "iPhone-6.5", size=(1284, 2778))
    contact_sheet(phone, out_dir / "preview-iphone.png")
    tablet = ipad_set(raw, raw_dir)
    save(tablet, out_dir / "iPad-13")
    contact_sheet(tablet, out_dir / "preview-ipad.png")
    wrist = watch_set(raw)
    save(wrist, out_dir / "AppleWatch-Ultra")
    contact_sheet(wrist, out_dir / "preview-watch.png", height=514)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
