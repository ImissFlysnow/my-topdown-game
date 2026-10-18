# Boss 地形与爆炸特效

生成器：`tools/generate_boss_terrain_art.py`，仅依赖 Python + Pillow。

运行 `python tools/generate_boss_terrain_art.py` 可重建所有素材。每种效果含 6 帧动画、逐帧 SVG / PNG 和横向图集 SVG / PNG；共 28 个 SVG、28 个 PNG，另有 `overview.png` 总览。SVG 和 PNG 来自同一个整数像素网格，支持透明度。

| 文件 | 原生帧大小 | 游戏用途 |
| --- | --- | --- |
| thorn.png | 24×24 | 第二层，两横两竖、各两格宽的荆棘墙 |
| water.png | 24×24 | 第三层，每块三乘三格的减速水域 |
| fire.png | 24×24 | 第四层，沿实际突进路径连续留下火焰 |
| shield_burst.png | 64×64 | 第五层，破盾爆炸冲击波 |

运行与碰撞逻辑在 `Scene/Enemies/boss_terrain.gd`，由各 Boss 脚本调用。预警阶段没有碰撞和伤害；暂停冻结计时。Boss 死亡清除所属特效及临时碰撞。

荆棘预警 1 秒、阻挡 4 秒，生长时站在荆棘中的玩家可以走出去，离开后恢复阻挡；木 Boss 可以穿过自己的荆棘。水域持续 6 秒、移速降低 45%，离开后最多残留 0.18 秒减速，仍受兔子被动减速抗性影响。火焰持续 5 秒，连续踩满 1 秒造成 1 点基础火伤，遵循玩家护盾、无敌和减伤规则；重叠与连斩共用计时，离开火焰重新计时。破盾爆炸圆面积约为当前房间的一半，圆心锁定破盾时 Boss 位置，实际预警 1 秒后伤害一次；不会杀死 Boss，阶段重铸不能取消已触发的爆炸，击杀 Boss 可以取消。

`tests/boss_terrain_tests.tscn` 提供机制检查；在图形模式传入 `--capture-dir=绝对路径` 会导出六张实际房间截图。
