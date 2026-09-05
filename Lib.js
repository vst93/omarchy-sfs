.pragma library

// SFS Sync plugin — shared helpers: status metadata, formatting, shell glue.
// Pure JS so both the bar widget and the panel can use it without creating
// extra Qt objects.

// ---- Shell glue -------------------------------------------------------------

// Single-quote for /bin/sh. Keeps user-configured paths (sfsPath) from
// breaking the command line — or from executing anything.
function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
}

// Build the /bin/sh script that finds the sfs binary wherever it lives.
// Order: explicit sfsPath setting → "sfs" on $PATH → known install
// directories → every directory on $PATH → bounded $HOME search (pruned, so
// it stays fast). Prints the first absolute path found, exit 1 otherwise.
// Never executes the binary — only stat() calls.
function locateScript(sfsBin, home) {
    var q = shellQuote
    var s = ""

    // 1) The user's setting: bare name resolves via $PATH, any path with a
    //    slash is tested directly. Missing/stale values fall through.
    if (sfsBin !== "") {
        s += "case " + q(sfsBin) + " in */*) [ -x " + q(sfsBin) + " ] && { echo " + q(sfsBin) + "; exit 0; } ;; "
        s += "*) p=$(command -v " + q(sfsBin) + " 2>/dev/null) && [ -n \"$p\" ] && { echo \"$p\"; exit 0; } ;; esac; "
    }

    // 2) Plain "sfs" on whatever PATH this shell sees.
    s += "p=$(command -v sfs 2>/dev/null) && [ -n \"$p\" ] && { echo \"$p\"; exit 0; }; "

    // 3) Known install locations (package managers, no-sudo script, brew,
    //    Termux — mirrors sfs install.sh's own choices).
    var dirs = [
        home + "/.local/bin",
        home + "/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/opt/sfs/bin",
        "/snap/bin",
        "/home/linuxbrew/.linuxbrew/bin",
        home + "/.linuxbrew/bin",
        "/opt/homebrew/bin",
        "/data/data/com.termux/files/usr/bin"
    ]
    s += "for d in " + dirs.map(q).join(" ") + "; do [ -x \"$d/sfs\" ] && { echo \"$d/sfs\"; exit 0; }; done; "

    // 4) Every directory already on PATH (covers distro-specific bin dirs).
    s += "oIFS=$IFS; IFS=:; for d in $PATH; do IFS=$oIFS; [ -n \"$d\" ] && [ -x \"$d/sfs\" ] && { echo \"$d/sfs\"; exit 0; }; done; IFS=$oIFS; "

    // 5) Last resort: bounded depth-3 search of $HOME, pruning directories
    //    that are big and never hold a binary. Metadata-only walk.
    s += "find " + q(home) + " -maxdepth 3 -xdev "
    s += "\\( -type d \\( -name .cache -o -name node_modules -o -name .git -o -name .npm -o -name vendor -o -name dist -o -name build \\) -prune \\) -o "
    s += "-type f -name sfs -perm -u+x -print 2>/dev/null | head -n 1; "

    s += "exit 1"
    return s
}

// Probe a list of ports for an already-listening SFS server. Prints
// "reuse <port>" for the first port that answers /api/info, "spawn" otherwise.
// Only stdout is parsed; curl noise goes to stderr and is discarded.
function probeScript(ports) {
    var script = ""
    for (var i = 0; i < ports.length; i++) {
        var p = ports[i]
        if (!(p > 0)) continue
        script += "if curl -sS -m 1 -o /dev/null " + shellQuote("http://127.0.0.1:" + p + "/api/info") + " 2>/dev/null; then echo reuse " + p + "; exit 0; fi; "
    }
    script += "echo spawn"
    return script
}

// `sfs web <port>` prints "SFS Web mode started at http://localhost:NNNNN".
// The requested port can be busy, in which case SFS re-binds to a random one
// and reports it here — always trust the printed port over the requested one.
function portFromLine(line) {
    var m = String(line || "").match(/localhost:(\d+)/)
    return m ? parseInt(m[1], 10) : 0
}

// ---- Status metadata -------------------------------------------------------
// One entry per status key the SFS API emits (web server `buildFileListItem`
// and the TUI's `computeFileStateUncached`). `tone` selects a theme color role
// at the call site — never a hardcoded hex, so every Omarchy theme works.
var STATUS = {
    "matched":         { icon: "\u2714", tone: "accent",  en: "Synced",        zh: "已同步" },
    "pending_upload":  { icon: "\u2191", tone: "warning", en: "Upload ready",  zh: "待上传" },
    "initial_upload":  { icon: "\u2191", tone: "warning", en: "First upload",  zh: "首次上传" },
    "download":        { icon: "\u2193", tone: "info",    en: "Download ready", zh: "待下载" },
    "conflict":        { icon: "\u0021", tone: "urgent",  en: "Conflict",      zh: "冲突" },
    "missing":         { icon: "\u2717", tone: "urgent",  en: "Missing",       zh: "本地缺失" },
    "unbound":         { icon: "\u25CB", tone: "muted",   en: "Unbound",       zh: "未绑定" },
    "pending_binding": { icon: "\u25CB", tone: "muted",   en: "Pending",       zh: "待绑定" }
}

function statusMeta(key) {
    return STATUS[key] || { icon: "\u00B7", tone: "muted", en: key, zh: key }
}

// The API's status *detail* strings are authored in Chinese. We never try to
// translate them — the panel shows its own localized one-liner per status
// instead, and the raw detail only in Chinese mode (where it is correct).
function statusDetail(meta, lang) {
    return lang === "zh" ? meta.zh : meta.en
}

// ---- Sync result translation ----------------------------------------------
// /api/sync returns Action/Status authored in Chinese ("上传"/"下载"/"跳过",
// "成功"/"失败"). Translate the closed set, pass anything else through.
var ACTION = { "\u4E0A\u4F20": "up", "\u4E0B\u8F7D": "down", "\u8DF3\u8FC7": "skip", "\u672A\u5904\u7406": "none" }
var VERDICT = { "\u6210\u529F": "ok", "\u5931\u8D25": "fail" }

function actionKind(action) { return ACTION[action] || "other" }
function verdictKind(status) { return VERDICT[status] || status }

// ---- Formatting ------------------------------------------------------------
function fmtSize(kb) {
    var v = Number(kb) || 0
    if (v >= 1024 * 1024) return (v / (1024 * 1024)).toFixed(1) + " GB"
    if (v >= 1024) return (v / 1024).toFixed(1) + " MB"
    if (v <= 0) return "0 KB"
    return Math.round(v) + " KB"
}

function fmtTime(ms, lang) {
    if (!ms) return ""
    var d = new Date(ms)
    function pad(n) { return (n < 10 ? "0" : "") + n }
    var hm = pad(d.getHours()) + ":" + pad(d.getMinutes())
    if (lang === "zh") return (d.getMonth() + 1) + "\u6708" + d.getDate() + "\u65E5 " + hm
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return months[d.getMonth()] + " " + d.getDate() + " " + hm
}

function hostOf(url) {
    var m = String(url || "").match(/^https?:\/\/([^\/]+)/)
    return m ? m[1] : url
}
