"""Generate the game's pixel skill SVG sources and pixel-exact PNG exports.

Run: python tools/generate_skill_art.py
Only Pillow is required. SVG and PNG are rendered from the same integer grid;
there is no font, browser, Cairo, network, or image service dependency.
"""
from pathlib import Path
import json
from html import escape
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Assets" / "Skills"
DATA = ROOT / "Data" / "Skills"
PALETTES = {
    "Bunny": ("#8cdbb0", "#dbffe4", "#387c70"),
    "Cat": ("#bba0ee", "#f3deff", "#65528b"),
    "Dog": ("#e8b46e", "#fff0ba", "#936846"),
    "Mouse": ("#7ecddd", "#d9faff", "#397f9e"),
}
# id, name, energy, cooldown, description; each role has three active/passive choices.
KITS = {
    "Bunny": [
        ("bunny_dash", "疾风跃迁", 10, 3, "向鼠标方向冲刺并短暂无敌，沿途造成80%技能伤害；攻速提高20%，持续2秒。"),
        ("bunny_blade", "月牙回旋", 20, 4, "投出回旋月刃，去程和回程各造成100%技能伤害，同一敌人每程仅受击一次。"),
        ("bunny_decoy", "脱兔残影", 10, 5, "留下2秒残影吸引普通敌人，移速提高30%，持续3秒；Boss不受嘲讽。"),
        ("bunny_charge", "蓄势待发", 0, 0, "战斗中移动累计160像素，下一次普通攻击伤害提高25%；最多储存一次。"),
        ("bunny_combo", "灵巧连击", 0, 0, "连续3次普通攻击命中同一目标，下一次对其普通攻击伤害提高20%；换目标重置。"),
        ("bunny_light", "轻盈步伐", 0, 0, "受到的减速效果降低30%。"),
    ],
    "Cat": [
        ("cat_blink", "暗影瞬步", 10, 3, "向鼠标方向闪现，获得0.25秒无敌；3秒内下一次普通攻击必定暴击。"),
        ("cat_mark", "猎杀印记", 20, 4, "标记鼠标附近一名可见敌人5秒，对其伤害提高25%；对Boss提高15%。"),
        ("cat_smoke", "猫步烟幕", 20, 5, "在鼠标处释放持续3秒的烟幕：敌人减速30%，敌方弹丸减速35%。"),
        ("cat_crit", "锐利直觉", 0, 0, "普通攻击暴击率提高8个百分点。"),
        ("cat_execute", "猎手本能", 0, 0, "对生命低于30%的敌人，直接伤害提高20%。"),
        ("cat_guard", "危险预感", 0, 0, "连续6秒未受到攻击后，下一次受到的伤害降低30%；触发后重新蓄势。"),
    ],
    "Dog": [
        ("dog_roar", "震荡战吼", 20, 4, "周围敌人受到150%技能伤害，普通敌人恐惧1秒；自身伤害提高20%，持续3秒。"),
        ("dog_shield", "守卫壁垒", 20, 5, "获得生命上限35%的临时护盾，持续4秒；期间免疫击退，不回复生命。"),
        ("dog_charge", "猛犬冲撞", 30, 4, "向鼠标方向冲撞，沿途造成220%技能伤害并眩晕普通敌人0.8秒；Boss仅轻微减速。"),
        ("dog_bravery", "越战越勇", 0, 0, "每个100像素内可见敌人使伤害提高3%，最多提高15%。"),
        ("dog_hide", "坚韧皮毛", 0, 0, "来自敌人身体接触的伤害降低20%。"),
        ("dog_bite", "撕咬连击", 0, 0, "每第4次普通攻击额外造成40%物理伤害；霰弹的一次开火只计一次。"),
    ],
    "Mouse": [
        ("mouse_bomb", "五行爆瓶", 30, 5, "向鼠标处投掷元素爆瓶，造成250%技能伤害；使用最强附魔元素，无附魔时为土。"),
        ("mouse_vortex", "磁力涡流", 20, 5, "在鼠标处制造2秒涡流，牵引普通敌人并造成3次伤害，合计240%技能伤害。"),
        ("mouse_mines", "机关雷阵", 20, 5, "在鼠标附近布置3枚地雷，持续6秒；接敌爆炸，各造成100%技能伤害并减速。"),
        ("mouse_elements", "元素亲和", 0, 0, "造成的元素伤害提高15%，包括武器附魔、元素爆瓶和燃烧。"),
        ("mouse_collect", "搜集专家", 0, 0, "拾取半径提高35%，经验获取提高15%；小数经验会累计。"),
        ("mouse_ambush", "趁乱出击", 0, 0, "对减速、眩晕或恐惧中的敌人，直接伤害提高15%。"),
    ],
}


