"""Generate eleven pixel shop icons (SVG + PNG) and their Godot resources.

Run with Python + Pillow. All coordinates are integer pixels, matching skill art.
"""
from pathlib import Path
import json
import generate_skill_art as art

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Assets" / "Items"
# id, Chinese name, kind, base price, limit, description, glyph, color
ITEMS = [
    ("echo_capacitor", "回响电容", 13, 16, 1, "主动技能造成伤害后返还2能量，每次施放仅一次。", "capacitor", "#8bc9ff"),
    ("energy_medal", "储能徽章", 14, 8, 1, "每满1格能量，普攻伤害+4%，最多+12%。", "medal", "#f7d68c"),
    ("cast_gauntlet", "施法护腕", 15, 10, 2, "施放技能后4秒内，下3次普攻伤害+20%/件。", "gauntlet", "#c4a1f2"),
    ("wind_boots", "风行靴", 16, 8, 2, "实际移动时受到的伤害降低10%/件。", "boots", "#8dddaf"),
    ("energy_crystal", "聚能晶核", 17, 14, 2, "伤害回能效率+25%/件，仍须战斗中实际造成伤害。", "crystal", "#87d9f3"),
    ("haste_sigil", "迅捷符印", 18, 10, 2, "施放技能后攻速+15%/件，持续4秒，重复刷新。", "sigil", "#f0bc87"),
    ("speed_ribbon", "疾行缎带", 19, 5, 2, "施放技能后移速+20%/件，持续3秒，重复刷新。", "ribbon", "#efa2c2"),
    ("residual_charm", "余能护符", 20, 8, 1, "施放技能获得生命上限10%的护盾，持续3秒。", "charm", "#b7a5f4"),
    ("combo_ring", "连携指环", 21, 12, 1, "5次普攻命中后，下次技能返还2能量，只存1次。", "ring", "#ffe29c"),
    ("talent_badge", "天赋徽章", 22, 10, 2, "当前被动技能的百分比效果增强20%/件。", "badge", "#d3b5f6"),
    ("emergency_battery", "应急电池", 23, 22, 1, "敌人致命攻击时恢复至20%生命、+5能量，无敌2秒。一次性。", "battery", "#a2e5b5"),
]


