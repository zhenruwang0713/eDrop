# 点译 · eDrop — 架构说明（0.3.17 · 选中即译 · 对齐 PRD v0.3）

品牌：中文名 **点译**；英文 eDrop；Slogan **点落生词，畅读外文**；Bundle ID `app.eyedrop.translate`。

## 1. 产品能力分层

| 层级 | 能力 | MVP？ | 说明 |
|------|------|-------|------|
| **L1 通吃层** | **选中即译** → 浮层释义 | ✅ 0.3.17 | 拖拽选区；AX + ⌘C；中文 gloss；Figma 实白卡浮层 |
| **L1 兜底** | 菜单翻译选区 / 剪贴板 | ✅ | 非主路径 |
| **P1** | 桌面挂件 / 划词本 | ✅ 0.3.6+ | 悬浮球 + 本地划词本 |
| **L2 增强层** | 吸管点词 | ❌ | 卖点稳后再做 |
| **L3 探索层** | 悬停 / OCR | ❌ | 后置 |

## 2. 运行时形态（0.3.17）

```
SelectionAutoMonitor（down+up · 拖拽≥5pt · 250ms debounce）
        │ expectSelection=true
        ▼
TranslateCoordinator.autoTranslateAfterSelection
   ├─ 立刻 Overlay.loading「正在识别文字…」（sentinel=overlayFetchingSelection）
   ├─ AX SelectionReader
   ├─ 失败 → 合成 ⌘C（~350ms）读板还原
   ├─ 仍空 → Overlay.failure（web hint，不静默）
   └─ beginTranslate → TranslateService → ensuringChineseGlosses
        → Overlay.success（实白卡 · 点译头 · 中文 gloss 主行 + 英文 source 次行）

NSStatusItem（菜单含「选中即译」Toggle + 兜底项）
Settings：选中即译置顶；关于含 slogan
悬浮球：单击划词本；右键切换选中即译（外观同步 preferences）
```

## 3. 翻译装配

```
TranslateServiceFactory.make
  ├─ 有 EyedropTranslateAPIBaseURL → Caching(URLSession…)
  └─ 否则 → Caching(Fallback(MyMemory → Google → Lingva → Mock))
```

| 层 | 行为 |
|----|------|
| `MyMemoryTranslateService` | ephemeral Session；~4s；UA；`de=` 邮箱；quota→下一引擎 |
| `GoogleTranslateService` | `clients5.google.com` Chrome dict；4s/5s；无需 Key |
| `LingvaTranslateService` | lingva.ml → thedaviddelta；~3.5s/host；HTML 快失败 |
| `FallbackTranslateService` | 顺序尝试；绝不抛错；Mock 取消仍中文占位 |
| `MockTranslateService` | glossary + `guaranteedChinese` 无 sleep 兜底 |
| `TranslationResult.ensuringChineseGlosses()` | 空/英译英 → 仅 Mock 注入占位；在线中文绝不被覆盖 |
| `CachingTranslateService` / Coordinator | success 前强制 ensure；超时/抛错再 Mock 成功态 |

## 4. 模块地图

| 路径 | 职责 |
|------|------|
| `App/TranslateCoordinator.swift` | auto + 菜单；⌘C；success 必带中文 |
| `App/MenuBarController.swift` | NSStatusItem；选中即译 Toggle |
| `Features/Selection/SelectionAutoMonitor.swift` | 拖拽检测 + debounce |
| `Features/Selection/SelectionReader.swift` | L1 AX |
| `Features/Translate/*` | MyMemory / Google / Lingva / Mock / Cache |
| `Features/Overlay/*` | 液化玻璃 loading / success / failure |
| `Features/Widget/DesktopFloatingBall.swift` | 品牌黑圆角方 + 白 e（Figma 悬浮球 48）；右键切换选中即译 |
| `Features/Wordbook/*` | 本地划词本 MVP |
| `Shared/AppTheme.swift` | LiquidGlass tokens + Metrics |
| `Shared/Constants.swift` / `PlaceholderStrings.swift` | 品牌 slogan + 文案 |

## 5. 权限与分发

- TCC 辅助功能：划词与全局鼠标监视前提；失败可见。
- 沙盒关闭；`network.client` entitlements；Ad-hoc 且 `CODE_SIGNING_REQUIRED=YES` 以确保嵌入。
- 出站 HTTPS（MyMemory / Google clients5 / Lingva）；ATS 默认即可。勿硬编码付费 API Key。
- Linux 环境无法链接 AppKit；本仓库以源码 + 文档 + tar 交付，真机 Mac ⌘R。