class PixelArt:
    def __init__(self, size=32):
        self.size = size
        self.image = Image.new("RGBA", (size, size))
        self.draw = ImageDraw.Draw(self.image)

    def rect(self, x, y, w, h, color):
        self.draw.rectangle((x, y, x + w - 1, y + h - 1), fill=color)

    def line(self, points, color, width=2):
        self.draw.line(points, fill=color, width=width)

    def poly(self, points, color):
        self.draw.polygon(points, fill=color)

    def save(self, name):
        # Each SVG rectangle is a horizontal run of equal pixels. The PNG is
        # this exact SVG grid at native resolution: no antialiasing or resampling.
        runs = []
        for y in range(self.size):
            x = 0
            while x < self.size:
                rgba = self.image.getpixel((x, y))
                end = x + 1
                while end < self.size and self.image.getpixel((end, y)) == rgba:
                    end += 1
                if rgba[3]:
                    color = "#%02x%02x%02x" % rgba[:3]
                    runs.append(f'<rect x="{x}" y="{y}" width="{end-x}" height="1" fill="{color}"/>')
                x = end
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.size}" height="{self.size}" viewBox="0 0 {self.size} {self.size}" shape-rendering="crispEdges"><title>{escape(name)}</title>' + "".join(runs) + "</svg>"
        (OUT / "svg" / f"{name}.svg").write_text(svg, encoding="utf-8")
        self.image.save(OUT / f"{name}.png")


