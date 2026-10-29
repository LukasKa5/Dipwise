"""A trial header video, English only: one day in Dippy's forest, as a 16-second loop at App Store Connect's header
video spec (21:9, 3840 x 1646, 60 fps, .mov, no sound).

  - Day, in the icon's own teal: the line reads "Your stock-watching owl." with a plain "o". Dippy blinks.
  - The sun sinks behind the firs; the sky warms to dusk, then deepens to the icon's navy night, and the stars come out.
  - The moon rises from behind the trees on the right, amber the way it is low on the horizon and the same size all
    the way, climbs the sky whitening as it goes, and comes down onto the "o", covering it with a soft bounce and a glow.
  - Dippy follows the sun, then the moon, and winks at you. He never sleeps.
  - Dawn: the night pales, the moon fades into the brightening sky, the "o" comes back, and the sun rises from behind
    the trees on the right and climbs to where it was in the first frame, so the loop never jumps.
Every move is eased, and Dippy's faces blend into each other.

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
FPS = 60
SECONDS = 16
FRAMES = FPS * SECONDS
HERE = Path(__file__).resolve().parent
LANG = "en"

SUNSET = (2.6, 6.2)          # the sun sinks behind the trees on the left
DUSK, NIGHT = 4.6, 7.4       # the sky is fully dusk, then fully night
MOONRISE, LAND = 5.4, 10.4   # the moon rises on the right and lands in the "o"
DAWN = (12.2, 13.8, 15.6)    # night pales into dawn, then day; the moon fades and the sun rises on the right
SUNRISE = (12.8, 16.0)       # and climbs back to where it was in the first frame
NOON = 0.45                  # where on its arc the sun is in the first frame

SKIES = {
    # Day in the icon's own palette: its deep teal, lit up, with a mint glow along the horizon.
    "day": [(0, (18, 78, 112)), (0.45, (32, 114, 144)), (0.78, (70, 168, 168)), (1, (96, 192, 176))],
    "dusk": [(0, (26, 38, 78)), (0.4, (96, 74, 120)), (0.7, (222, 130, 108)), (1, (246, 176, 120))],
    "night": [(0, (10, 26, 44)), (0.45, (20, 58, 82)), (0.72, (30, 80, 104)), (1, (10, 28, 44))],
}

# Dippy never sleeps: he only blinks once, and watches everything else happen.
FACES = [
    ("sleep", 1.5, 1.66, 0.05),        # a blink
    ("look-left", 3.0, 5.6, 0.2),      # watching the sun go down
    ("look-right", 6.0, 8.4, 0.2),     # the moon rising
    ("look-up", 8.4, 10.6, 0.2),       # the moon coming over the line
    ("wink", 11.0, 11.5, 0.1),         # a wink at you
    ("look-right", 13.0, 15.2, 0.25),  # the sun coming up
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


def recolor(layer, scale, offset):
    """The same land in another light: each channel scaled and lifted, alpha kept."""
    r, g, b, a = layer.split()
    channels = [ch.point(lambda v, s=s, o=o: min(255, round(v * s + o))) for ch, s, o in zip((r, g, b), scale, offset)]
    return Image.merge("RGBA", (*channels, a))


class Stage:
    def __init__(self, raw_dir):
        W, H = SIZE
        u = self.u = H / 1080
        cx = W / 2

        # The skies, each with the icon's faint lines.
        lines = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        ld = ImageDraw.Draw(lines)
        for i in range(1, 6):
            ld.line([(0, H * 0.12 * i), (W, H * 0.12 * i)], fill=(160, 210, 230, 16), width=max(1, round(2 * u)))
        self.skies = {}
        for name, stops in SKIES.items():
            sky = c.vertical_gradient(SIZE, stops)
            sky.alpha_composite(lines)
            self.skies[name] = sky

        # The land, in night, dusk, and day light.
        night = c.forest(SIZE, cx, moon=False, drop=0.1, front_gap=0.8, sky=False)
        self.land = {
            "night": night,
            "dusk": recolor(night, (1.25, 1.0, 1.05), (22, 6, 16)),
            "day": recolor(night, (1.3, 1.6, 1.3), (8, 26, 22)),
        }
        shade = Image.new("L", (64, 36), 0)
        ImageDraw.Draw(shade).ellipse((-14, -10, 78, 46), fill=255)
        self.shade = shade.filter(ImageFilter.GaussianBlur(7)).resize(SIZE, Image.BICUBIC).point(lambda v: 255 - v)

        # The stars: a quiet field and some that twinkle.
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
            self.stars.append((x, y, self.sparkle(r, rng.random() < 0.3), rng.uniform(1.2, 2.4), rng.uniform(0, 2 * math.pi)))

        # The line, with the moon's letter kept separate, and Dippy.
        (text_size, max_width, middle), (ox, feet, height) = c.header_layout(SIZE)
        self.text = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        letters = []
        self.slot = c.moonlit_line(self.text, c.TAGLINES[LANG], cx, 0, LANG, text_size, max_width, u,
                                   middle=middle, draw_moons=False, letters=letters)[0]
        # By day the moon's place holds an "o" drawn as a clean ring the moon's size, so it fills the same space and
        # the moon covers it exactly.
        self.letter = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        _, _, _, font, color = letters[0]
        mx, my, mr = self.slot
        k = 4
        ro = mr * 0.9
        ring = Image.new("L", (round(ro * 2 * k) + 8, round(ro * 2 * k) + 8), 0)
        ImageDraw.Draw(ring).ellipse((4, 4, ring.width - 5, ring.height - 5), outline=255, width=round(text_size * 0.108 * k))
        ring = ring.resize((ring.width // k, ring.height // k), Image.LANCZOS)
        paint = Image.new("RGBA", ring.size, color + (0,))
        paint.putalpha(ring)
        self.letter.alpha_composite(paint, (round(mx - ring.width / 2), round(my - ring.height / 2)))
        self.owls = {p: c.owl_image(raw_dir, p, height) for p in ("idle", "sleep", "look-left", "look-right", "look-up", "wink")}
        idle = self.owls["idle"]
        self.owl_at = (round(ox - idle.width / 2), round(feet - idle.height * 0.97))

        mx, my, mr = self.slot
        self.moon = self.body(mr * 1.2, moon=True)
        self.sun = self.body(H * 0.075, moon=False)
        self.first = None

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
        """The moon (with craters) or the sun, with its glow, drawn once, large, in its white and warm versions."""
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
        return {"disc": disc, "glow": glow, "r": r,
                "warm": (recolor(disc, warm, (0, 0, 0)), recolor(glow, warm, (0, 0, 0)))}

    def place(self, canvas, body, x, y, r, warmth, glow, alpha=1.0):
        k = r / body["r"]
        size = (max(2, round(body["disc"].width * k)), max(2, round(body["disc"].height * k)))
        at = (round(x - size[0] / 2), round(y - size[1] / 2))
        disc = Image.blend(body["disc"], body["warm"][0], warmth) if warmth > 0.01 else body["disc"]
        halo = Image.blend(body["glow"], body["warm"][1], warmth) if warmth > 0.01 else body["glow"]
        halo = halo.resize(size, Image.BILINEAR)
        halo.putalpha(halo.getchannel("A").point(lambda a: min(255, round(a * glow * alpha))))
        canvas.alpha_composite(halo, at)
        disc = disc.resize(size, Image.LANCZOS)
        if alpha < 1:
            disc.putalpha(disc.getchannel("A").point(lambda a: round(a * alpha)))
        canvas.alpha_composite(disc, at)

    def moon_path(self, k):
        """Up from behind the trees on the right, over the top, and straight down onto the letter."""
        W, H = SIZE
        mx, my, mr = self.slot
        points = [(W / 2 + H * 1.08, H * 1.0), (W / 2 + H * 1.02, H * 0.02), (mx + H * 0.04, H * 0.04), (mx, my)]
        a, b, cc, d = (1 - k) ** 3, 3 * (1 - k) ** 2 * k, 3 * (1 - k) * k * k, k ** 3
        x = a * points[0][0] + b * points[1][0] + cc * points[2][0] + d * points[3][0]
        y = a * points[0][1] + b * points[1][1] + cc * points[2][1] + d * points[3][1]
        return x, y

    def sun_at(self, s):
        """The sun's one arc across the sky: up from behind the trees on the right (0), over the top, and down behind
        the trees on the left (1)."""
        W, H = SIZE
        angle = math.pi * s
        return W / 2 + H * 1.15 * math.cos(angle), H * 1.05 - H * 0.98 * math.sin(angle)

    def scenery(self, t):
        """Sky, stars, sun, the rising moon while it is behind the trees, the land, and the vignette. Returns the
        canvas and the moon in front of everything once it is clear of the trees (or None)."""
        W, H = SIZE
        to_dusk = between(t, SUNSET[0], DUSK) * (1 - between(t, DAWN[1], DAWN[2]))
        to_night = between(t, DUSK, NIGHT) * (1 - between(t, DAWN[0], DAWN[1]))

        def mix(images):
            image = Image.blend(images["day"], images["dusk"], to_dusk) if to_dusk < 1 else images["dusk"]
            return Image.blend(image, images["night"], to_night) if to_night > 0 else image

        canvas = mix(self.skies)

        dark = between(t, DUSK, NIGHT + 0.6) * (1 - between(t, DAWN[0] - 0.2, DAWN[1]))
        if dark > 0.01:
            field = self.starfield.copy()
            field.putalpha(self.starfield.getchannel("A").point(lambda a: round(a * dark)))
            canvas.alpha_composite(field)
            for x, y, sprite, speed, offset in self.stars:
                level = dark * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(speed * t * 2 * math.pi / 3 + offset)))
                faded = sprite.copy()
                faded.putalpha(sprite.getchannel("A").point(lambda a: round(a * level)))
                canvas.alpha_composite(faded, (round(x - sprite.width / 2), round(y - sprite.height / 2)))

        # The sun travels one arc, right to left: it sets on the left, and at dawn comes up again on the right, so
        # it never jumps. Low in the sky it warms to amber.
        if t < SUNSET[1] + 0.1:
            s = NOON + (1 - NOON) * between(t, *SUNSET)
        elif t >= SUNRISE[0] - 0.1:
            s = NOON * between(t, *SUNRISE)
        else:
            s = None
        if s is not None:
            sx, sy = self.sun_at(s)
            warmth = min(1.0, max(0.0, (sy - H * 0.3) / (H * 0.5)))
            self.place(canvas, self.sun, sx, sy, self.sun["r"], warmth, 1.0)

        # The moon, the same size all the way, rises behind the trees, then crosses in front of the sky to the
        # letter; at dawn it fades into the brightening sky.
        moon, behind = None, False
        if MOONRISE <= t:
            k = between(t, MOONRISE, LAND)
            x, y = self.moon_path(k)
            r = self.slot[2]
            if t >= LAND:
                since = t - LAND
                r *= 1 + 0.08 * math.exp(-since * 5) * math.cos(since * 14)
            glow = 0.9 + (1.4 * math.exp(-(t - LAND) * 2.4) if t >= LAND else 0)
            fade = 1 - between(t, DAWN[0] + 0.4, DAWN[1] + 0.8)
            if fade > 0.001:
                moon = (x, y, r, 1 - smooth(k * 1.6), glow, fade)
                behind = k < 0.35
                if behind:
                    self.place(canvas, self.moon, *moon)

        canvas.alpha_composite(mix(self.land))
        vignette = Image.new("RGBA", SIZE, (4, 10, 20, 0))
        vignette.putalpha(self.shade.point(lambda v: round(v * (0.25 + 0.25 * to_night))))
        canvas.alpha_composite(vignette)
        return canvas, (None if behind else moon)

    def actors(self, canvas, t, moon):
        """Dippy, the line, the letter while the moon is away, and the moon over it."""
        owl = self.owls["idle"]
        for pose, weight in faces_at(t):
            owl = Image.blend(owl, self.owls[pose], weight)
        c.paste_clipped(canvas, owl, *self.owl_at)
        canvas.alpha_composite(self.text)
        letter = max(1 - between(t, LAND - 0.3, LAND), between(t, DAWN[0] + 0.4, DAWN[1] + 0.8))
        if letter > 0.001:
            shown = self.letter.copy()
            shown.putalpha(self.letter.getchannel("A").point(lambda a: round(a * letter)))
            canvas.alpha_composite(shown)
        if moon:
            self.place(canvas, self.moon, *moon)
        return canvas.convert("RGB")

    def frame(self, index):
        t = index / FPS
        canvas, moon = self.scenery(t)
        return self.actors(canvas, t, moon)


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
