#!/usr/bin/env python3
"""Composes the Dipwise App Store screenshots.

All ten images are cut from one wide night-sky panorama, so swiping through the App Store page tells one story:
a glowing price line runs from the first image to the last, dipping along the way, and Dippy perches on the dips.
Each image pairs a bold headline with a real app screen in a tilted iPhone, and lifts the key moment out of the
screen as a floating card.

Usage: python3 compose.py <raw folder> <output folder>
Output: 1320 × 2868 PNGs, Apple's 6.9-inch iPhone size, plus a small panorama preview beside the folder.
"""

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
COUNT = 10
NAVY_TOP = (14, 42, 64)
NAVY_MID = (11, 33, 52)
NAVY_BOTTOM = (5, 15, 27)
GREEN = (24, 196, 124)
WHITE = (255, 255, 255)
SOFT = (192, 203, 215)
INK = (10, 27, 46)

ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
TEXT = "/System/Library/Fonts/SFNS.ttf"


def font(path, size, weight):
    f = ImageFont.truetype(path, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


# MARK: - The panorama

def sky(width, height):
    """Night navy with a scatter of stars in the upper sky."""
    image = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / (height - 1)
        a, b, k = (NAVY_TOP, NAVY_MID, t / 0.5) if t < 0.5 else (NAVY_MID, NAVY_BOTTOM, (t - 0.5) / 0.5)
        draw.line([(0, y), (width, y)], fill=tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)))
    stars = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    star_draw = ImageDraw.Draw(stars)
    rng = random.Random(7)
    for _ in range(int(width * 0.09)):
        x, y = rng.uniform(0, width), rng.uniform(0, height * 0.62)
        r = rng.choice([1.5, 2, 2, 2.5, 3.5])
        star_draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, rng.randint(40, 150)))
    image = image.convert("RGBA")
    image.alpha_composite(stars.filter(ImageFilter.GaussianBlur(0.6)))
    return image


# The price line across the whole panorama: (x, y). Dips sit where Dippy perches.
LINE = [
    (-200, 2470), (120, 2560), (380, 2700), (640, 2560), (980, 2420), (1320, 2480),
    (1700, 2380), (2100, 2520), (2500, 2410), (2900, 2560),
    (3300, 2500), (3700, 2620), (4020, 2700), (4300, 2560), (4700, 2420), (5000, 2500),
    (5300, 2390), (5700, 2470), (6100, 2370), (6500, 2500),
    (6900, 2450), (7200, 2600), (7500, 2700), (7800, 2560), (8100, 2420),
    (8500, 2480), (8900, 2380), (9300, 2460), (9700, 2360), (10100, 2470),
    (10500, 2390), (10900, 2480), (11300, 2420), (11700, 2520), (12100, 2600),
    (12540, 2690), (12900, 2560), (13400, 2430),
]


def line_y(x):
    """The line's height at x, a smooth Catmull-Rom curve through its points."""
    pts = LINE
    for i in range(len(pts) - 1):
        if pts[i][0] <= x <= pts[i + 1][0]:
            p0, p1, p2, p3 = pts[max(i - 1, 0)], pts[i], pts[i + 1], pts[min(i + 2, len(pts) - 1)]
            t = (x - p1[0]) / (p2[0] - p1[0])
            return 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t * t
                          + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t ** 3)
    return pts[-1][1]


def draw_price_line(canvas):
    width, height = canvas.size
    points = [(x, line_y(x)) for x in range(0, width + 1, 6)]
    # A soft green wash under the line, fading toward the bottom.
    wash = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(wash).polygon(points + [(width, height), (0, height)], fill=(24, 196, 124, 40))
    fade = Image.new("L", (1, height), 0)
    for y in range(height):
        fade.putpixel((0, y), int(255 * max(0.0, min(1.0, 1 - (y - 2380) / 480))))
    wash.putalpha(Image.composite(wash.split()[3], Image.new("L", canvas.size, 0), fade.resize(canvas.size)))
    canvas.alpha_composite(wash)
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).line(points, fill=(24, 196, 124, 200), width=34, joint="curve")
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(22)))
    crisp = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(crisp).line(points, fill=(60, 222, 150, 255), width=11, joint="curve")
    canvas.alpha_composite(crisp)


