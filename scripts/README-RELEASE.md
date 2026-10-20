# 点译 · eDrop — Developer ID 磁盘映像

在已安装 **Developer ID Application** 证书的 Mac 上，用 `scripts/build-signed-dmg.sh` 生成签名并公证的 `.dmg`。脚本只做打包、签名、公证和装订，不改翻译、划词、浮层或菜单栏功能。

工程里的 Debug/Release 仍是本机 Ad-hoc 签名（`CODE_SIGN_IDENTITY="-"`，`DEVELOPMENT_TEAM` 为空）。脚本只在 `xcodebuild` / `codesign` 命令行上覆盖为 Developer ID，并打开 Hardened Runtime（公证要求）。Bundle ID 保持 `app.eyedrop.translate`。

本步骤**不**上传 GitHub Releases。脚本成功后，由著作权人自行上传 `dist/` 里的 `.dmg`。

## 准备

1. macOS 上安装 Xcode，并执行 `sudo xcode-select -s /Applications/Xcode.app`。
2. 在钥匙串中安装 **Developer ID Application** 证书及其私钥。  
   Xcode → Settings → Accounts → Manage Certificates → **+** → Developer ID Application。  
   `security find-identity -v -p codesigning` 能列出该证书时，私钥才算就绪。
3. 准备公证凭据（二选一）。

钥匙串配置文件（推荐，密码不必留在 shell 历史里）：

```bash
xcrun notarytool store-credentials "edrop-notary" \
  --apple-id "you@example.com" \
  --team-id "YOURTEAMID"
```

或使用 App 专用密码（[appleid.apple.com](https://appleid.apple.com) → 登录与安全 → App 专用密码），不是 Apple ID 登录密码。

若 `codesign` 提示钥匙串被锁：

```bash
security unlock-keychain "$HOME/Library/Keychains/login.keychain-db"
```

## 运行

```bash
export TEAM_ID="YOURTEAMID"
export NOTARY_PROFILE="edrop-notary"
# 同一 Team 有多张 Developer ID Application 时再设置：
# export CODESIGN_IDENTITY="Developer ID Application: Your Name (YOURTEAMID)"

./scripts/build-signed-dmg.sh
```

不用钥匙串配置文件时：

```bash
export TEAM_ID="YOURTEAMID"
export APPLE_ID="you@example.com"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
./scripts/build-signed-dmg.sh
```

等价写法：`--team-id` 与 `--identity`。查看环境变量说明：`./scripts/build-signed-dmg.sh --help`。

证书名不是 `Developer ID Application: …`、钥匙串里没有对应私钥、或公证变量缺失时，脚本会在开始编译前退出，并写明缺哪一项。

## 产物

营销版本取自 Xcode 工程的 `MARKETING_VERSION`（当前 **0.3.18**，构建号 **27**）。

| 路径 | 内容 |
|---|---|
| `dist/点译-eDrop-0.3.18.dmg` | 给用户的磁盘映像。卷名同为 `点译-eDrop-0.3.18`，内含 `eDrop.app`（显示名「点译」）和指向「应用程序」的替身 |
| `dist/eDrop.app` | 已签名、已公证、票据已装订的 App |
| `dist/notary-app.log` / `dist/notary-dmg.log` | notarytool 的 JSON 结果（含 submission id） |

`dist/` 已在 `.gitignore` 中。脚本结束时会打印上述路径和 DMG 的 SHA-256。

脚本会向 Apple 提交两次公证：先是 `.app`（拷到「应用程序」后离线仍能通过 Gatekeeper），再是 `.dmg`。两次都需要能访问 Apple 的时间戳与公证服务。

发行说明草稿：[`docs/RELEASE-NOTES-0.3.18.md`](../docs/RELEASE-NOTES-0.3.18.md)。把日志里的公证 id 填进该草稿的占位处后再发布。

---

# 点译 · eDrop — Developer ID disk image

On a Mac that already has a **Developer ID Application** certificate, `scripts/build-signed-dmg.sh` builds a signed and notarized `.dmg`. The script packages, signs, notarizes, and staples. It does not change translation, selection, overlay, or menu-bar behavior.

Debug/Release in the Xcode project stay ad-hoc (`CODE_SIGN_IDENTITY="-"`, empty `DEVELOPMENT_TEAM`) for local runs. The script passes Developer ID only on the `xcodebuild` / `codesign` command line and enables the hardened runtime, which notarization requires. The bundle id stays `app.eyedrop.translate`.

This step does not upload GitHub Releases. After the script succeeds, the copyright holder uploads the `.dmg` from `dist/`.

## Prepare

1. Install Xcode on macOS and run `sudo xcode-select -s /Applications/Xcode.app`.
2. Install a **Developer ID Application** certificate and its private key in the login keychain.  
   Xcode → Settings → Accounts → Manage Certificates → **+** → Developer ID Application.  
   The private key is present when `security find-identity -v -p codesigning` lists the certificate.
3. Choose one notarization method.

Keychain profile (preferred; the password is not stored in shell history):

```bash
xcrun notarytool store-credentials "edrop-notary" \
  --apple-id "you@example.com" \
  --team-id "YOURTEAMID"
```

Or an app-specific password from [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords. That is not the Apple ID password.

If `codesign` reports a locked keychain:

```bash
security unlock-keychain "$HOME/Library/Keychains/login.keychain-db"
```

## Run

```bash
export TEAM_ID="YOURTEAMID"
export NOTARY_PROFILE="edrop-notary"
# Only when more than one Developer ID Application certificate exists for the team:
# export CODESIGN_IDENTITY="Developer ID Application: Your Name (YOURTEAMID)"

./scripts/build-signed-dmg.sh
```

Without a keychain profile:

```bash
export TEAM_ID="YOURTEAMID"
export APPLE_ID="you@example.com"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
./scripts/build-signed-dmg.sh
```

`--team-id` and `--identity` are equivalent to those variables. `./scripts/build-signed-dmg.sh --help` prints the environment contract.

The script exits before the build when the certificate name is not `Developer ID Application: …`, the private key is absent from the keychain, or notarization variables are missing. The message names what is missing.

## Output

The marketing version is `MARKETING_VERSION` in the Xcode project (currently **0.3.18**, build **27**).

| Path | Contents |
|---|---|
| `dist/点译-eDrop-0.3.18.dmg` | User-facing disk image. Volume name `点译-eDrop-0.3.18`. Contains `eDrop.app` (display name 点译) and an Applications alias |
| `dist/eDrop.app` | Signed, notarized, stapled app |
| `dist/notary-app.log` / `dist/notary-dmg.log` | notarytool JSON, including the submission id |

`dist/` is gitignored. The script prints these paths and the DMG SHA-256 when it finishes.

Notarization is submitted twice: the `.app` (so a copy in `/Applications` still passes Gatekeeper offline) and the `.dmg`. Both need network access to Apple's timestamp and notarization services.

Draft notes: [`docs/RELEASE-NOTES-0.3.18.md`](../docs/RELEASE-NOTES-0.3.18.md). Copy the notarization id from the log into that draft before publishing.
