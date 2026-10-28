#!/usr/bin/env python3
"""Composes the Dipwise App Store screenshots for iPhone, iPad, and Apple Watch.

Every image shares one seamless navy night sky in the app's own colors, so the set reads as a single scene as
people swipe. Dippy is the main character: he perches on top of each device and reacts to what's on it. He keeps
watch, peers down at the buy zone, flaps his wings when the alert lands, checks the odds, and in the last image
falls asleep in the crescent moon.

Each image still works on its own: one short headline, one real screen, and at most one moment from it enlarged.
The first three carry the promise, because they're the only ones people see in search results.

Usage: python3 compose.py <raw folder> <output folder>
Writes iPhone-6.9 (1320 × 2868), iPhone-6.5 (1284 × 2778), iPad-13 (2064 × 2752), and AppleWatch-Series-11
(416 × 496) folders into the output folder, plus a panorama preview of each set.
"""

import math
import random
import re
import sys
from pathlib import Path

from PIL import ImageChops, Image, ImageDraw, ImageFilter, ImageFont

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

def owl_image(raw_dir, pose, height):
    """A Dippy render trimmed to his outline, top to toe, and kept centered on his body so poses line up."""
    image = Image.open(raw_dir / f"owl-{pose}.png").convert("RGBA")
    left, top, right, bottom = image.getbbox()
    center = image.width / 2
    half = max(center - left, right - center)
    image = image.crop((round(center - half), top, round(center + half), bottom))
    return image.resize((round(image.width * height / image.height), round(height)), Image.LANCZOS)


def perch(canvas, raw_dir, pose, cx, edge, height):
    """Dippy sitting on a device's top edge, his feet just over it."""
    image = owl_image(raw_dir, pose, height)
    paste_clipped(canvas, image, round(cx - image.width / 2), round(edge - image.height * 0.97))


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
        image = owl_image(raw_dir, pose, height)
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


def fix_ipad_status(screen, time="9:41 AM"):
    """US date format in the status bar, no window title, and no window-resize corner."""
    screen = screen.convert("RGB")
    draw = ImageDraw.Draw(screen)
    background = screen.getpixel((30, 30))
    draw.rectangle((30, 6, 560, 62), fill=background)
    status = font(TEXT, 30, "Semibold")
    draw.text((50, 16), f"{time}   Wed Oct 14", font=status, fill=(0, 0, 0) if sum(background) / 3 > 128 else WHITE)
    corner = screen.getpixel((screen.width - 110, screen.height - 20))
    draw.rectangle((screen.width - 96, screen.height - 96, screen.width, screen.height), fill=corner)
    return screen


# The intro's device finish (DeviceFinish in ShowcaseSteps.swift): dark metal, a bright top edge, black glass border.
METAL_TOP, METAL_BOTTOM = (61, 61, 61), (26, 26, 26)
BUTTON_TOP, BUTTON_BOTTOM = (87, 87, 87), (41, 41, 41)


def finish_case(size, radius):
    """The metal case with its edge highlight, white 40% at the top fading to 6% at the bottom."""
    case = Image.new("RGBA", size, (0, 0, 0, 0))
    case.paste(gradient(size, METAL_TOP, METAL_BOTTOM), (0, 0), rounded_mask(size, radius))
    s = 3
    ring = Image.new("L", (size[0] * s, size[1] * s), 0)
    width = max(2, round(size[0] * 0.004)) * s
    ImageDraw.Draw(ring).rounded_rectangle((0, 0, ring.width - 1, ring.height - 1), radius=radius * s, outline=255, width=width)
    ring = ring.resize(size, Image.LANCZOS)
    fade = gradient(size, (102,) * 3, (15,) * 3).convert("L")
    edge = Image.new("RGBA", size, WHITE + (0,))
    edge.putalpha(Image.composite(fade, Image.new("L", size, 0), ring))
    case.alpha_composite(edge)
    return case


