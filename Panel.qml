import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Lib.js" as Lib

// SFS Sync — control panel.
//
// Layout, top to bottom:
//   PanelHero        product mark + connection state (color, never hardcoded)
//   action row       Sync All button + language toggle + web UI shortcut
//   "Files" header   file count in muted
//   file list        one row per file: status glyph, name, size, age
//   last sync line   outcome of the most recent full sync, localized
//
// Every color comes from the theme via Color.* / bar / root.barForeground —
// the panel must look native under any Omarchy theme, light or dark.
Panel {
  id: root
  moduleName: "io.github.vst93.sfs"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // ---- Assisted install ----------------------------------------------------
  // ConfirmDialog state + terminal launcher. installFailedShown latches on
  // once the user returns from an install attempt that did not produce a
  // usable sfs binary; a successful relocate() clears it.
  property bool installConfirmOpen: false
  property bool installFailedShown: false

  function launchInstall() {
    var sh = [
      "curl -fsSL https://raw.githubusercontent.com/vst93/sfs/main/cmd/install.sh -o /tmp/sfs-install.sh",
      "&& sh /tmp/sfs-install.sh",
      "; echo",
      "; read -n 1 -s -r -p '" + (root.lang === "zh" ? "按任意键关闭…" : "Press any key to close…") + "'"
    ].join(" ")
    if (root.bar) root.bar.run("omarchy-launch-tui sh -c " + Lib.shellQuote(sh))
    // When the terminal closes there is no callback — the user comes back and
    // either hits "Search again" (which clears the latch on success) or the
    // heartbeat retries on its own. Show the failure hint meanwhile.
    root.installFailedShown = true
  }

  readonly property var widget: hostWidget || null
  readonly property var m: widget ? widget.model : null
  readonly property bool syncing: widget ? widget.syncing : false
  readonly property var lastSync: widget ? widget.lastSync : null
  readonly property string lang: widget ? widget.lang : "en"

  readonly property color fg: root.bar ? root.bar.barForeground : Color.foreground
  readonly property color dim: Color.muted
  readonly property color warn: Color.urgent
  readonly property string fontFam: root.bar ? root.bar.fontFamily : Style.font.family

  function open() {
    if (widget) widget.locateIfIdle()
    root.controller.show()
  }
  function close() {
    root.controller.hide()
  }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  // ---- i18n -----------------------------------------------------------------
  readonly property var tr: ({
    "en": {
      title: "SFS Sync", subtitle: "WebDAV file sync",
      on: "Connected", off: "Offline", starting: "Starting…",
      notInstalled: "SFS not found", retrying: "Looking for SFS…",
      installTitle: "SFS is not installed yet.",
      installBody: "Install the SFS command line tool, then retry. The plugin opens a terminal and runs SFS's official install script.",
      installBtn: "Install SFS…", installConfirm: "Run the SFS install script in a terminal?",
      installNow: "Install", installCancel: "Cancel", installLater: "Not now",
      retryBtn: "Search again",
      installFailed: "Install did not finish — run the script manually and try again.",
      syncAll: "Sync all", syncing: "Syncing…", web: "Web UI",
      files: "Files", empty: "No files yet — add them in the SFS app.",
      notConfigured: "WebDAV not configured — open SFS to set it up.",
      lastSync: "Last sync", never: "—",
      up: "uploaded", down: "downloaded", skip: "skipped", fail: "failed",
      upload: "Upload", download: "Download", forcedUp: "Force up", forcedDown: "Force down",
      language: "中文", langTip: "Switch to English",
      busy: "…"
    },
    "zh": {
      title: "SFS 同步", subtitle: "WebDAV 文件同步",
      on: "已连接", off: "未连接", starting: "启动中…",
      notInstalled: "未找到 SFS", retrying: "正在查找 SFS…",
      installTitle: "尚未安装 SFS。",
      installBody: "需要先安装 SFS 命令行工具。点击下面的按钮会打开终端并运行 SFS 官方安装脚本。",
      installBtn: "安装 SFS…", installConfirm: "在终端中运行 SFS 官方安装脚本？",
      installNow: "安装", installCancel: "取消", installLater: "暂不",
      retryBtn: "重新查找",
      installFailed: "安装未完成 — 请手动运行安装脚本后重试。",
      syncAll: "全部同步", syncing: "同步中…", web: "网页界面",
      files: "文件", empty: "还没有文件 — 请在 SFS 应用里添加。",
      notConfigured: "WebDAV 未配置 — 请先打开 SFS 设置。",
      lastSync: "上次同步", never: "—",
      up: "上传", down: "下载", skip: "跳过", fail: "失败",
      upload: "上传", download: "下载", forcedUp: "强传", forcedDown: "强拉",
      language: "English", langTip: "Switch to Chinese",
      busy: "…"
    }
  })
  function t(key) {
    var dict = tr[lang] || tr["en"]
    return dict[key] !== undefined ? dict[key] : tr["en"][key]
  }

  function toneColor(tone) {
    if (tone === "urgent") return Color.urgent
    if (tone === "warning") return Qt.alpha(fg, 0.85)
    if (tone === "info") return Qt.alpha(fg, 0.7)
    if (tone === "accent") return Color.accent
    return dim
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.installConfirmOpen) { root.installConfirmOpen = false; return }
        root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      // Install confirmation — overlay above the key catcher so keys route to
      // the dialog while it is open.
      ConfirmDialog {
        anchors.fill: parent
        opened: root.installConfirmOpen
        message: root.t("installConfirm")
        confirmText: root.t("installNow")
        cancelText: root.t("installLater")
        fontFamily: root.fontFam
        onConfirmed: {
          root.installConfirmOpen = false
          root.launchInstall()
        }
        onCanceled: root.installConfirmOpen = false
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        // ---- Hero ---------------------------------------------------------
        PanelHero {
          width: parent.width
          title: root.t("title")
          detail: {
            var w = root.widget
            if (!w) return root.t("off")
            if (w.phase === "notFound") return root.t("notInstalled")
            if (w.phase === "connected") return root.t("on")
            if (w.phase === "starting") return root.t("starting")
            return root.t("off")
          }
          foreground: root.fg
          fontFamily: root.fontFam
          iconComponent: Component {
            SfsIcon {
              iconSize: Style.font.display
              color: {
                var w = root.widget
                if (!w || w.phase !== "connected") return root.dim
                return Color.accent
              }
            }
          }
          trailingControl: Component {
            Item {
              width: Style.space(60)
              height: Style.space(22)
              anchors.verticalCenter: parent.verticalCenter

              Button {
                anchors.fill: parent
                text: root.t("language")
                tooltipText: root.t("langTip")
                fontFamily: root.fontFam
                fontSize: Style.font.caption
                bordered: true
                onClicked: {
                  if (root.widget) root.widget.setLang(root.lang === "en" ? "zh" : "en")
                }
              }
            }
          }
        }

        // ---- Action row ----------------------------------------------------
        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            text: root.syncing ? root.t("syncing") : root.t("syncAll")
            iconText: root.syncing ? "\u2026" : "\u21C4"
            iconSpinning: root.syncing
            fontFamily: root.fontFam
            enabled: !root.syncing && root.m !== null
            onClicked: { if (root.widget) root.widget.syncAll() }
          }

          Button {
            text: root.t("web")
            iconText: "\u2197"
            fontFamily: root.fontFam
            onClicked: { if (root.widget) root.widget.openWebUI() }
          }
        }

        // ---- Section header -------------------------------------------------
        PanelSectionHeader {
          width: parent.width
          text: root.t("files") + (root.m ? "  \u00B7  " + (root.m.summary.total || 0) : "")
          foreground: root.fg
          fontFamily: root.fontFam
        }

        // ---- States replacing the list -------------------------------------
        // "SFS not found" page: explanation + assisted install + manual retry.
        // The install runs SFS's official install.sh in a user-facing terminal
        // (omarchy-launch-tui) after an explicit confirm — the plugin itself
        // never downloads or writes anything outside the shell's view.
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.widget !== null && root.widget.phase === "notFound"

          Text {
            width: parent.width
            text: root.t("installTitle")
            color: root.warn
            font.family: root.fontFam
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }
          Text {
            width: parent.width
            text: root.t("installBody")
            color: root.dim
            font.family: root.fontFam
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
          Row {
            spacing: Style.space(8)

            Button {
              text: root.t("installBtn")
              iconText: "\u2193"
              fontFamily: root.fontFam
              onClicked: { root.installConfirmOpen = true }
            }
            Button {
              text: root.t("retryBtn")
              iconText: "\u21BB"
              fontFamily: root.fontFam
              bordered: true
              onClicked: { root.installFailedShown = false; if (root.widget) root.widget.relocate() }
            }
          }
          Text {
            width: parent.width
            visible: root.installFailedShown
            text: root.t("installFailed")
            color: root.warn
            font.family: root.fontFam
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        Text {
          width: parent.width
          visible: {
            if (!root.widget) return false
            if (root.widget.phase === "notFound") return false
            if (root.widget.phase === "locating" || root.widget.phase === "starting") return root.m === null
            if (root.m === null) return false
            return root.m.storage === false
          }
          text: {
            if (root.m !== null && root.m.storage === false) return root.t("notConfigured")
            if (root.widget && root.widget.phase === "locating") return root.t("retrying")
            return root.t("off")
          }
          color: root.warn
          font.family: root.fontFam
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Text {
          width: parent.width
          visible: root.m !== null && (root.m.files || []).length === 0
          text: root.t("empty")
          color: root.dim
          font.family: root.fontFam
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        // ---- File list -------------------------------------------------------
        Column {
          width: parent.width
          spacing: Style.space(2)
          visible: root.m !== null && (root.m.files || []).length > 0

          Repeater {
            model: root.m !== null ? (root.m.files || []) : []

            delegate: Item {
              id: row
              required property var modelData
              readonly property var meta: Lib.statusMeta(modelData.status)
              width: parent.width
              implicitHeight: nameCol.implicitHeight + Style.space(8)
              height: implicitHeight

              // Row background — flat highlight on hover, theme-derived.
              Rectangle {
                id: rowBg
                anchors.fill: parent
                radius: Style.space(4)
                color: rowMouse.containsMouse ? Qt.alpha(root.fg, 0.06) : "transparent"
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
              }

              // Status glyph
              Text {
                id: glyph
                anchors.left: parent.left
                anchors.leftMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(18)
                text: Lib.statusMeta(modelData.status).icon
                color: root.toneColor(Lib.statusMeta(modelData.status).tone)
                font.family: root.fontFam
                font.pixelSize: Style.font.body
              }

              // Name + meta
              Column {
                id: nameCol
                anchors.left: glyph.right
                anchors.leftMargin: Style.space(8)
                anchors.right: actions.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  text: modelData.fileName || ""
                  color: root.fg
                  font.family: root.fontFam
                  font.pixelSize: Style.font.body
                  elide: Text.ElideMiddle
                }

                Text {
                  width: parent.width
                  text: {
                    var bits = []
                    var meta = Lib.statusMeta(modelData.status)
                    bits.push(root.lang === "zh" ? meta.zh : meta.en)
                    if (modelData.size) bits.push(Lib.fmtSize(modelData.size))
                    var when = modelData.lastUploadTime || modelData.lastChangeTime
                    var ago = Lib.fmtTime(when, root.lang)
                    if (ago !== "") bits.push(ago)
                    return bits.join("  \u00B7  ")
                  }
                  color: root.dim
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              // Per-file actions
              Row {
                id: actions
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)
                visible: rowMouse.containsMouse

                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: modelData.status === "download" || modelData.status === "missing"
                  iconText: "\u2193"
                  tooltipText: root.t("download")
                  foreground: root.fg
                  fontFamily: root.fontFam
                  onClicked: { if (root.widget) root.widget.syncSingle(modelData.id, "force_download") }
                }

                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: modelData.status === "pending_upload" || modelData.status === "initial_upload"
                  iconText: "\u2191"
                  tooltipText: root.t("upload")
                  foreground: root.fg
                  fontFamily: root.fontFam
                  onClicked: { if (root.widget) root.widget.syncSingle(modelData.id, "force_upload") }
                }

                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: modelData.status === "conflict"
                  iconText: "\u2193"
                  tooltipText: root.t("forcedDown")
                  foreground: root.warn
                  fontFamily: root.fontFam
                  onClicked: { if (root.widget) root.widget.syncSingle(modelData.id, "force_download") }
                }

                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: modelData.status === "conflict"
                  iconText: "\u2191"
                  tooltipText: root.t("forcedUp")
                  foreground: root.warn
                  fontFamily: root.fontFam
                  onClicked: { if (root.widget) root.widget.syncSingle(modelData.id, "force_upload") }
                }
              }
            }
          }
        }

        // ---- Last sync outcome ----------------------------------------------
        Text {
          width: parent.width
          visible: root.lastSync !== null
          text: {
            var s = root.lastSync ? root.lastSync.summary : null
            if (!s) return ""
            var bits = [root.t("lastSync")]
            if (root.lang === "zh") {
              bits.push("\u2191" + (s.uploaded || 0) + " \u2193" + (s.downloaded || 0) +
                        " \u21BB" + (s.skipped || 0) + " \u2717" + (s.failed || 0))
            } else {
              bits.push((s.uploaded || 0) + " " + root.t("up") + ", " +
                        (s.downloaded || 0) + " " + root.t("down") + ", " +
                        (s.skipped || 0) + " " + root.t("skip") + ", " +
                        (s.failed || 0) + " " + root.t("fail"))
            }
            return bits.join(":  ")
          }
          color: root.lastSync && root.lastSync.summary && root.lastSync.summary.failed > 0
                 ? root.warn : root.dim
          font.family: root.fontFam
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
