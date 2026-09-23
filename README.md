# 点译 · eDrop

**点落生词，畅读外文**  
**Drop the word, keep reading.**

macOS 菜单栏阅读辅助：在任意应用中划选英文 → 松开鼠标 → 自动显示英→中释义。

| | |
|---|---|
| 中文名 | **点译** |
| 英文名 | **eDrop** |
| 显示名 | 点译 · eDrop |
| 平台 | macOS 13+（菜单栏 App） |
| 著作权人 | **王振茹 (Zhenru Wang)** |
| 许可 | 专有 · **仅下载与个人使用**（见 [`LICENSE`](LICENSE) / [`LICENSE-PROPRIETARY.md`](LICENSE-PROPRIETARY.md)） |

---

## 中文

### 许可与使用范围（请先阅读）

本仓库若公开可见，**仅为展示与核验**，**不构成**对源代码或二进制的拷贝许可。

- **允许**：从著作权人官方渠道（例如本仓库的 **Releases**）下载官方构建；在个人设备上安装并用于**个人、非商业**目的。
- **不允许**（未经事先书面许可）：拷贝、克隆、镜像、转存或再分发源码/二进制；商用；公开 Fork/修改版；去除权利或品牌声明。
- **公开可见 ≠ 许可拷贝。** 你没有拷贝复制权。

完整条款见 [`LICENSE`](LICENSE) 与 [`LICENSE-PROPRIETARY.md`](LICENSE-PROPRIETARY.md)。  
署名须保留为：**王振茹 (Zhenru Wang)**。

`Copyright © 2026 王振茹 (Zhenru Wang). All rights reserved.`

### 安装与使用

1. 打开本仓库的 **[Releases](../../releases)**（仓库创建后可用），下载官方构建并安装。  
2. 或从源码本地构建（仅供个人在本机编译运行，**不授予**拷贝/再分发权）：
   ```bash
   open eDrop.xcodeproj
   ```
   在 Xcode 中 Clean 后 ⌘R。需要 **macOS 13+**。
3. 首次运行后：系统设置 → 隐私与安全性 → **辅助功能** → 为 **「点译」或「eDrop」** 打开开关。  
   App 仅在你划选文本时读取选区，不会在后台持续读屏。
4. 在浏览器或文档中划选英文单词/短语并松开 → 浮层显示中文释义。

可选：菜单栏可开关「选中即译」；划词本与悬浮球为本地辅助功能。

### 品牌

- 产品名：**点译 · eDrop**
- Slogan（中）：**点落生词，畅读外文**
- Slogan（英）：**Drop the word, keep reading.**

---

## English

### License & scope (read first)

Public visibility of this repository is for **inspection only**. It does **not** grant a license to copy the source or binaries.

- **Granted**: Download official builds from the copyright holder’s official channels (e.g. this repo’s **Releases**); install and use those builds on your own devices for **personal, non-commercial** purposes only.
- **Not granted** (without prior written permission): Copying, cloning, mirroring, or redistributing source or binaries; commercial use; publishing forks or modified versions; removing copyright, license, or brand notices.
- **Public visibility ≠ a license to copy.** You do not receive copy rights.

See [`LICENSE`](LICENSE) and [`LICENSE-PROPRIETARY.md`](LICENSE-PROPRIETARY.md) for full terms.  
Attribution must remain: **王振茹 (Zhenru Wang)**.

`Copyright © 2026 王振茹 (Zhenru Wang). All rights reserved.`

### Install & use

1. Open **[Releases](../../releases)** (once the repo exists), download an official build, and install.  
2. Or build locally for personal use on your Mac only (this does **not** grant copy/redistribution rights):
   ```bash
   open eDrop.xcodeproj
   ```
   Clean, then ⌘R in Xcode. Requires **macOS 13+**.
3. After first launch: System Settings → Privacy & Security → **Accessibility** → enable **「点译」 or 「eDrop」**.  
   The app reads selected text only when you select; it does not continuously capture the screen in the background.
4. Select English text in a browser or document and release the mouse → a gloss overlay appears.

Optional: toggle “选中即译” (auto-translate on selection) from the menu bar; wordbook and floating ball are local helpers.

### Brand

- Product: **点译 · eDrop**
- Slogan (CN): **点落生词，畅读外文**
- Slogan (EN): **Drop the word, keep reading.**

---

## Development notes (brief)

- Open `eDrop.xcodeproj` (product name **eDrop**; display name **点译**).
- Default Debug/Release signing is Ad-hoc (`CODE_SIGN_IDENTITY = "-"`) for local runs; use your Apple Team before notarized distribution.
- Bundle ID remains `app.eyedrop.translate` (unchanged).
- Optional remote API: environment keys `EYEDROP_TRANSLATE_API_BASE_URL` / `EYEDROP_TRANSLATE_API_KEY` (not required for the default free fallback chain).

## Version

Current tree: **0.3.17**. See in-app Settings → About for version and copyright.

Commercial or other licensing: contact the copyright holder **王振茹 (Zhenru Wang)** via this repository’s Issues (once published).
