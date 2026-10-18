"""Generate animated pixel SVG sources and exact PNG exports for four Boss effects.

Run: python tools/generate_boss_terrain_art.py (Pillow only).
The SVG and PNG share the same integer RGBA grid, including transparency.
"""
from pathlib import Path
from html import escape
import math
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / 'Assets' / 'BossEffects'


def save(image, name):
    runs = []
    for y in range(image.height):
        x = 0
        while x < image.width:
            rgba = image.getpixel((x, y))
            end = x + 1
            while end < image.width and image.getpixel((end, y)) == rgba:
                end += 1
            if rgba[3]:
                color = '#%02x%02x%02x' % rgba[:3]
                alpha = '' if rgba[3] == 255 else f' fill-opacity="{rgba[3]/255:.6f}"'
                runs.append(f'<rect x="{x}" y="{y}" width="{end-x}" height="1" fill="{color}"{alpha}/>')
            x = end
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{image.width}" height="{image.height}" shape-rendering="crispEdges"><title>{escape(name)}</title>' + ''.join(runs) + '</svg>'
    (OUT / 'svg' / f'{name}.svg').write_text(svg, encoding='utf-8')
    image.save(OUT / f'{name}.png')


def thorn(frame):
    image = Image.new('RGBA', (24, 24))
    d = ImageDraw.Draw(image)
    d.rectangle((0, 6, 23, 18), fill='#284b3e')
    d.line([(0, 14), (5, 9), (11, 15), (17, 9), (23, 13)], fill='#579957', width=4)
    d.line([(0, 13), (5, 8), (11, 14), (17, 8), (23, 12)], fill='#a5cf76', width=1)
    for x, y, flip in [(4, 8, -1), (12, 15, 1), (20, 9, -1)]:
        tip = 6 + (frame % 3)
        d.polygon([(x-3, y), (x+3, y), (x+1, y+flip*tip)], fill='#c5e48d')
        d.line([(x, y), (x+1, y+flip*(tip-1))], fill='#eaf7b0')
    if frame in (1, 4):
        d.rectangle((7, 19, 9, 21), fill='#7eae53')
    return image


def water(frame):
    image = Image.new('RGBA', (24, 24), (30, 108, 151, 190))
    d = ImageDraw.Draw(image)
    for y in (3, 11, 19):
        shift = (frame*2 + y) % 24
        for x in range(-24, 48, 12):
            sx = x + shift % 12
            d.line([(sx, y), (sx+3, y-1), (sx+7, y-1), (sx+9, y)], fill=(112, 216, 236, 210), width=1)
            d.line([(sx+2, y+2), (sx+6, y+2)], fill=(55, 155, 192, 200), width=1)
    for x, y in [(5, 6), (18, 15)]:
        if (frame+x) % 3 == 0:
            d.rectangle((x, y, x+1, y+1), fill='#daf9f6')
    return image


def fire(frame):
    image = Image.new('RGBA', (24, 24))
    d = ImageDraw.Draw(image)
    d.ellipse((1, 13, 22, 23), fill=(125, 41, 26, 150))
    sway = [0, 1, 2, 0, -2, -1][frame]
    for x, base, height in [(5, 21, 13), (12, 22, 20), (19, 21, 12)]:
        tip = x+sway
        d.polygon([(x-4, base), (x-5, base-5), (tip-1, base-height), (tip+2, base-height+5), (x+5, base-4), (x+4, base)], fill='#d94832')
        d.polygon([(x-2, base-1), (x-3, base-5), (tip, base-height+5), (x+3, base-5), (x+2, base-1)], fill='#ff9d42')
        d.polygon([(x-1, base-1), (x-1, base-5), (x+1, base-9), (x+2, base-3)], fill='#ffe68a')
    d.rectangle((5 + frame*3 % 15, 3 + frame % 4, 6 + frame*3 % 15, 4 + frame % 4), fill='#ffc866')
    return image


def burst(frame):
    image = Image.new('RGBA', (64, 64))
    d = ImageDraw.Draw(image)
    radius = 10 + frame*4
    d.ellipse((32-radius, 32-radius, 32+radius, 32+radius), fill=(218, 153, 72, max(12, 70-frame*9)), outline='#ffe3a1', width=2)
    d.ellipse((34-radius, 34-radius, 30+radius, 30+radius), outline='#bc7d48', width=2)
    for index in range(12):
        angle = math.tau*index/12 + frame*.09
        x = round(32+math.cos(angle)*(radius-1))
        y = round(32+math.sin(angle)*(radius-1))
        d.rectangle((x-2, y-2, x+1, y+1), fill='#f4c37e')
        if index % 3 == 0:
            d.line([(32, 32), (x, y)], fill=(255, 208, 130, max(30, 150-frame*20)), width=1)
    return image


def main():
    OUT.mkdir(exist_ok=True)
    (OUT / 'svg').mkdir(exist_ok=True)
    overview = Image.new('RGBA', (6*80, 4*80), '#211c2e')
    for row, (name, draw) in enumerate([('thorn', thorn), ('water', water), ('fire', fire), ('shield_burst', burst)]):
        frames = [draw(index) for index in range(6)]
        size = frames[0].width
        sheet = Image.new('RGBA', (size*6, size))
        for index, frame in enumerate(frames):
            save(frame, f'{name}_{index}')
            sheet.paste(frame, (size*index, 0))
            preview = frame.resize((size*2, size*2), Image.Resampling.NEAREST) if size == 24 else frame
            overview.alpha_composite(preview, (index*80+(80-preview.width)//2, row*80+(80-preview.height)//2))
        save(sheet, name)
    overview.save(OUT / 'overview.png')
    print('Generated 4 animated effects: 28 SVG sources, 28 PNG assets, 1 overview.')


if __name__ == '__main__':
    main()
