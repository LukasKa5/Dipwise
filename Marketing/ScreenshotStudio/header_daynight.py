"""A trial header video, English only: one day and night in Dippy's forest, as a 20-second loop at App Store
Connect's header video spec (21:9, 3840 x 1646, 30 fps, .mov, no sound).

It follows the sky the way it really works, so every moment leads to the next and nothing ever jumps or stalls:
  - The sun crosses the sky on one arc, rising behind the firs on the right and setting behind those on the left, at
    an even pace. The sky follows it: day in the icon's teal, a long dusk from the sun nearing the trees until the
    moon is well up, the icon's navy night, and a long dawn around sunrise.
  - The stars come out with the dark and fade with the dawn.
  - The full moon rises as the sun sets, from behind the trees on the right, and its arc reaches its highest
    point exactly at the "o" of "owl": it slows there and covers the letter, a real letter in the same font as the
    rest, then carries on and sets behind the trees on the left, well before the sun comes up. It keeps the same size
    and color all the way.
  - Dippy follows the sun and the moon with his eyes, blinks, and winks at you. He never sleeps.
Every bit of motion is continuous, and Dippy's faces blend into each other.

Run:  python3 Marketing/ScreenshotStudio/header_daynight.py Marketing/ScreenshotStudio/Raw Marketing/AppStore/HeaderVideo
"""

import math
import random
import shutil
import subprocess
import sys
import tempfile
from multiprocessing import Pool
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

import compose as c

SIZE = (3840, 1646)
FPS = 30
SUBFRAMES = 2                     # each frame blends two moments, a touch of motion blur, so 30 fps glides
SECONDS = 20
FRAMES = FPS * SECONDS
HERE = Path(__file__).resolve().parent
LANG = "en"

SUNRISE, DAYLIGHT = 17.0, 8.0     # the sun comes up at 17 s and is up for 8 s, across the loop's seam
MOONRISE, MOONSET = 5.2, 15.0     # a full moon rises as the sun sets, and sets well before sunrise
TRANSIT = (MOONRISE + MOONSET) / 2  # its highest point, in the "o"

SKIES = {
    # Day in the icon's own palette: its deep teal, lit up, with a mint glow along the horizon.
    "day": [(0, (18, 78, 112)), (0.45, (32, 114, 144)), (0.78, (70, 168, 168)), (1, (96, 192, 176))],
    "dusk": [(0, (26, 38, 78)), (0.4, (96, 74, 120)), (0.7, (222, 130, 108)), (1, (246, 176, 120))],
    "night": [(0, (10, 26, 44)), (0.45, (20, 58, 82)), (0.72, (30, 80, 104)), (1, (10, 28, 44))],
}

# How dark the sky is (0 day, 0.5 dusk, 1 night) through the loop. The twilights are long: dusk lingers from the
# sun nearing the trees until the moon is well up, and dawn the same way around sunrise. Joined by a smooth curve
# that never stops in the middle of a change.
SKY = [(0.0, 0.0), (2.8, 0.0), (4.3, 0.36), (5.0, 0.48), (7.0, 0.6), (8.8, 1.0),
       (14.6, 1.0), (16.0, 0.62), (17.0, 0.5), (17.8, 0.38), (19.4, 0.0), (20.0, 0.0)]

# Dippy never sleeps: one blink, and his eyes on whatever is moving in the sky.
FACES = [
    ("sleep", 1.0, 1.16, 0.05),        # a blink
    ("look-left", 2.6, 5.0, 0.3),      # the sun going down on the left
    ("look-right", 5.6, 8.6, 0.3),     # the moon rising on the right
    ("look-up", 8.6, 9.8, 0.3),        # the moon reaching the "o"
    ("wink", 10.4, 10.9, 0.1),         # a wink at you, the moon in its letter
    ("look-left", 12.4, 14.8, 0.3),    # the moon setting on the left
    ("look-right", 16.6, 19.0, 0.3),   # the sun coming up on the right
]


def smooth(x):
    x = min(1.0, max(0.0, x))
    return x * x * x * (x * (x * 6 - 15) + 10)


def between(t, start, end):
    return smooth((t - start) / (end - start))


def faces_at(t):
    weights = []
    for pose, start, end, fade in FACES:
        w = min(between(t, start - fade, start), 1 - between(t, end, end + fade))
        if w > 0.001:
            weights.append((pose, w))
    return weights