def glyph(a, kind, main, light, dark):
    # Small integer-grid silhouettes remain legible at 32 px in the game's HUD.
    r, p, line = a.rect, a.poly, a.line
    if kind in ("dash", "charge"):
        for y, w in ((10, 7), (15, 10), (20, 6)):
            r(5, y, w, 2, dark)
        p([(14, 8), (27, 16), (14, 24), (17, 17), (11, 17), (11, 14), (17, 14)], main)
        r(18, 13, 4, 2, light)
        if kind == "charge":
            r(18, 7, 4, 3, light)
    elif kind == "blade":
        p([(24, 6), (18, 8), (13, 12), (10, 18), (12, 24), (18, 27), (12, 27), (6, 22), (6, 15), (11, 8), (17, 5)], main)
        line([(19, 7), (12, 12), (9, 18), (11, 23)], light)
        r(22, 20, 3, 3, dark)
        r(25, 17, 2, 3, light)
    elif kind == "decoy":
        for x, c in ((7, dark), (16, main)):
            r(x, 12, 10, 12, c); r(x+1, 6, 3, 7, c); r(x+6, 5, 3, 8, c)
        r(18, 15, 2, 2, light); r(23, 15, 2, 2, light)
    elif kind == "combo":
        for x, y in ((7, 9), (14, 15), (21, 21)):
            p([(x, y-4), (x+4, y), (x, y+4), (x-4, y)], main)
            r(x-1, y-1, 2, 2, light)
        line([(8, 19), (13, 24), (17, 24)], dark)
    elif kind == "light":
        p([(10, 6), (24, 10), (23, 17), (17, 25), (8, 25), (7, 21), (13, 19), (12, 13)], main)
        line([(15, 11), (18, 16), (14, 20)], light)
        r(5, 11, 4, 2, dark); r(4, 16, 5, 2, dark)
    elif kind == "blink":
        p([(21, 5), (18, 13), (26, 13), (12, 27), (15, 18), (7, 18)], main)
        line([(20, 8), (17, 15), (22, 15), (15, 22)], light)
        r(5, 7, 3, 3, dark); r(25, 23, 2, 2, light)
    elif kind == "mark":
        line([(10, 7), (7, 7), (7, 11)], light); line([(21, 7), (25, 7), (25, 11)], light)
        line([(7, 21), (7, 25), (11, 25)], light); line([(25, 21), (25, 25), (21, 25)], light)
        p([(16, 10), (22, 16), (16, 22), (10, 16)], main); r(14, 14, 4, 4, dark)
    elif kind == "smoke":
        for x, y, w in ((6, 17, 8), (10, 12, 8), (17, 10, 7), (19, 17, 7), (11, 20, 12)):
            r(x, y, w, 6, main)
        r(11, 13, 6, 2, light); r(18, 11, 5, 2, light); r(9, 24, 16, 2, dark)
    elif kind in ("crit", "execute"):
        p([(5, 15), (10, 10), (21, 10), (27, 15), (21, 21), (10, 21)], main)
        r(10, 13, 12, 5, light); r(14, 11, 4, 10, dark); r(15, 13, 2, 4, "#ffffff")
        if kind == "execute":
            line([(22, 5), (9, 27)], "#f18994", 3)
    elif kind in ("guard", "shield", "hide"):
        p([(16, 5), (26, 9), (25, 20), (16, 28), (7, 20), (6, 9)], dark)
        p([(16, 7), (24, 10), (23, 19), (16, 25), (9, 19), (8, 10)], main)
        line([(16, 10), (16, 22)], light, 3)
        if kind == "shield":
            line([(11, 16), (21, 16)], light, 3)
        elif kind == "hide":
            r(11, 12, 3, 3, dark); r(18, 12, 3, 3, dark)
    elif kind == "roar":
        r(8, 10, 11, 14, main); r(6, 8, 4, 7, main); r(17, 8, 4, 7, main)
        r(10, 13, 2, 2, dark); r(16, 13, 2, 2, dark); r(11, 18, 7, 4, dark)
        line([(23, 10), (26, 14), (26, 21), (23, 25)], light)
        r(21, 15, 2, 5, light)
    elif kind == "bravery":
        p([(16, 5), (19, 12), (27, 12), (21, 18), (23, 26), (16, 22), (9, 26), (11, 18), (5, 12), (13, 12)], main)
        r(14, 13, 4, 7, light)
    elif kind == "bite":
        p([(6, 9), (12, 14), (16, 10), (20, 14), (26, 9), (24, 22), (16, 27), (8, 22)], main)
        for x in (10, 15, 20):
            p([(x, 16), (x+3, 16), (x+1, 22)], light)
        r(10, 13, 12, 3, dark)
    elif kind == "bomb":
        r(13, 6, 7, 3, light); r(14, 9, 5, 4, dark)
        p([(12, 13), (21, 13), (25, 18), (23, 25), (10, 25), (7, 18)], main)
        r(10, 19, 4, 4, "#f18c83"); r(15, 16, 4, 4, "#c9e680"); r(20, 20, 3, 3, "#d1b5ef")
        r(21, 7, 3, 3, "#f3ce7c")
    elif kind == "vortex":
        line([(26, 16), (25, 9), (17, 6), (9, 9), (6, 17), (10, 24), (20, 26), (25, 21), (22, 14), (16, 12), (12, 16), (16, 20), (19, 17)], main, 3)
        r(8, 10, 3, 4, light); r(21, 23, 3, 2, light)
    elif kind == "mines":
        for x, y in ((10, 12), (22, 13), (16, 24)):
            r(x-4, y-3, 8, 6, main); r(x-2, y-5, 4, 2, light); r(x-1, y-1, 2, 2, "#f18c83")
    elif kind == "elements":
        for x, y, c in ((16, 7, "#efcf7d"), (25, 14, "#a3db8f"), (22, 24, "#7bcbe7"), (10, 24, "#f29482"), (7, 14, "#b6a1de")):
            p([(x, y-4), (x+4, y), (x, y+4), (x-4, y)], c)
        r(14, 14, 4, 4, light)
    elif kind == "collect":
        r(8, 10, 16, 15, main); r(6, 13, 20, 9, main); r(11, 7, 10, 3, dark)
        r(10, 11, 12, 3, light); r(15, 16, 3, 6, "#f3ce7c"); r(12, 18, 9, 2, "#f3ce7c")
    elif kind == "ambush":
        for x in (9, 15, 21):
            line([(x+3, 6), (x-2, 25)], main, 3)
            r(x+1, 7, 2, 4, light)
        r(6, 26, 18, 2, dark)


