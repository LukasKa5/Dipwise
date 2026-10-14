#!/usr/bin/env python3
"""Composes the Dipwise App Store screenshots for iPhone, iPad, and Apple Watch.

Every image shares one seamless navy night sky in the app's own colors, so the set reads as a single scene as
people swipe. Dippy is the main character: he perches on top of each device and reacts to what's on it. He keeps
watch, peers down at the buy zone, flaps his wings when the alert lands, checks the odds, and in the last image
falls asleep in the crescent moon.

Each image still works on its own: one short headline, one real screen, and at most one moment from it enlarged.
The first three carry the promise, because they're the only ones people see in search results.

Usage: python3 compose.py <raw folder> <output folder>
Writes iPhone-6.9 (1320 × 2868), iPhone-6.5 (1284 × 2778), iPad-13 (2064 × 2752), and AppleWatch-Ultra
(422 × 514) folders into the output folder, plus a panorama preview of each set.
"""

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# The app's own colors: Brand.swift and the asset catalog, as they render on screen.
NIGHT_TOP = (22, 64, 90)
NIGHT_MIDDLE = (12, 36, 56)
NIGHT_BOTTOM = (6, 15, 28)
WATCH_NAVY = NIGHT_MIDDLE
GREEN = (24, 196, 124)
SOFT = (176, 192, 208)
MINT = (47, 230, 160)
WATCH_GREEN = (18, 184, 115)
WHITE = (255, 255, 255)
INK = (10, 27, 46)
SECONDARY = (108, 117, 128)

ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
TEXT = "/System/Library/Fonts/SFNS.ttf"


def font(path, size, weight):
    f = ImageFont.truetype(path, round(size))
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f

# MARK: - The night sky

class Sky:
    """One seamless navy night across every image, in the app's own night colors, with a few quiet stars."""

    def __init__(self, frame, count, seed=11):
        self.W, self.H = frame
        self.count = count
        self.unit = self.W / 1320
        width = self.W * count
        strip = Image.new("RGB", (1, 512))
        for y in range(512):
            t = y / 511
            a, b, k = (NIGHT_TOP, NIGHT_MIDDLE, t / 0.6) if t < 0.6 else (NIGHT_MIDDLE, NIGHT_BOTTOM, (t - 0.6) / 0.4)
            strip.putpixel((0, y), tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)))
        self.canvas = strip.resize((width, self.H), Image.BICUBIC).convert("RGBA")
        stars = Image.new("RGBA", self.canvas.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(stars)
        rng = random.Random(seed)
        for _ in range(int(count * 26)):
            x, y = rng.uniform(0, width), rng.uniform(0, self.H * 0.42)
            r = rng.choice([1.4, 1.8, 2.2, 2.8]) * self.unit
            draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, rng.randint(50, 140)))
        self.canvas.alpha_composite(stars)

    def x0(self, index):
        return self.W * index

    def moon(self, cx, cy, r, glow=True):
        """A soft crescent, like the one the app shows while markets sleep. Returns its mask box."""
        if glow:
            halo = Image.new("RGBA", self.canvas.size, (0, 0, 0, 0))
            ImageDraw.Draw(halo).ellipse((cx - r * 1.9, cy - r * 1.9, cx + r * 1.9, cy + r * 1.9), fill=(255, 232, 180, 22))
            self.canvas.alpha_composite(halo.filter(ImageFilter.GaussianBlur(r * 0.5)))
        s = 4
        disc = Image.new("L", (r * 2 * s, r * 2 * s), 0)
        ImageDraw.Draw(disc).ellipse((0, 0, r * 2 * s - 1, r * 2 * s - 1), fill=255)
        ImageDraw.Draw(disc).ellipse((round(r * 0.62 * s), round(-r * 0.36 * s), round(r * 2.62 * s), round(r * 1.64 * s)), fill=0)
        disc = disc.resize((r * 2, r * 2), Image.LANCZOS)
        self.canvas.paste((255, 230, 170), (round(cx - r), round(cy - r)), disc)

    def owl(self, raw_dir, pose, cx, feet, height):
        """Dippy with his feet at (cx, feet), perched on whatever is there."""
        image = Image.open(raw_dir / f"owl-{pose}.png").convert("RGBA")
        image = image.resize((round(image.width * height / image.height), round(height)), Image.LANCZOS)
        paste_clipped(self.canvas, image, round(cx - image.width / 2), round(feet - image.height))

    def frames(self):
        return [self.canvas.crop((self.W * i, 0, self.W * (i + 1), self.H)) for i in range(self.count)]


# MARK: - Text

