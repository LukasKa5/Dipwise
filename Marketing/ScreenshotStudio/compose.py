#!/usr/bin/env python3
"""Composes the Dipwise App Store screenshots for iPhone, iPad, and Apple Watch.

Each set is one continuous night panorama, so swiping through the App Store page tells Dippy's story. His price
line, drawn exactly like the charts in the app, runs from the first image to the last: it drifts down, drops into
your buy zone, pings the alert, climbs back out, and ends on a peak where Dippy falls asleep under the moon.

The devices stand behind that horizon like a skyline, so the line hides the least important bottom of each screen
and the part that matters sits big and readable. Dippy stands on the line in every image, reacting to what happens.
Each image still works on its own: one short headline, one screen, and at most one enlarged moment from it.

Usage: python3 compose.py <raw folder> <output folder>
Writes iPhone-6.9 (1320 × 2868), iPhone-6.5 (1284 × 2778), iPad-13 (2064 × 2752), and AppleWatch-Ultra
(422 × 514) folders into the output folder, plus a panorama preview of each set.
"""

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# The app's own colors (Shared/Brand.swift).
NIGHT_TOP = (22, 64, 90)
NIGHT_MIDDLE = (12, 36, 56)
NIGHT_BOTTOM = (6, 15, 28)
WATCH_NAVY = NIGHT_MIDDLE
GREEN = (24, 196, 124)
LINE_GREEN = (46, 214, 142)
GROUND = (8, 22, 38)
WHITE = (255, 255, 255)
SOFT = (186, 200, 215)
INK = (10, 27, 46)
AMBER = (255, 178, 36)

ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
TEXT = "/System/Library/Fonts/SFNS.ttf"


def font(path, size, weight):
    f = ImageFont.truetype(path, round(size))
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


# MARK: - The night

