import QtQuick
import QtQuick.Controls
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
      syncAll: "Sync all", syncing: "Syncing…", web: "Web UI", refresh: "Refresh",
      files: "Files", empty: "No files yet — add them in the SFS app.",
      notConfigured: "WebDAV not configured — open SFS to set it up.",
      lastSync: "Last sync", never: "—",
      up: "uploaded", down: "downloaded", skip: "skipped", fail: "failed",
      upload: "Upload", download: "Download", forcedUp: "Force up", forcedDown: "Force down",
      addFile: "Add file", storage: "Storage", export: "Export", copied: "copied to clipboard",
      actPull: "Pull", actDownload: "Download", actUpload: "Upload",
      actSetDir: "Dir", actNote: "Note", actDel: "Delete", actCopy: "Copy",
      edit: "Edit", autoSync: "Auto sync",
      addTitle: "Add sync file",
      addBody: "Add a new file to sync",
      addPath: "File path", addPathPh: "/home/user/.config/foo.conf",
      addNote: "Note (optional)", addNotePh: "≤ 50 chars",
      addOk: "Add", cancel: "Cancel", requiredPath: "File path required",
      storageTitle: "Storage settings",
      storageBody: "WebDAV connection for remote sync.",
      endpoint: "WebDAV URL", endpointPh: "https://dav.jianguoyun.com/dav",
      username: "Username", password: "Password / app password",
      basePath: "Remote base dir", basePathPh: "blank = small-file-sync, / = root",
      test: "Test", save: "Save",
      testOk: "connection OK", testFail: "connection failed",
      saved: "Settings saved", requiresAuth: "URL, username and password are required",
      dirTitle: "Local directory",
      dirBody: "Set where this file lives on this device.",
      dirInput: "Local dir path", apply: "Apply", unbind: "Unbind",
      unbindMsg: "Unbind local dir only — cloud record and local file stay.",
      dirSet: "Dir set", dirDone: "Unbound",
      noteTitle: "Edit note", notePh: "Note for this file", noteDone: "Note saved",
      delTitle: "Delete record",
      delBody: "Removes the cloud copy and the sync record. The local file is kept.",
      delOk: "Delete", delCancel: "Cancel", delDone: "Record deleted",
      expConfig: "Export config", expList: "Export list", close: "Close",
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
      syncAll: "全部同步", syncing: "同步中…", web: "网页界面", refresh: "刷新",
      files: "文件", empty: "还没有文件 — 请在 SFS 应用里添加。",
      notConfigured: "WebDAV 未配置 — 请先打开 SFS 设置。",
      lastSync: "上次同步", never: "—",
      up: "上传", down: "下载", skip: "跳过", fail: "失败",
      upload: "上传", download: "下载", forcedUp: "强传", forcedDown: "强拉",
      addFile: "添加文件", storage: "存储设置", export: "导出", copied: "已复制到剪贴板",
      actPull: "拉取", actDownload: "下载", actUpload: "上传",
      actSetDir: "目录", actNote: "备注", actDel: "删除", actCopy: "复制",
      edit: "编辑", autoSync: "自动同步",
      addTitle: "添加文件",
      addBody: "添加一个新的待同步文件",
      addPath: "文件路径", addPathPh: "/home/user/.config/foo.conf",
      addNote: "备注（可选）", addNotePh: "50 字以内",
      addOk: "添加", cancel: "取消", requiredPath: "请填写文件路径",
      storageTitle: "存储设置",
      storageBody: "配置 WebDAV 服务器以启用远程同步。",
      endpoint: "WebDAV 地址", endpointPh: "https://dav.jianguoyun.com/dav",
      username: "用户名", password: "密码 / 应用密码",
      basePath: "远端目录", basePathPh: "留空默认 small-file-sync，/ 表示根目录",
      test: "测试连接", save: "保存",
      testOk: "连接成功", testFail: "连接失败",
      saved: "设置已保存", requiresAuth: "地址、用户名、密码均为必填",
      dirTitle: "设置本地目录",
      dirBody: "设置此文件在本机的存放位置。",
      dirInput: "目录路径", apply: "保存", unbind: "解除关联",
      unbindMsg: "仅解除本机关联 — 云端记录和本地文件都会保留。",
      dirSet: "目录已关联", dirDone: "已解除关联",
      noteTitle: "编辑备注", notePh: "给这个文件加个备注", noteDone: "备注已保存",
      delTitle: "删除同步记录",
      delBody: "将删除云端保存的副本与同步记录；本地文件不会删除。",
      delOk: "删除", delCancel: "取消", delDone: "记录已删除",
      expConfig: "导出配置", expList: "导出列表", close: "关闭",
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

  // ---- Settings / modal state -----------------------------------------------
  property var settings: null
  property var currentTarget: null
  property var delTarget: null
  property var dirTarget: null

  function toastMsg(msg) {
    toastText.text = msg
    toastBar.visible = true
    toastTimer.restart()
  }
  function copyOut(text) {
    if (widget) { widget.copy(text); root.toastMsg(root.t("copied")) }
  }
  function loadSettings() {
    if (!widget) return
    widget.settingsGet(function (payload) {
      if (!payload || !payload.settings) return
      root.settings = payload.settings
      sfAuto.checked = payload.settings.autoSync === true
      var w = payload.settings.storage && payload.settings.storage.webdav
      if (w) { sfEndpoint.text = w.endpoint || ""; sfUsername.text = w.username || ""; sfBase.text = w.basePath || "" }
    })
  }

  // ---- Add file -------------------------------------------------------------
  function doAdd() {
    var path = addPath.text.trim()
    if (!path) { addErr.text = root.t("requiredPath"); addErr.visible = true; return }
    widget.addFile(path, addNote.text.trim(), function (payload) {
      if (payload && payload.message) {
        addModal.visible = false
        addPath.text = ""; addNote.text = ""
        toastMsg(payload.message)
      } else {
        addErr.text = (payload && payload.error) || "error"
        addErr.visible = true
      }
    })
  }

  // ---- Storage settings -----------------------------------------------------
  function webdavFromForm() {
    return {
      endpoint: sfEndpoint.text.trim(),
      username: sfUsername.text.trim(),
      password: sfPassword.text,
      basePath: sfBase.text.trim()
    }
  }
  function doSaveSettings() {
    var w = root.webdavFromForm()
    if (!w.endpoint || !w.username || !w.password) { sfErr.text = root.t("requiresAuth"); sfErr.visible = true; return }
    var data = { autoSync: sfAuto.checked, storage: { type: "webdav", webdav: w } }
    widget.settingsSave(data, function (payload) {
      if (payload && payload.message) {
        root.loadSettings()
        sfError.text = root.t("saved")
      } else {
        sfError.text = (payload && payload.error) || "error"
      }
      sfError.visible = true
    })
  }
  function doTestSettings() {
    var w = root.webdavFromForm()
    if (!w.endpoint || !w.username || !w.password) { sfError.text = root.t("requiresAuth"); sfError.visible = true; return }
    widget.settingsTest(w, function (payload) {
      sfError.text = payload ? (payload.success ? root.t("testOk") : (payload.message || root.t("testFail")))
                             : root.t("testFail")
      sfError.visible = true
    })
  }

  // ---- Dir modal ------------------------------------------------------------
  function openDirModal(item) {
    root.dirTarget = item
    dirInput.text = item.localDir || ""
    dirError.visible = false
    dirModal.visible = true
  }
  function doSetDir() {
    if (!root.dirTarget) return
    widget.setFileDir(root.dirTarget.id, dirInput.text.trim(), function (payload) {
      if (payload && payload.message) { dirModal.visible = false; toastMsg(payload.message) }
      else { dirError.text = (payload && payload.error) || "error"; dirError.visible = true }
    })
  }
  function doUnbind() {
    if (!root.dirTarget) return
    widget.setFileDir(root.dirTarget.id, "", function (payload) {
      if (payload && payload.message) { dirModal.visible = false; toastMsg(root.t("dirDone")) }
      else { dirError.text = (payload && payload.error) || "error"; dirError.visible = true }
    })
  }

  // ---- Note modal -----------------------------------------------------------
  function openNoteModal(item) {
    root.currentTarget = item
    noteInput.text = item.note || ""
    noteModal.visible = true
  }
  function doNote() {
    if (!root.currentTarget) return
    widget.setNote(root.currentTarget.id, noteInput.text, function (payload) {
      if (payload && payload.message) { noteModal.visible = false; toastMsg(payload.message) }
      else { noteErr.text = (payload && payload.error) || "error"; noteErr.visible = true }
    })
  }

  // ---- Edit modal (dir / note / copy / delete in one place) -----------------
  property var editTarget: null
  function openEditModal(item) {
    root.editTarget = item
    editDirInput.text = item.localDir || ""
    editNoteInput.text = item.note || ""
    editErr.visible = false
    editModal.visible = true
  }
  function doEditDir() {
    if (!root.editTarget) return
    widget.setFileDir(root.editTarget.id, editDirInput.text.trim(), function (payload) {
      if (payload && payload.message) toastMsg(payload.message)
      else { editErr.text = (payload && payload.error) || "error"; editErr.visible = true }
    })
  }
  function doEditUnbind() {
    if (!root.editTarget) return
    widget.setFileDir(root.editTarget.id, "", function (payload) {
      if (payload && payload.message) toastMsg(payload.message)
      else { editErr.text = (payload && payload.error) || "error"; editErr.visible = true }
    })
  }
  function doEditNote() {
    if (!root.editTarget) return
    widget.setNote(root.editTarget.id, editNoteInput.text, function (payload) {
      if (payload && payload.message) toastMsg(payload.message)
      else { editErr.text = (payload && payload.error) || "error"; editErr.visible = true }
    })
  }

  // ---- Delete ---------------------------------------------------------------
  function openDeleteConfirm(item) { root.delTarget = item; delConfirm.opened = true }
  function doDelete() {
    if (!root.delTarget) return
    widget.deleteFile(root.delTarget.id, function (payload) {
      if (payload && payload.message) toastMsg(payload.message)
      root.delTarget = null
    })
  }

  // ---- Export ---------------------------------------------------------------
  function doExportConfig() {
    var w = (root.settings && root.settings.storage && root.settings.storage.webdav) || {}
    copyOut(JSON.stringify({
      endpoint: w.endpoint || "", username: w.username || "", basePath: w.basePath || "",
      autoSync: root.settings ? (root.settings.autoSync === true) : false
    }, null, 2))
  }
  function doExportList() {
    if (!root.m) return
    var rows = (root.m.files || []).map(function (f) {
      return { fileName: f.fileName, status: f.status, sizeKb: f.size, localDir: f.localDir, localPath: f.localPath, note: f.note, lastSyncTime: f.lastUploadTime }
    })
    copyOut(JSON.stringify({ summary: root.m.summary, files: rows }, null, 2))
  }
  function scrollListBy(dy) {
    var lv = fileList
    if (!lv) return
    lv.contentY = Math.max(0, Math.min(lv.contentHeight - lv.height, lv.contentY + dy))
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
      Keys.onPressed: function (event) {
        if (event.key === Qt.Key_PageDown) { root.scrollListBy(220); event.accepted = true }
        else if (event.key === Qt.Key_PageUp) { root.scrollListBy(-220); event.accepted = true }
        else if (event.key === Qt.Key_Home) { fileList.contentY = 0; event.accepted = true }
        else if (event.key === Qt.Key_End) { fileList.contentY = Math.max(0, fileList.contentHeight - fileList.height); event.accepted = true }
      }
      onCloseRequested: {
        if (root.installConfirmOpen) { root.installConfirmOpen = false; return }
        if (addModal.visible) { addModal.visible = false; return }
        if (storageModal.visible) { storageModal.visible = false; return }
        if (dirModal.visible) { dirModal.visible = false; return }
        if (noteModal.visible) { noteModal.visible = false; return }
        if (editModal.visible) { editModal.visible = false; return }
        if (delConfirm.opened) { delConfirm.opened = false; return }
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

      // ---- Delete confirm ------------------------------------------------------
      ConfirmDialog {
        id: delConfirm
        anchors.fill: parent
        opened: false
        message: root.t("delBody")
        confirmText: root.t("delOk")
        cancelText: root.t("delCancel")
        fontFamily: root.fontFam
        onConfirmed: { delConfirm.opened = false; root.doDelete() }
        onCanceled: { delConfirm.opened = false; root.delTarget = null }
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

        // ---- Action row (two compact lines) --------------------------------
        Row {
          width: parent.width
          spacing: Style.space(6)

          Button {
            text: root.syncing ? root.t("syncing") : root.t("syncAll")
            iconText: root.syncing ? "\u2026" : "\u21C4"
            iconSpinning: root.syncing
            fontFamily: root.fontFam
            enabled: !root.syncing && root.m !== null
            onClicked: { if (root.widget) root.widget.syncAll() }
          }
          Button {
            text: root.t("addFile")
            iconText: "+"
            fontFamily: root.fontFam
            onClicked: { addPath.text = ""; addNote.text = ""; addErr.visible = false; addModal.visible = true; addPath.forceActiveFocus() }
          }
          Button {
            text: root.t("storage")
            iconText: "\u2699"
            fontFamily: root.fontFam
            onClicked: { root.loadSettings(); storageModal.visible = true }
          }
        }
        Row {
          width: parent.width
          spacing: Style.space(6)
          Button {
            text: root.t("export")
            iconText: "\u2B07"
            tooltipText: root.t("expConfig") + " L" + " / " + root.t("expList") + " R"
            fontFamily: root.fontFam
            onClicked: root.doExportConfig()
            onRightClicked: root.doExportList()
          }
          Button {
            text: root.t("web")
            iconText: "\u2197"
            fontFamily: root.fontFam
            onClicked: { if (root.widget) root.widget.openWebUI() }
          }
          Button {
            text: root.t("refresh")
            iconText: "\u21BB"
            fontFamily: root.fontFam
            onClicked: { if (root.widget) root.widget.refresh() }
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

        // ---- File list (scrollable, custom scrollbar) ---------------------------
        Item {
          id: listWrap
          width: parent.width
          property real listH: Math.min((root.m && root.m.files) ? root.m.files.length * Style.space(48) : 0, Style.space(320))
          height: listH

          ListView {
            id: fileList
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            clip: true
            visible: root.m !== null && (root.m.files || []).length > 0
            model: root.m !== null ? (root.m.files || []) : []
            spacing: Style.space(2)

            flickDeceleration: 2200
            maximumFlickVelocity: 1600
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }


          delegate: Item {
            id: row
            required property var modelData
            width: fileList.width
            height: Style.space(48)

            // row background
            Rectangle {
              id: rowBg
              anchors.fill: parent
              radius: Style.space(4)
              color: rowMouse.containsMouse ? Qt.alpha(root.fg, 0.06) : "transparent"
            }
            MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.openEditModal(modelData) }

            // status glyph
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

            // name + status/size/localdir line
            Column {
              id: metaCol
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
                  var meta = Lib.statusMeta(modelData.status)
                  var bits = [root.lang === "zh" ? meta.zh : meta.en]
                  if (modelData.size) bits.push(Lib.fmtSize(modelData.size))
                  var when = modelData.lastUploadTime || modelData.lastChangeTime
                  var ago = Lib.fmtTime(when, root.lang)
                  if (ago !== "") bits.push(ago)
                  if (modelData.localPath) bits.push(modelData.localPath)
                  return bits.join("  ·  ")
                }
                color: root.dim
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            // per-file actions (hover) — primary sync + edit
            Row {
              id: actions
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)
              visible: rowMouse.containsMouse

              Button {
                text: {
                  if (modelData.status === "matched") return root.t("actPull")
                  if (modelData.status === "download" || modelData.status === "missing") return root.t("actDownload")
                  if (modelData.status === "conflict") return root.t("forcedUp")
                  return root.t("actUpload")
                }
                fontFamily: root.fontFam
                fontSize: Style.font.caption
                foreground: (modelData.status === "conflict" || modelData.status === "missing") ? root.warn : root.fg
                onClicked: {
                  var st = (modelData.status === "download" || modelData.status === "missing") ? "force_download"
                          : (modelData.status === "matched") ? "force_download"
                          : "force_upload"
                  if (root.widget) root.widget.syncSingle(modelData.id, st, function (payload, text) {
                    if (payload && payload.status === "失败" && payload.error) root.toastMsg(payload.error)
                    if (payload && payload.reason) root.toastMsg(payload.reason)
                  })
                }
              }
              Button {
                iconText: "\u270E"
                tooltipText: root.t("edit")
                fontFamily: root.fontFam
                fontSize: Style.font.caption
                onClicked: root.openEditModal(modelData)
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

      // ---- Add-file modal -------------------------------------------------------
      Rectangle {
        id: addModal
        anchors.fill: parent
        visible: false
        color: Qt.alpha(Color.background, 0.45)
        z: 10

        MouseArea { anchors.fill: parent; onClicked: addModal.visible = false }

        Rectangle {
          id: addCard
          width: parent.width - Style.space(56)
          anchors.centerIn: parent
          color: Color.popups.background
          radius: Style.space(6)
          z: 1
          height: Math.min(addCol.implicitHeight + Style.space(24), parent.height - Style.space(32))
          Column {
            id: addCol
            anchors.margins: Style.space(12)
            width: parent.width - Style.space(24)
            spacing: Style.space(8)
            Text { text: root.t("addTitle"); font.family: root.fontFam; font.pixelSize: Style.font.body; color: root.fg }
            Text { text: root.t("addBody"); font.family: root.fontFam; font.pixelSize: Style.font.caption; color: root.dim; wrapMode: Text.WordWrap }
            TextField {
              id: addPath
              width: parent.width
              placeholderText: root.t("addPathPh")
              onAccepted: root.doAdd()
            }
            TextField {
              id: addNote
              width: parent.width
              placeholderText: root.t("addNotePh")
              onAccepted: root.doAdd()
            }
            Text {
              id: addErr
              visible: false
              text: ""
              color: root.warn
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Row {
              spacing: Style.space(6)
              Button { text: root.t("cancel"); fontFamily: root.fontFam; bordered: true; onClicked: addModal.visible = false }
              Button { text: root.t("addOk"); fontFamily: root.fontFam; onClicked: root.doAdd() }
            }
          }
        }
      }

      // ---- Storage settings modal --------------------------------------------------------------
      Rectangle {
        id: storageModal
        anchors.fill: parent
        visible: false
        color: Qt.alpha(Color.background, 0.45)
        z: 10

        MouseArea { anchors.fill: parent; onClicked: storageModal.visible = false }

        Rectangle {
          id: storageCard
          width: parent.width - Style.space(56)
          anchors.centerIn: parent
          color: Color.popups.background
          radius: Style.space(6)
          z: 1
          height: Math.min(storageCol.implicitHeight + Style.space(24), parent.height - Style.space(32))
          Column {
            id: storageCol
            anchors.margins: Style.space(12)
            width: parent.width - Style.space(24)
            spacing: Style.space(5)

            Text { text: root.t("storageTitle"); font.family: root.fontFam; font.pixelSize: Style.font.body; color: root.fg }
            Text { text: root.t("storageBody"); font.family: root.fontFam; font.pixelSize: Style.font.caption; color: root.dim; wrapMode: Text.WordWrap }
            Text { text: root.t("endpoint"); font.family: root.fontFam; font.pixelSize: Style.font.caption; color: root.dim }
            TextField { id: sfEndpoint; width: parent.width; placeholderText: root.t("endpointPh") }
            Text { text: root.t("username"); font.family: root.fontFam; font.pixelSize: Style.font.caption; color: root.dim }
            TextField { id: sfUsername; width: parent.width }
            Text { text: root.t("password"); font.family: root.fontFam; font.pixelSize: Style.font.caption; color: root.dim }
            TextField { id: sfPassword; width: parent.width; password: true }
            Text { text: root.t("basePath"); font.family: root.fontFam; font.pixelSize: Style.font.caption; color: root.dim }
            TextField { id: sfBase; width: parent.width; placeholderText: root.t("basePathPh") }
            Text {
              id: sfError
              visible: false
              text: ""
              color: root.warn
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Row {
              spacing: Style.space(6)
              Button { text: root.t("test"); fontFamily: root.fontFam; bordered: true; onClicked: root.doTestSettings() }
              Button { text: root.t("save"); fontFamily: root.fontFam; onClicked: root.doSaveSettings() }
              Toggle {
                id: sfAuto
                checked: root.settings !== null ? root.settings.autoSync === true : false

                label: root.t("autoSync")
                fontFamily: root.fontFam
              }
            }
          }
        }
      }

      // ---- Dir modal ---------------------------------------------------------------------------
      Rectangle {
        id: dirModal
        anchors.fill: parent
        visible: false
        color: Qt.alpha(Color.background, 0.45)
        z: 10

        MouseArea { anchors.fill: parent; onClicked: dirModal.visible = false }

        Rectangle {
          id: dirCard
          width: parent.width - Style.space(56)
          anchors.centerIn: parent
          color: Color.popups.background
          radius: Style.space(6)
          z: 1
          height: Math.min(dirCol.implicitHeight + Style.space(24), parent.height - Style.space(32))
          Column {
            id: dirCol
            anchors.margins: Style.space(12)
            width: parent.width - Style.space(24)
            spacing: Style.space(6)

            Text { text: root.t("dirTitle"); font.family: root.fontFam; font.pixelSize: Style.font.body; color: root.fg }
            Text {
              text: (root.dirTarget ? root.dirTarget.fileName : "") + " — " + root.t("dirBody")
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              color: root.dim
              wrapMode: Text.WordWrap
            }
            TextField {
              id: dirInput
              width: parent.width
              placeholderText: root.t("dirInput")
              onAccepted: root.doSetDir()
            }
            Text {
              id: dirError
              visible: false
              text: ""
              color: root.warn
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Row {
              spacing: Style.space(6)
              Button { text: root.t("cancel"); fontFamily: root.fontFam; bordered: true; onClicked: dirModal.visible = false }
              Button { text: root.t("unbind"); fontFamily: root.fontFam; bordered: true; foreground: root.warn; onClicked: root.doUnbind() }
              Button { text: root.t("apply"); fontFamily: root.fontFam; onClicked: root.doSetDir() }
            }
          }
        }
      }

      // ---- Note modal --------------------------------------------------------------------------
      Rectangle {
        id: noteModal
        anchors.fill: parent
        visible: false
        color: Qt.alpha(Color.background, 0.45)
        z: 10

        MouseArea { anchors.fill: parent; onClicked: noteModal.visible = false }

        Rectangle {
          id: noteCard
          width: parent.width - Style.space(56)
          anchors.centerIn: parent
          color: Color.popups.background
          radius: Style.space(6)
          z: 1
          height: Math.min(noteCol.implicitHeight + Style.space(24), parent.height - Style.space(32))
          Column {
            id: noteCol
            anchors.margins: Style.space(12)
            width: parent.width - Style.space(24)
            spacing: Style.space(6)

            Text { text: root.t("noteTitle"); font.family: root.fontFam; font.pixelSize: Style.font.body; color: root.fg }
            TextField {
              id: noteInput
              width: parent.width
              placeholderText: root.t("notePh")
              onAccepted: root.doNote()
            }
            Text {
              id: noteErr
              visible: false
              text: ""
              color: root.warn
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Row {
              spacing: Style.space(6)
              Button { text: root.t("cancel"); fontFamily: root.fontFam; bordered: true; onClicked: noteModal.visible = false }
              Button { text: root.t("save"); fontFamily: root.fontFam; onClicked: root.doNote() }
            }
          }
        }
      }

      // ---- Edit-file modal (dir / note / copy / delete) ----------------------------------------
      Rectangle {
        id: editModal
        anchors.fill: parent
        visible: false
        color: Qt.alpha(Color.background, 0.45)
        z: 10

        MouseArea { anchors.fill: parent; onClicked: editModal.visible = false }

        Rectangle {
          id: editCard
          width: parent.width - Style.space(56)
          anchors.centerIn: parent
          color: Color.popups.background
          radius: Style.space(6)
          z: 1
          height: Math.min(editCol.implicitHeight + Style.space(24), parent.height - Style.space(32))
          Column {
            id: editCol
            anchors.margins: Style.space(12)
            width: parent.width - Style.space(24)
            spacing: Style.space(6)

            Text {
              width: parent.width
              text: root.editTarget ? root.editTarget.fileName : ""
              color: root.fg
              font.family: root.fontFam
              font.pixelSize: Style.font.body
              elide: Text.ElideMiddle
            }
            Text {
              width: parent.width
              text: {
                var it = root.editTarget
                if (!it) return ""
                var meta = Lib.statusMeta(it.status)
                var bits = [root.lang === "zh" ? meta.zh : meta.en]
                if (it.size) bits.push(Lib.fmtSize(it.size))
                var when = it.lastUploadTime || it.lastChangeTime
                var ago = Lib.fmtTime(when, root.lang)
                if (ago !== "") bits.push(ago)
                return bits.join("  ·  ")
              }
              color: root.dim
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Text { text: root.t("dirTitle"); color: root.dim; font.family: root.fontFam; font.pixelSize: Style.font.caption }
            TextField {
              id: editDirInput
              width: parent.width
              placeholderText: root.t("dirInput")
              onAccepted: root.doEditDir()
            }
            Row {
              spacing: Style.space(6)
              Button { text: root.t("apply"); fontFamily: root.fontFam; onClicked: root.doEditDir() }
              Button { text: root.t("unbind"); fontFamily: root.fontFam; bordered: true; foreground: root.warn; onClicked: root.doEditUnbind() }
            }

            Text { text: root.t("actNote"); color: root.dim; font.family: root.fontFam; font.pixelSize: Style.font.caption }
            TextField {
              id: editNoteInput
              width: parent.width
              placeholderText: root.t("notePh")
              onAccepted: root.doEditNote()
            }
            Button { text: root.t("save"); fontFamily: root.fontFam; onClicked: root.doEditNote() }

            Text {
              id: editErr
              visible: false
              text: ""
              color: root.warn
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Row {
              spacing: Style.space(6)
              Button { text: root.t("actCopy"); fontFamily: root.fontFam; bordered: true; onClicked: { if (root.editTarget) root.copyOut(root.editTarget.localPath || root.editTarget.fileName) } }
              Button { text: root.t("actDel"); fontFamily: root.fontFam; foreground: root.warn; onClicked: { editModal.visible = false; root.openDeleteConfirm(root.editTarget) } }
              Button { text: root.t("close"); fontFamily: root.fontFam; bordered: true; onClicked: editModal.visible = false }
            }
          }
        }
      }

      // ---- Toast bar (short-lived feedback) ------------------------------------------------------
      Rectangle {
        id: toastBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(16)
        width: parent.width - Style.space(80)
        height: Style.space(26)
        visible: false
        radius: Style.space(4)
        color: Qt.alpha(Color.background, 0.85)
        z: 20
        Text {
          anchors.centerIn: parent
          text: toastText.text
          color: root.fg
          font.family: root.fontFam
          font.pixelSize: Style.font.caption
        }
      }
      Text { id: toastText; visible: false; text: "" }
      Timer { id: toastTimer; interval: 2200; onTriggered: toastBar.visible = false }
    }
  }
}
}