def moon(canvas, cx, cy, r):
    """A soft crescent moon with a gentle halo."""
    halo = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse((cx - r * 2.4, cy - r * 2.4, cx + r * 2.4, cy + r * 2.4), fill=(255, 236, 190, 30))
    canvas.alpha_composite(halo.filter(ImageFilter.GaussianBlur(44)))
    disc = Image.new("L", (r * 2, r * 2), 0)
    ImageDraw.Draw(disc).ellipse((0, 0, r * 2 - 1, r * 2 - 1), fill=240)
    ImageDraw.Draw(disc).ellipse((round(r * 0.55), round(-r * 0.3), round(r * 2.55), round(r * 1.7)), fill=0)
    canvas.paste((255, 236, 196), (cx - r, cy - r), disc)


# MARK: - Text

def headline(canvas, ox, eyebrow, title, subline):
    """An eyebrow pill, a bold headline with *highlighted* words in green, and a balanced supporting line."""
    draw = ImageDraw.Draw(canvas)
    pill_font = font(ROUNDED, 38, "Bold")
    head_font = font(ROUNDED, 132, "Heavy")
    sub_font = font(TEXT, 50, "Medium")

    w = draw.textlength(eyebrow, font=pill_font)
    px, py = ox + (W - w - 64) / 2, 150
    pill = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(pill).rounded_rectangle((px, py, px + w + 64, py + 74), radius=37, fill=(24, 196, 124, 46))
    canvas.alpha_composite(pill)
    draw.text((px + 32, py + 15), eyebrow, font=pill_font, fill=GREEN)

    y = 262
    for line in title.split("\n"):
        parts = line.split("*")
        x = ox + (W - sum(draw.textlength(part, font=head_font) for part in parts)) / 2
        for index, part in enumerate(parts):
            draw.text((x, y), part, font=head_font, fill=GREEN if index % 2 else WHITE)
            x += draw.textlength(part, font=head_font)
        y += 148
    y += 18
    for line in balanced(draw, subline, sub_font, 1100):
        w = draw.textlength(line, font=sub_font)
        draw.text((ox + (W - w) / 2, y), line, font=sub_font, fill=SOFT)
        y += 66
    return y


def balanced(draw, text, text_font, max_width):
    """Two lines of similar length, so no word is left alone."""
    if draw.textlength(text, font=text_font) <= max_width:
        return [text]
    words, best = text.split(), None
    for split in range(1, len(words)):
        a, b = " ".join(words[:split]), " ".join(words[split:])
        widest = max(draw.textlength(a, font=text_font), draw.textlength(b, font=text_font))
        if widest <= max_width and (best is None or widest < best[0]):
            best = (widest, [a, b])
    return best[1] if best else [text]


# MARK: - Devices and cards