def sun_progress(t):
    """How far across its arc the sun is (0 rising, 1 setting), or None while it is down, and its height: positive
    above the horizon, negative below it, deepest at midnight."""
    since = (t - SUNRISE) % SECONDS
    if since < DAYLIGHT:
        p = since / DAYLIGHT
        return p, math.sin(math.pi * p)
    q = (since - DAYLIGHT) / (SECONDS - DAYLIGHT)
    return None, -math.sin(math.pi * q)


def darkness(t):
    """How far the sky is from day (0) to night (1) at time `t`, along `SKY`: a monotone cubic through the keys, so
    the change is smooth everywhere and only rests where the sky itself rests, at full day and full night."""
    t %= SECONDS
    times, values = zip(*SKY)
    slopes = [(values[i + 1] - values[i]) / (times[i + 1] - times[i]) for i in range(len(SKY) - 1)]
    tangents = [slopes[0]] + [0.0 if a * b <= 0 else 2 / (1 / a + 1 / b) for a, b in zip(slopes, slopes[1:])] + [slopes[-1]]
    for i in range(len(SKY) - 1):
        if times[i] <= t <= times[i + 1]:
            h = times[i + 1] - times[i]
            x = (t - times[i]) / h
            return (values[i] * (2 * x ** 3 - 3 * x ** 2 + 1) + tangents[i] * h * (x ** 3 - 2 * x ** 2 + x)
                    + values[i + 1] * (-2 * x ** 3 + 3 * x ** 2) + tangents[i + 1] * h * (x ** 3 - x ** 2))
    return 0.0


def moon_progress(t):
    """How far along its arc the moon is (0 rising, 1 setting): an even pace that slows to rest in the "o" at its
    highest point, then picks up again, symmetric, so it rises and sets at the same speed."""
    if not MOONRISE <= t <= MOONSET:
        return None

    def speed(x):
        return 1 - 0.94 * math.exp(-((x - TRANSIT) / 1.2) ** 2)

    def travelled(x, steps=400):
        h = (x - MOONRISE) / steps
        return sum(speed(MOONRISE + (i + 0.5) * h) for i in range(steps)) * h

    return travelled(t) / travelled(MOONSET)


def recolor(layer, scale, offset):
    r, g, b, a = layer.split()
    channels = [ch.point(lambda v, s=s, o=o: min(255, round(v * s + o))) for ch, s, o in zip((r, g, b), scale, offset)]
    return Image.merge("RGBA", (*channels, a))


