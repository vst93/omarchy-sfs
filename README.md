# SFS Sync for Omarchy

A native [Omarchy](https://omarchy.org) bar plugin for [SFS (SmallFileSync)](https://github.com/vst93/sfs) — see your WebDAV file-sync status at a glance and drive uploads, downloads, and full syncs right from the bar.

**[English](#features)** · **[中文](#中文说明)**

![SFS Sync control panel](docs/image.png)

---

## Features

- **Bar widget** — a compact sync-ring glyph that turns **urgent-red** when any file has a conflict or is missing locally (the counts live in the panel, not on the bar)
- **Compact control panel** — one primary **Sync all** button plus a single row of icon commands (add / storage / export / web / refresh); no wasted space on tiles
- **Status filter** — a compact dropdown next to the list header (All / Linked / Unlinked / Pending) with live counts, plus an optional free-text filter
- **File list** — attention-first ordering (conflicts and missing files float to the top); each row shows status, size, age and note; the list scrolls and claims the leftover panel height
- **Per-file actions** — each row has a single **Edit** control (plus clicking the row); one **Save** in the dialog writes the note and, when you changed it, rebinds the local dir. Copy the path, unbind, or delete the record from the same dialog (delete asks for confirmation)
- **Keyboard driven** — `j`/`k` or ↑/↓ move a row cursor, `Enter` opens edit, `x` deletes, `f` filters, and `s`/`a`/`r`/`w`/`e` run sync / add / refresh / web / export
- **Responsive dialogs** — every dialog shares one card shell (scrim, title, close button, scrolling body) and closes on `Esc` or outside click
- **Sync all** — one click, with a localized outcome line (uploaded / downloaded / skipped / failed)
- **Storage settings** — read and set the WebDAV endpoint, username, password, and remote base dir, test the connection, and toggle auto-sync (actions sit under the form; a ⇄ marker appears in the header while auto-sync is on)
- **Add file** — add a sync entry from the bar (path + optional note)
- **Share config** — copy an `sfs --import-config <base64>` command (same format the SFS app shares) so another machine can import your WebDAV settings, credentials and all
- **Web UI shortcut** — middle-click the bar widget (or the panel button) to open the full SFS web interface
- **Assisted install** — if `sfs` is missing the panel offers a one-click install that runs SFS's official script in a terminal (you confirm first)
- **Auto backend** — starts `sfs web` on demand, reuses a server that is already running, suppresses the automatic browser popup, and reconnects on its own after crashes or restarts
- **Bilingual** — English by default, 中文 with one click (persisted in your Omarchy config)
- **Theme-native** — every color, font, and spacing token comes from your Omarchy theme (`Color.*` / `Style.*`), so it looks right in any theme

## Requirements

- [Omarchy](https://omarchy.org) (Quattro shell, Hyprland)
- [SFS](https://github.com/vst93/sfs) ≥ 0.1.11 — the plugin talks to `sfs` over its local web API; **the SFS app itself stays untouched**

## Install

```sh
omarchy plugin add https://github.com/vst93/omarchy-sfs.git --enable
```

The widget appears in the right section of your bar. It starts the `sfs web` backend automatically on first click.

### If SFS is not installed

The plugin looks for the `sfs` binary in `$PATH` and the standard install locations (`~/.local/bin`, Homebrew, `/usr/local/bin`). If it cannot find one, the panel shows a short "SFS not found" page with:

- **Install SFS…** — opens a terminal and runs SFS's official install script (you confirm before anything runs; the plugin itself never downloads or writes files)
- **Search again** — re-scan after you have installed SFS another way

Omarchy plugins are plain QML folders with no install hooks, so SFS cannot be pulled in automatically by `omarchy plugin add` — the assisted install above is the one-click path.

## Usage

| Action | Result |
|---|---|
| Left-click the widget | Open the control panel |
| Click **Sync all** | Full sync (smart: uploads local changes, downloads cloud changes, skips identical) |
| Click the **+** action | Add a sync entry (path + optional note) |
| Click the **gear** action | Open WebDAV settings, test the connection, toggle auto-sync |
| Click the **export** action | Copy the `sfs --import-config …` share command to the clipboard |
| Click the **external-link** action | Open the SFS web UI |
| Click the **refresh** action | Force a status refresh |
| Use the **status dropdown** | Filter the list: All / Linked / Unlinked / Pending (with counts) |
| Click the **filter** action | Show a free-text field for name / path / note |
| Click a row or its ✎ | Open the edit dialog: bind/unbind the local dir, edit the note, copy the path, delete the record — one **Save** commits the note and any dir change |
| Middle-click the widget | Open the SFS web UI in your browser |
| Right-click the widget | Force a status refresh |
| **中文 / English** button | Switch language (persisted) |
| `Esc` | Close the active dialog (or clear the filter), then the panel |
| `j` / `k`, ↑ / ↓ | Move the row cursor |
| `Enter` | Open the selected row's edit dialog |
| `x` | Delete the selected record (with confirmation) |
| `s` / `a` / `r` / `w` / `e` / `f` | Sync all / add file / refresh / web UI / export / filter |

### Configuration

All settings are optional and live in `~/.config/omarchy/shell.json` under the plugin's id:

```jsonc
{
  "io.github.vst93.sfs": {
    "port": 8791,          // local port for the sfs web backend (default 8791)
    "pollSeconds": 30,     // status refresh interval while connected (min 10)
    "sfsPath": "sfs",      // path to the sfs binary if not on $PATH
    "lang": "en"           // "en" or "zh" (also set by the panel toggle)
  }
}
```

### Bar placement

```sh
omarchy bar move io.github.vst93.sfs --section right
```

## Remove

```sh
omarchy plugin remove io.github.vst93.sfs
```

The plugin never edits your SFS settings or data — removing it leaves SFS exactly as it was.

## Privacy & security

The backend binds to `127.0.0.1` only, and the plugin talks to it with plain local HTTP. Credentials are only held in the panel while editing and are sent to the local SFS API. The Share command intentionally includes the password (it is the same `sfs --import-config` blob the SFS app itself shares), so treat it as a secret.

## License

[MIT](LICENSE)

---

## 中文说明

[Omarchy](https://omarchy.org) 原生状态栏插件，为 [SFS (SmallFileSync)](https://github.com/vst93/sfs) 提供系统栏内的 WebDAV 同步状态与快捷操作。

![SFS Sync 控制面板](docs/image.png)

### 功能

- **栏组件** — 简洁的同步环图标；出现冲突或文件缺失时变红（计数移到面板里，状态栏只保留图标）
- **紧凑控制面板** — 一个主操作 **全部同步** 按钮 + 一行图标命令（添加 / 存储 / 分享 / 网页 / 刷新），不再用大块按钮平铺浪费空间
- **状态筛选** — 列表标题旁的紧凑下拉（全部 / 已关联 / 未关联 / 待同步）并显示各自数量，另可按需展开关键词筛选
- **文件列表** — 需要处理的条目优先排前（冲突、缺失置顶）；每行显示状态、大小、时间与备注；列表自动占满剩余高度
- **单文件操作** — 每行只有一个 **编辑** 按钮（点击整行同样进入编辑）；弹窗里一个 **保存** 同时提交备注与（如已修改的）本地目录，并可复制路径、解除关联或删除（删除带确认）
- **键盘操作** — `j`/`k` 或 ↑/↓ 移动行光标，`Enter` 编辑，`x` 删除，`f` 筛选，`s`/`a`/`r`/`w`/`e` 分别执行同步/添加/刷新/网页/导出
- **响应式弹窗** — 所有弹窗共用同一张卡片外壳（遮罩、标题、关闭按钮、可滚动内容），Esc 或点击外部即可关闭
- **全部同步** — 一键全量同步，并显示结果统计（上传/下载/跳过/失败）
- **存储设置** — 在面板直接查看/配置 WebDAV 地址/用户名/密码/远端目录、测试连接、自动同步开关（操作按钮放在表单下方；开启自动同步后标题栏会出现 ⇄ 标记）
- **添加文件** — 面板直接添加待同步条目（路径 + 可选备注）
- **分享配置** — 一键复制 `sfs --import-config <base64>` 导入命令（与 SFS 应用一致的格式），另一台机器可直接导入 WebDAV 设置与凭据
- **网页界面** — 中键点击栏组件直接打开 SFS Web UI
- **辅助安装** — 找不到 `sfs` 时，面板提供一键安装：确认后在终端运行 SFS 官方安装脚本
- **自动后端** — 按需启动 `sfs web`，复用已在运行的实例，自动屏蔽 SFS 的浏览器弹窗，崩溃或重启后自动重连
- **中英双语** — 默认英文，面板内一键切换中文（设置持久化到 Omarchy 配置）
- **跟随主题** — 所有颜色、字体、间距均取自 Omarchy 主题 token，任何主题下都原生协调

### 用法

| 操作 | 结果 |
|---|---|
| 左键点击栏图标 | 打开控制面板 |
| 点击 **全部同步** | 全量同步（智能：上传本地改动、下载云端改动、跳过相同项） |
| 点击 **+** | 添加同步条目（路径 + 可选备注） |
| 点击 **齿轮** | 打开 WebDAV 设置，测试连接，自动同步开关 |
| 点击 **分享** | 复制 `sfs --import-config …` 导入命令到剪贴板 |
| 点击 **外链** | 打开 SFS 网页界面 |
| 点击 **刷新** | 强制刷新状态 |
| 使用 **状态下拉** | 按 全部 / 已关联 / 未关联 / 待同步 过滤列表（带数量） |
| 点击 **漏斗** | 展开关键词筛选（名称 / 路径 / 备注） |
| 点击整行或 ✎ | 打开编辑弹窗：绑定/解除本地目录、编辑备注、复制路径、删除记录；一个 **保存** 同时提交备注与目录改动 |
| 中键点击栏图标 | 在浏览器打开 SFS 网页界面 |
| 右键点击栏图标 | 强制刷新状态 |
| **中文 / English** 按钮 | 切换语言（已持久化） |
| `Esc` | 关闭当前弹窗（或清空筛选），再关闭面板 |
| `j` / `k`、↑ / ↓ | 移动行光标 |
| `Enter` | 打开所选行的编辑弹窗 |
| `x` | 删除所选记录（带确认） |
| `s` / `a` / `r` / `w` / `e` / `f` | 全部同步 / 添加 / 刷新 / 网页 / 导出 / 筛选 |

### 安装

```sh
omarchy plugin add https://github.com/vst93/omarchy-sfs.git --enable
```

### 如果还没安装 SFS

插件会在 `$PATH` 和常见安装位置（`~/.local/bin`、Homebrew、`/usr/local/bin`）查找 `sfs`。找不到时面板会显示"未找到 SFS"页面：

- **安装 SFS…** — 打开终端运行 SFS 官方安装脚本（运行前需确认；插件本身不下载不写任何文件）
- **重新查找** — 用其他方式装好 SFS 后重新扫描

Omarchy 插件只是纯 QML 文件夹，没有安装钩子，所以 `omarchy plugin add` 无法顺带自动安装 SFS — 上面的辅助安装就是一键路径。

### 配置

配置项写在 `~/.config/omarchy/shell.json`（均可省略）：

```jsonc
{
  "io.github.vst93.sfs": {
    "port": 8791,
    "pollSeconds": 30,
    "sfsPath": "sfs",
    "lang": "en"
  }
}
```

### 卸载

```sh
omarchy plugin remove io.github.vst93.sfs
```

插件不修改 SFS 的任何设置与数据，卸载后 SFS 保持原样。
