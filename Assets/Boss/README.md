# 五行地牢守卫动画

使用内置 imagegen 生成，透明 RGBA 图集，原图保留在本目录的 `dungeon_sentinel_sheet.png`，实际尺寸 1254 × 1254。

`sentinel_frames.tres` 使用四行四列 AtlasTexture，无需额外裁图。每行分别是 idle / walk / attack / death，每组四帧；前两组循环，攻击和死亡不循环。可直接在 Godot SpriteFrames 编辑器修改帧、速度与循环。

游戏场景：`res://Scene/Enemies/boss.tscn`；动画由 `boss.gd` 中的追踪、蓄力、恢复和死亡状态驱动。原石像守卫用于第一层，第二至第五层使用下列独立 Boss。

## 新增四个 Boss

使用内置 imagegen 工具生成，透明 RGBA 图集与可编辑 Godot SpriteFrames 均保留在本项目中。每套四行四列、共 16 帧，行顺序为 idle / walk / attack / death；待机、行走循环，攻击、死亡不循环。

| Boss / 层数 | 图集与 SpriteFrames | 游戏场景 | 完整生成提示词 |
| --- | --- | --- | --- |
| 荆棘树王 / 2 | `thorn_sovereign_sheet.png`、`thorn_sovereign_frames.tres` | `Scene/Enemies/boss_summoner.tscn` | `thorn_sovereign_prompt.txt` |
| 寒潮巫王 / 3 | `tide_archmage_sheet.png`、`tide_archmage_frames.tres` | `Scene/Enemies/boss_ranged.tscn` | `tide_archmage_prompt.txt` |
| 烬影刺王 / 4 | `ember_stalker_sheet.png`、`ember_stalker_frames.tres` | `Scene/Enemies/boss_assassin.tscn` | `ember_stalker_prompt.txt` |
| 玄岩堡垒 / 5 | `bastion_warden_sheet.png`、`bastion_warden_frames.tres` | `Scene/Enemies/boss_warden.tscn` | `bastion_warden_prompt.txt` |

基础数值资源分别位于 `Data/Enemies/` 的同名 `.tres`。技能参数在各自脚本与继承场景的导出属性中，护盾比例和虚弱倍率可在堡垒场景中调整。帧区域根据图集实际尺寸配置；更换素材时同步更新 SpriteFrames，运行时会按帧宽度缩放角色。

法师与刺客原图的第三行有部分攻击特效跨格，因此 SpriteFrames 对蓄力帧使用局部区域及等尺寸 margin，并选择四个干净姿态组成攻击动画（蓄力、举杖/举刃、跟进、恢复）；跨格特效帧保留在原图中，不直接用于游戏。伤害弹幕、突进和地面特效由游戏代码绘制。原始 PNG 与透明通道均未修改。

最终生成提示词（内置工具，未使用 API / CLI）：

Use case: stylized-concept. Asset type: production-ready animation sprite sheet for a pixel-art 2D top-down dungeon action roguelike. Generate ONE original large boss character, an imposing horned stone dungeon sentinel with huge armored fists, a stout readable silhouette, a small neutral white glowing chest crystal, gray-violet stone and muted brass bands. Style: crisp low-resolution pixel art, solid dark-purple outline with a thin pale highlight, 3/4 front top-down game view, matching small cute pixel dungeon enemies but substantially more imposing. Transparent RGBA background, genuinely empty alpha outside each sprite. Exact layout: a square 1024 by 1024 sprite sheet divided into an invisible regular 4-column x 4-row grid, each cell 256 by 256. EXACTLY 16 sprites, one per cell, same character, same scale, aligned center with feet on a consistent baseline within each cell, fully contained with ample padding. Each sprite is drawn like a 64x64 pixel character enlarged using crisp nearest-neighbor pixel blocks. Row 1: four subtly different idle/breathing frames. Row 2: four walking frames alternating heavy feet and arm sway. Row 3: four attack animation frames: fists up windup, leaning forward, both fists slamming the ground, recovery. Row 4: four death animation frames: cracked staggering body, collapsing on knees, falling apart, small pile of rubble. No text, labels, borders, checkerboard pattern, shadows spanning cells, background, extra characters, detached effects outside cells or watermark. Maintain identical stone sentinel design across all frames. Monochrome-neutral crystal so it can be tinted to five elemental colors inside the game.
