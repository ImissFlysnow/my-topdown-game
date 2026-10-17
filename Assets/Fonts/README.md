# 中文像素界面字体

中文界面使用 [Fusion Pixel Font / 缝合像素字体](https://github.com/TakWolf/fusion-pixel-font)，固定版本 [2026.10.16](https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.10.16)，简体中文、比例宽度 OTF。8、10、12 像素版本分别用于小号提示、普通文字、技能名称及说明；大标题以整数倍放大。技能树说明固定使用原生 12 像素点阵，行间距为 2，能量消耗与冷却提示使用 10 像素，避免复杂汉字挤在 8 像素网格里。

`sources.json` 保存原始下载地址、文件名和 SHA-256。字体文件未修改，原始字体与上游组件的许可证按字号保存在 `licenses/`，字体主许可证另见 `LICENSE-OFL.txt`。

`Extra/pixel_fonts.gd` 统一设置原生字号、禁用抗锯齿和子像素定位，避免像素笔画模糊。已用于技能树、角色技能选择、战斗 HUD、交互弹窗、元素标记和伤害数字；原菜单标题和按钮继续使用项目原有 Lilian 英文字体。