def headline(canvas, ox, frame_width, title, subline, size=140, top=None):
    """A bold two-line headline with *highlighted* words in the app's night green and a short supporting line,
    centered in the image that starts at x = ox."""
    width = frame_width
    draw = ImageDraw.Draw(canvas)
    head_font = font(ROUNDED, size, "Bold")
    widest = max(draw.textlength(line.replace("*", ""), font=head_font) for line in title.split("\n"))
    if widest > width * 0.9:
        size = size * width * 0.9 / widest
        head_font = font(ROUNDED, size, "Bold")
    sub_font = font(ROUNDED, size * 0.34, "Medium")
    y = top if top is not None else round(size * 1.0)
    for line in title.split("\n"):
        parts = line.split("*")
        x = ox + (width - sum(draw.textlength(part, font=head_font) for part in parts)) / 2
        for index, part in enumerate(parts):
            draw.text((x, y), part, font=head_font, fill=MINT if index % 2 else WHITE)
            x += draw.textlength(part, font=head_font)
        y += round(size * 1.08)
    if subline:
        y += round(size * 0.14)
        for line in balanced(draw, subline, sub_font, width * 0.86):
            w = draw.textlength(line, font=sub_font)
            draw.text((ox + (width - w) / 2, y), line, font=sub_font, fill=SOFT)
            y += round(size * 0.46)
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
    draw.text((dw - round(48 * k) - draw.textlength(title, font=name), round(62 * k)), title, font=name, fill=WATCH_GREEN)

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
            fd.line([(0, y), (piece.width, y)], fill=round(255 * (i / strap) ** 3))
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





def checklist(canvas, cx, top, items, scale=1.0):
    """Everything Dipwise does, ticked off on a soft tile like the app's tiles on navy."""
    item_font = font(ROUNDED, 56 * scale, "Semibold")
    row = round(114 * scale)
    width = round(940 * scale)
    height = row * len(items) + round(60 * scale)
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    layer.paste((255, 255, 255, 22), (0, 0), rounded_mask((width, height), round(60 * scale)))
    draw = ImageDraw.Draw(layer)
    for index, item in enumerate(items):
        y = round(30 * scale) + index * row
        d = round(62 * scale)
        x0, y0 = round(56 * scale), y + round(26 * scale)
        draw.ellipse((x0, y0, x0 + d, y0 + d), fill=GREEN)
        draw.line([(x0 + 17 * scale, y0 + 32 * scale), (x0 + 27 * scale, y0 + 42 * scale), (x0 + 46 * scale, y0 + 21 * scale)], fill=WHITE, width=round(7 * scale), joint="curve")
        draw.text((round(148 * scale), y + round(26 * scale)), item, font=item_font, fill=WHITE)
    canvas.alpha_composite(layer, (round(cx - width / 2), round(top)))