def framed(screen, width, radius, border, inset, buttons=(), island=None):
    """Any device: metal case, black border, the real screen, and optional side buttons and Dynamic Island.
    Returns the device and where the screen sits in it: (left, top, scale)."""
    k = width / screen.width
    screen = screen.convert("RGB").resize((round(width), round(screen.height * k)), Image.LANCZOS)
    over = round(width * 0.01) if buttons else 0
    case = (screen.width + (border + inset) * 2, screen.height + (border + inset) * 2)
    image = Image.new("RGBA", (case[0] + over * 2, case[1]), (0, 0, 0, 0))
    for side, top, height in buttons:
        x = 0 if side == "left" else image.width - over * 2
        piece = gradient((over * 2, height), BUTTON_TOP, BUTTON_BOTTOM, horizontal=True).convert("RGBA")
        image.paste(piece, (x, top), rounded_mask(piece.size, max(1, over // 2)))
    image.alpha_composite(finish_case(case, radius + border + inset), (over, 0))
    bezel = (screen.width + border * 2, screen.height + border * 2)
    image.paste((0, 0, 0), (over + inset, inset), rounded_mask(bezel, radius + border))
    left, top = over + inset + border, inset + border
    image.paste(screen, (left, top), rounded_mask(screen.size, radius))
    if island:
        iw, ih, gap = island
        image.paste((0, 0, 0), (left + (screen.width - iw) // 2, top + gap), rounded_mask((iw, ih), ih // 2))
    return image, (left, top, k)


def iphone(screen, width):
    """The intro's iPhone (PhoneMockup), drawn whole: in points it's a 402-wide screen with a 56 corner,
    an 11 border, a 5 case, the Action and volume buttons on the left and the side button on the right."""
    p = width / 402
    buttons = [("left", round(170 * p), round(34 * p)), ("left", round(228 * p), round(64 * p)),
               ("left", round(316 * p), round(64 * p)), ("right", round(236 * p), round(104 * p))]
    return framed(screen, width, round(56 * p), round(11 * p), round(5 * p), buttons, (round(124 * p), round(36 * p), round(11 * p)))


def ipad(screen, width):
    """An iPad Pro in the same finish: even black border, rounded display corners."""
    p = width / 1032
    return framed(screen, width, round(26 * p), round(22 * p), round(5 * p))


def duo(screen, width):
    """iPhone Duo's inner display in the same finish, thin borders all round."""
    p = width / 900
    return framed(screen, width, round(36 * p), round(14 * p), round(5 * p))


def perspective_coefficients(output, source):
    import numpy
    rows, values = [], []
    for (x, y), (X, Y) in zip(output, source):
        rows += [[x, y, 1, 0, 0, 0, -X * x, -X * y], [0, 0, 0, x, y, 1, -Y * x, -Y * y]]
        values += [X, Y]
    return numpy.linalg.solve(numpy.array(rows, float), numpy.array(values, float)).tolist()


def half_folded(device, lean=0.14, depth=0.5):
    """Stands a device on a desk like a half-folded iPhone Duo: the top half upright, the bottom half lying
    toward you, foreshortened and slightly darker, with a soft hinge shadow between them."""
    w, h = device.size
    half = h // 2
    spread = round(w * lean / 2)
    out_w, bottom_h = w + spread * 2, round(half * depth)
    result = Image.new("RGBA", (out_w, half + bottom_h), (0, 0, 0, 0))
    result.alpha_composite(device.crop((0, 0, w, half)), (spread, 0))
    lower = device.crop((0, half, w, h))
    coefficients = perspective_coefficients(
        [(spread, 0), (spread + w, 0), (out_w, bottom_h), (0, bottom_h)], [(0, 0), (w, 0), (w, h - half), (0, h - half)])
    flat = lower.transform((out_w, bottom_h), Image.PERSPECTIVE, coefficients, Image.BICUBIC)
    shade = Image.new("RGBA", flat.size, (0, 0, 0, 0))
    shade.paste((0, 0, 0, 70), (0, 0), flat.split()[3])
    flat.alpha_composite(shade)
    result.alpha_composite(flat, (0, half))
    hinge = Image.new("RGBA", (w, max(4, round(h * 0.012))), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hinge)
    for i in range(hinge.height):
        hd.line([(0, i), (w, i)], fill=(0, 0, 0, round(120 * (1 - abs(i / hinge.height - 0.5) * 2))))
    result.alpha_composite(hinge, (spread, half - hinge.height // 2))
    return result


def desk_shadow(canvas, cx, y, width, unit=1.0):
    """A soft shadow where a standing device meets the desk."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((cx - width / 2, y - 30 * unit, cx + width / 2, y + 40 * unit), fill=(0, 0, 0, 150))
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(30 * unit)))


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
    bd.rounded_rectangle((case[0] - crown_w, round(case[1] * 0.22), case[0] + crown_w - 1, round(case[1] * 0.40)), radius=round(10 * k), fill=BUTTON_TOP + (255,))
    for i in range(9):
        y = round(case[1] * 0.235 + i * case[1] * 0.017)
        bd.line([(case[0] + 2, y), (case[0] + crown_w - 3, y)], fill=BUTTON_BOTTOM + (255,), width=max(1, round(3 * k)))
    bd.rounded_rectangle((case[0] - crown_w, round(case[1] * 0.52), case[0] + crown_w // 2, round(case[1] * 0.68)), radius=round(8 * k), fill=(70, 70, 70, 255))
    body.alpha_composite(finish_case(case, radius + border + band))
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



def touch(canvas, x, y, label, unit=1.0, side="left"):
    """A finger-tap hint: mint ripples on the spot and a small label pointing at it."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for r, a in [(92, 50), (64, 110)]:
        draw.ellipse((x - r * unit, y - r * unit, x + r * unit, y + r * unit), outline=MINT + (a,), width=round(6 * unit))
    draw.ellipse((x - 36 * unit, y - 36 * unit, x + 36 * unit, y + 36 * unit), fill=(255, 255, 255, 150))
    canvas.alpha_composite(layer)
    if not label:
        return
    label_font = font(ROUNDED, 46 * unit, "Bold")
    w = ImageDraw.Draw(canvas).textlength(label, font=label_font) + 64 * unit
    h = round(84 * unit)
    pill_layer = Image.new("RGBA", (round(w), h), (0, 0, 0, 0))
    pill_layer.paste(MINT, (0, 0), rounded_mask(pill_layer.size, h // 2))
    ImageDraw.Draw(pill_layer).text((32 * unit, h * 0.17), label, font=label_font, fill=INK)
    if side == "below":
        shadowed(canvas, pill_layer, x - w / 2, y + 120 * unit, blur=round(20 * unit), offset=round(10 * unit), opacity=120)
        return
    px = x - 120 * unit - w if side == "left" else x + 120 * unit
    shadowed(canvas, pill_layer, px, y - h / 2, blur=round(20 * unit), offset=round(10 * unit), opacity=120)


BEZELS = Path(__file__).parent / "Bezels"


class Bezel:
    """One of Apple's product bezels and the exact shape of its screen: the transparent area around the center."""

    def __init__(self, name, upside_down=False):
        self.image = Image.open(BEZELS / f"{name}.png").convert("RGBA")
        if upside_down:
            self.image = self.image.rotate(180)
        hole = self.image.split()[3].point(lambda a: 255 if a < 10 else 0)
        center = (self.image.width // 2, self.image.height // 2)
        ImageDraw.floodfill(hole, center, 128)
        self.mask = hole.point(lambda v: 255 if v == 128 else 0)
        self.box = self.mask.getbbox()

    def device(self, screen, height):
        """The bezel with a screen inside it, scaled to `height`. Returns the device and its scale."""
        left, top, right, bottom = self.box
        layer = Image.new("RGBA", self.image.size, (0, 0, 0, 0))
        layer.paste(screen.convert("RGB").resize((right - left, bottom - top), Image.LANCZOS), (left, top))
        # A little wider than the hole, so the bezel's antialiased inner edge sits on the screen, not on nothing.
        layer.putalpha(self.mask.filter(ImageFilter.MaxFilter(7)))
        layer.alpha_composite(self.image)
        k = height / layer.height
        return layer.resize((round(layer.width * k), round(height)), Image.LANCZOS), k


def watch_screen(content, title="Dipwise", time="9:41", size=(416, 496)):
    """A watch page as it shows on the display, under the watchOS title bar, at Series 11's 416 × 496 shape × 4."""
    k = 4
    dw, dh = size[0] * k, size[1] * k
    display = Image.new("RGBA", (dw, dh), WATCH_NAVY + (255,))
    side, page_top = 16 * k, 116 * k
    page = content.convert("RGBA")
    page = page.resize((dw - side * 2, round(page.height * (dw - side * 2) / page.width)), Image.LANCZOS)
    page = page.crop((0, 0, page.width, min(page.height, dh - page_top)))
    fade = Image.new("L", page.size, 255)
    fade_draw = ImageDraw.Draw(fade)
    span = 60 * k
    for i in range(span):
        fade_draw.line([(0, page.height - span + i), (page.width, page.height - span + i)], fill=255 - 255 * i // span)
    page.putalpha(Image.composite(page.split()[3], Image.new("L", page.size, 0), fade))
    display.alpha_composite(page, (side, page_top))
    draw = ImageDraw.Draw(display)
    clock = font(ROUNDED, 34 * k, "Semibold")
    name = font(ROUNDED, 38 * k, "Semibold")
    draw.text((dw - 48 * k - draw.textlength(time, font=clock), 22 * k), time, font=clock, fill=WHITE)
    draw.text((dw - 48 * k - draw.textlength(title, font=name), 62 * k), title, font=name, fill=WATCH_GREEN)
    return display


def banner_on(screen, icon, width, top, title, body):
    """The real alert arriving on an unlocked screen, like iOS shows it: a banner over whatever is open."""
    screen = screen.convert("RGBA")
    banner = notification(width, icon, title, body)
    shadowed(screen, banner, (screen.width - width) / 2, top, blur=30, offset=16, opacity=90)
    return screen


STICKER = (12, 36, 56, 236)


def sticker(canvas, cx, top, labels, unit=1.0, icon=None):
    """The promises (No login, No ads, …) as one solid navy pill, readable wherever it sits. `icon` swaps the
    checkmarks for a single drawn symbol in front."""
    draw = ImageDraw.Draw(canvas)
    label_font = font(ROUNDED, 46 * unit, "Bold")
    d, gap, pad, height = round(42 * unit), round(44 * unit), round(40 * unit), round(110 * unit)
    widths = [(0 if icon else d + 16 * unit) + draw.textlength(label, font=label_font) for label in labels]
    lead = round(64 * unit) if icon else 0
    width = round(sum(widths) + gap * (len(labels) - 1) + pad * 2 + lead)
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    layer.paste(STICKER, (0, 0), rounded_mask(layer.size, height // 2))
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle((1, 1, width - 2, height - 2), radius=height // 2, outline=(255, 255, 255, 50), width=2)
    x = pad
    if icon:
        icon(ld, x, (height - 48 * unit) / 2, 48 * unit)
        x += lead
    for label, w in zip(labels, widths):
        y0 = (height - d) / 2
        if not icon:
            ld.ellipse((x, y0, x + d, y0 + d), fill=MINT)
            ld.line([(x + 11 * unit, y0 + 22 * unit), (x + 18 * unit, y0 + 29 * unit), (x + 31 * unit, y0 + 13 * unit)], fill=INK, width=round(5 * unit), joint="curve")
            ld.text((x + d + 16 * unit, height * 0.22), label, font=label_font, fill=WHITE)
        else:
            ld.text((x, height * 0.22), label, font=label_font, fill=WHITE)
        x += w + gap
    shadowed(canvas, layer, cx - width / 2, top, blur=round(26 * unit), offset=round(14 * unit), opacity=140)


def face_id(draw, x, y, size):
    """The Face ID glyph: four corner brackets, two eyes, a nose, and a smile, in mint."""
    w = max(3, round(size * 0.085))
    r, c = size, size * 0.3
    for (cx, cy, sx, sy) in [(x, y, 1, 1), (x + r, y, -1, 1), (x, y + r, 1, -1), (x + r, y + r, -1, -1)]:
        draw.line([(cx, cy + sy * c), (cx, cy), (cx + sx * c, cy)], fill=MINT, width=w, joint="curve")
    draw.line([(x + r * 0.34, y + r * 0.36), (x + r * 0.34, y + r * 0.46)], fill=MINT, width=w)
    draw.line([(x + r * 0.66, y + r * 0.36), (x + r * 0.66, y + r * 0.46)], fill=MINT, width=w)
    draw.line([(x + r * 0.5, y + r * 0.36), (x + r * 0.5, y + r * 0.58), (x + r * 0.44, y + r * 0.58)], fill=MINT, width=w, joint="curve")
    draw.arc((x + r * 0.3, y + r * 0.48, x + r * 0.7, y + r * 0.76), 20, 160, fill=MINT, width=w)



def promises(canvas, cx, top, labels, unit=1.0):
    """The app's promises as bold mint pills with a dark check, so they're the first thing people read."""
    draw = ImageDraw.Draw(canvas)
    label_font = font(ROUNDED, 50 * unit, "Heavy")
    height, gap, d = round(112 * unit), round(20 * unit), round(46 * unit)
    widths = [round(draw.textlength(label, font=label_font) + d + 92 * unit) for label in labels]
    x = cx - (sum(widths) + gap * (len(labels) - 1)) / 2
    for label, w in zip(labels, widths):
        pill = Image.new("RGBA", (w, height), (0, 0, 0, 0))
        pill.paste(MINT, (0, 0), rounded_mask(pill.size, height // 2))
        pd = ImageDraw.Draw(pill)
        x0, y0 = round(30 * unit), (height - d) // 2
        pd.ellipse((x0, y0, x0 + d, y0 + d), fill=INK)
        pd.line([(x0 + 12 * unit, y0 + 24 * unit), (x0 + 20 * unit, y0 + 32 * unit), (x0 + 34 * unit, y0 + 15 * unit)], fill=MINT, width=round(6 * unit), joint="curve")
        pd.text((x0 + d + 16 * unit, height * 0.19), label, font=label_font, fill=INK)
        shadowed(canvas, pill, x, top, blur=round(24 * unit), offset=round(12 * unit), opacity=130)
        x += w + gap


def finger(canvas, x, y, unit=1.0):
    """A clear touch: a soft white fingertip with a mint ring and two fading ripples, like a screen recording shows."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for r, a, w in [(150, 60, 8), (112, 120, 9)]:
        draw.ellipse((x - r * unit, y - r * unit, x + r * unit, y + r * unit), outline=MINT + (a,), width=round(w * unit))
    shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).ellipse((x - 72 * unit, y - 66 * unit, x + 72 * unit, y + 78 * unit), fill=(0, 0, 0, 90))
    canvas.alpha_composite(shade.filter(ImageFilter.GaussianBlur(14 * unit)))
    draw.ellipse((x - 70 * unit, y - 70 * unit, x + 70 * unit, y + 70 * unit), fill=(255, 255, 255, 170), outline=MINT + (255,), width=round(8 * unit))
    canvas.alpha_composite(layer)


def hint(canvas, raw_dir, cx, top, width):
    """The intro's own "Try it" chip, rendered by the app."""
    chip = Image.open(raw_dir / "hint-drag.png").convert("RGBA")
    chip = chip.resize((round(width), round(chip.height * width / chip.width)), Image.LANCZOS)
    shadowed(canvas, chip, cx - chip.width / 2, top, blur=24, offset=12, opacity=150)


def sleepy_zs(canvas, x, y, unit=1.0):
    """Dippy's "z z z" while he sleeps, the same rounded heavy z's the app floats above him."""
    draw = ImageDraw.Draw(canvas)
    for i, size in enumerate([58, 78, 100]):
        f = font(ROUNDED, size * unit, "Heavy")
        draw.text((x + i * 62 * unit, y - i * 86 * unit), "z", font=f, fill=(255, 255, 255, 200 - i * 30))


def tent(device, lean=0.035):
    """iPhone Duo standing like a tent: the outer display facing you with the hinge on top, leaning back a little,
    and the other half peeking out behind it as the stand."""
    w, h = device.size
    inset = round(w * lean)
    coefficients = perspective_coefficients([(inset, 0), (w - inset, 0), (w, h), (0, h)], [(0, 0), (w, 0), (w, h), (0, h)])
    front = device.transform((w, h), Image.PERSPECTIVE, coefficients, Image.BICUBIC)
    back = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    silhouette = front.split()[3]
    back.paste((150, 152, 158, 255), (0, 0), silhouette)
    back_shade = Image.new("RGBA", (w, h), (40, 44, 52, 255))
    back.paste(back_shade, (0, 0), silhouette.point(lambda a: a * 0.55))
    result = Image.new("RGBA", (w + round(w * 0.02), h + round(h * 0.03)), (0, 0, 0, 0))
    result.alpha_composite(back.resize((round(w * 0.985), round(h * 0.985)), Image.LANCZOS), (round(w * 0.03), 0))
    result.alpha_composite(front, (0, round(h * 0.03)))
    return result


ALERT_TITLE = "NVDA entered your buy zone"
ALERT_BODY = ["Now $211.38, inside $205.65–$217.10.", "Your plan: buy 3 shares."]


class Story:
    """Every image of a set drawn on one wide canvas, then cut apart, so the glowing price line and anything that
    crosses an edge continue exactly into the next image as people swipe."""

    def __init__(self, size, count):
        self.W, self.H = size
        self.unit = self.W / 1320
        self.canvas = plain_sky((self.W, self.H), count)
        self.count = count
        self.canvas_sky = Sky((self.W, self.H), 1)
        self.canvas_sky.canvas = self.canvas
        self.canvas_sky.unit = self.unit

    def line(self, points):
        self.icon_line = IconLine(self.canvas_sky, [points])
        self.icon_line.draw()
        return self.icon_line

    def x(self, index, local):
        return self.W * index + local

    def title(self, index, text, top, size):
        title(self.canvas, self.W * index, self.W, text, top, size)

    def place(self, index, layer, cx, top, shadow=1.0):
        x = self.W * index + cx - layer.width / 2
        shadowed(self.canvas, layer, x, top, blur=round(60 * self.unit), offset=round(36 * self.unit), opacity=round(160 * shadow))
        return x

    def frames(self, names):
        return [(name, self.canvas.crop((self.W * i, 0, self.W * (i + 1), self.H))) for i, name in enumerate(names)]


def popout(canvas, screen, box, cx, top, width, unit=1.0):
    """Lifts one part of a real screen out of the device, larger, so it reads even in a small App Store thumbnail."""
    crop = screen.convert("RGB").crop(box)
    crop = crop.resize((round(width), round(crop.height * width / crop.width)), Image.LANCZOS)
    radius = round(44 * width / 1200)
    tile = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    tile.paste(crop, (0, 0), rounded_mask(crop.size, radius))
    edge = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((1, 1, crop.width - 2, crop.height - 2), radius=radius, outline=(255, 255, 255, 120), width=max(2, round(3 * unit)))
    tile.alpha_composite(edge)
    shadowed(canvas, tile, cx - tile.width / 2, top, blur=round(50 * unit), offset=round(30 * unit), opacity=170)
    return tile.height


def fingertip(canvas, x, y, unit=1.0):
    """A finger on the glass, the way iOS shows touches: a soft white disc with a gentle shadow."""
    shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).ellipse((x - 64 * unit, y - 58 * unit, x + 64 * unit, y + 70 * unit), fill=(10, 27, 46, 90))
    canvas.alpha_composite(shade.filter(ImageFilter.GaussianBlur(16 * unit)))
    disc = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(disc).ellipse((x - 58 * unit, y - 58 * unit, x + 58 * unit, y + 58 * unit), fill=(255, 255, 255, 150),
                                 outline=(255, 255, 255, 235), width=round(5 * unit))
    canvas.alpha_composite(disc)


def callout(canvas, text, x, y, tip_x, tip_y, unit=1.0):
    """A navy speech callout in the app's own style, with a short tail pointing at what it explains."""
    draw = ImageDraw.Draw(canvas)
    label_font = font(ROUNDED, 50 * unit, "Bold")
    w = round(draw.textlength(text, font=label_font) + 84 * unit)
    h = round(108 * unit)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    layer.paste(NIGHT_MIDDLE + (255,), (0, 0), rounded_mask((w, h), h // 2))
    ld = ImageDraw.Draw(layer)
    ld.rounded_rectangle((2, 2, w - 3, h - 3), radius=h // 2, outline=MINT + (255,), width=round(4 * unit))
    ld.ellipse((30 * unit, h / 2 - 9 * unit, 48 * unit, h / 2 + 9 * unit), fill=MINT)
    ld.text((62 * unit, h * 0.2), text, font=label_font, fill=WHITE)
    # A short tail under the callout, pointing down at the finger.
    tail = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    bx, by = min(max(tip_x, x + h / 2 + 30 * unit), x + w - h / 2 - 30 * unit), y + h
    ImageDraw.Draw(tail).polygon([(bx - 26 * unit, by - 6), (bx + 26 * unit, by - 6), (bx, by + 34 * unit)], fill=NIGHT_MIDDLE + (255,))
    shadowed(canvas, layer, x, y, blur=round(26 * unit), offset=round(14 * unit), opacity=150)
    canvas.alpha_composite(tail)


def lift_over(canvas, card, at, k, box, scale=1.1, align="center"):
    """Lays a crisp, whole render of a card exactly over where it sits on the device's screen, a little larger, so it
    lifts off the glass instead of being a cropped copy."""
    left, top = at(box[0], box[1])
    right, bottom = at(box[2], box[3])
    width = (right - left) * scale
    card = card.convert("RGBA")
    card = card.resize((round(width), round(card.height * width / card.width)), Image.LANCZOS)
    radius = round(card.width * 0.06)
    mask = rounded_mask(card.size, radius)
    card.putalpha(Image.composite(card.split()[3], Image.new("L", card.size, 0), mask))
    cx = (left + right) / 2
    y = (top + bottom) / 2 - card.height / 2 if align == "center" else top - (card.height - (bottom - top)) * 0.15
    shadowed(canvas, card, cx - card.width / 2, y, blur=46, offset=30, opacity=175)


def yawed(device, depth=0.1, squeeze=0.94):
    """Turns a device a little away from the viewer, like a product photo: the far edge shorter, the whole a touch
    narrower."""
    w, h = device.size
    out_w = round(w * squeeze)
    inset = round(h * depth / 2)
    coefficients = perspective_coefficients([(0, 0), (out_w, inset), (out_w, h - inset), (0, h)], [(0, 0), (w, 0), (w, h), (0, h)])
    return device.transform((out_w, h), Image.PERSPECTIVE, coefficients, Image.BICUBIC)


def reflection(device, height_share=0.35, opacity=0.22):
    """A soft mirror image fading into the desk under a standing device."""
    flipped = device.transpose(Image.FLIP_TOP_BOTTOM).crop((0, 0, device.width, round(device.height * height_share)))
    fade = Image.new("L", flipped.size, 0)
    fd = ImageDraw.Draw(fade)
    for y in range(flipped.height):
        fd.line([(0, y), (flipped.width, y)], fill=round(255 * opacity * (1 - y / flipped.height) ** 1.6))
    flipped.putalpha(Image.composite(flipped.split()[3], Image.new("L", flipped.size, 0), fade))
    return flipped


def iphone_story(raw, raw_dir):
    """Ten pages, one story, told by Dippy on one night sky. The icon's glowing price line runs through all of them:
    it dips under the alert, climbs through the features, and ends where Dippy falls asleep on top of your iPhone.
    Every page holds Apple's real device, and the moment that matters lifts out of the screen, larger."""
    W, H = 1320, 2868
    story = Story((W, H), 10)
    phone = Bezel("iphone-18-pro-max")
    phone_height, phone_top, owl_height = 1990, 740, 230
    x = story.x
    line = story.line([
        (-200, 2330), (300, 2400), (760, 2470), (1180, 2450),
        (1600, 2540), (2050, 2610), (2480, 2600),
        (2900, 2680), (3320, 2700), (3760, 2770),
        (4250, 2810), (4620, 2818), (5000, 2770),
        (5450, 2690), (5900, 2640), (6380, 2560),
        (6850, 2520), (7260, 2440), (7720, 2380),
        (8180, 2330), (8580, 2290), (9020, 2240),
        (9500, 2150), (9900, 2120), (10320, 2130),
        (10800, 2120), (11250, 2080), (11660, 2050),
        (12100, 2020), (12520, 1985), (12920, 2010), (13500, 2110),
    ])

    def page(index, text, screen, pose, owl_side=1, top=phone_top, height=phone_height, cx=W / 2, owl=True):
        if text:
            story.title(index, text, 170, 140)
        device, k = phone.device(screen, height)
        left = story.place(index, device, cx, top)
        if owl:
            perch(story.canvas, raw_dir, pose, x(index, cx + owl_side * (device.width / 2 - 190)), top + 8, owl_height)
        bx, by = phone.box[0], phone.box[1]
        return lambda px, py: (left + (bx + px) * k, top + (by + py) * k), k

    # 1 · Hello, with the promises right under the headline.
    page(0, "Hi, I'm *Dippy*.\nI watch the dips.", raw("iphone-home"), "wave", top=900, height=1900)
    promises(story.canvas, x(0, W / 2), 520, ["No login", "No ads", "Any broker"], unit=0.86)

    # 2 · Drag the zone: a finger on the handle and a callout in the app's own style.
    at, _ = page(1, "Show me where\nyou'd *buy*.", fix_iphone_clock(raw("iphone-plan")), "look-down", owl_side=-1)
    hx, hy = at(1041, 2049)
    fingertip(story.canvas, hx, hy)
    callout(story.canvas, "Drag to your price", min(hx - 360, x(1, W - 140) - 620), hy - 230, hx, hy)

    # 3 · The odds card, lifting off the stock screen.
    at, k = page(2, "I'll show your\n*odds* first.", raw("iphone-odds"), "look-left")
    lift_over(story.canvas, raw("odds-card"), at, k, (60, 384, 1260, 2205), scale=1.12)

    # 4 · The alert, exactly as iOS shows it, lifted off the lock screen.
    at, k = page(3, "Get alerted the\n*moment it dips*.", raw("scene-lock"), "wings")
    lift_over(story.canvas, raw("notification-card"), at, k, (42, 708, 1278, 936), scale=1.18)
    line.dot(x(3, 660), rings=True)

    # 5 · The flock's mood, lifted out of the Flock.
    at, k = page(4, "Meet the *flock*.\nAll anonymous.", raw("iphone-flock"), "wink", owl_side=-1)
    lift_over(story.canvas, raw("sentiment-card"), at, k, (60, 1710, 1260, 2868), scale=1.1, align="top")

    page(5, "*28* alerts,\nin plain words.", fix_iphone_clock(raw("iphone-plan-smart")), "blush")
    page(6, "I live on your\n*Home Screen*.", raw("iphone-home-widgets"), "look-down", owl_side=-1)

    # 8 · iPhone Duo standing on the desk, turned a little like a product photo, reflected in the desk.
    story.title(7, "Your stocks,\n*live on your desk*.", 170, 140)
    duo = Bezel("iphone-duo-outer-landscape", upside_down=True)
    front, _ = duo.device(raw("desk-mode"), 960)
    stand = yawed(front, depth=0.08, squeeze=0.96)
    stand_bottom = 1720
    top = stand_bottom - stand.height
    shine = reflection(stand)
    paste_clipped(story.canvas, shine, round(x(7, (W - shine.width) / 2)), round(stand_bottom + 6))
    story.place(7, stand, W / 2, top, shadow=0.55)
    perch(story.canvas, raw_dir, "look-down", x(7, W / 2 - 300), top + 14, owl_height)
    sticker(story.canvas, x(7, W / 2), stand_bottom + 380, ["Optimized for iPhone Duo"])

    # 9 · Apple Watch on its own: big, with its band running off the page, the app filling the display.
    story.title(8, "Or keep me\non your *wrist*.", 170, 140)
    wrist = Bezel("watch-series-11")
    watch_device, k = wrist.device(watch_screen(raw("watch-today")), 2050)
    band_fade = Image.new("L", watch_device.size, 255)
    bf = ImageDraw.Draw(band_fade)
    span = round(watch_device.height * 0.12)
    for i in range(span):
        bf.line([(0, i), (watch_device.width, i)], fill=round(255 * i / span))
    watch_device.putalpha(Image.composite(watch_device.split()[3], Image.new("L", watch_device.size, 0), band_fade))
    story.place(8, watch_device, W / 2 - 16, 600)

    # 10 · Asleep under the moon, on the same glowing line.
    sky = story.canvas_sky
    sky.moon(round(x(9, W - 250)), 690, 96)
    story.title(9, "Sleep well.\n*I'm on watch.*", 170, 140)
    line.owl(raw_dir, "sleep", x(9, 640), 760)
    sleepy_zs(story.canvas, x(9, 880), 1240)

    frames = story.frames(["01-meet-dippy", "02-buy-zone", "03-odds", "04-alert", "05-flock", "06-smart-alerts",
                           "07-widgets", "08-desk-mode", "09-apple-watch", "10-sleep-well"])
    return frames, story.canvas


# MARK: - iPad

def ipad_story(raw, raw_dir):
    """The same story on iPad, on one continuous night: the real iPad Pro, Dippy on top, the same glowing line."""
    W, H = 2064, 2752
    icon = Image.open(raw_dir / "app-icon.png")
    story = Story((W, H), 5)
    tablet = Bezel("ipad-pro-13")
    height, top, owl_height = 1830, 820, 230
    x = story.x
    line = story.line([
        (-200, 2380), (500, 2450), (1300, 2520), (1900, 2500),
        (2500, 2580), (3300, 2620), (3950, 2600),
        (4500, 2560), (5300, 2470), (6000, 2400),
        (6600, 2560), (7230, 2600), (7900, 2560),
        (8600, 2300), (9180, 2240), (9800, 2270), (10600, 2360),
    ])

    def page(index, text, screen, pose, owl_side=1, top=top, height=height, time="9:41 AM"):
        story.title(index, text, 160, 170)
        device, _ = tablet.device(fix_ipad_status(screen, time), height)
        story.place(index, device, W / 2, top)
        perch(story.canvas, raw_dir, pose, x(index, W / 2 + owl_side * (device.width / 2 - 260)), top + 10, owl_height)

    page(0, "Hi, I'm *Dippy*.\nI watch the dips.", raw("ipad-home"), "wave", top=960, height=1720)
    promises(story.canvas, x(0, W / 2), 560, ["No login", "No ads", "Any broker"], unit=1.15)
    page(1, "Show me where\nyou'd *buy*.", raw("ipad-stock"), "look-down", owl_side=-1)
    page(2, "I'll show your\n*odds* first.", raw("ipad-odds"), "look-left")
    alert = banner_on(raw("ipad-alerts"), icon, 1160, 90, ALERT_TITLE, ALERT_BODY)
    page(3, "Get alerted the\n*moment it dips*.", alert, "wings")
    line.dot(x(3, W / 2 + 200), rings=True)
    sky = story.canvas_sky
    sky.moon(round(x(4, 260)), 640, 110)
    page(4, "Sleep well.\n*I'm on watch.*", raw("ipad-night"), "sleep", time="10:42 PM")
    sleepy_zs(story.canvas, x(4, W / 2 + 640), 680, unit=1.2)

    frames = story.frames(["01-meet-dippy", "02-buy-zone", "03-odds", "04-alert", "05-sleep-well"])
    return frames, story.canvas


# MARK: - Apple Watch

def watch_set(raw):
    """Full-screen watch pages under a short caption, drawn at 6× and scaled down so every edge is crisp."""
    W, H = 416, 496
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


# MARK: - Header

def vertical_gradient(size, stops):
    """A top-to-bottom gradient through (position, color) stops."""
    w, h = size
    strip = Image.new("RGB", (1, 512))
    for y in range(512):
        t = y / 511
        for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
            if p0 <= t <= p1:
                k = (t - p0) / max(p1 - p0, 1e-6)
                strip.putpixel((0, y), tuple(int(c0[i] + (c1[i] - c0[i]) * k) for i in range(3)))
                break
    return strip.resize((w, h), Image.BICUBIC).convert("RGBA")


def fill_below(canvas, points, top_color, bottom_color):
    """Fills the land under a ridge with its own soft gradient."""
    w, h = canvas.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(points + [(w + 50, h + 50), (-50, h + 50)], fill=255)
    land = vertical_gradient((w, h), [(0, top_color), (1, bottom_color)])
    canvas.paste(land, (0, 0), mask)


def smooth_curve(points, samples=24):
    """A Catmull-Rom curve through the points, left to right."""
    out = []
    for i in range(len(points) - 1):
        p0, p1 = points[max(i - 1, 0)], points[i]
        p2, p3 = points[i + 1], points[min(i + 2, len(points) - 1)]
        for j in range(samples):
            t = j / samples
            out.append(tuple(
                0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t * t
                       + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t ** 3) for c in range(2)))
    out.append(points[-1])
    return out


def glow_path(canvas, points, color, width, glow, unit):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).line(points, fill=color + (130,), width=round(glow * unit), joint="curve")
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(glow * 0.55 * unit)))
    ImageDraw.Draw(canvas).line(points, fill=color + (255,), width=round(width * unit), joint="curve")


LANGUAGES = ["en", "de", "es", "fr", "it", "pt-BR", "ja", "ko"]

# One short phrase per asset, as Apple asks, in every language the app speaks. *Stars* mark the mint words.
# The header's one phrase, in every language with the moon as a letter: {o} is an "o" drawn as the moon, {ö} keeps
# its two dots above the moon, and {.} is a full stop that is the moon, for Japanese and Korean, which have no "o".
# *Stars* mark the mint words.
TAGLINES = {
    "en": "Your *stock-watching* {o}wl.",
    "de": "Deine Eule für die *B{ö}rse*.",
    "es": "Tu búh{o} que *vigila la bolsa*.",
    "fr": "Ta ch{o}uette qui *veille sur la Bourse*.",
    "it": "Il tuo guf{o} che *veglia sulla Borsa*.",
    "pt-BR": "Sua c{o}ruja que *vigia a bolsa*.",
    "ja": "*株価*を見守るフクロウ{.}",
    "ko": "*주식*을 지켜보는 부엉이{.}",
}

SEARCH_LINES = {
    "en": "Get alerted when\nyour stocks *dip*.",
    "de": "Ein Alarm, wenn deine\nAktien *fallen*.",
    "es": "Un aviso cuando tus\nacciones *bajan*.",
    "fr": "Une alerte quand tes\nactions *baissent*.",
    "it": "Un avviso quando le\ntue azioni *scendono*.",
    "pt-BR": "Um alerta quando suas\nações *caem*.",
    "ja": "株価が*下がったら*、\nすぐにお知らせ。",
    "ko": "주가가 *떨어지면*\n바로 알려드려요.",
}


def lang_font(lang, size, weight="Bold"):
    """SF Rounded for the Latin languages; Hiragino and Apple SD Gothic Neo, Apple's own, for Japanese and Korean."""
    if lang == "ja":
        return ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc", round(size))
    if lang == "ko":
        return ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", round(size), index=14)
    return font(ROUNDED, size, weight)


def rich_text(canvas, text, cx, top, lang, size, max_width, unit, line_gap=1.12):
    """Centered lines with the *starred* words in mint and a soft shadow, shrunk until the widest line fits."""
    draw = ImageDraw.Draw(canvas)
    lines = text.split("\n")
    while True:
        text_font = lang_font(lang, size)
        widths = [draw.textlength(line.replace("*", ""), font=text_font) for line in lines]
        if max(widths) <= max_width or size < 10:
            break
        size *= 0.95
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layers = [(shadow, (0, 0, 0, 130), 7 * unit), (canvas, None, 0)]
    for layer, shade, dy in layers:
        ld = ImageDraw.Draw(layer)
        # A starred phrase can run across a line break, so the color carries over from line to line.
        mint = False
        for row, (line, width) in enumerate(zip(lines, widths)):
            x = cx - width / 2
            y = top + row * size * line_gap + dy
            for index, part in enumerate(line.split("*")):
                if index:
                    mint = not mint
                ld.text((x, y), part, font=text_font, fill=shade or (MINT if mint else WHITE))
                x += ld.textlength(part, font=text_font)
        if layer is shadow:
            canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(12 * unit)))
    return top + len(lines) * size * line_gap


def aa_shapes(canvas, paint, fill, scale=2):
    """Flat vector shapes with clean edges: `paint(draw, k)` draws on a mask `scale`× larger, which is smoothed down
    and filled with `fill`, a color or an image the size of the canvas."""
    W, H = canvas.size
    mask = Image.new("L", (W * scale, H * scale), 0)
    paint(ImageDraw.Draw(mask), scale)
    mask = mask.resize((W, H), Image.LANCZOS)
    if isinstance(fill, Image.Image):
        canvas.paste(fill, (0, 0), mask)
    else:
        canvas.paste(Image.new("RGBA", (W, H), fill + (255,)), (0, 0), mask)


def fir(draw, k, x, base, height, width):
    """A flat fir in the icon's style: a trunk and four tiers, each a soft triangle a little wider than the last."""
    trunk = width * 0.08
    draw.rectangle(((x - trunk) * k, (base - height * 0.16) * k, (x + trunk) * k, base * k), fill=255)
    tiers = 4
    for i in range(tiers):
        top = base - height + height * 0.2 * i
        bottom = top + height * 0.36
        half = width / 2 * (0.42 + 0.58 * (i + 1) / tiers)
        draw.polygon([(x * k, top * k), ((x + half) * k, bottom * k), ((x + half * 0.5) * k, (bottom - height * 0.035) * k),
                      ((x - half * 0.5) * k, (bottom - height * 0.035) * k), ((x - half) * k, bottom * k)], fill=255)


def glowing_eyes(canvas, x, y, size, look=0.0, sleepy=False):
    """A pair of the flock's eyes shining out of the dark, drawn exactly like Dippy's: a dark ring, an amber iris, a
    pupil, and a glint, with a warm glow around them. Sleepy eyes are half shut."""
    s = size
    k = 4
    w, h = round(s * 5.6), round(s * 3)
    patch = Image.new("RGBA", (w * k, h * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(patch)
    for ex in (w * 0.29, w * 0.71):
        cx, cy = ex * k, h / 2 * k
        r = s * k
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(12, 22, 36, 255))
        d.ellipse((cx - r * 0.8, cy - r * 0.8, cx + r * 0.8, cy + r * 0.8), fill=(250, 172, 32, 255))
        px = cx + look * r * 0.25
        d.ellipse((px - r * 0.42, cy - r * 0.42, px + r * 0.42, cy + r * 0.42), fill=(12, 22, 36, 255))
        d.ellipse((px - r * 0.36, cy - r * 0.44, px - r * 0.1, cy - r * 0.18), fill=(255, 255, 255, 255))
        if sleepy:
            d.pieslice((cx - r * 1.04, cy - r * 1.04, cx + r * 1.04, cy + r * 1.04), 180, 360, fill=(14, 34, 52, 255))
            d.line([(cx - r, cy), (cx + r, cy)], fill=(12, 22, 36, 255), width=round(r * 0.14))
    patch = patch.resize((w, h), Image.LANCZOS)
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((x - s * 3.2, y - s * 1.9, x + s * 3.2, y + s * 1.9), fill=(250, 172, 32, 70 if not sleepy else 30))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(s * 1.2)))
    canvas.alpha_composite(patch, (round(x - w / 2), round(y - h / 2)))


def full_moon(canvas, mx, my, mr):
    """The moon, full and flat, with its craters and a soft halo."""
    W, H = canvas.size
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse((mx - mr * 3.4, my - mr * 3.4, mx + mr * 3.4, my + mr * 3.4), fill=(255, 236, 190, 40))
    canvas.alpha_composite(halo.filter(ImageFilter.GaussianBlur(mr * 1.4)))
    aa_shapes(canvas, lambda d, k: d.ellipse(((mx - mr) * k, (my - mr) * k, (mx + mr) * k, (my + mr) * k), fill=255), (255, 234, 184))
    aa_shapes(canvas, lambda d, k: [d.ellipse(((mx + a * mr - b * mr) * k, (my + c * mr - b * mr) * k, (mx + a * mr + b * mr) * k, (my + c * mr + b * mr) * k), fill=255)
                                    for a, c, b in [(-0.3, -0.2, 0.2), (0.32, 0.25, 0.14), (-0.1, 0.45, 0.1)]], (240, 214, 160))


def forest(size, clearing, eyes=False, moon=True, moon_at=None, drop=0.0, front_gap=0.6):
    """Dippy's forest at night in the icon's flat style: the icon's navy with its faint lines in the sky, a moon,
    rolling hills and three layers of firs that grow darker toward you, and, if asked, two of the flock's eyes
    shining from the trees. A clearing in the middle keeps the focal point in the center, where every crop keeps it."""
    W, H = size
    u = H / 1080
    cx = W / 2
    canvas = vertical_gradient((W, H), [(0, (10, 26, 44)), (0.45, (20, 58, 82)), (0.72, (30, 80, 104)), (1, (10, 28, 44))])
    rng = random.Random(5)

    lines = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    for i in range(1, 6):
        y = H * 0.12 * i
        ld.line([(0, y), (W, y)], fill=(160, 210, 230, 16), width=max(1, round(2 * u)))
    canvas.alpha_composite(lines)

    stars = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stars)
    for _ in range(int(W / H * 26)):
        sx, sy = rng.uniform(0, W), rng.uniform(H * 0.02, H * 0.5)
        r = rng.choice([1.6, 2.2, 3.0]) * u
        sd.ellipse((sx - r, sy - r, sx + r, sy + r), fill=(255, 255, 255, rng.randint(60, 170)))
    canvas.alpha_composite(stars)

    if moon:
        full_moon(canvas, *(moon_at or (cx + H * 0.48, H * 0.3, H * 0.075)))

    def hills(base, amplitude, seed, color_top, color_bottom):
        r = random.Random(seed)
        pts = [(x, base - amplitude * r.uniform(0.2, 1.0)) for x in [-W * 0.1 + i * W * 1.2 / 7 for i in range(8)]]
        curve = smooth_curve(pts, samples=40)
        fill = vertical_gradient((W, H), [(0, color_top), (1, color_bottom)])
        aa_shapes(canvas, lambda d, k: d.polygon([(x * k, y * k) for x, y in curve] + [((W + 50) * k, (H + 50) * k), (-50 * k, (H + 50) * k)], fill=255), fill)

    hills(H * (0.66 + drop), H * 0.12, 3, (34, 82, 104), (26, 66, 88))

    def tree_row(base, heights, spacing, gap, seed, top, bottom, scatter=0.025, steps=(0.7, 1.15)):
        # Scattered the way a forest grows: uneven gaps, some trees a little nearer (lower and taller), some farther.
        r = random.Random(seed)
        trees = []
        x = -spacing * r.uniform(0, 1)
        while x < W + spacing:
            if abs(x - clearing) > gap:
                depth = r.uniform(-scatter, scatter)
                h = r.uniform(*heights) * (1 + depth * 3)
                trees.append((x, base + depth * H, h, h * r.uniform(0.46, 0.56)))
            x += spacing * r.uniform(*steps)
        fill = vertical_gradient((W, H), [(0, top), (1, bottom)])
        aa_shapes(canvas, lambda d, k: [fir(d, k, *t) for t in trees], fill)
        return trees

    tree_row(H * (0.74 + drop), (H * 0.13, H * 0.27), H * 0.1, H * 0.22, 7, (36, 84, 106), (26, 64, 86), scatter=0.04, steps=(0.35, 1.6))
    hills(H * (0.84 + drop), H * 0.06, 9, (18, 50, 72), (12, 36, 54))
    tree_row(H * (0.84 + drop), (H * 0.2, H * 0.32), H * 0.1, 0, 12, (24, 62, 84), (16, 46, 66), scatter=0.04, steps=(0.4, 1.7))
    middle = tree_row(H * (0.93 + drop), (H * 0.26, H * 0.42), H * 0.16, 0, 13, (16, 44, 64), (10, 30, 46), scatter=0.05, steps=(0.45, 1.8))
    hills(H * (0.93 + drop), H * 0.04, 21, (10, 28, 44), (6, 16, 28))
    front = tree_row(H * (1.06 + drop), (H * 0.66, H * 0.84), H * 0.2, H * front_gap, 17, (10, 28, 44), (5, 14, 26))

    if eyes:
        # The flock, peeking out of the firs on both sides of the clearing: big near, small far, one fast asleep.
        # Just two of the flock: one watching Dippy from the left, one dozing on the right.
        left = max((t for t in front if t[0] < clearing), key=lambda t: t[0])
        right = min((t for t in front if t[0] > clearing), key=lambda t: t[0])
        glowing_eyes(canvas, left[0], left[1] - left[2] * 0.42, H * 0.024, look=1)
        glowing_eyes(canvas, right[0] - H * 0.08, right[1] - right[2] * 0.3, H * 0.022, look=-1, sleepy=True)
    return canvas


def moonlit_line(canvas, text, cx, top, lang, size, max_width, unit, middle=None, draw_moons=True, letters=None):
    """One centered line with the *starred* words in mint, a soft shadow, and the moon standing in for a letter: {o},
    {ö} (its dots stay above the moon), or {.}, a full stop. The moon gets a little air on both sides, like a letter.
    Returns where each moon sits, for drawing (or animating) it separately with `draw_moons=False`; `letters`, if
    given, collects the plain letter each moon stands in for, as (letter, x, top, font, color)."""
    draw = ImageDraw.Draw(canvas)
    runs, mint = [], False
    for index, part in enumerate(text.split("*")):
        if index:
            mint = not mint
        for token in re.split(r"(\{[oö.]\}|)", part):
            if token:
                runs.append((token, mint))
    while True:
        text_font = lang_font(lang, size)
        latin = lang_font("en", size)
        _, o_top, _, o_bottom = latin.getbbox("o")
        moon_d = (o_bottom - o_top) * 1.2

        def width_of(token):
            if token == "{.}":
                return moon_d * 1.25
            if token in ("{o}", "{ö}"):
                return max(draw.textlength(token[1], font=latin), moon_d) + size * 0.1
            return draw.textlength(token, font=text_font)

        width = sum(width_of(t) for t, _ in runs)
        if width <= max_width or size < 10:
            break
        size *= 0.96
    if middle is not None:
        # Center the letters themselves, not the font's line box, on `middle`.
        plain = "".join({"{o}": "o", "{ö}": "ö", "{.}": "."}.get(t, t) for t, _ in runs)
        _, ink_top, _, ink_bottom = text_font.getbbox(plain)
        top = middle - (ink_top + ink_bottom) / 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    x = cx - width / 2
    for token, _ in runs:
        if not token.startswith("{"):
            sd.text((x, top + 7 * unit), token, font=text_font, fill=(0, 0, 0, 130))
        x += width_of(token)
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(12 * unit)))
    draw = ImageDraw.Draw(canvas)
    moons, x = [], cx - width / 2
    for token, is_mint in runs:
        color = MINT if is_mint else WHITE
        w = width_of(token)
        if token == "{ö}" and draw_moons:
            draw.text((x + (w - draw.textlength("ö", font=latin)) / 2, top), "ö", font=latin, fill=color)
        if token.startswith("{"):
            moons.append((x + w / 2, top + (o_top + o_bottom) / 2, moon_d / 2))
            if letters is not None:
                letter = "." if token == "{.}" else "o"
                letters.append((letter, x + (w - draw.textlength(letter, font=latin)) / 2, top, latin, color))
        else:
            draw.text((x, top), token, font=text_font, fill=color)
        x += w
    if draw_moons:
        for mx, my, mr in moons:
            full_moon(canvas, mx, my, mr)
    # The dots of an ö go back on top of its moon: the glyph minus its plain "o".
    x = cx - width / 2
    for token, is_mint in runs:
        if token == "{ö}":
            gx = x + (width_of(token) - draw.textlength("ö", font=latin)) / 2
            dots = Image.new("L", canvas.size, 0)
            ImageDraw.Draw(dots).text((gx, top), "ö", font=latin, fill=255)
            bowl = Image.new("L", canvas.size, 0)
            ImageDraw.Draw(bowl).text((gx, top), "o", font=latin, fill=255)
            dots = ImageChops.subtract(dots, bowl.filter(ImageFilter.MaxFilter(5)))
            canvas.paste(Image.new("RGBA", canvas.size, (MINT if is_mint else WHITE) + (255,)), (0, 0), dots)
        x += width_of(token)
    return moons


def header_scene(size):
    """The header's stage without its actors: Dippy's night forest, kept low, and a soft vignette, so the edges fall a
    little darker and the eye goes to the middle, the way premium art is lit."""
    W, H = size
    canvas = forest(size, W / 2, moon=False, drop=0.1, front_gap=0.8)
    shade = Image.new("L", (64, 36), 0)
    ImageDraw.Draw(shade).ellipse((-14, -10, 78, 46), fill=255)
    shade = shade.filter(ImageFilter.GaussianBlur(7)).resize((W, H), Image.BICUBIC)
    vignette = Image.new("RGBA", (W, H), (4, 10, 20, 0))
    vignette.putalpha(shade.point(lambda v: round((255 - v) * 0.5)))
    canvas.alpha_composite(vignette)
    return canvas


def header_layout(size):
    """Where the line and Dippy go. On 16:9 the line sits right below iPhone's back and share buttons, as wide as the
    space between the screen's edges allows, and Dippy rises under it, his beak just above the bottom edge. The 21:9
    header is shown wide, on iPad and Mac, without iPhone's crop, so it gets a bigger line and a bigger Dippy. Returns
    the line's (size, max width, middle) and Dippy's (center, feet, height)."""
    W, H = size
    if W / H > 2:
        return (H * 0.19, W * 0.64, H * 0.44), (W / 2, H * 0.565 + H * 0.68 * 0.97, H * 0.68)
    return (H * 0.15, H * 1.25, H * 0.505), (W / 2, H * 0.605 + H * 0.62 * 0.97, H * 0.62)


def header(raw, raw_dir, size, lang="en"):
    """The product page header: Dippy's night forest, drawn flat in the icon's own navy, white, mint, and amber. Dippy
    rises large from the bottom edge, his face and big eyes the first thing anyone sees. Above him is one line whose
    letter "o" (or full stop) is the full moon. The top stays quiet sky, since that is where iPhone puts the Dynamic
    Island and the back and share buttons."""
    W, H = size
    canvas = header_scene(size)
    (text_size, max_width, middle), (cx, feet, height) = header_layout(size)
    moonlit_line(canvas, TAGLINES[lang], W / 2, 0, lang, text_size, max_width, H / 1080, middle=middle)
    perch(canvas, raw_dir, "idle", cx, feet, height)
    return canvas


def search_asset(raw, raw_dir, size, lang="en"):
    """The search results asset, built on Apple's guidance: say what the app does at a glance and show it firsthand.
    The real iPhone holds the lock screen with the dip alert lifting off it, Dippy on top, his forest behind."""
    W, H = size
    u = H / 1080
    cx = W / 2
    canvas = forest(size, cx, eyes=True, moon=False)

    bottom = rich_text(canvas, SEARCH_LINES[lang], cx, H * 0.06, lang, H * 0.1, min(W * 0.9, H * 1.4), u)
    phone = Bezel("iphone-18-pro-max")
    top = bottom + H * 0.17
    device, k = phone.device(raw("scene-lock"), H * 1.05)
    left = round(cx - device.width / 2)
    shadowed(canvas, device, left, top, blur=round(40 * u), offset=round(26 * u), opacity=160)
    bx, by = phone.box[0], phone.box[1]
    at = lambda px, py: (left + (bx + px) * k, top + (by + py) * k)
    lift_over(canvas, raw("notification-card"), at, k, (42, 708, 1278, 936), scale=1.24)
    perch(canvas, raw_dir, "wings", cx + device.width / 2 - 130 * u, top + 6 * u, H * 0.13)
    return canvas


def _render(job):
    kind, raw_dir, folder, name, size, lang, with_text = job
    raw = Raw(raw_dir)
    image = header(raw, raw_dir, size, lang) if kind == "header" else search_asset(raw, raw_dir, size, lang)
    path = folder / f"{name}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(path, optimize=True)
    return path


def headers(raw, raw_dir, folder):
    """Every creative asset at App Store Connect's exact sizes, in every language: the header (the universal 16:9 and
    21:9), the search results asset (3:2 and 16:9), and a social banner."""
    from multiprocessing import Pool
    store = folder.parent
    jobs = [("header", raw_dir, folder, "header-social-1500x500", (1500, 500), "en", False)]
    for lang in LANGUAGES:
        jobs += [("header", raw_dir, folder / lang, "header-5244x2950", (5244, 2950), lang, True),
                 ("header", raw_dir, folder / lang, "header-3840x1646", (3840, 1646), lang, True),
                 ("search", raw_dir, store / "Search" / lang, "search-3840x2560", (3840, 2560), lang, True),
                 ("search", raw_dir, store / "Search" / lang, "search-5244x2950", (5244, 2950), lang, True)]
    with Pool() as pool:
        for path in pool.imap_unordered(_render, jobs):
            print(path)


def main(raw_dir, out_dir):
    raw = Raw(raw_dir)
    headers(raw, raw_dir, out_dir / "Header")
    phone, phone_canvas = iphone_story(raw, raw_dir)
    save(phone, out_dir / "iPhone-6.9")
    save(phone, out_dir / "iPhone-6.5", size=(1284, 2778))
    panorama(phone_canvas, out_dir / "preview-iphone.png")
    tablet, tablet_canvas = ipad_story(raw, raw_dir)
    save(tablet, out_dir / "iPad-13")
    panorama(tablet_canvas, out_dir / "preview-ipad.png")
    wrist = watch_set(raw)
    save(wrist, out_dir / "AppleWatch-Series-11")
    contact_sheet(wrist, out_dir / "preview-watch.png", height=514)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
