# 设计资源槽位（0.3.17）

品牌见 `eyedrop-translate/launch/brand.md`。Slogan：点落生词，畅读外文；英名 eDrop。Accent `#2AA8A0`；品牌黑 `#0A0A0A`。

| 资源 | 尺寸 | 说明 |
|------|------|------|
| `AppIcon.appiconset` | **1024×1024** 主图（Xcode 生成其余） | 安装器 / 关于 / Dock（若显示）；真图未到前槽位保留 |
| `MenuBarIcon.imageset` | **16×16** (1x) / **32×32** (2x)，**template** 单色几何小写 **e** | **已交付**（0.3.15+）；黑模透明；`template-rendering-intent`；SVG masters 见 `launch/figma-exports/menubar-e-*.svg` / `P0-C-menubar-done.md` |

菜单栏已嵌入品牌 template；缺 named image 时回退 SF Symbol。

**悬浮球 48**：对齐 Figma「02 组件 · 悬浮球 48」——品牌黑 `#0A0A0A` 圆角方（continuous）+ 白色几何 **e**（复用 `MenuBarIcon` template）。**已移除** SF Symbol `drop.fill`。

交付包：`/workspace/点译-0.3.17.tar.gz`（解压后顶层目录为 **`点译-0.3.17/`**，非 `eyedrop-translate-app/`）。工程根亦可为 `/workspace/点译-0.3.17`（`eyedrop-translate-app` 可为指向它的 symlink）。

| `FloatingBallIcon.imageset` | 矢量 PDF template（用户 e） | 悬浮球；**不要**拿 MenuBarIcon 16/32 放大 |
