"""The animated product page header: a 12-second loop of Dippy's night forest, at App Store Connect's header video
spec (21:9, 3840 x 1646, 60 fps, 5-30 s, .mov, no sound), in every language the app supports.

The moon stays in the "o" of "owl" the whole time; everything is eased, at 60 frames a second, so it glides:
  - The stars twinkle and the moon breathes softly. Dippy blinks.
  - Dippy looks up at the moon, and it slowly brightens while he watches, then settles.
  - Dippy looks back at you and winks, blinks once more, and the last frame flows into the first.
The first frame is the finished line with Dippy looking at you, so it doubles as the poster frame.

Run:  python3 Marketing/ScreenshotStudio/header_animation.py Marketing/ScreenshotStudio/Raw Marketing/AppStore/HeaderVideo
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
SECONDS = 12
FRAMES = FPS * SECONDS
HERE = Path(__file__).resolve().parent

def smooth(x):
    """Ease in and out, clamped: the curve every move in the video follows."""
    x = min(1.0, max(0.0, x))
    return x * x * x * (x * (x * 6 - 15) + 10)


def between(t, start, end):
    return smooth((t - start) / (end - start))


# Dippy's faces over time, each as (pose, start, end, fade): the face fades in over `fade` seconds and out again.
FACES = [
    ("sleep", 1.6, 1.78, 0.05),     # a blink
    ("look-up", 4.2, 9.2, 0.18),    # watching the moon
    ("sleep", 9.9, 10.08, 0.05),    # a blink
    ("wink", 10.5, 11.1, 0.1),      # a wink at you
]


def faces_at(t):
    """How much of each face shows at time `t`; Dippy's own idle face fills in the rest."""
    weights = []
    for pose, start, end, fade in FACES:
        w = min(between(t, start - fade, start), 1 - between(t, end, end + fade))
        if w > 0.001:
            weights.append((pose, w))
    return weights


class Stage:
    """Everything that doesn't move, rendered once; each frame only lays the moving parts on top."""

    def __init__(self, raw_dir, lang):
        W, H = SIZE
        self.u = H / 1080
        self.background = c.header_scene(SIZE)
        (text_size, max_width, middle), (cx, feet, height) = c.header_layout(SIZE)
        self.text = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        moons = c.moonlit_line(self.text, c.TAGLINES[lang], W / 2, 0, lang, text_size, max_width, self.u,
                               middle=middle, draw_moons=False)
        self.slot = moons[0]
        self.owls = {pose: c.owl_image(raw_dir, pose, height) for pose in ("idle", "sleep", "look-up", "wink")}
        idle = self.owls["idle"]
        self.owl_at = (round(cx - idle.width / 2), round(feet - idle.height * 0.97))
        self.moon = self.moon_sprite(self.slot[2] * 1.3)
        rng = random.Random(27)
        self.stars = []
        for _ in range(26):
            x, y = rng.uniform(0.04, 0.96) * W, rng.uniform(0.04, 0.34) * H
            r = rng.uniform(2.2, 3.6) * self.u
            self.stars.append((x, y, self.sparkle(r, sparkle=rng.random() < 0.3), rng.choice([1, 2]), rng.uniform(0, 2 * math.pi)))

    def moon_sprite(self, r):
        """The moon and its halo, drawn once, large, and scaled down per frame."""
        pad = round(r * 6)
        disc = Image.new("RGBA", (pad * 2, pad * 2), (0, 0, 0, 0))
        c.full_moon(disc, pad, pad, r)
        halo = Image.new("RGBA", disc.size, (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse((pad - r * 2.6, pad - r * 2.6, pad + r * 2.6, pad + r * 2.6), fill=(255, 236, 190, 120))
        return disc, halo.filter(ImageFilter.GaussianBlur(r * 1.1)), r

    def sparkle(self, r, sparkle):
        """A star: a soft dot, and for some a thin four-pointed glint."""
        size = round(r * (9 if sparkle else 4))
        image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(image)
        m = size / 2
        d.ellipse((m - r * 1.8, m - r * 1.8, m + r * 1.8, m + r * 1.8), fill=(255, 255, 255, 40))
        if sparkle:
            d.polygon([(m, 0), (m + r * 0.35, m), (m, size), (m - r * 0.35, m)], fill=(255, 255, 255, 150))
            d.polygon([(0, m), (m, m - r * 0.35), (size, m), (m, m + r * 0.35)], fill=(255, 255, 255, 150))
        d.ellipse((m - r, m - r, m + r, m + r), fill=(255, 255, 255, 255))
        return image

    def moon_state(self, t):
        """The moon sits in the letter; it breathes, and brightens while Dippy looks up at it."""
        x, y, r = self.slot
        breathe = 0.85 + 0.15 * math.sin(2 * math.pi * 2 * t / SECONDS)
        watched = between(t, 4.4, 6.2) * (1 - between(t, 8.0, 9.6))
        return x, y, r * (1 + 0.06 * watched), breathe + 0.9 * watched

    def frame(self, index):
        t = index / FPS
        phase = t / SECONDS
        canvas = self.background.copy()

        # Stars twinkle on whole cycles of the loop, so the last frame flows into the first.
        for x, y, sprite, cycles, offset in self.stars:
            level = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(2 * math.pi * cycles * phase + offset))
            faded = sprite.copy()
            faded.putalpha(sprite.getchannel("A").point(lambda a: round(a * level)))
            canvas.alpha_composite(faded, (round(x - sprite.width / 2), round(y - sprite.height / 2)))

        # Dippy: his idle face, with any other face blended over it as it fades in and out.
        owl = self.owls["idle"]
        for pose, weight in faces_at(t):
            owl = Image.blend(owl, self.owls[pose], weight)
        c.paste_clipped(canvas, owl, *self.owl_at)

        canvas.alpha_composite(self.text)

        x, y, r, glow = self.moon_state(t)
        disc, halo, base = self.moon
        k = r / base
        size = (max(2, round(disc.width * k)), max(2, round(disc.height * k)))
        at = (round(x - size[0] / 2), round(y - size[1] / 2))
        lit = halo.resize(size, Image.BILINEAR)
        lit.putalpha(lit.getchannel("A").point(lambda a: min(255, round(a * glow))))
        canvas.alpha_composite(lit, at)
        canvas.alpha_composite(disc.resize(size, Image.LANCZOS), at)
        return canvas.convert("RGB")


_stage = None


def _init(raw_dir, lang):
    global _stage
    _stage = Stage(raw_dir, lang)


def _render(job):
    index, folder = job
    _stage.frame(index).save(folder / f"{index:04d}.png", compress_level=1)
    return index


def render(raw_dir, lang, out_dir, encoder):
    frames = Path(tempfile.mkdtemp(prefix=f"dipwise-header-{lang}-"))
    with Pool(initializer=_init, initargs=(raw_dir, lang)) as pool:
        for _ in pool.imap_unordered(_render, [(i, frames) for i in range(FRAMES)], chunksize=8):
            pass
    target = out_dir / lang / "header-3840x1646.mov"
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(encoder), str(frames), str(target), str(FPS)], check=True)
    shutil.copy(frames / "0000.png", target.with_name("poster-3840x1646.png"))
    shutil.rmtree(frames)


def main(raw_dir, out_dir, langs):
    encoder = Path(tempfile.gettempdir()) / "dipwise-encode-frames"
    subprocess.run(["swiftc", "-O", str(HERE / "encode_frames.swift"), "-o", str(encoder)], check=True)
    for lang in langs:
        render(raw_dir, lang, out_dir, encoder)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:] or c.LANGUAGES)