class Stage:
    def __init__(self, raw_dir):
        W, H = SIZE
        u = self.u = H / 1080
        cx = W / 2

        lines = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        ld = ImageDraw.Draw(lines)
        for i in range(1, 6):
            ld.line([(0, H * 0.12 * i), (W, H * 0.12 * i)], fill=(160, 210, 230, 16), width=max(1, round(2 * u)))
        self.skies = {}
        for name, stops in SKIES.items():
            sky = c.vertical_gradient(SIZE, stops)
            sky.alpha_composite(lines)
            self.skies[name] = sky

        night = c.forest(SIZE, cx, moon=False, drop=0.1, front_gap=0.8, sky=False)
        self.land = {
            "night": night,
            "dusk": recolor(night, (1.25, 1.0, 1.05), (22, 6, 16)),
            "day": recolor(night, (1.3, 1.6, 1.3), (8, 26, 22)),
        }
        shade = Image.new("L", (64, 36), 0)
        ImageDraw.Draw(shade).ellipse((-14, -10, 78, 46), fill=255)
        self.shade = shade.filter(ImageFilter.GaussianBlur(7)).resize(SIZE, Image.BICUBIC).point(lambda v: 255 - v)

        rng = random.Random(5)
        self.starfield = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        sd = ImageDraw.Draw(self.starfield)
        for _ in range(int(W / H * 26)):
            sx, sy = rng.uniform(0, W), rng.uniform(H * 0.02, H * 0.5)
            r = rng.choice([1.6, 2.2, 3.0]) * u
            sd.ellipse((sx - r, sy - r, sx + r, sy + r), fill=(255, 255, 255, rng.randint(60, 170)))
        rng = random.Random(27)
        self.stars = []
        for _ in range(22):
            x, y = rng.uniform(0.04, 0.96) * W, rng.uniform(0.04, 0.34) * H
            r = rng.uniform(2.2, 3.4) * u
            # Whole twinkles per loop, so the last frame meets the first.
            self.stars.append((x, y, self.sparkle(r, rng.random() < 0.3), rng.choice([5, 6, 7]), rng.uniform(0, 2 * math.pi)))

        # The line with a real "o", in the same font and spacing as the rest, kept on its own layer.
        (text_size, max_width, middle), (ox, feet, height) = c.header_layout(SIZE)
        self.text = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        letters = []
        self.slot = c.moonlit_line(self.text, c.TAGLINES[LANG], cx, 0, LANG, text_size, max_width, u, middle=middle,
                                   draw_moons=False, letters=letters, natural=True)[0]
        self.letter = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        letter, lx, ltop, font, color = letters[0]
        ImageDraw.Draw(self.letter).text((lx, ltop), letter, font=font, fill=color)

        self.owls = {p: c.owl_image(raw_dir, p, height) for p in ("idle", "sleep", "look-left", "look-right", "look-up", "wink")}
        idle = self.owls["idle"]
        self.owl_at = (round(ox - idle.width / 2), round(feet - idle.height * 0.97))

        mx, my, mr = self.slot
        self.moon = self.body(mr * 1.2, moon=True)
        self.sun = self.body(H * 0.075, moon=False)

    def sparkle(self, r, glint):
        size = round(r * (9 if glint else 4))
        image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(image)
        m = size / 2
        d.ellipse((m - r * 1.8, m - r * 1.8, m + r * 1.8, m + r * 1.8), fill=(255, 255, 255, 40))
        if glint:
            d.polygon([(m, 0), (m + r * 0.35, m), (m, size), (m - r * 0.35, m)], fill=(255, 255, 255, 150))
            d.polygon([(0, m), (m, m - r * 0.35), (size, m), (m, m + r * 0.35)], fill=(255, 255, 255, 150))
        d.ellipse((m - r, m - r, m + r, m + r), fill=(255, 255, 255, 255))
        return image

    def body(self, r, moon):
        pad = round(r * 6)
        disc = Image.new("RGBA", (pad * 2, pad * 2), (0, 0, 0, 0))
        if moon:
            c.full_moon(disc, pad, pad, r)
            glow_color, reach = (255, 236, 190, 120), 2.6
        else:
            c.aa_shapes(disc, lambda d, k: d.ellipse(((pad - r) * k, (pad - r) * k, (pad + r) * k, (pad + r) * k), fill=255), (255, 248, 226))
            glow_color, reach = (255, 240, 200, 150), 4.0
        glow = Image.new("RGBA", disc.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse((pad - r * reach, pad - r * reach, pad + r * reach, pad + r * reach), fill=glow_color)
        glow = glow.filter(ImageFilter.GaussianBlur(r * 1.2))
        warm = (1.0, 0.72, 0.46)
        return {"disc": disc, "glow": glow, "r": r, "warm": (recolor(disc, warm, (0, 0, 0)), recolor(glow, warm, (0, 0, 0)))}

    def place(self, canvas, body, x, y, r, warmth=0.0, glow=1.0):
        k = r / body["r"]
        size = (max(2, round(body["disc"].width * k)), max(2, round(body["disc"].height * k)))
        at = (round(x - size[0] / 2), round(y - size[1] / 2))
        disc = Image.blend(body["disc"], body["warm"][0], warmth) if warmth > 0.01 else body["disc"]
        halo = Image.blend(body["glow"], body["warm"][1], warmth) if warmth > 0.01 else body["glow"]
        if glow > 0:
            halo = halo.resize(size, Image.BILINEAR)
            halo.putalpha(halo.getchannel("A").point(lambda a: min(255, round(a * glow))))
            canvas.alpha_composite(halo, at)
        canvas.alpha_composite(disc.resize(size, Image.LANCZOS), at)

    def sun_at(self, p):
        """The sun's arc: up from behind the trees on the right, high over the line, down behind the trees on the left."""
        W, H = SIZE
        angle = math.pi * p
        return W / 2 + H * 0.95 * math.cos(angle), H * 1.15 - H * 1.05 * math.sin(angle)

    def moon_at(self, p):
        """The moon's arc: up from behind the trees on the right, its highest point exactly in the "o", and down
        behind the trees on the left."""
        H = SIZE[1]
        mx, my, _ = self.slot
        angle = math.pi * p
        # A shorter reach on the rising side, so it comes up just inside the frame, and a longer one on the setting
        # side, so it sets in the forest to the left of Dippy rather than behind him.
        reach = H * (0.62 if p < 0.5 else 1.4)
        return mx + reach * math.cos(angle), H * 1.15 - (H * 1.15 - my) * math.sin(angle)

    def mix(self, images, dark):
        if dark <= 0.5:
            return Image.blend(images["day"], images["dusk"], dark * 2)
        return Image.blend(images["dusk"], images["night"], (dark - 0.5) * 2)

    def frame(self, index):
        moments = [self.moment((index + k / SUBFRAMES) / FPS) for k in range(SUBFRAMES)]
        image = moments[0]
        for k, other in enumerate(moments[1:], start=2):
            image = Image.blend(image, other, 1 / k)
        return image

    def moment(self, t):
        sun, height = sun_progress(t)
        dark = darkness(t)
        canvas = self.mix(self.skies, dark)

        stars = smooth((dark - 0.6) / 0.35)
        if stars > 0.001:
            field = self.starfield.copy()
            field.putalpha(self.starfield.getchannel("A").point(lambda a: round(a * stars)))
            canvas.alpha_composite(field)
            for x, y, sprite, cycles, offset in self.stars:
                level = stars * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(2 * math.pi * cycles * t / SECONDS + offset)))
                faded = sprite.copy()
                faded.putalpha(sprite.getchannel("A").point(lambda a: round(a * level)))
                canvas.alpha_composite(faded, (round(x - sprite.width / 2), round(y - sprite.height / 2)))

        if sun is not None:
            sx, sy = self.sun_at(sun)
            self.place(canvas, self.sun, sx, sy, self.sun["r"], warmth=1 - smooth(height / 0.45))

        moon = moon_progress(t)
        coverage = 0.0
        if moon is not None:
            mx, my = self.moon_at(moon)
            # A soft glow in the "o" as it settles there.
            glow = 1.0 + 0.6 * math.exp(-((t - TRANSIT) / 1.0) ** 2)
            self.place(canvas, self.moon, mx, my, self.slot[2], glow=glow)
            distance = math.hypot(mx - self.slot[0], my - self.slot[1])
            coverage = 1 - smooth(distance / (self.slot[2] * 2.2))

        # The land, in front of the sun and the moon, so they rise and set behind the trees.
        canvas.alpha_composite(self.mix(self.land, dark))
        vignette = Image.new("RGBA", SIZE, (4, 10, 20, 0))
        vignette.putalpha(self.shade.point(lambda v: round(v * (0.25 + 0.25 * dark))))
        canvas.alpha_composite(vignette)

        owl = self.owls["idle"]
        for pose, weight in faces_at(t):
            owl = Image.blend(owl, self.owls[pose], weight)
        c.paste_clipped(canvas, owl, *self.owl_at)

        # The line, in front of the moon as it glides behind the words; its "o" gives way as the moon covers it.
        canvas.alpha_composite(self.text)
        if coverage < 0.999:
            shown = self.letter.copy()
            shown.putalpha(self.letter.getchannel("A").point(lambda a: round(a * (1 - coverage))))
            canvas.alpha_composite(shown)
        if coverage > 0.001:
            # In the "o" the moon is the letter, so it comes to the front there.
            front = Image.new("RGBA", SIZE, (0, 0, 0, 0))
            self.place(front, self.moon, *self.moon_at(moon), self.slot[2], glow=0)
            front.putalpha(front.getchannel("A").point(lambda a: round(a * coverage)))
            canvas.alpha_composite(front)
        return canvas.convert("RGB")


_stage = None


def _init(raw_dir):
    global _stage
    _stage = Stage(raw_dir)


def _render(job):
    index, folder = job
    _stage.frame(index).save(folder / f"{index:04d}.png", compress_level=1)
    return index


def main(raw_dir, out_dir):
    encoder = Path(tempfile.gettempdir()) / "dipwise-encode-frames"
    subprocess.run(["swiftc", "-O", str(HERE / "encode_frames.swift"), "-o", str(encoder)], check=True)
    frames = Path(tempfile.mkdtemp(prefix="dipwise-daynight-"))
    with Pool(initializer=_init, initargs=(raw_dir,)) as pool:
        for _ in pool.imap_unordered(_render, [(i, frames) for i in range(FRAMES)], chunksize=8):
            pass
    target = out_dir / LANG / "header-day-night-3840x1646.mov"
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(encoder), str(frames), str(target), str(FPS)], check=True)
    shutil.copy(frames / "0000.png", target.with_name("poster-day-night-3840x1646.png"))
    shutil.rmtree(frames)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