def pill(canvas, cx, top, label, scale=1.0):
    """The app's prominent button: solid green with white text."""
    draw = ImageDraw.Draw(canvas)
    label_font = font(ROUNDED, 58 * scale, "Bold")
    w = draw.textlength(label, font=label_font) + 150 * scale
    h = round(132 * scale)
    layer = Image.new("RGBA", (round(w), h), (0, 0, 0, 0))
    layer.paste(GREEN, (0, 0), rounded_mask(layer.size, h // 2))
    ImageDraw.Draw(layer).text((75 * scale, h * 0.2), label, font=label_font, fill=WHITE)
    shadowed(canvas, layer, cx - w / 2, top, blur=round(30 * scale), offset=round(16 * scale), opacity=120)


# MARK: - iPhone

# Regions of the raw iPhone captures that get lifted out as cards: (left, top, right, bottom).
PLAN_CARD = (60, 1935, 1260, 2620)
ZONE_CARD = (60, 1190, 1260, 2310)
STAT_TILES = (108, 1838, 1212, 2182)
# The NVDA plan card in the high-resolution watch render.
WATCH_PLAN = (0, 561, 1170, 1062)


class Raw:
    def __init__(self, folder):
        self.folder = folder

    def __call__(self, name):
        return Image.open(self.folder / f"{name}.png")


def clean_lock_screen(screen):
    """Hides the flashlight and camera buttons at the bottom of the lock screen."""
    screen = screen.convert("RGB")
    strip = screen.crop((0, 2300, screen.width, 2340)).resize((screen.width, screen.height - 2300), Image.BICUBIC)
    screen.paste(strip, (0, 2300))
    return screen


def device(canvas, layer, cx, top, unit=1.0):
    """Places a device by its center and top edge. Returns its left and right edges."""
    x = cx - layer.width / 2
    shadowed(canvas, layer, x, top, blur=round(60 * unit), offset=round(40 * unit), opacity=170)
    return x, x + layer.width


def lift(canvas, layer, x, top, unit=1.0):
    shadowed(canvas, layer, x, top, blur=round(44 * unit), offset=round(30 * unit), opacity=180)


def iphone_story(raw, raw_dir):
    W, H = 1320, 2868
    icon = Image.open(raw_dir / "app-icon.png")
    sky = Sky((W, H), 10)
    x0 = sky.x0
    c = sky.canvas
    phone_w, top = 900, 920
    perch = 250

    def phone(index, screen):
        left, right = device(c, iphone(screen, phone_w), x0(index) + W / 2, top)
        return left, right

    # 1 · Dippy keeps watch on NVDA as the alert arrives.
    l, r = phone(0, fix_iphone_clock(raw("iphone-stock")))
    banner = notification(1180, icon, "NVDA entered your buy zone", ["Now $209.35, inside $206.35–$217.80.", "Your plan: buy a little."])
    lift(c, banner, x0(0) + (W - banner.width) / 2, 1560)
    sky.owl(raw_dir, "idle", r - 200, top + 24, perch)

    # 2 · He peers down at the zone being drawn.
    l, r = phone(1, fix_iphone_clock(raw("iphone-plan")))
    sky.owl(raw_dir, "look-down", l + 210, top + 24, perch)

    # 3 · The alert lands, and he can't sit still.
    l, r = phone(2, clean_lock_screen(raw("scene-lock")))
    sky.owl(raw_dir, "wings", r - 230, top + 24, perch)

    # 4 · He checks the odds.
    l, r = phone(3, fix_iphone_clock(raw("iphone-alerts")))
    plan = card(fix_iphone_clock(raw("iphone-stock")), PLAN_CARD, 1180, radius=60)
    lift(c, plan, x0(3) + (W - plan.width) / 2, 1980)
    sky.owl(raw_dir, "look-left", r - 200, top + 24, perch)

    # 5 · Smart alerts, each explained.
    l, r = phone(4, fix_iphone_clock(raw("iphone-plan-smart")))
    sky.owl(raw_dir, "look-right", l + 200, top + 24, perch)

    # 6 · Widgets, full size, with Dippy on top of the big one.
    scene = raw("scene-widgets")
    big = card(scene, (155, 229, 1165, 699), 1160, radius=86)
    big_top = 1000
    lift(c, big, x0(5) + (W - big.width) / 2, big_top)
    small = 560
    left = card(scene, (155, 806, 626, 1277), small, radius=96)
    right = card(scene, (694, 806, 1165, 1277), small, radius=96)
    lift(c, left, x0(5) + W / 2 - 20 - small, big_top + big.height + 40)
    lift(c, right, x0(5) + W / 2 + 20, big_top + big.height + 40)
    movers = card(scene, (155, 1383, 1165, 1853), 1160, radius=86)
    lift(c, movers, x0(5) + (W - movers.width) / 2, big_top + big.height + 40 + small + 40)
    sky.owl(raw_dir, "look-up", x0(5) + W / 2 + 360, big_top + 24, perch)

    # 7 · Apple Watch, with Dippy perched on the case.
    wrist = watch(raw("watch-today"), 720)
    wl, wr = device(c, wrist, x0(6) + W / 2, 1000)
    plan = card(raw("watch-plans"), WATCH_PLAN, 960, radius=80)
    lift(c, plan, x0(6) + (W - plan.width) / 2, 2160)
    sky.owl(raw_dir, "wink", wl + 230, 1000 + 24, perch)

    # 8 · Import.
    l, r = phone(7, fix_iphone_clock(raw("iphone-import")))
    sky.owl(raw_dir, "look-down", r - 210, top + 24, perch)

    # 9 · Portfolio, with the stat tiles enlarged.
    l, r = phone(8, fix_iphone_clock(raw("iphone-home")))
    tiles = card(fix_iphone_clock(raw("iphone-home")), STAT_TILES, 1180, radius=60)
    lift(c, tiles, x0(8) + (W - tiles.width) / 2, 2200)
    sky.owl(raw_dir, "idle", l + 210, top + 24, perch)

    # 10 · Asleep in the moon, everything ticked off, free to start.
    sky.moon(x0(9) + W / 2 - 20, 1000, 300)
    sky.owl(raw_dir, "sleep", x0(9) + W / 2 + 70, 1262, 300)
    checklist(c, x0(9) + W / 2, 1540, ["Buy and sell zones", "Instant price alerts", "27 smart alerts", "Odds for every plan", "Widgets & Apple Watch", "Import from any broker"])
    pill(c, x0(9) + W / 2, 2460, "Start free")

    for index, (title, subline) in enumerate([
        ("Buy the *dip*.\nNever miss it.", "Dippy watches your stocks day and night."),
        ("Draw your\n*buy zone*", "Drag two handles. That's your whole plan."),
        ("It dips.\n*Dippy taps you.*", "An alert the second a stock enters your zone."),
        ("Know your *odds*\nbefore you buy", "See how likely each plan is to trigger."),
        ("*27* smart alerts,\nplain English", "Dips, trends, RSI, and stops, each explained."),
        ("Your plans,\nalways *in sight*", "Live widgets with your zones and today's movers."),
        ("Your portfolio,\n*on your wrist*", "Plans, prices, and charts on Apple Watch."),
        ("Your portfolio\nin *seconds*", "Import a CSV from any broker. No login needed."),
        ("All your stocks,\n*one calm place*", "Value, returns, and dividends at a glance."),
        ("Sleep well.\n*Dippy's on watch.*", "Free to start. Go Pro for every alert."),
    ]):
        headline(c, x0(index), W, title, subline)

    names = ["01-buy-the-dip", "02-buy-zone", "03-alert", "04-odds", "05-smart-alerts",
             "06-widgets", "07-apple-watch", "08-import", "09-portfolio", "10-start-free"]
    return list(zip(names, sky.frames())), sky.canvas


# MARK: - iPad

def ipad_story(raw, raw_dir):
    W, H = 2064, 2752
    u = W / 1320
    icon = Image.open(raw_dir / "app-icon.png")
    sky = Sky((W, H), 5)
    x0 = sky.x0
    c = sky.canvas
    tablet_w, top = 1700, 900
    perch = 300

    def tablet(index, screen):
        return device(c, ipad(fix_ipad_status(screen), tablet_w), x0(index) + W / 2, top, u)

    l, r = tablet(0, raw("ipad-home"))
    banner = notification(1400, icon, "NVDA entered your buy zone", ["Now $209.35, inside $206.35–$217.80.", "Your plan: buy a little."])
    lift(c, banner, x0(0) + (W - banner.width) / 2, 1560, u)
    sky.owl(raw_dir, "idle", r - 260, top + 28, perch)

    l, r = tablet(1, raw("ipad-stock"))
    zone = card(fix_iphone_clock(raw("iphone-plan")), ZONE_CARD, 1300, radius=60)
    lift(c, zone, x0(1) + (W - zone.width) / 2, 1560, u)
    sky.owl(raw_dir, "look-down", l + 260, top + 28, perch)

    l, r = tablet(2, raw("ipad-alerts"))
    plan = card(fix_iphone_clock(raw("iphone-stock")), PLAN_CARD, 1400, radius=60)
    lift(c, plan, x0(2) + (W - plan.width) / 2, 1820, u)
    sky.owl(raw_dir, "wings", r - 280, top + 28, perch)

    l, r = tablet(3, raw("ipad-watchlist"))
    sky.owl(raw_dir, "look-left", r - 260, top + 28, perch)

    sky.moon(x0(4) + W / 2 - 20, 980, 330)
    sky.owl(raw_dir, "sleep", x0(4) + W / 2 + 80, 1268, 330)
    checklist(c, x0(4) + W / 2, 1480, ["Buy and sell zones", "Instant price alerts", "27 smart alerts", "Odds for every plan", "Widgets & Apple Watch", "Import from any broker"], scale=1.05)
    pill(c, x0(4) + W / 2, 2420, "Start free", scale=1.15)

    for index, (title, subline) in enumerate([
        ("Buy the *dip*.\nNever miss it.", "Dippy watches your stocks day and night."),
        ("Draw your\n*buy zone*", "Drag two handles. That's your whole plan."),
        ("It dips.\n*Dippy taps you.*", "See your odds, and get an alert the second it's in your zone."),
        ("Every stock,\n*one calm list*", "Prices, trends, and how close each plan is."),
        ("Sleep well.\n*Dippy's on watch.*", "Free to start. Go Pro for every alert."),
    ]):
        headline(c, x0(index), W, title, subline, size=160)

    names = ["01-buy-the-dip", "02-buy-zone", "03-alert", "04-watchlist", "05-start-free"]
    return list(zip(names, sky.frames())), sky.canvas


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
            draw.text((x, 30 * k), part, font=caption_font, fill=WATCH_GREEN if index % 2 else WHITE)
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


def panorama(canvas, path, height=600):
    canvas.convert("RGB").resize((round(canvas.width * height / canvas.height), height), Image.LANCZOS).save(path, optimize=True)


def main(raw_dir, out_dir):
    raw = Raw(raw_dir)
    phone, phone_canvas = iphone_story(raw, raw_dir)
    save(phone, out_dir / "iPhone-6.9")
    save(phone, out_dir / "iPhone-6.5", size=(1284, 2778))
    panorama(phone_canvas, out_dir / "preview-iphone.png")
    tablet, tablet_canvas = ipad_story(raw, raw_dir)
    save(tablet, out_dir / "iPad-13")
    panorama(tablet_canvas, out_dir / "preview-ipad.png")
    wrist = watch_set(raw)
    save(wrist, out_dir / "AppleWatch-Ultra")
    contact_sheet(wrist, out_dir / "preview-watch.png", height=514)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
