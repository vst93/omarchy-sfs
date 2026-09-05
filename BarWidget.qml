import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Lib.js" as Lib

// SFS Sync — bar entry point.
//
// Bar label: "⇄ synced/total" while connected, "⇄ ···" while locating or
// starting the backend, "⇄ ×" only when sfs truly cannot be found. Urgent
// color when any file is conflicting or missing. Left click opens the control
// panel, middle click opens the SFS web UI, right click forces a refresh.
//
// Backend lifecycle: locate → probe → spawn → connect. "Locate" tries the
// configured sfsPath, then $PATH, then the usual no-sudo install locations
// (~/.local/bin, homebrew paths) — the shell process's PATH is often minimal,
// so the probe must not depend on it. "Probe" checks every known location for
// an already-listening server before spawning a fresh one, so a server the
// user started themselves (any port) is reused instead of duplicated.
BarWidget {
  id: root
  moduleName: "io.github.vst93.sfs"

  // ---- Settings (shell.json → [io.github.vst93.sfs]) -----------------------
  property int reqPort: setting("port", 8791)
  property int pollSec: setting("pollSeconds", 30)
  property string sfsBin: setting("sfsPath", "sfs")
  property string lang: setting("lang", "en") // "en" | "zh" — default English

  // ---- State ----------------------------------------------------------------
  // phase: "locating" → "starting" → "connected"; "notFound" only after every
  // candidate path has been exhausted; "backendLost" while re-spawning.
  property string phase: "locating"
  property var model: null        // parsed /api/files payload
  property var lastSync: null     // parsed /api/sync payload
  property bool syncing: false
  property bool netBusy: false
  property string endpoint: ""    // "http://127.0.0.1:<port>"
  property string resolvedBin: "" // absolute path the backend was launched with
  property int apiFails: 0        // consecutive HTTP failures (transient!)
  property int spawnFails: 0      // consecutive spawn crashes
  property var pendingPorts: []   // ports queued for the existing-server probe

  readonly property bool ready: phase === "connected" && model !== null
  readonly property bool notFound: phase === "notFound"
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

  // ---- Candidate binaries (in probe order) -----------------------------------
  // $HOME must be resolved at runtime — QML has no tilde expansion.
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property var binCandidates: {
    var list = []
    var add = function(p) { if (p !== "" && list.indexOf(p) < 0) list.push(p) }
    if (sfsBin.indexOf("/") >= 0) add(sfsBin)                       // explicit path, absolute or ~/
    else add(sfsBin)                                                // bare name — try $PATH first
    add(home + "/.local/bin/sfs")                                   // no-sudo script install
    add("/home/linuxbrew/.linuxbrew/bin/sfs")                       // homebrew (Linux)
    add(home + "/.linuxbrew/bin/sfs")                               // homebrew (macOS, homedir)
    add("/usr/local/bin/sfs")
    add("/opt/homebrew/bin/sfs")                                    // homebrew (macOS, arm)
    return list
  }

  // Ports to check for an already-running server: the configured one, plus
  // whatever previous plugin sessions recorded (survives shell restarts).
  readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
  readonly property string stateFile: stateDir + "/omarchy-sfs/endpoint.json"

  // ---- i18n -----------------------------------------------------------------
  readonly property var tr: ({
    "en": {
      tooltipReady: "SFS Sync — click for details, right-click to refresh",
      tooltipOff: "SFS starting — click for details",
      tooltipMissing: "SFS not found — click for details"
    },
    "zh": {
      tooltipReady: "SFS 同步 — 点击查看详情，右键刷新",
      tooltipOff: "SFS 启动中 — 点击查看详情",
      tooltipMissing: "未找到 SFS — 点击查看详情"
    }
  })
  function t(key) { return tr[lang] && tr[lang][key] ? tr[lang][key] : tr["en"][key] }

  // ---- Lifecycle --------------------------------------------------------------
  Component.onCompleted: locate()

  // Step 1: find the binary. Tries each candidate with `test -x` (absolute
  // paths) or `command -v` (bare names) in one shell call; first hit wins.
  function locate() {
    phase = "locating"
    var probe = ""
    for (var i = 0; i < binCandidates.length; i++) {
      var p = binCandidates[i]
      if (p.indexOf("/") >= 0)
        probe += "if [ -x " + Lib.shellQuote(p) + " ]; then echo " + Lib.shellQuote(p) + "; exit 0; fi; "
      else
        probe += "p=$(command -v " + Lib.shellQuote(p) + " 2>/dev/null) && [ -n \"$p\" ] && echo \"$p\" && exit 0; "
    }
    probe += "exit 1"
    locateProc.command = ["/bin/sh", "-c", probe]
    locateProc.running = true
  }

  // Step 2: with a binary in hand, load the recorded port from the last
  // session, then look for an already-listening server. The state read is
  // async, so the port probe starts from its onExited — never inline.
  function probeExisting(binPath) {
    resolvedBin = binPath
    pendingPorts = [reqPort]
    stateOut = ""
    readStateProc.running = true
  }

  function probePorts() {
    probeProc.command = ["/bin/sh", "-c", Lib.probeScript(pendingPorts)]
    probeProc.running = true
  }

  // Step 3: no server anywhere — spawn one on the configured port.
  function spawn(binPath) {
    phase = "starting"
    webProc.command = ["/bin/sh", "-c",
      "env -u DISPLAY -u WAYLAND_DISPLAY exec " + Lib.shellQuote(binPath) + " web " + reqPort]
    webProc.running = true
  }

  function connectTo(port) {
    endpoint = "http://127.0.0.1:" + port
    phase = "connected"
    saveState(port)
    refresh()
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

  // Full teardown + fresh locate. Used by the panel's retry button and the
  // right-click refresh when the backend is gone.
  function relocate() {
    endpoint = ""
    model = null
    apiFails = 0
    spawnFails = 0
    locate()
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
          root.apiFails = 0
          root.model = payload
        } else {
          // Transient HTTP trouble — never conflate with "binary missing".
          // Several failures in a row mean the server died; go re-locate.
          root.apiFails++
          if (root.apiFails >= 3) root.relocate()
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

  // Step 1 output: first candidate that exists and is executable.
  property string locateOut: ""
  Process {
    id: locateProc
    stdout: SplitParser {
      onRead: function(data) { if (root.locateOut === "") root.locateOut = data.trim() }
    }
    onExited: function(exitCode) {
      var bin = root.locateOut
      root.locateOut = ""
      if (bin !== "") {
        root.probeExisting(bin)
      } else {
        root.phase = "notFound"
      }
    }
  }

  // Step 2 output: "reuse <port>" when a server answers on a probed port.
  property string probeOut: ""
  Process {
    id: probeProc
    stdout: SplitParser {
      onRead: function(data) { if (root.probeOut === "") root.probeOut = data.trim() }
    }
    onExited: function(exitCode) {
      var line = root.probeOut
      root.probeOut = ""
      var m = line.match(/reuse (\d+)/)
      if (m) {
        root.connectTo(parseInt(m[1], 10))
      } else {
        root.spawn(root.resolvedBin)
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
      if (root.endpoint === "") {
        // Died before ever printing a port (bad binary? immediate crash?).
        root.spawnFails++
        if (root.spawnFails >= 2) { root.phase = "notFound"; return }
      }
      // Backend died while connected (crash or user kill) — clean up and
      // re-locate; the heartbeat below drives recovery.
      root.endpoint = ""
      root.model = null
      root.phase = "locating"
      root.locate()
    }
  }

  // ---- Polling ---------------------------------------------------------------
  Timer {
    interval: Math.max(10, root.pollSec) * 1000
    running: root.phase === "connected"
    repeat: true
    onTriggered: root.refresh()
  }
  Timer {
    // slow heartbeat while not connected so the widget recovers on its own
    // (e.g. user installs sfs after the shell started)
    interval: 60000
    running: root.phase !== "connected"
    repeat: true
    onTriggered: root.locate()
  }

  // ---- Endpoint state persistence (survives shell restarts) ------------------
  function saveState(port) {
    writeProc.command = ["/bin/sh", "-c",
      "mkdir -p " + Lib.shellQuote(root.stateDir + "/omarchy-sfs") + " && printf '%s\\n' " +
      Lib.shellQuote(JSON.stringify({ port: port, bin: root.resolvedBin, ts: Date.now() })) +
      " > " + Lib.shellQuote(root.stateFile)]
    writeProc.running = true
  }
  property string stateOut: ""
  Process {
    id: writeProc
  }
  Process {
    id: readStateProc
    stdout: SplitParser {
      onRead: function(data) { if (root.stateOut === "") root.stateOut = data.trim() }
    }
    onExited: function(exitCode) {
      var line = root.stateOut
      root.stateOut = ""
      try {
        var st = JSON.parse(line)
        if (st && st.port > 0 && root.pendingPorts.indexOf(st.port) < 0)
          root.pendingPorts.push(st.port)
      } catch (e) { }
      root.probePorts()   // state read done — now probe the queued ports
    }
  }

  // ---- IPC (omarchy-shell shell summon/hide/toggle) --------------------------
  IpcHandler {
    target: "io.github.vst93.sfs"
    function refresh(): void { root.relocate() }
    function sync(): void { root.syncAll() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  // ---- Panel wiring (bar-widget contract) ------------------------------------
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    root.locateIfIdle()
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
  // Re-run locate only when nothing else is in flight — cheap enough to call
  // on every panel open, catches a freshly-installed sfs without waiting for
  // the heartbeat.
  function locateIfIdle() {
    if (phase === "connected" || phase === "locating" || phase === "starting") return
    locate()
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
    labelVisible: false
    hasVisualContent: true
    iconComponent: Component {
      Item {
        SfsIcon {
          anchors.centerIn: parent
          iconSize: Style.space(13)
          color: {
            if (root.ready && root.hasUrgent) return Color.urgent
            if (!root.ready) return Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.5)
            return root.bar ? root.bar.barForeground : Color.foreground
          }
        }
      }
    }
    tooltipText: root.ready ? root.t("tooltipReady")
                : root.notFound ? root.t("tooltipMissing")
                : root.t("tooltipOff")
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
      else if (b === Qt.MiddleButton) root.openWebUI()
      else if (b === Qt.RightButton) root.relocate()
    }
  }
}