class Story:
    """One panorama: the sky, Dippy's price line across every image, and the ground beneath it."""

    def __init__(self, frame, count, line, seed=7):
        self.W, self.H = frame
        self.count = count
        self.points = line
        width = self.W * count
        self.canvas = self.sky((width, self.H), seed)
        self.unit = self.W / 1320

    def x0(self, index):
        return self.W * index

    def sky(self, size, seed):
        """The app's night gradient, with a scatter of small stars in the upper sky."""
        width, height = size
        strip = Image.new("RGB", (1, 512))
        for y in range(512):
            t = y / 511
            a, b, k = (NIGHT_TOP, NIGHT_MIDDLE, t / 0.55) if t < 0.55 else (NIGHT_MIDDLE, NIGHT_BOTTOM, (t - 0.55) / 0.45)
            strip.putpixel((0, y), tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)))
        image = strip.resize(size, Image.BICUBIC).convert("RGBA")
        stars = Image.new("RGBA", size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(stars)
        rng = random.Random(seed)
        unit = self.W / 1320
        for _ in range(int(width / 1320 * 60)):
            x, y = rng.uniform(0, width), rng.uniform(0, height * 0.5)
            r = rng.choice([1.3, 1.6, 2, 2, 2.6, 3.4]) * unit
            draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, rng.randint(40, 150)))
        image.alpha_composite(stars)
        return image

    def y(self, x):
        """The line's height at panorama x: a smooth Catmull-Rom curve through its points."""
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

    def ground(self):
        """The area under the line, filled the way the app fills its charts: green fading into deep navy."""
        width, height = self.canvas.size
        points = [(x, self.y(x)) for x in range(0, width + 1, 4)]
        mask = Image.new("L", (width, height), 0)
        ImageDraw.Draw(mask).polygon(points + [(width, height), (0, height)], fill=255)
        fill = Image.new("RGBA", (width, height), GROUND + (255,))
        # The chart's green wash, strongest at the line and fading out below it.
        span = 420 * self.unit
        wash_layer = Image.new("RGBA", (width, height), GREEN + (0,))
        offset = Image.new("L", (width, height), 0)
        od = ImageDraw.Draw(offset)
        for step in range(0, int(span), 6):
            alpha = int(64 * (1 - step / span) ** 1.6)
            od.line([(x, y + step) for x, y in points], fill=alpha, width=7)
        wash_layer.putalpha(offset)
        fill.alpha_composite(wash_layer)
        self.canvas.paste(fill, (0, 0), mask)
        # The line itself: a soft glow and a crisp stroke.
        glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        ImageDraw.Draw(glow).line(points, fill=LINE_GREEN + (150,), width=round(30 * self.unit), joint="curve")
        self.canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(18 * self.unit)))
        crisp = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        ImageDraw.Draw(crisp).line(points, fill=LINE_GREEN + (255,), width=round(11 * self.unit), joint="curve")
        self.canvas.alpha_composite(crisp)

    def zone(self, x_from, x_to, low, high, label=None):
        """A buy zone across the ground, drawn like the app's zone chart: a soft green band between two lines,
        with a capsule label like the app's High and Low handles."""
        width, height = self.canvas.size
        band = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(band)
        draw.rectangle((x_from, high, x_to, low), fill=GREEN + (52,))
        for y in (high, low):
            draw.line([(x_from, y), (x_to, y)], fill=GREEN + (230,), width=round(6 * self.unit))
        # Fades in and out at its ends instead of stopping hard.
        fade = Image.new("L", (width, height), 255)
        fd = ImageDraw.Draw(fade)
        edge = round(160 * self.unit)
        for i in range(edge):
            a = 255 * i // edge
            fd.line([(x_from + i, 0), (x_from + i, height)], fill=a)
            fd.line([(x_to - i, 0), (x_to - i, height)], fill=a)
        band.putalpha(Image.composite(band.split()[3], Image.new("L", band.size, 0), fade))
        self.canvas.alpha_composite(band)
        if label:
            capsule(self.canvas, label[0], (high + low) / 2, label[1], self.unit)

    def ping(self, x):
        """The moment the price enters the zone: the app's chart dot with rings spreading out."""
        y = self.y(x)
        u = self.unit
        rings = Image.new("RGBA", self.canvas.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(rings)
        for r, a in [(150, 40), (105, 80), (66, 130)]:
            draw.ellipse((x - r * u, y - r * u, x + r * u, y + r * u), outline=LINE_GREEN + (a,), width=round(5 * u))
        self.canvas.alpha_composite(rings)
        halo = Image.new("RGBA", self.canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse((x - 46 * u, y - 46 * u, x + 46 * u, y + 46 * u), fill=LINE_GREEN + (90,))
        self.canvas.alpha_composite(halo.filter(ImageFilter.GaussianBlur(10 * u)))
        draw = ImageDraw.Draw(self.canvas)
        draw.ellipse((x - 28 * u, y - 28 * u, x + 28 * u, y + 28 * u), fill=LINE_GREEN)
        draw.ellipse((x - 12 * u, y - 12 * u, x + 12 * u, y + 12 * u), fill=WHITE)

    def moon(self, cx, cy, r):
        """A soft crescent with a gentle halo, like the app's sleeping-market moon."""
        halo = Image.new("RGBA", self.canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse((cx - r * 2.6, cy - r * 2.6, cx + r * 2.6, cy + r * 2.6), fill=(255, 236, 190, 26))
        self.canvas.alpha_composite(halo.filter(ImageFilter.GaussianBlur(r * 0.8)))
        s = 4
        disc = Image.new("L", (r * 2 * s, r * 2 * s), 0)
        ImageDraw.Draw(disc).ellipse((0, 0, r * 2 * s - 1, r * 2 * s - 1), fill=245)
        ImageDraw.Draw(disc).ellipse((round(r * 0.6 * s), round(-r * 0.32 * s), round(r * 2.6 * s), round(r * 1.68 * s)), fill=0)
        disc = disc.resize((r * 2, r * 2), Image.LANCZOS)
        self.canvas.paste((255, 236, 196), (cx - r, cy - r), disc)

    def owl(self, raw_dir, pose, cx, height, lift=0):
        """Dippy standing on the line at panorama x = cx."""
        image = Image.open(raw_dir / f"owl-{pose}.png").convert("RGBA")
        image = image.resize((round(image.width * height / image.height), round(height)), Image.LANCZOS)
        feet = self.y(cx) + height * 0.03 - lift
        shade = Image.new("RGBA", self.canvas.size, (0, 0, 0, 0))
        body = height * 0.36
        ImageDraw.Draw(shade).ellipse((cx - body, feet - height * 0.04, cx + body, feet + height * 0.05), fill=(0, 0, 0, 110))
        self.canvas.alpha_composite(shade.filter(ImageFilter.GaussianBlur(height * 0.03)))
        paste_clipped(self.canvas, image, round(cx - image.width / 2), round(feet - image.height))

    def frames(self):
        return [self.canvas.crop((self.W * i, 0, self.W * (i + 1), self.H)) for i in range(self.count)]


def capsule(canvas, cx, cy, text, unit=1.0):
    """The app's zone label: a solid green capsule with white bold text."""
    label_font = font(ROUNDED, 44 * unit, "Bold")
    draw = ImageDraw.Draw(canvas)
    w = draw.textlength(text, font=label_font) + 64 * unit
    h = round(80 * unit)
    layer = Image.new("RGBA", (round(w), h), (0, 0, 0, 0))
    layer.paste(GREEN, (0, 0), rounded_mask(layer.size, h // 2))
    ImageDraw.Draw(layer).text((32 * unit, h * 0.17), text, font=label_font, fill=WHITE)
    shadowed(canvas, layer, cx - w / 2, cy - h / 2, blur=round(16 * unit), offset=round(8 * unit), opacity=120)


def tags(canvas, cx, top, labels, columns, unit=1.0, dots=None):
    """Small dark tiles with a colored dot, like the app's tiles on navy."""
    label_font = font(ROUNDED, 44 * unit, "Bold")
    draw = ImageDraw.Draw(canvas)
    height, gap = round(92 * unit), round(20 * unit)
    y = top
    for start in range(0, len(labels), columns):
        row = labels[start:start + columns]
        widths = [draw.textlength(label, font=label_font) + (100 if dots else 70) * unit for label in row]
        x = cx - (sum(widths) + gap * (len(row) - 1)) / 2
        for index, (label, w) in enumerate(zip(row, widths)):
            tile = Image.new("RGBA", (round(w), height), (0, 0, 0, 0))
            tile.paste((255, 255, 255, 30), (0, 0), rounded_mask(tile.size, height // 2))
            td = ImageDraw.Draw(tile)
            td.rounded_rectangle((1, 1, tile.width - 2, height - 2), radius=height // 2, outline=(255, 255, 255, 40), width=2)
            tx = 35 * unit
            if dots:
                color = dots[(start + index) % len(dots)]
                td.ellipse((32 * unit, height / 2 - 11 * unit, 54 * unit, height / 2 + 11 * unit), fill=color)
                tx = 70 * unit
            td.text((tx, height * 0.18), label, font=label_font, fill=WHITE)
            canvas.alpha_composite(tile, (round(x), round(y)))
            x += w + gap
        y += height + gap


# MARK: - Text

def headline(canvas, ox, frame_width, title, subline, size=140, top=None):
    """A bold two-line headline with *highlighted* words in green and one short supporting line, centered in the
    image that starts at x = ox. Returns the y just below the text."""
    width = frame_width
    draw = ImageDraw.Draw(canvas)
    head_font = font(ROUNDED, size, "Heavy")
    widest = max(draw.textlength(line.replace("*", ""), font=head_font) for line in title.split("\n"))
    if widest > width * 0.9:
        size = size * width * 0.9 / widest
        head_font = font(ROUNDED, size, "Heavy")
    sub_font = font(TEXT, size * 0.36, "Medium")
    y = top if top is not None else round(size * 1.0)
    for line in title.split("\n"):
        parts = line.split("*")
        x = ox + (width - sum(draw.textlength(part, font=head_font) for part in parts)) / 2
        for index, part in enumerate(parts):
            draw.text((x, y), part, font=head_font, fill=GREEN if index % 2 else WHITE)
            x += draw.textlength(part, font=head_font)
        y += round(size * 1.08)
    if subline:
        y += round(size * 0.18)
        for line in balanced(draw, subline, sub_font, width * 0.86):
            w = draw.textlength(line, font=sub_font)
            draw.text((ox + (width - w) / 2, y), line, font=sub_font, fill=SOFT)
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
STAT_TILES = (108, 1838, 1212, 2182)
# The NVDA plan card in the high-resolution watch render.
WATCH_PLAN = (0, 561, 1170, 1062)


class Raw:
    def __init__(self, folder):
        self.folder = folder

    def __call__(self, name):
        return Image.open(self.folder / f"{name}.png")


def line(frame_width, chapters, dy=0):
    """Turns per-image points [(x within the image, y), …] into one panorama line, shifted down by dy."""
    points = []
    for index, chapter in enumerate(chapters):
        points += [(frame_width * index + x, y + dy) for x, y in chapter]
    return points


def clean_lock_screen(screen):
    """Hides the flashlight and camera buttons, which would otherwise poke out right at the horizon."""
    screen = screen.convert("RGB")
    strip = screen.crop((0, 2300, screen.width, 2340)).resize((screen.width, screen.height - 2300), Image.BICUBIC)
    screen.paste(strip, (0, 2300))
    return screen


def device(canvas, layer, cx, top, unit=1.0):
    x = cx - layer.width / 2
    shadowed(canvas, layer, x, top, blur=round(50 * unit), offset=round(30 * unit), opacity=150)
    return x


def iphone_story(raw, raw_dir):
    W, H = 1320, 2868
    icon = Image.open(raw_dir / "app-icon.png")
    story = Story((W, H), 10, line(W, [
        # 1 · Calm, drifting down.
        [(-120, 2200), (180, 2250), (430, 2200), (700, 2270), (1000, 2250), (1240, 2320)],
        # 2 · Falling toward the zone.
        [(160, 2330), (420, 2300), (700, 2380), (960, 2400), (1200, 2500)],
        # 3 · In the zone: the bottom, the ping, then a turn.
        [(150, 2560), (420, 2590), (700, 2560), (980, 2570), (1240, 2520)],
        # 4 · Climbing out.
        [(220, 2450), (520, 2400), (820, 2340), (1160, 2300)],
        # 5–8 · Steady, with small waves.
        [(160, 2290), (480, 2240), (820, 2280), (1150, 2230)],
        [(160, 2260), (480, 2220), (820, 2250), (1150, 2220)],
        [(160, 2250), (480, 2210), (820, 2240), (1150, 2200)],
        [(160, 2230), (480, 2190), (820, 2220), (1150, 2180)],
        # 9 · Rising.
        [(180, 2200), (480, 2150), (800, 2160), (1120, 2090)],
        # 10 · The peak where Dippy sleeps.
        [(150, 2060), (420, 2030), (660, 2010), (900, 2050), (1200, 2110), (1500, 2120)],
    ], dy=200))
    x0 = story.x0
    phone_w, phone_top = 880, 760
    c = story.canvas

    # Devices first: they stand behind the horizon.
    device(c, iphone(fix_iphone_clock(raw("iphone-stock")), phone_w), x0(0) + 780, phone_top)
    device(c, iphone(fix_iphone_clock(raw("iphone-zones")), phone_w), x0(1) + 560, phone_top)
    device(c, iphone(clean_lock_screen(raw("scene-lock")), phone_w), x0(2) + 780, phone_top)
    device(c, iphone(fix_iphone_clock(raw("iphone-alerts")), phone_w), x0(3) + 560, phone_top)
    device(c, iphone(fix_iphone_clock(raw("iphone-smart")), phone_w), x0(4) + 760, phone_top)
    device(c, iphone(fix_iphone_clock(raw("iphone-import")), phone_w), x0(7) + 660, phone_top)
    device(c, iphone(fix_iphone_clock(raw("iphone-home")), phone_w), x0(8) + 560, phone_top)
    wrist = watch(raw("watch-today"), 640, strap=300)
    device(c, wrist, x0(6) + 600, 880 - 300)

    # 6 · Widgets float above the horizon instead of sitting in a phone.
    scene = raw("scene-widgets")
    big = card(scene, (155, 229, 1165, 699), 1160, radius=86)
    shadowed(c, big, x0(5) + (W - big.width) / 2, 760, blur=40, offset=28, opacity=170)
    small = 560
    left = card(scene, (155, 806, 626, 1277), small, radius=96)
    right = card(scene, (694, 806, 1165, 1277), small, radius=96)
    shadowed(c, left, x0(5) + W / 2 - 20 - small, 760 + big.height + 40, blur=40, offset=28, opacity=170)
    shadowed(c, right, x0(5) + W / 2 + 20, 760 + big.height + 40, blur=40, offset=28, opacity=170)

    story.moon(x0(9) + 1150, 640, 56)
    story.ground()

    # The zone and the alert.
    story.zone(x0(1) + 540, x0(3) + 420, 2840, 2700, label=(x0(1) + 1010, "Your buy zone"))
    story.ping(x0(2) + 420)

    # Ground details.
    tags(c, x0(4) + W / 2, 2640, ["Golden cross", "RSI oversold", "52-week low", "Trailing stop"], 2,
         dots=[AMBER, LINE_GREEN, (120, 170, 255), (255, 110, 110)])
    tags(c, x0(7) + W / 2, 2590, ["Robinhood", "Fidelity", "Schwab", "Vanguard", "E*TRADE", "IBKR", "Trading 212", "DEGIRO"], 4)
    pill(c, x0(9) + W / 2, 2560, "Start free")

    # Cards lifted out of the screens.
    banner = notification(1180, icon, "NVDA entered your buy zone", ["Now $209.35, inside $206.35–$217.80.", "Your plan: buy a little."])
    shadowed(c, banner, x0(0) + (W - banner.width) / 2, 1520, blur=40, offset=26, opacity=170)
    lift = card(fix_iphone_clock(raw("iphone-zones")), ZONE_CHART, 1080)
    shadowed(c, lift, x0(1) + 120, 1640, blur=44, offset=30, opacity=180)
    lift = card(fix_iphone_clock(raw("iphone-zones")), ODDS_CARD, 1080)
    shadowed(c, lift, x0(3) + 120, 1860, blur=44, offset=30, opacity=180)
    plan = card(raw("watch-plans"), WATCH_PLAN, 820, radius=70)
    shadowed(c, plan, x0(6) + 80, 2020, blur=44, offset=30, opacity=190)
    lift = card(fix_iphone_clock(raw("iphone-home")), STAT_TILES, 1080, radius=56)
    shadowed(c, lift, x0(8) + 120, 1940, blur=44, offset=30, opacity=180)
    checklist(c, x0(9) + W / 2, 760, ["Buy and sell zones", "Instant price alerts", "27 smart alerts", "Odds for every plan", "Widgets & Apple Watch", "Import from any broker"])

    # Dippy, reacting to each chapter.
    story.owl(raw_dir, "idle", x0(0) + 190, 360)
    story.owl(raw_dir, "wings", x0(2) + 190, 260)
    story.owl(raw_dir, "look-up", x0(5) + 660, 260)
    story.owl(raw_dir, "wink", x0(6) + 1170, 250)
    story.owl(raw_dir, "look-left", x0(7) + 1190, 230)
    story.owl(raw_dir, "sleep", x0(9) + 660, 470)

    # Headlines last, so nothing ever covers them.
    for index, (title, subline) in enumerate([
        ("Buy the *dip*.\nNever miss it.", "Dippy watches your stocks day and night."),
        ("Draw your\n*buy zone*", "Drag two handles. That's your whole plan."),
        ("It dips.\n*Dippy taps you.*", "An alert the second a stock enters your zone."),
        ("Know your *odds*\nbefore you buy", "See how likely each plan is to trigger."),
        ("*27* smart alerts,\nplain English", "Dips, trends, RSI, and stops, each explained."),
        ("Your plans,\nalways *in sight*", "Live widgets with your zones and today's movers."),
        ("Your portfolio,\n*on your wrist*", "Plans, prices, and charts on Apple Watch."),
        ("Your portfolio\nin *seconds*", "Import a CSV from any broker. No login needed."),
        ("Watch it\n*grow*", "Value, returns, and dividends in one calm place."),
        ("Sleep well.\n*Dippy's on watch.*", None),
    ]):
        headline(c, x0(index), W, title, subline)

    names = ["01-buy-the-dip", "02-buy-zone", "03-alert", "04-odds", "05-smart-alerts",
             "06-widgets", "07-apple-watch", "08-import", "09-portfolio", "10-start-free"]
    return list(zip(names, story.frames())), story.canvas


# MARK: - iPad

def ipad_story(raw, raw_dir):
    W, H = 2064, 2752
    u = W / 1320
    icon = Image.open(raw_dir / "app-icon.png")
    story = Story((W, H), 5, line(W, [
        [(-150, 2180), (400, 2230), (900, 2180), (1400, 2250), (1950, 2300)],
        [(300, 2360), (800, 2400), (1300, 2470), (1900, 2540)],
        [(250, 2560), (600, 2580), (1100, 2520), (1600, 2420), (2000, 2330)],
        [(400, 2280), (900, 2230), (1400, 2250), (1950, 2160)],
        [(400, 2100), (900, 2040), (1300, 2060), (1800, 2120), (2300, 2130)],
    ], dy=140))
    x0 = story.x0
    c = story.canvas
    tablet_w, top = 1640, 880

    device(c, ipad(fix_ipad_status(raw("ipad-home")), tablet_w), x0(0) + W / 2 + 80, top, u)
    device(c, ipad(fix_ipad_status(raw("ipad-stock")), tablet_w), x0(1) + W / 2 - 80, top, u)
    device(c, ipad(fix_ipad_status(raw("ipad-alerts")), tablet_w), x0(2) + W / 2 + 80, top, u)
    device(c, ipad(fix_ipad_status(raw("ipad-watchlist")), tablet_w), x0(3) + W / 2 - 80, top, u)
    story.moon(x0(4) + 1800, 700, 80)
    story.ground()

    story.zone(x0(1) + 900, x0(2) + 1400, 2770, 2640, label=(x0(1) + 1350, "Your buy zone"))
    story.ping(x0(2) + 600)
    pill(c, x0(4) + W / 2, 2500, "Start free", scale=1.2)

    banner = notification(1360, icon, "NVDA entered your buy zone", ["Now $209.35, inside $206.35–$217.80.", "Your plan: buy a little."])
    shadowed(c, banner, x0(0) + (W - banner.width) / 2 + 80, 1500, blur=44, offset=30, opacity=180)
    lift = card(fix_iphone_clock(raw("iphone-zones")), ZONE_CHART, 1300)
    shadowed(c, lift, x0(1) + (W - 1300) / 2 - 80, 1450, blur=50, offset=34, opacity=180)
    lift = card(fix_iphone_clock(raw("iphone-zones")), ODDS_CARD, 1300)
    shadowed(c, lift, x0(2) + (W - 1300) / 2 + 80, 1640, blur=50, offset=34, opacity=180)
    checklist(c, x0(4) + W / 2, 760, ["Buy and sell zones", "Instant price alerts", "27 smart alerts", "Odds for every plan", "Widgets & Apple Watch", "Import from any broker"], scale=1.15)

    story.owl(raw_dir, "idle", x0(0) + 190, 380)
    story.owl(raw_dir, "wings", x0(2) + 230, 300)
    story.owl(raw_dir, "look-left", x0(3) + 1930, 300)
    story.owl(raw_dir, "sleep", x0(4) + 1000, 560)

    for index, (title, subline) in enumerate([
        ("Buy the *dip*.\nNever miss it.", "Dippy watches your stocks day and night."),
        ("Draw your\n*buy zone*", "Drag two handles. That's your whole plan."),
        ("It dips.\n*Dippy taps you.*", "See your odds, and get an alert the second it's in your zone."),
        ("Every stock,\n*one calm list*", "Prices, trends, and how close each plan is."),
        ("Sleep well.\n*Dippy's on watch.*", None),
    ]):
        headline(c, x0(index), W, title, subline, size=176)

    names = ["01-buy-the-dip", "02-buy-zone", "03-alert", "04-watchlist", "05-start-free"]
    return list(zip(names, story.frames())), story.canvas


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