def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def gradient(size, top, bottom):
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(size[1]):
        t = y / max(size[1] - 1, 1)
        draw.line([(0, y), (size[0], y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return image


def fix_clock(screen):
    """The simulator's status bar shows 09:41; US iPhones show 9:41."""
    screen = screen.convert("RGB")
    draw = ImageDraw.Draw(screen)
    background = screen.getpixel((70, 96))
    draw.rectangle((150, 50, 400, 140), fill=background)
    clock = font(TEXT, 51, "Semibold")
    w = draw.textlength("9:41", font=clock)
    draw.text((273 - w / 2, 66), "9:41", font=clock, fill=(0, 0, 0) if sum(background) / 3 > 128 else WHITE)
    return screen


def iphone(screen, width):
    """A raw 1320 × 2868 capture in an iPhone: metal case, black border, Dynamic Island, side buttons."""
    s = width / 1320
    screen = screen.convert("RGB").resize((width, round(2868 * s)), Image.LANCZOS)
    radius, border, metal, button = round(165 * s), round(33 * s), round(15 * s), round(12 * s)
    case_w, case_h = width + (border + metal) * 2, screen.height + (border + metal) * 2
    phone = Image.new("RGBA", (case_w + button * 2, case_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(phone)
    for top, height in [(510, 102), (702, 192), (966, 192)]:
        draw.rounded_rectangle((0, round(top * s), button * 2, round((top + height) * s)), radius=button, fill=(74, 74, 74, 255))
    draw.rounded_rectangle((case_w, round(708 * s), case_w + button * 2 - 1, round(1020 * s)), radius=button, fill=(74, 74, 74, 255))
    phone.paste(gradient((case_w, case_h), (70, 70, 72), (28, 28, 30)), (button, 0), rounded_mask((case_w, case_h), radius + border + metal))
    edge = Image.new("RGBA", (case_w, case_h), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((1, 1, case_w - 2, case_h - 2), radius=radius + border + metal, outline=(255, 255, 255, 80), width=3)
    phone.alpha_composite(edge, (button, 0))
    bezel = Image.new("RGB", (width + border * 2, screen.height + border * 2), (0, 0, 0))
    phone.paste(bezel, (button + metal, metal), rounded_mask(bezel.size, radius + border))
    phone.paste(screen, (button + metal + border, metal + border), rounded_mask(screen.size, radius))
    iw, ih = round(378 * s), round(111 * s)
    ix, iy = button + metal + border + (width - iw) // 2, metal + border + round(33 * s)
    ImageDraw.Draw(phone).rounded_rectangle((ix, iy, ix + iw, iy + ih), radius=ih // 2, fill=(0, 0, 0, 255))
    return phone


def watch(screen, width):
    """A raw Apple Watch capture in a watch case with the Digital Crown and side button."""
    s = width / screen.width
    screen = screen.convert("RGB").resize((width, round(screen.height * s)), Image.LANCZOS)
    radius, border, metal = round(width * 0.2), round(width * 0.045), round(width * 0.05)
    case_w, case_h = width + (border + metal) * 2, screen.height + (border + metal) * 2
    crown_w = round(width * 0.07)
    body = Image.new("RGBA", (case_w + crown_w, case_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(body)
    draw.rounded_rectangle((case_w - crown_w, round(case_h * 0.2), case_w + crown_w - 2, round(case_h * 0.36)), radius=crown_w // 2, fill=(120, 120, 124, 255))
    draw.rounded_rectangle((case_w - crown_w // 2, round(case_h * 0.48), case_w + crown_w // 2, round(case_h * 0.7)), radius=crown_w // 3, fill=(78, 78, 82, 255))
    body.paste(gradient((case_w, case_h), (72, 72, 76), (26, 26, 28)), (0, 0), rounded_mask((case_w, case_h), radius + border + metal))
    edge = Image.new("RGBA", (case_w, case_h), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((1, 1, case_w - 2, case_h - 2), radius=radius + border + metal, outline=(255, 255, 255, 80), width=3)
    body.alpha_composite(edge)
    bezel = Image.new("RGB", (width + border * 2, screen.height + border * 2), (0, 0, 0))
    body.paste(bezel, (metal, metal), rounded_mask(bezel.size, radius + border))
    body.paste(screen, (metal + border, metal + border), rounded_mask(screen.size, radius))
    return body


def card(raw, box, width, radius=48):
    """Lifts part of a screen out as a floating card."""
    crop = raw.convert("RGB").crop(box)
    crop = crop.resize((width, round(crop.height * width / crop.width)), Image.LANCZOS)
    tile = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    tile.paste(crop, (0, 0), rounded_mask(crop.size, radius))
    edge = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((1, 1, crop.width - 2, crop.height - 2), radius=radius, outline=(255, 255, 255, 60), width=3)
    tile.alpha_composite(edge)
    return tile


def place(canvas, layer, cx, top, angle=0, shadow=True):
    """Places a layer by its horizontal center and top edge, optionally tilted, with a soft shadow."""
    if angle:
        layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    x, y = round(cx - layer.width / 2), round(top)
    if shadow:
        alpha = layer.split()[3].point(lambda a: min(a, 170))
        shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        shade.paste((0, 0, 0, 255), (x + 10, y + 46), alpha)
        canvas.alpha_composite(shade.filter(ImageFilter.GaussianBlur(46)))
    canvas.alpha_composite(layer, (x, y))


def owl_on_line(canvas, owl, cx, width):
    """Dippy standing on the price line at panorama x = cx, with a soft contact shadow."""
    owl = owl.resize((width, round(owl.height * width / owl.width)), Image.LANCZOS)
    feet = line_y(cx) + width * 0.035
    shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).ellipse((cx - width * 0.36, feet - width * 0.05, cx + width * 0.36, feet + width * 0.07), fill=(0, 0, 0, 120))
    canvas.alpha_composite(shade.filter(ImageFilter.GaussianBlur(14)))
    canvas.alpha_composite(owl, (round(cx - width / 2), round(feet - owl.height)))


def chips(canvas, cx, top, labels, columns):
    """Labels as floating white pills, centered in rows."""
    draw = ImageDraw.Draw(canvas)
    chip_font = font(ROUNDED, 46, "Bold")
    y = top
    for start in range(0, len(labels), columns):
        row = labels[start:start + columns]
        widths = [draw.textlength(label, font=chip_font) + 76 for label in row]
        x = cx - (sum(widths) + 22 * (len(row) - 1)) / 2
        for label, w in zip(row, widths):
            shade = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
            ImageDraw.Draw(shade).rounded_rectangle((x, y + 12, x + w, y + 108), radius=48, fill=(0, 0, 0, 120))
            canvas.alpha_composite(shade.filter(ImageFilter.GaussianBlur(16)))
            draw.rounded_rectangle((x, y, x + w, y + 96), radius=48, fill=(255, 255, 255))
            draw.text((x + 38, y + 20), label, font=chip_font, fill=INK)
            x += w + 22
        y += 122


def checklist(canvas, cx, top, items):
    """The closing card: everything Dipwise does, ticked off."""
    item_font = font(ROUNDED, 56, "Bold")
    width, row = 1000, 112
    height = row * len(items) + 70
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle((0, 0, width - 1, height - 1), radius=56, fill=(255, 255, 255, 22), outline=(255, 255, 255, 50), width=3)
    for index, item in enumerate(items):
        y = 35 + index * row
        draw.ellipse((52, y + 20, 118, y + 86), fill=GREEN)
        draw.line([(68, y + 54), (81, y + 67), (103, y + 40)], fill=INK, width=9, joint="curve")
        draw.text((150, y + 20), item, font=item_font, fill=WHITE)
    place(canvas, layer, cx, top, shadow=False)


# MARK: - The ten images

def compose(raw_dir, out_dir):
    def raw(name):
        return Image.open(raw_dir / name)

    def owl(pose):
        return Image.open(raw_dir / f"owl-{pose}.png").convert("RGBA")

    pano = sky(W * COUNT, H)
    moon(pano, 1170, 420, 60)
    moon(pano, W * 9 + 1110, 250, 64)
    draw_price_line(pano)

    def x0(i):
        return W * i

    # 1 · Hero: Dippy perched on the dip, the app beside him, an alert flying in.
    headline(pano, x0(0), "YOUR STOCK-WATCHING OWL", "Buy the *dip*.", "Dippy watches your stocks day and night and taps you when it's time.")
    place(pano, iphone(fix_clock(raw("iphone-home.png")), 860), x0(0) + 830, 820, angle=-7)
    place(pano, card(raw("scene-lock.png"), (45, 708, 1275, 905), 880, radius=52), x0(0) + 840, 1700, angle=3)
    owl_on_line(pano, owl("idle"), x0(0) + 380, 560)

    # 2 · Draw the zone.
    headline(pano, x0(1), "BUY ZONES", "Draw your\n*buy zone*", "Drag two handles. Dippy alerts you the moment the price gets there.")
    place(pano, iphone(fix_clock(raw("iphone-zones.png")), 900), x0(1) + 760, 960, angle=6)
    place(pano, card(raw("iphone-zones.png"), (60, 1440, 1260, 2010), 980), x0(1) + 560, 1900, angle=-4)

    # 3 · The alert.
    headline(pano, x0(2), "SMART NOTIFICATIONS", "Never miss\n*the dip*", "An alert the second a stock enters your zone, with your plan inside.")
    place(pano, iphone(raw("scene-lock.png"), 900), x0(2) + 600, 960, angle=-6)
    place(pano, card(raw("scene-lock.png"), (45, 708, 1275, 1374), 1020, radius=60), x0(2) + 700, 1820, angle=3)
    owl_on_line(pano, owl("look-up"), x0(2) + 1110, 300)

    # 4 · The odds.
    headline(pano, x0(3), "ODDS", "Know your *odds*\nbefore you buy", "See how likely each plan is to trigger in the next 30 days.")
    place(pano, iphone(fix_clock(raw("iphone-stock.png")), 900), x0(3) + 700, 960, angle=6)
    place(pano, card(raw("iphone-stock.png"), (60, 2270, 1260, 2600), 1080, radius=44), x0(3) + 600, 2120, angle=-3)

    # 5 · Smart alerts.
    headline(pano, x0(4), "27 SMART ALERTS", "Pro signals,\n*plain English*", "RSI, golden crosses, trailing stops and more, each explained by Dippy.")
    place(pano, iphone(fix_clock(raw("iphone-smart.png")), 900), x0(4) + 600, 960, angle=-6)
    place(pano, card(raw("iphone-smart.png"), (60, 1320, 1260, 2385), 900, radius=48), x0(4) + 760, 1720, angle=4)

    # 6 · Widgets.
    headline(pano, x0(5), "WIDGETS", "Your plans,\nalways *in sight*", "Your plans, today's movers, and your streak right on your Home Screen.")
    place(pano, iphone(raw("scene-widgets.png"), 900), x0(5) + 740, 960, angle=6)
    place(pano, card(raw("scene-widgets.png"), (690, 805, 1170, 1280), 560, radius=70), x0(5) + 360, 1900, angle=-7)

    # 7 · Apple Watch.
    headline(pano, x0(6), "APPLE WATCH", "Your portfolio,\n*on your wrist*", "Portfolio, closest plans, and charts you scrub with the Digital Crown.")
    place(pano, watch(raw("watch-plans.png"), 520), x0(6) + 960, 1330, angle=9)
    place(pano, watch(raw("watch-today.png"), 660), x0(6) + 470, 1000, angle=-7)
    owl_on_line(pano, owl("wink"), x0(6) + 1040, 300)

    # 8 · Import.
    headline(pano, x0(7), "IMPORT", "Your portfolio\n*in seconds*", "Bring your positions in from a CSV export, no broker login needed.")
    place(pano, iphone(fix_clock(raw("iphone-import.png")), 860), x0(7) + 660, 960, angle=-5)
    chips(pano, x0(7) + 660, 2240, ["Robinhood", "Fidelity", "Schwab", "Vanguard", "E*TRADE", "IBKR", "Trading 212", "DEGIRO"], 4)

    # 9 · Watchlist and portfolio.
    headline(pano, x0(8), "PORTFOLIO", "Everything you own,\n*one calm place*", "Value, today's move, total return, and dividends in your currency.")
    place(pano, iphone(fix_clock(raw("iphone-watchlist.png")), 860), x0(8) + 820, 980, angle=6)
    place(pano, card(raw("iphone-home.png"), (60, 528, 1260, 2220), 760, radius=56), x0(8) + 420, 1460, angle=-5)

    # 10 · The closer: Dippy asleep on the last dip, everything ticked off.
    headline(pano, x0(9), "START FREE", "Sleep well.\n*Dippy's on watch.*", "Free to start. Go Pro when you want every alert.")
    checklist(pano, x0(9) + 660, 990, ["Buy and sell zones", "Instant price alerts", "27 smart alerts", "Odds for every plan", "Widgets & Apple Watch", "Import from your broker"])
    owl_on_line(pano, owl("sleep"), 12540, 520)

    out_dir.mkdir(parents=True, exist_ok=True)
    names = ["01-buy-the-dip", "02-buy-zone", "03-alerts", "04-odds", "05-smart-alerts",
             "06-widgets", "07-apple-watch", "08-import", "09-portfolio", "10-start-free"]
    for index, name in enumerate(names):
        path = out_dir / f"{name}.png"
        pano.crop((W * index, 0, W * (index + 1), H)).convert("RGB").save(path, optimize=True)
        print(path)
    pano.convert("RGB").resize((W * COUNT // 6, H // 6), Image.LANCZOS).save(out_dir.parent / "panorama-preview.png")


if __name__ == "__main__":
    compose(Path(sys.argv[1]), Path(sys.argv[2]))
