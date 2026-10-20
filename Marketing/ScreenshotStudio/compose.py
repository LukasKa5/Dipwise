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

class IconLine:
    """Dippy's price line, drawn exactly like the app icon's: a thick mint stroke with a soft glow, ending in the
    icon's glowing dot. One line runs through every image, so swiping follows a single chart."""

    def __init__(self, sky, chapters):
        self.sky = sky
        self.points = []
        for index, chapter in enumerate(chapters):
            self.points += [(sky.W * index + x, y) for x, y in chapter]

    def y(self, x):
        pts = self.points
        if x <= pts[0][0]:
            return pts[0][1]
        for i in range(len(pts) - 1):
            if pts[i][0] <= x <= pts[i + 1][0]:
                p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
                t = (x - p1[0]) / (p2[0] - p1[0])
                return 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t * t
                              + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t ** 3)
        return pts[-1][1]

    def draw(self, until=None):
        canvas = self.sky.canvas
        u = self.sky.unit
        end = until or canvas.width
        points = [(x, self.y(x)) for x in range(0, round(end) + 1, 3)]
        glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).line(points, fill=MINT + (120,), width=round(46 * u), joint="curve")
        canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(26 * u)))
        stroke = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(stroke).line(points, fill=MINT + (255,), width=round(17 * u), joint="curve")
        canvas.alpha_composite(stroke)

    def dot(self, x, rings=False):
        """The icon's end dot: white center, mint ring, and a soft halo; optionally with alert rings."""
        canvas = self.sky.canvas
        u = self.sky.unit
        y = self.y(x)
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        if rings:
            for r, a in [(150, 45), (106, 90)]:
                draw.ellipse((x - r * u, y - r * u, x + r * u, y + r * u), outline=MINT + (a,), width=round(6 * u))
        draw.ellipse((x - 62 * u, y - 62 * u, x + 62 * u, y + 62 * u), fill=MINT + (60,))
        canvas.alpha_composite(layer)
        draw = ImageDraw.Draw(canvas)
        draw.ellipse((x - 30 * u, y - 30 * u, x + 30 * u, y + 30 * u), fill=MINT)
        draw.ellipse((x - 15 * u, y - 15 * u, x + 15 * u, y + 15 * u), fill=WHITE)

    def owl(self, raw_dir, pose, cx, height):
        """Dippy perched on the line, feet on the stroke like in the icon."""
        self.sky.owl(raw_dir, pose, cx, self.y(cx) + height * 0.035, height)


def bubble(canvas, text, tail_x, tail_y, unit=1.0, side="left", max_width=520, bounds=None):
    """A white speech bubble with Dippy's line, its tail pointing down at him."""
    label_font = font(ROUNDED, 46 * unit, "Bold")
    draw = ImageDraw.Draw(canvas)
    lines = balanced(draw, text, label_font, max_width * unit)
    w = max(draw.textlength(l, font=label_font) for l in lines) + 64 * unit
    lh = 58 * unit
    h = round(len(lines) * lh + 40 * unit)
    tail = round(30 * unit)
    layer = Image.new("RGBA", (round(w), h + tail), (0, 0, 0, 0))
    layer.paste(WHITE, (0, 0), rounded_mask((round(w), h), round(34 * unit)))
    ld = ImageDraw.Draw(layer)
    tx = round(w * (0.28 if side == "left" else 0.72))
    ld.polygon([(tx - 22 * unit, h - 2), (tx + 22 * unit, h - 2), (tx - (8 if side == "left" else -8) * unit, h + tail)], fill=WHITE)
    for i, l in enumerate(lines):
        lw = ld.textlength(l, font=label_font)
        ld.text(((w - lw) / 2, 18 * unit + i * lh), l, font=label_font, fill=INK)
    x = tail_x - tx
    if bounds:
        x = min(max(x, bounds[0]), bounds[1] - w)
    shadowed(canvas, layer, x, tail_y - h - tail, blur=round(24 * unit), offset=round(12 * unit), opacity=110)


