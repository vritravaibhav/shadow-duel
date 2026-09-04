#!/usr/bin/env python3
"""Imports the downloaded CC0 sprite packs in assets/images/packs/ into the
game. For every pack it detects the frame size (frames may be non-square),
the feet baseline, body center and height, which way the art faces, maps the
pack's sheets onto the game's animation names, records a per-frame weapon-tip
point for attack trails, crops a headshot portrait, and writes
assets/images/packs.json.

    python3 tool/import_packs.py
"""
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'assets', 'images'))

# Candidate sheet names per game animation, first match wins.
ANIMS = {
    'idle': ['Idle'],
    'walk': ['Run', 'Move'],
    'punch': ['Attack1', 'Attack_1', 'Attack'],
    'kick': ['Attack2', 'Attack_2', 'Attack1', 'Attack_1', 'Attack'],
    'slash': ['Attack2', 'Attack_2', 'Attack1', 'Attack_1', 'Attack'],
    'heavy': ['Attack3', 'Attack2', 'Attack_2', 'Attack1', 'Attack_1', 'Attack'],
    'hit': ['TakeHit', 'Hit', 'GetHit'],
    'death': ['Death'],
    'victory': ['Idle'],
    # Extra strips used by the two-stick combo clips (lib/game/combos.dart);
    # packs without them fall back to the core set at load time.
    'jump': ['Jump', 'GoingUp'],
    'fall': ['Fall', 'GoingDown'],
    'attack3': ['Attack3', 'Attack4'],
    'dash': ['Dash'],
}
OPTIONAL = {'jump', 'fall', 'attack3', 'dash'}
ATTACKS = {'punch', 'kick', 'slash', 'heavy', 'attack3'}
FPS = dict(idle=10, walk=12, punch=12, kick=12, slash=12, heavy=11, hit=12, death=10, victory=10,
           jump=10, fall=10, attack3=12, dash=14)
LOOP = {'idle', 'walk', 'victory'}
ALPHA_MIN = 40

# height = on-screen body height in game units; build scales the ground shadow;
# glow = portrait tint; head = portrait crop (center y, size, x shift) as body
# fractions; flip overrides the auto facing detection when set.
PACKS = {
    'martial-hero': dict(credit='Martial Hero', height=150, glow=(125, 235, 255), head=(0.30, 0.5, 0.0)),
    'martial-hero-2': dict(credit='Martial Hero 2', height=150, glow=(255, 90, 90)),
    'martial-hero-3': dict(credit='Martial Hero 3', height=150, glow=(255, 150, 80), head=(0.20, 0.5, 0.0)),
    'hero-knight-2': dict(credit='Hero Knight 2', height=150, glow=(200, 200, 220)),
    'huntress-2': dict(credit='Huntress 2', height=145, glow=(140, 230, 120)),
    'medieval-warrior-pack-2': dict(credit='Medieval Warrior Pack 2', height=150, glow=(255, 120, 120)),
    'medieval-warrior-pack-3': dict(credit='Medieval Warrior Pack 3', height=150, glow=(150, 170, 255)),
    'fantasy-warrior': dict(credit='Fantasy Warrior', height=158, build=1.1, glow=(120, 255, 200)),
    'huntress': dict(credit='Huntress', height=150, glow=(200, 180, 120)),
    'hero-knight': dict(credit='Hero Knight', height=155, glow=(190, 200, 230)),
    'evil-wizard': dict(credit='Evil Wizard', height=150, glow=(255, 160, 60)),
    'medieval-king-pack': dict(credit='Medieval King Pack', height=165, build=1.15, glow=(255, 215, 90)),
    'medieval-king-pack-2': dict(credit='Medieval King Pack 2', height=160, build=1.15, glow=(120, 170, 255)),
    'wizard-pack': dict(credit='Wizard Pack', height=175, build=1.3, glow=(200, 120, 255)),
    'evil-wizard-2': dict(credit='Evil Wizard 2', height=178, build=1.4, glow=(220, 90, 255), head=(0.47, 0.45, -0.03)),
}


def normalize_names(folder):
    for f in os.listdir(folder):
        if f.endswith('.png') and ' ' in f:
            os.rename(os.path.join(folder, f), os.path.join(folder, f.replace(' ', '')))


def sheet_path(folder, names):
    for n in names:
        p = os.path.join(folder, n + '.png')
        if os.path.exists(p):
            return n, p
    return None, None


def detect_frame_width(folder, fs):
    widths = [Image.open(os.path.join(folder, f)).size[0]
              for f in os.listdir(folder) if f.endswith('.png') and f != 'portrait.png']
    for w in range(fs, int(fs * 1.6) + 1):
        if all(W % w == 0 for W in widths):
            return w
    return fs


