# SFS Sync for Omarchy

A native [Omarchy](https://omarchy.org) bar plugin for [SFS (SmallFileSync)](https://github.com/vst93/sfs) — see your WebDAV file-sync status at a glance and drive uploads, downloads, and full syncs right from the bar.

**[English](#features)** · **[中文](#中文说明)**

---

## Features

- **Bar widget** — a `⇄ synced/total` counter that turns **urgent-red** when any file has a conflict or is missing locally
- **Control panel** — file list with per-file status, size, and last-sync time
- **Per-file actions** — upload pending files, download cloud-only files, resolve conflicts with explicit force-up/force-down
- **Sync all** — one click, with a localized outcome line (uploaded / downloaded / skipped / failed)
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

## Usage

| Action | Result |
|---|---|
| Left-click the `⇄` widget | Open the control panel |
| Click **Sync all** | Full sync (smart: uploads local changes, downloads cloud changes, skips identical) |
| Hover a file row | Show per-file actions (↑ upload / ↓ download; conflicts get both) |
| Middle-click the widget | Open the SFS web UI in your browser |
| Right-click the widget | Force a status refresh |
| **中文 / English** button | Switch language (persisted) |
| `Esc` | Close the panel |

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

The backend binds to `127.0.0.1` only, and the plugin talks to it with plain local HTTP. Your WebDAV credentials stay inside SFS; the plugin never sees them.

## License

[MIT](LICENSE)

---

## 中文说明

[Omarchy](https://omarchy.org) 原生状态栏插件，为 [SFS (SmallFileSync)](https://github.com/vst93/sfs) 提供系统栏内的 WebDAV 同步状态与快捷操作。

### 功能

- **栏组件** — `⇄ 已同步/总数` 计数；出现冲突或文件缺失时变红
- **控制面板** — 文件列表，显示每个文件的状态、大小、最近同步时间
- **单文件操作** — 上传待传文件、下载云端文件；冲突文件提供"强传/强拉"两个方向
- **全部同步** — 一键全量同步，并显示结果统计（上传/下载/跳过/失败）
- **网页界面** — 中键点击栏组件直接打开 SFS Web UI
- **自动后端** — 按需启动 `sfs web`，复用已在运行的实例，自动屏蔽 SFS 的浏览器弹窗，崩溃或重启后自动重连
- **中英双语** — 默认英文，面板内一键切换中文（设置持久化到 Omarchy 配置）
- **跟随主题** — 所有颜色、字体、间距均取自 Omarchy 主题 token，任何主题下都原生协调

### 安装

```sh
omarchy plugin add https://github.com/vst93/omarchy-sfs.git --enable
```

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