# Regions of the raw captures lifted out as cards: (left, top, right, bottom).
PLAN_CARD = (60, 1935, 1260, 2620)
ZONE_CARD = (60, 1190, 1260, 2310)
ZONE_CHART_ONLY = (60, 1440, 1260, 2230)
STAT_TILES = (108, 1838, 1212, 2182)
WIDGET_PORTFOLIO = (155, 229, 1165, 699)
WIDGET_PLANS = (155, 806, 1165, 1277)
WIDGET_SMALL_LEFT = (155, 1383, 626, 1853)
WIDGET_SMALL_RIGHT = (694, 1383, 1165, 1853)
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


def app_icon_tile(icon, size):
    mark = icon.convert("RGBA").resize((size, size), Image.LANCZOS)
    tile = Image.new("RGBA", mark.size, (0, 0, 0, 0))
    tile.paste(mark, (0, 0), rounded_mask(mark.size, round(size * 0.225)))
    return tile


def screen_tile(screen, width, unit=1.0, corner=0.125):
    """A real screen, frameless: Apple's display corner shape, a hairline edge, and a soft shadow, no drawn bezel."""
    screen = screen.convert("RGB")
    height = round(screen.height * width / screen.width)
    image = screen.resize((width, height), Image.LANCZOS)
    radius = round(width * corner)
    tile = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    tile.paste(image, (0, 0), rounded_mask((width, height), radius))
    edge = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((1, 1, width - 2, height - 2), radius=radius, outline=(255, 255, 255, 40), width=max(2, round(3 * unit)))
    tile.alpha_composite(edge)
    return tile


def place_screen(canvas, tile, cx, top, unit=1.0):
    shadowed(canvas, tile, cx - tile.width / 2, top, blur=round(70 * unit), offset=round(36 * unit), opacity=150)


def chapter(canvas, ox, frame_width, label, top, raw_dir, unit=1.0):
    """The small header above each headline: a tiny Dippy and a mint chapter label, like a story's page marker."""
    draw = ImageDraw.Draw(canvas)
    label_font = font(ROUNDED, 40 * unit, "Bold")
    text = label.upper()
    tracking = 5 * unit
    text_w = sum(draw.textlength(ch, font=label_font) + tracking for ch in text) - tracking
    owl_h = round(64 * unit)
    owl_img = Image.open(raw_dir / "owl-idle.png").convert("RGBA")
    owl_img = owl_img.resize((round(owl_img.width * owl_h / owl_img.height), owl_h), Image.LANCZOS)
    gap = 18 * unit
    total = owl_img.width + gap + text_w
    x = ox + (frame_width - total) / 2
    canvas.alpha_composite(owl_img, (round(x), round(top)))
    x += owl_img.width + gap
    for ch in text:
        draw.text((x, top + owl_h * 0.18), ch, font=label_font, fill=MINT)
        x += draw.textlength(ch, font=label_font) + tracking


def title(canvas, ox, frame_width, text, top, size, unit=1.0):
    """The headline: bold rounded type, white with *highlighted* words in mint, centered, no supporting line."""
    draw = ImageDraw.Draw(canvas)
    head_font = font(ROUNDED, size, "Bold")
    widest = max(draw.textlength(line.replace("*", ""), font=head_font) for line in text.split("\n"))
    if widest > frame_width * 0.88:
        size = size * frame_width * 0.88 / widest
        head_font = font(ROUNDED, size, "Bold")
    y = top
    for line in text.split("\n"):
        parts = line.split("*")
        x = ox + (frame_width - sum(draw.textlength(part, font=head_font) for part in parts)) / 2
        for index, part in enumerate(parts):
            draw.text((x, y), part, font=head_font, fill=MINT if index % 2 else WHITE)
            x += draw.textlength(part, font=head_font)
        y += round(size * 1.06)
    return y


