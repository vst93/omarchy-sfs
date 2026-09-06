# SFS Sync for Omarchy

A native [Omarchy](https://omarchy.org) bar plugin for [SFS (SmallFileSync)](https://github.com/vst93/sfs) — see your WebDAV file-sync status at a glance and drive uploads, downloads, and full syncs right from the bar.

**[English](#features)** · **[中文](#中文说明)**

---

## Features

- **Bar widget** — a flat folder-sync icon (Lucide) with a `synced/total` counter that turns **urgent-red** when any file has a conflict or is missing locally
- **Control panel** — a scrollable file list with per-file status, size, last-sync time, and local path
- **Per-file actions** — every row keeps its primary sync action and edit control visible; edit a row to bind/unbind the local dir, edit the note, copy the path, or delete the record (with confirmation)
- **Responsive controls** — the panel and every form dialog scroll on short screens; Escape closes the active dialog before closing the panel
- **Sync all** — one click, with a localized outcome line (uploaded / downloaded / skipped / failed)
- **Storage settings** — read and set the WebDAV endpoint, username, password, and remote base dir, test the connection, and toggle auto-sync
- **Add file** — add a sync entry from the bar (path + optional note)
- **Export** — copy the storage config (or, on right-click, the file list) as JSON to the clipboard
- **Web UI shortcut** — middle-click the bar widget (or the panel button) to open the full SFS web interface
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
| Click **Add file** | Add a sync entry (path + optional note) |
| Click **Storage** | Open WebDAV settings, test the connection, toggle auto-sync |
| Click **Export** | Copy the storage config to clipboard (right-click = export file list) |
| Use a file row's action controls | Primary action for its state (↑ upload / ↓ download / pull); ✎ opens edit (dir / note / copy / delete) |
| Middle-click the widget | Open the SFS web UI in your browser |
| Right-click the widget | Force a status refresh |
| **中文 / English** button | Switch language (persisted) |
| `Esc` | Close the active dialog, or the panel when no dialog is open |

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

The backend binds to `127.0.0.1` only, and the plugin talks to it with plain local HTTP. Credentials are only held in the panel while editing and are sent to the local SFS API; exported config intentionally omits the password.

## License

[MIT](LICENSE)

---

## 中文说明

[Omarchy](https://omarchy.org) 原生状态栏插件，为 [SFS (SmallFileSync)](https://github.com/vst93/sfs) 提供系统栏内的 WebDAV 同步状态与快捷操作。

### 功能

- **栏组件** — 扁平 folder-sync 图标（Lucide 风格）+ `已同步/总数` 计数；出现冲突或文件缺失时变红
- **控制面板** — 滚动的文件列表，显示每个文件的状态、大小、最近同步时间与本地路径
- **单文件操作** — 每行常驻主操作与编辑按钮（上传/下载/拉取）；编辑后可设置目录、备注、复制路径或删除（带确认）
- **响应式交互** — 面板和所有表单弹窗在小屏上可滚动；按 Esc 先关闭当前弹窗，再关闭面板
- **全部同步** — 一键全量同步，并显示结果统计（上传/下载/跳过/失败）
- **存储设置** — 在面板直接查看/配置 WebDAV 地址/用户名/密码/远端目录、测试连接、自动同步开关
- **添加文件** — 面板直接添加待同步条目（路径 + 可选备注）
- **导出** — 一键把存储配置（或文件清单）以 JSON 复制到剪贴板
- **网页界面** — 中键点击栏组件直接打开 SFS Web UI
- **自动后端** — 按需启动 `sfs web`，复用已在运行的实例，自动屏蔽 SFS 的浏览器弹窗，崩溃或重启后自动重连
- **中英双语** — 默认英文，面板内一键切换中文（设置持久化到 Omarchy 配置）
- **跟随主题** — 所有颜色、字体、间距均取自 Omarchy 主题 token，任何主题下都原生协调

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