def main():
    (OUT / "svg").mkdir(parents=True, exist_ok=True)
    DATA.mkdir(parents=True, exist_ok=True)
    entries = []
    for character, rows in KITS.items():
        main_color, light, dark = PALETTES[character]
        for index, (key, name, cost, cooldown, description) in enumerate(rows):
            art = PixelArt()
            glyph(art, key.split("_", 1)[1], main_color, light, dark)
            art.save(key)
            entries.append(dict(id=key, name=name, character=character, kind="active" if index < 3 else "passive", cost=cost, cooldown=cooldown, description=description))
    for name, border, background in (("node_idle", "#625b81", "#24273c"), ("node_selected", "#ddc68d", "#3c4066"), ("tree_panel", "#8c86ad", "#191e31")):
        a = PixelArt(48)
        a.rect(2, 0, 44, 48, "#111322"); a.rect(0, 2, 48, 44, "#111322")
        a.rect(2, 2, 44, 44, border); a.rect(4, 4, 40, 40, background)
        a.rect(5, 5, 38, 1, "#565b80"); a.rect(5, 42, 38, 1, "#101426")
        for x in (2, 44):
            for y in (2, 44):
                a.rect(x, y, 2, 2, "#e9dbaa" if name == "node_selected" else "#b4acce")
        a.save(name)
    (OUT / "manifest.json").write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
    (DATA / "skill_definitions.gd").write_text("# Generated by tools/generate_skill_art.py\nextends RefCounted\nconst ENTRIES = " + json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    sheet = Image.new("RGB", (768, 440), "#191e31")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(str(ROOT / "Assets/Fonts/fusion-pixel-12px-zh-hans.otf"), 12)
    draw.fontmode = "1"
    for row, (character, rows) in enumerate(KITS.items()):
        for col, (key, name, cost, _, _) in enumerate(rows):
            x, y = col*128, row*110
            tile = Image.open(OUT / "node_idle.png").resize((64, 64), Image.Resampling.NEAREST)
            icon = Image.open(OUT / f"{key}.png").resize((64, 64), Image.Resampling.NEAREST)
            sheet.paste(tile, (x+32, y+4), tile); sheet.paste(icon, (x+32, y+4), icon)
            draw.text((x+64, y+72), name, font=font, fill="#eee3cf", anchor="mt")
            draw.text((x+64, y+90), f"主动 · {cost}能量" if cost else "被动", font=font, fill="#929bbc", anchor="mt")
    sheet.save(OUT / "skill_icons_overview.png")
    print(f"Generated {len(entries)} skill icons, 3 UI textures, SVG sources, PNG exports and skill definitions.")


if __name__ == "__main__":
    main()