def plain_sky(size, count):
    """The icon's navy, top to bottom, and nothing else."""
    width, height = size[0] * count, size[1]
    strip = Image.new("RGB", (1, 512))
    for y in range(512):
        t = y / 511
        a, b, k = (NIGHT_TOP, NIGHT_MIDDLE, t / 0.55) if t < 0.55 else (NIGHT_MIDDLE, NIGHT_BOTTOM, (t - 0.55) / 0.45)
        strip.putpixel((0, y), tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)))
    return strip.resize((width, height), Image.BICUBIC).convert("RGBA")


class Frames:
    """Separate images that share one look; each is drawn on its own canvas."""

    def __init__(self, size, count):
        self.W, self.H = size
        self.count = count
        self.images = [plain_sky(size, 1) for _ in range(count)]


def iphone_story(raw, raw_dir):
    W, H = 1320, 2868
    icon = Image.open(raw_dir / "app-icon.png")
    frames = []

    def frame():
        return plain_sky((W, H), 1)

    def standard(label, headline_text, screen, width=1040, top=720):
        c = frame()
        chapter(c, 0, W, label, 150, raw_dir)
        title(c, 0, W, headline_text, 255, 132)
        place_screen(c, screen_tile(screen, width), W / 2, top)
        return c

    # 1 · The icon, life-size: Dippy on his glowing line, the real alert arriving above him.
    c = frame()
    sky = Sky((W, H), 1)
    sky.canvas = c
    line = IconLine(sky, [[(-200, 1960), (160, 2240), (420, 2420), (640, 2440), (860, 2330), (1020, 2050), (1130, 1830), (1240, 1880), (1500, 2100)]])
    line.draw()
    line.dot(1130)
    title(c, 0, W, "Buy the *dip*.\nNever miss it.", 210, 150)
    banner = notification(1180, icon, "NVDA entered your buy zone", ["Now $209.35, inside $206.35–$217.80.", "Your plan: buy a little."])
    lift(c, banner, (W - banner.width) / 2, 760)
    line.owl(raw_dir, "wave", 560, 860)
    frames.append(("01-buy-the-dip", c))

    frames.append(("02-buy-zone", standard("Plan", "Draw your\n*buy zone*", fix_iphone_clock(raw("iphone-plan")))))
    frames.append(("03-odds", standard("Odds", "Know your *odds*\nbefore you buy", fix_iphone_clock(raw("iphone-stock")))))
    frames.append(("04-alert", standard("Alert", "It dips.\n*Dippy taps you.*", clean_lock_screen(raw("scene-lock")))))
    frames.append(("05-profile", standard("Your profile", "See what your\n*broker sees*", fix_iphone_clock(raw("iphone-profile")))))
    frames.append(("06-smart-alerts", standard("Signals", "*27* smart alerts,\nplain English", fix_iphone_clock(raw("iphone-plan-smart")))))

    # 7 · Widgets, shown full size on the navy, without a phone around them.
    c = frame()
    chapter(c, 0, W, "Home Screen", 150, raw_dir)
    title(c, 0, W, "Your plans,\nalways *in sight*", 255, 132)
    scene = raw("scene-widgets")
    wtop = 760
    big = card(scene, WIDGET_PORTFOLIO, 1120, radius=88)
    lift(c, big, (W - big.width) / 2, wtop)
    plans = card(scene, WIDGET_PLANS, 1120, radius=88)
    lift(c, plans, (W - plans.width) / 2, wtop + big.height + 40)
    small = 540
    y = wtop + big.height + plans.height + 80
    lift(c, card(scene, WIDGET_SMALL_LEFT, small, radius=96), W / 2 - 20 - small, y)
    lift(c, card(scene, WIDGET_SMALL_RIGHT, small, radius=96), W / 2 + 20, y)
    frames.append(("07-widgets", c))

    # 8 · Apple Watch.
    c = frame()
    chapter(c, 0, W, "Apple Watch", 150, raw_dir)
    title(c, 0, W, "Your portfolio,\n*on your wrist*", 255, 132)
    wrist = watch(raw("watch-today"), 900)
    device(c, wrist, W / 2 - 18, 960)
    frames.append(("08-apple-watch", c))

    frames.append(("09-import", standard("Import", "Your portfolio\nin *seconds*", fix_iphone_clock(raw("iphone-import")))))

    # 10 · Asleep under the moon.
    c = frame()
    sky = Sky((W, H), 1)
    sky.canvas = c
    sky.moon(W - 300, 1050, 96)
    line = IconLine(sky, [[(-200, 2280), (300, 2160), (640, 2120), (980, 2160), (1500, 2260)]])
    line.draw()
    title(c, 0, W, "Sleep well.\n*Dippy's on watch.*", 210, 150)
    line.owl(raw_dir, "sleep", 640, 760)
    draw = ImageDraw.Draw(c)
    sub = font(ROUNDED, 54, "Medium")
    text = "Free to start. Go Pro for every alert."
    draw.text(((W - draw.textlength(text, font=sub)) / 2, 2400), text, font=sub, fill=SOFT)
    lift(c, app_icon_tile(icon, 190), (W - 190) / 2, 2540)
    frames.append(("10-start-free", c))

    panorama = Image.new("RGBA", (W * len(frames), H))
    for index, (_, image) in enumerate(frames):
        panorama.paste(image, (W * index, 0))
    return frames, panorama


