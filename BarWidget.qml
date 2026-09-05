import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Lib.js" as Lib

// SFS Sync — bar entry point.
//
// Bar label: "⇄ synced/total" while connected, "⇄ ···" while starting or
// offline. Urgent color when any file is conflicting or missing. Left click
// opens the control panel, middle click opens the SFS web UI, right click
// forces a refresh.
//
// Backend: this widget owns the `sfs web <port>` child process. DISPLAY and
// WAYLAND_DISPLAY are cleared for the child so SFS's automatic `openBrowser`
// (xdg-open) fails silently instead of popping a browser window on every
// shell start. If a server from a previous shell session is still listening
// on the configured port, it is reused and nothing is spawned.
BarWidget {
  id: root
  moduleName: "io.github.vst93.sfs"

  // ---- Settings (shell.json → [io.github.vst93.sfs]) -----------------------
  property int reqPort: setting("port", 8791)
  property int pollSec: setting("pollSeconds", 30)
  property string sfsBin: setting("sfsPath", "sfs")
  property string lang: setting("lang", "en") // "en" | "zh" — default English

  // ---- State ----------------------------------------------------------------
  property var model: null        // parsed /api/files payload
  property var lastSync: null     // parsed /api/sync payload
  property bool syncing: false
  property bool netBusy: false
  property bool starting: false
  property string endpoint: ""    // "http://127.0.0.1:<port>"
  property int retry: 0

  readonly property bool ready: model !== null
  readonly property int total: ready ? (model.summary.total || 0) : 0
  readonly property int matched: ready ? (model.summary.matched || 0) : 0
  readonly property int attention: ready ? (model.summary.pending || 0) : 0
  readonly property bool hasUrgent: {
    if (!ready) return false
    var files = model.files || []
    for (var i = 0; i < files.length; i++) {
      var s = files[i].status || ""
      if (s === "conflict" || s === "missing") return true
    }
    return false
  }

  // ---- i18n -----------------------------------------------------------------
  readonly property var tr: ({
    "en": {
      tooltipReady: "SFS Sync — click for details, right-click to refresh",
      tooltipOff: "SFS offline — click to retry",
      starting: "Starting…"
    },
    "zh": {
      tooltipReady: "SFS 同步 — 点击查看详情，右键刷新",
      tooltipOff: "SFS 未运行 — 点击重试",
      starting: "启动中…"
    }
  })
  function t(key) { return tr[lang] && tr[lang][key] ? tr[lang][key] : tr["en"][key] }

  // ---- Backend lifecycle ----------------------------------------------------
  function ensureBackend() {
    if (endpoint !== "" || starting) return
    starting = true
    checkProc.command = ["sh", "-c", "command -v " + root.sfsBin + " >/dev/null 2>&1 && echo ok"]
    checkProc.running = true
  }

  function connectTo(port) {
    endpoint = "http://127.0.0.1:" + port
    starting = false
    root.refresh()
  }

  function refresh() {
    if (endpoint === "" || netBusy) return
    netBusy = true
    api.run("GET", "/api/files", "")
  }

  function syncAll() {
    if (endpoint === "" || netBusy || syncing) return
    syncing = true
    netBusy = true
    api.run("POST", "/api/sync", JSON.stringify({ syncType: "", isAuto: false }))
  }

  function syncSingle(id, syncType) {
    if (endpoint === "" || netBusy) return
    netBusy = true
    api.run("POST", "/api/sync/single", JSON.stringify({ id: id, syncType: syncType }))
  }

  function openWebUI() {
    if (endpoint !== "" && root.bar) root.bar.run("xdg-open " + root.endpoint)
  }

  function resetConnection() {
    endpoint = ""
    model = null
    starting = false
  }

  function persistSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setLang(l) {
    if (l !== "en" && l !== "zh") return
    persistSetting("lang", l)
  }

  // ---- HTTP client (curl; the shell sandbox has no QML XHR) ------------------
  property string apiOut: ""
  Process {
    id: api
    property string path: ""
    function run(method, p, body) {
      path = p
      var args = ["curl", "-sS", "-m", "120"]
      if (method === "POST") args.push("-X", "POST", "-H", "Content-Type: application/json", "-d", body)
      args.push(root.endpoint + p)
      command = args
      running = true
    }
    stdout: SplitParser {
      onRead: function(data) { root.apiOut += data + "\n" }
    }
    onExited: function(exitCode) {
      var text = root.apiOut
      var path = api.path
      api.path = ""
      root.apiOut = ""
      root.netBusy = false
      if (path === "/api/files") {
        var payload = null
        try { payload = JSON.parse(text) } catch (e) { payload = null }
        if (payload && payload.files) {
          root.retry = 0
          root.model = payload
        } else {
          root.retry++
          if (root.retry >= 3) root.resetConnection()
        }
      } else if (path === "/api/sync") {
        root.syncing = false
        var res = null
        try { res = JSON.parse(text) } catch (e) { res = null }
        if (res && res.summary) root.lastSync = res
        root.refresh()
      } else if (path === "/api/sync/single") {
        root.refresh()
      }
    }
  }

  // sfs presence check — only spawn when the binary actually exists.
  property string checkOut: ""
  Process {
    id: checkProc
    stdout: SplitParser {
      onRead: function(data) { root.checkOut += data }
    }
    onExited: function(exitCode) {
      var found = root.checkOut.indexOf("ok") >= 0
      root.checkOut = ""
      root.starting = false
      if (!found) return
      portProc.command = ["sh", "-c",
        "curl -sS -m 2 -o /dev/null http://127.0.0.1:" + root.reqPort + "/api/info 2>/dev/null && echo reuse || echo spawn"]
      portProc.running = true
    }
  }

  // Reuse an already-listening server, otherwise spawn a fresh one.
  property string portOut: ""
  Process {
    id: portProc
    stdout: SplitParser {
      onRead: function(data) { root.portOut += data }
    }
    onExited: function(exitCode) {
      var verdict = root.portOut
      root.portOut = ""
      if (verdict.indexOf("reuse") >= 0) {
        root.connectTo(root.reqPort)
      } else {
        webProc.running = false
        webProc.command = ["/bin/sh", "-c",
          "env -u DISPLAY -u WAYLAND_DISPLAY exec " + root.sfsBin + " web " + root.reqPort]
        webProc.running = true
      }
    }
  }

  // `sfs web` child. stdout carries the *actual* port (SFS falls back to a
  // random one when the requested port is taken — trust the printed port).
  // Runs for the shell's lifetime; when the shell dies the child does too.
  property string webOut: ""
  Process {
    id: webProc
    stdout: SplitParser {
      onRead: function(data) {
        root.webOut += data
        var port = Lib.portFromLine(data)
        if (port > 0 && root.endpoint === "") root.connectTo(port)
      }
    }
    onExited: function(exitCode) {
      root.webOut = ""
      // Backend died (crash or user kill). Retry a few times, then idle until
      // the slow heartbeat below picks it back up.
      root.endpoint = ""
      root.model = null
      root.retry++
      if (root.retry < 3) root.ensureBackend()
    }
  }

  // ---- Polling ---------------------------------------------------------------
  Timer {
    interval: Math.max(10, root.pollSec) * 1000
    running: root.ready
    repeat: true
    onTriggered: root.refresh()
  }
  Timer {
    // slow heartbeat while offline so the widget recovers on its own
    interval: 60000
    running: root.endpoint === ""
    repeat: true
    onTriggered: { root.retry = 0; root.ensureBackend() }
  }

  // ---- IPC (omarchy-shell shell summon/hide/toggle) --------------------------
  IpcHandler {
    target: "io.github.vst93.sfs"
    function refresh(): void { root.ensureBackend(); root.refresh() }
    function sync(): void { root.syncAll() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  // ---- Panel wiring (bar-widget contract) ------------------------------------
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    root.ensureBackend()
    if (panelLoader.item) panelLoader.item.open()
  }
  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }
  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.ready ? "\u21C4 " + root.matched + "/" + root.total : "\u21C4 \u00B7\u00B7\u00B7"
    tooltipText: root.ready || root.starting ? root.t("tooltipReady") : root.t("tooltipOff")
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
      else if (b === Qt.MiddleButton) root.openWebUI()
      else if (b === Qt.RightButton) { root.ensureBackend(); root.refresh() }
    }
    foreground: {
      if (!root.ready) return Color.muted
      if (root.hasUrgent) return Color.urgent
      return root.bar ? root.bar.barForeground : Color.foreground
    }
  }

  Component.onCompleted: root.ensureBackend()
}