def make_icon(kind, color):
    a = art.PixelArt()
    r, p, line = a.rect, a.poly, a.line
    dark, light = "#46516c", "#f0f8ff"
    if kind in ("capacitor", "battery"):
        r(8, 7, 16, 21, dark); r(10, 9, 12, 17, color)
        r(12, 4, 8, 3, dark); r(12, 10, 3, 13, light)
        p([(18, 12), (14, 18), (18, 18), (16, 23), (22, 16), (18, 16)], dark)
        if kind == "capacitor":
            r(4, 14, 3, 7, color); r(25, 14, 3, 7, color)
    elif kind in ("medal", "badge"):
        p([(8, 4), (14, 4), (19, 15), (14, 18)], "#987aaf")
        p([(18, 4), (24, 4), (18, 18), (13, 15)], "#74649c")
        p([(12, 12), (20, 12), (25, 18), (25, 23), (20, 28), (12, 28), (7, 23), (7, 18)], dark)
        p([(12, 14), (20, 14), (23, 18), (23, 22), (19, 26), (13, 26), (9, 22), (9, 18)], color)
        if kind == "badge":
            p([(16, 15), (18, 19), (22, 20), (18, 22), (16, 25), (14, 22), (10, 20), (14, 19)], light)
        else:
            for x in (11, 15, 19): r(x, 18, 2, 5, light)
    elif kind == "gauntlet":
        p([(8, 11), (11, 11), (11, 6), (21, 6), (24, 10), (24, 20), (20, 25), (11, 25), (8, 19)], dark)
        r(12, 8, 9, 15, color); r(10, 13, 3, 7, color)
        r(11, 23, 11, 4, "#d0b57c"); r(14, 10, 2, 9, light)
        r(18, 10, 2, 9, "#9272be")
    elif kind == "boots":
        p([(12, 6), (23, 6), (23, 20), (26, 23), (26, 27), (6, 27), (6, 21), (12, 19)], dark)
        p([(14, 8), (21, 8), (21, 22), (24, 23), (24, 25), (8, 25), (8, 22), (14, 20)], color)
        r(14, 12, 8, 2, light); r(14, 16, 8, 2, light)
        r(3, 12, 7, 2, "#608e8e"); r(5, 17, 5, 2, "#608e8e")
    elif kind == "crystal":
        p([(16, 3), (25, 12), (23, 23), (16, 29), (7, 22), (7, 12)], dark)
        p([(16, 5), (22, 12), (20, 22), (16, 26), (10, 21), (10, 12)], color)
        p([(16, 5), (16, 25), (12, 19), (12, 11)], light)
        r(3, 8, 3, 3, color); r(26, 22, 3, 3, color)
    elif kind == "sigil":
        r(7, 5, 18, 23, dark); r(9, 7, 14, 19, "#f6e3c0")
        p([(17, 9), (11, 17), (16, 17), (13, 24), (21, 14), (16, 14)], color)
        r(10, 4, 12, 3, "#af795e")
    elif kind == "ribbon":
        p([(6, 7), (14, 10), (17, 16), (10, 20), (6, 16)], dark)
        p([(26, 7), (18, 10), (15, 16), (22, 20), (26, 16)], dark)
        p([(8, 9), (13, 12), (15, 16), (10, 17), (8, 15)], color)
        p([(24, 9), (19, 12), (17, 16), (22, 17), (24, 15)], color)
        p([(12, 17), (16, 18), (12, 28), (9, 25)], color)
        p([(17, 17), (20, 18), (24, 26), (20, 28)], color)
        r(14, 13, 5, 6, light)
    elif kind == "charm":
        line([(9, 5), (9, 9), (16, 14), (23, 9), (23, 5)], "#d7c189", 2)
        p([(16, 12), (25, 16), (23, 24), (16, 29), (9, 24), (7, 16)], dark)
        p([(16, 14), (22, 17), (21, 23), (16, 26), (11, 23), (10, 17)], color)
        r(15, 17, 2, 7, light); r(13, 19, 6, 2, light)
    elif kind == "ring":
        a.draw.ellipse((5, 11, 26, 29), fill=dark)
        a.draw.ellipse((7, 13, 24, 27), fill=color)
        a.draw.ellipse((11, 16, 20, 24), fill=(0, 0, 0, 0))
        p([(12, 3), (20, 3), (24, 8), (16, 15), (8, 8)], dark)
        p([(13, 5), (19, 5), (21, 8), (16, 12), (11, 8)], "#85cee4")
        r(13, 6, 4, 2, light)
    return a


def main():
    OUT.mkdir(exist_ok=True)
    (OUT / "svg").mkdir(exist_ok=True)
    art.OUT = OUT
    for ident, name, kind, price, limit, description, glyph, color in ITEMS:
        make_icon(glyph, color).save(ident)
        text = '\n'.join([
            '[gd_resource type="Resource" script_class="ItemData" load_steps=3 format=3]',
            '[ext_resource type="Script" path="res://Data/Items/item_data.gd" id="1"]',
            f'[ext_resource type="Texture2D" path="res://Assets/Items/{ident}.png" id="2"]',
            '[resource]', 'script = ExtResource("1")',
            'item_name = ' + json.dumps(name, ensure_ascii=False), f'kind = {kind}',
            'icon = ExtResource("2")', f'shop_price = {price}', f'max_stacks = {limit}',
            'description = ' + json.dumps(description, ensure_ascii=False), '',
        ])
        (ROOT / "Data" / "Items" / f"{ident}.tres").write_text(text, encoding="utf-8")
    # Keep legacy resource effects and enum IDs intact; price by actual utility.
    prices = {"damage": 8, "speed": 6, "attack_speed": 8, "magnet": 4,
              "light_grip": 6, "armor_piercing": 10, "headhunter": 8,
              "frost_shard": 10, "ember_mark": 8, "greedy_pouch": 7}
    for ident, price in prices.items():
        path = ROOT / "Data" / "Items" / f"{ident}.tres"
        lines = [line for line in path.read_text(encoding="utf-8").splitlines()
                 if not line.startswith("shop_price =")]
        lines.append(f"shop_price = {price}")
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Generated 11 SVG + PNG icons, 11 item resources, and tiered shop prices.")


if __name__ == "__main__":
    main()