def frames(sheet, fw):
    fs = sheet.size[1]
    return [sheet.crop((i * fw, 0, (i + 1) * fw, fs)) for i in range(sheet.size[0] // fw)]


def bbox(frame):
    return frame.split()[3].point(lambda a: 255 if a > ALPHA_MIN else 0).getbbox()


def far_point(frame, facing_right):
    """Farthest opaque point on the facing side (used as the swing-trail tip)."""
    b = bbox(frame)
    if not b:
        return None
    alpha = frame.split()[3]
    w, h = frame.size
    cols = range(b[2] - 1, b[0] - 1, -1) if facing_right else range(b[0], b[2])
    for x in cols:
        ys = [y for y in range(b[1], b[3]) if alpha.getpixel((x, y)) > ALPHA_MIN]
        if ys:
            return x, sum(ys) / len(ys)
    return None


def drop_flash_frames(sheet, fw):
    """Some packs paint a solid-white silhouette frame into the hit strip as a
    built-in flash; the game does its own tinting, so those frames go."""
    keep = []
    for fr in frames(sheet, fw):
        px = fr.load()
        opaque = white = 0
        for y in range(fr.size[1]):
            for x in range(fr.size[0]):
                r, g, b, a = px[x, y]
                if a > ALPHA_MIN:
                    opaque += 1
                    if r > 235 and g > 235 and b > 235:
                        white += 1
        if opaque == 0 or white / opaque < 0.9:
            keep.append(fr)
    out = Image.new('RGBA', (fw * len(keep), sheet.size[1]), (0, 0, 0, 0))
    for i, fr in enumerate(keep):
        out.paste(fr, (i * fw, 0))
    return out


def portrait(frame0, flip, glow, out_path, head=(0.22, 0.6, 0.0)):
    l, t, r, b = bbox(frame0)
    h = b - t
    size = max(12, int(h * head[1]))
    cx, cy = (l + r) / 2 + h * head[2], t + h * head[0]
    crop = frame0.crop((int(cx - size / 2), int(cy - size / 2), int(cx + size / 2), int(cy + size / 2)))
    if flip:
        crop = crop.transpose(Image.FLIP_LEFT_RIGHT)
    crop = crop.resize((88, 88), Image.NEAREST)
    img = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(62, 0, -1):
        k = i / 62
        col = tuple(int(base + (g - base) * (1 - k) * 0.4) for base, g in zip((11, 9, 19), glow)) + (255,)
        d.ellipse((64 - i, 64 - i, 64 + i, 64 + i), fill=col)
    mask = Image.new('L', (128, 128), 0)
    ImageDraw.Draw(mask).ellipse((2, 2, 126, 126), fill=255)
    layer = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
    layer.alpha_composite(crop, (20, 22))
    img.paste(layer, (0, 0), mask)
    d.ellipse((3, 3, 125, 125), outline=glow + (140,), width=3)
    img.save(out_path)


def main():
    out = {'chars': {}, 'portraits': {}, 'credits': {}}
    for key, cfg in PACKS.items():
        folder = os.path.join(ROOT, 'packs', key)
        normalize_names(folder)
        idle = Image.open(os.path.join(folder, 'Idle.png')).convert('RGBA')
        fs = idle.size[1]
        fw = detect_frame_width(folder, fs)
        idle_frames = frames(idle, fw)
        boxes = [b for b in map(bbox, idle_frames) if b]
        cx = (min(b[0] for b in boxes) + max(b[2] for b in boxes)) / 2
        feet = max(b[3] for b in boxes)
        height = feet - min(b[1] for b in boxes)
        scale = height / cfg['height']

        # Facing: attacks extend farther toward the side the art faces.
        _, atk = sheet_path(folder, ANIMS['punch'])
        aboxes = [b for b in map(bbox, frames(Image.open(atk).convert('RGBA'), fw)) if b]
        faces_right = (max(b[2] for b in aboxes) - cx) >= (cx - min(b[0] for b in aboxes))
        flip = cfg.get('flip', not faces_right)

        entry = {'build': cfg.get('build', 1.0)}
        for anim, names in ANIMS.items():
            name, path = sheet_path(folder, names)
            if path is None:
                if anim in OPTIONAL:
                    continue
                raise SystemExit(f'{key}: no sheet for {anim} (tried {names})')
            sheet = Image.open(path).convert('RGBA')
            if anim == 'hit':
                sheet = drop_flash_frames(sheet, fw)
                name = f'{name}Clean'
                sheet.save(os.path.join(folder, name + '.png'))
            n = sheet.size[0] // fw
            item = {
                'file': f'packs/{key}/{name}.png',
                'n': n, 'fw': fw, 'fh': fs,
                'ax': round(cx, 2), 'ay': feet,
                'scale': round(scale, 4),
                'dur': round(n / FPS[anim], 3),
                'loop': anim in LOOP,
                'flip': flip,
                'pixel': True,
            }
            if anim in ATTACKS:
                tips = []
                for fr in frames(sheet, fw):
                    p = far_point(fr, not flip)
                    if p is None:
                        tips.append([0.0, -60.0])
                    else:
                        dx = (p[0] - cx) / scale
                        tips.append([round(abs(dx), 1), round((p[1] - feet) / scale, 1)])
                item['tip'] = tips
            entry[anim] = item
        out['chars'][key] = entry
        portrait(idle_frames[0], flip, cfg['glow'], os.path.join(folder, 'portrait.png'),
                 head=cfg.get('head', (0.22, 0.6, 0.0)))
        out['portraits'][key] = f'packs/{key}/portrait.png'
        out['credits'][key] = f"{cfg['credit']} by LuizMelo (CC0) https://luizmelo.itch.io/{key}"
        print(f"{key:24s} frame {fw}x{fs} body {height:3d}px scale {scale:.3f} "
              f"{'LEFT->mirrored' if flip else 'right'}")

    with open(os.path.join(ROOT, 'packs.json'), 'w') as f:
        json.dump(out, f, indent=1)
    print('wrote packs.json with', len(out['chars']), 'characters')


if __name__ == '__main__':
    main()
