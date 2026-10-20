# 点译 · eDrop 0.3.18

**点落生词，畅读外文**  
**Drop the word, keep reading.**

| | |
|---|---|
| 版本 | **0.3.18**（build 27） |
| 文件 | `点译-eDrop-0.3.18.dmg` |
| Bundle ID | `app.eyedrop.translate` |
| 系统 | macOS 13 或更高 |
| 著作权人 | **王振茹 (Zhenru Wang)** |
| 状态 | 发行说明草稿。磁盘映像由装有 Developer ID 证书的 Mac 运行 `scripts/build-signed-dmg.sh` 生成。本仓库变更不上传 GitHub Releases。 |

相对仅源码包的 0.3.17，此版本是第一份 **Developer ID** 签名并公证的二进制发行。翻译、划词、浮层与菜单栏行为与 0.3.17 相同。

公证请求 ID（构建成功后从 `dist/notary-dmg.log` 抄录）：`待填写`

---

## 中文

### 下载与打开

1. 从著作权人官方渠道（本仓库 **Releases**）下载 `点译-eDrop-0.3.18.dmg`。
2. 打开磁盘映像。卷名为 **点译-eDrop-0.3.18**。
3. 将 App 拖入「应用程序」，或直接打开映像中的 App。Finder 中显示名是 **点译**，包名为 `eDrop.app`。
4. 首次运行后授予辅助功能：  
   **系统设置 → 隐私与安全性 → 辅助功能**  
   为 **「点译」或「eDrop」** 打开开关。

需要 **macOS 13** 或更高版本。

### 辅助功能用来做什么

辅助功能权限只在**你划选文本时**读取当前选区，用来显示英→中释义。点译不会在后台持续截屏，也不会持续读取屏幕内容。

### 签名与公证

本发行包使用 **Developer ID Application** 签名，并通过 Apple **notarytool** 公证，票据已装订（stapled）。

占位：证书安装在著作权人的 Mac 上之后，运行 `scripts/build-signed-dmg.sh` 生成最终 `.dmg`。脚本打印的 DMG 公证 id 填入上文「待填写」。在该构建完成并上传之前，未签名的文件不是 0.3.18 官方下载。

### 许可（专有 · 仅下载与个人使用）

`Copyright © 2026 王振茹 (Zhenru Wang). All rights reserved.`

著作权人署名必须保留为：**王振茹 (Zhenru Wang)**。不得替换、省略或改写。

本软件「点译 · eDrop」（含源代码、二进制、文档、截图、品牌标识「点译」「eDrop」）之全部权利归著作权人所有。

在遵守许可的前提下，著作权人仅授予一项**个人的、非独占、不可转让、不可再许可、可撤销**的权利：

1. 从著作权人指定的官方渠道（例如 GitHub Releases）**下载**官方发行版本；
2. 在你个人设备上**安装并使用**该官方发行版本，且仅限**个人、非商业**目的。

除此以外，不授予任何其他权利。**商业使用未授予。**

未经著作权人事先书面许可，不得：

1. **拷贝 / 复制**：复制、克隆、镜像、转存源代码、二进制或其实质性部分（无论是否修改）；
2. **再分发**：上传网盘、二次发布、打包出售、内置于其他产品中提供给第三方；
3. **商用**：用于公司业务、对客户服务、SaaS、广告变现或任何营利活动；
4. **衍生发布**：基于本软件制作修改版、Fork 公开库并向他人提供；
5. **去除权利声明**：删除或篡改 Copyright、本许可或品牌标识；
6. **混淆性商标使用**：将「点译」「eDrop」用作易混淆的产品名或店铺名。

若仓库公开可见源代码，该可见性仅为展示与核验，不构成对源代码的拷贝许可、再许可或开源授权。公开可见不等于许可拷贝。

本软件按「现状」提供，不附带任何担保。违反许可则权利立即终止。完整条款见仓库 [`LICENSE`](../LICENSE) 与 [`LICENSE-PROPRIETARY.md`](../LICENSE-PROPRIETARY.md)。

商业授权或其他例外：通过本仓库 Issues 联系著作权人 **王振茹 (Zhenru Wang)**。

---

## English

### Download and open

1. Download `点译-eDrop-0.3.18.dmg` from the copyright holder’s official channel (this repository’s **Releases**).
2. Open the disk image. The volume name is **点译-eDrop-0.3.18**.
3. Drag the app to Applications, or open the app from the image. Finder shows **点译**. The bundle file name is `eDrop.app`.
4. After the first launch, grant Accessibility:  
   **System Settings → Privacy & Security → Accessibility**  
   Turn on **点译** or **eDrop**.

Requires **macOS 13** or later.

### What Accessibility is used for

Accessibility is used to read the current selection **only when you select text**, so the app can show an English-to-Chinese gloss. 点译 does not continuously capture the screen and does not continuously read screen contents in the background.

### Signing and notarization

This build is signed with **Developer ID Application**, submitted through Apple **notarytool**, and stapled.

Placeholder: after the Developer ID certificate is installed on the copyright holder’s Mac, `scripts/build-signed-dmg.sh` produces the final `.dmg`. Copy the DMG notarization id printed by the script into the “待填写” field above. Until that build is created and uploaded, an unsigned file is not the official 0.3.18 download.

### License (proprietary · download and personal use only)

`Copyright © 2026 王振茹 (Zhenru Wang). All rights reserved.`

Attribution must remain exactly: **王振茹 (Zhenru Wang)**.

All rights in 点译 · eDrop (source, binaries, documentation, screenshots, and the marks “点译” and “eDrop”) belong to the copyright holder.

The only right granted is a **personal, non-exclusive, non-transferable, non-sublicensable, revocable** right to:

1. **Download** an official build from the copyright holder’s official channels (for example GitHub Releases);
2. **Install and use** that official build on your own devices for **personal, non-commercial** purposes.

No other right is granted. **Commercial use is not granted.**

Without prior written permission, the following are not allowed:

1. **Copying**: copying, cloning, mirroring, or storing the source, binaries, or a substantial part of them, whether modified or not;
2. **Redistribution**: re-uploading, republishing, selling a bundle, or shipping the software inside another product to a third party;
3. **Commercial use**: company business, client work, SaaS, ad monetization, or any profit-making activity;
4. **Derivative publication**: publishing a modified version, public fork, or other derivative;
5. **Stripping notices**: removing or altering the copyright, this license, or the brand marks;
6. **Confusing trademark use**: using “点译” or “eDrop” as a product or store name that is likely to confuse.

If source code is visible in a public repository, that visibility is for inspection only. It is not a license to copy, a sublicense, or an open-source grant. Public visibility is not a license to copy.

The software is provided “AS IS”, without warranty of any kind. A breach ends the license. Full terms: [`LICENSE`](../LICENSE) and [`LICENSE-PROPRIETARY.md`](../LICENSE-PROPRIETARY.md).

Commercial or other licensing: contact the copyright holder **王振茹 (Zhenru Wang)** via this repository’s Issues.