# MARK: - iPad

def ipad_story(raw, raw_dir):
    W, H = 2064, 2752
    u = W / 1320
    icon = Image.open(raw_dir / "app-icon.png")
    frames = []

    def frame():
        return plain_sky((W, H), 1)

    def standard(label, headline_text, screen, width=1700, top=780):
        c = frame()
        chapter(c, 0, W, label, 160, raw_dir, unit=1.3)
        title(c, 0, W, headline_text, 290, 160)
        tile = screen_tile(fix_ipad_status(screen), width, u, corner=0.045)
        place_screen(c, tile, W / 2, top, u)
        return c

    c = frame()
    sky = Sky((W, H), 1)
    sky.canvas = c
    line = IconLine(sky, [[(-200, 2000), (300, 2240), (700, 2380), (1060, 2400), (1380, 2250), (1620, 1960), (1780, 1820), (1960, 1880), (2300, 2100)]])
    line.draw()
    line.dot(1780)
    title(c, 0, W, "Buy the *dip*.\nNever miss it.", 220, 180)
    banner = notification(1500, icon, "NVDA entered your buy zone", ["Now $209.35, inside $206.35–$217.80.", "Your plan: buy a little."])
    lift(c, banner, (W - banner.width) / 2, 820, u)
    line.owl(raw_dir, "wave", 860, 1080)
    frames.append(("01-buy-the-dip", c))

    frames.append(("02-buy-zone", standard("Plan", "Draw your *buy zone*", raw("ipad-stock"))))
    frames.append(("03-alert", standard("Odds & alerts", "Know your odds.\n*Dippy taps you.*", raw("ipad-alerts"))))
    frames.append(("04-watchlist", standard("Watchlist", "Every stock,\n*one calm list*", raw("ipad-watchlist"))))

    c = frame()
    sky = Sky((W, H), 1)
    sky.canvas = c
    sky.moon(W - 420, 1040, 130)
    line = IconLine(sky, [[(-200, 2260), (500, 2140), (1000, 2100), (1500, 2140), (2300, 2240)]])
    line.draw()
    title(c, 0, W, "Sleep well.\n*Dippy's on watch.*", 220, 180)
    line.owl(raw_dir, "sleep", 1000, 900)
    draw = ImageDraw.Draw(c)
    sub = font(ROUNDED, 70, "Medium")
    text = "Free to start. Go Pro for every alert."
    draw.text(((W - draw.textlength(text, font=sub)) / 2, 2370), text, font=sub, fill=SOFT)
    lift(c, app_icon_tile(icon, 190), (W - 190) / 2, 2520, u)
    frames.append(("05-start-free", c))

    panorama = Image.new("RGBA", (W * len(frames), H))
    for index, (_, image) in enumerate(frames):
        panorama.paste(image, (W * index, 0))
    return frames, panorama


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
