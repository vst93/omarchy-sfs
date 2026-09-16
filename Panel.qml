import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Ui
import "Lib.js" as Lib

// SFS Sync — control panel.
//
// Compact, keyboard-friendly layout. Top to bottom:
//   PanelHero     product mark, title, and a trailing pair of uniform chips
//                 (connection status + language toggle)
//   toolbar       one primary "Sync all" button + a row of icon actions
//   banner        transient state/notice text (offline, not configured, …)
//   files         a collapsible section: count + filter + selection cursor,
//                 then the scrollable file list (or its empty state)
//   footer        outcome of the most recent full sync, localized
//
// Dialogs all share ModalCard, so the chrome (scrim, title bar, close button,
// scrolling body) is defined once. Every color comes from the theme via
// Color.* / root.fg — the panel must look native under any Omarchy theme.
Panel {
    id: root
    moduleName: "io.github.vst93.sfs"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null

    readonly property var widget: hostWidget || null
    readonly property var m: widget ? widget.model : null
    readonly property bool syncing: widget ? widget.syncing : false
    readonly property var lastSync: widget ? widget.lastSync : null
    readonly property string lang: widget ? widget.lang : "en"

    readonly property color fg: root.bar ? root.bar.barForeground : Color.foreground
    readonly property color dim: Color.muted
    readonly property color warn: Color.urgent
    readonly property string fontFam: root.bar ? root.bar.fontFamily : Style.font.family

    // ---- Layout metrics ------------------------------------------------------
    readonly property int rowHeight: Style.space(48)
    readonly property int rowSpacing: Style.space(2)
    // One control height for the toolbar (the primary button and the icon
    // cluster), so their borders line up exactly. The kit Button defaults to a
    // slightly taller box than a 28px group, which left the cluster 5px short.
    readonly property int controlH: Style.space(32)

    // ---- Assisted install ----------------------------------------------------
    // installFailedShown latches on once the user returns from an install
    // attempt that did not produce a usable sfs binary; a successful
    // relocate() clears it.
    property bool installConfirmOpen: false
    property bool installFailedShown: false

    // Pinned to an immutable commit and verified against a digest committed in
    // Lib.js before anything runs — see Lib.installScript(). The dialog below
    // shows the same pin so the confirmation is bound to the reviewed code.
    readonly property string installCommit: Lib.SFS_INSTALL_COMMIT
    readonly property string installCommitShort: Lib.SFS_INSTALL_COMMIT.substring(0, 12)

    function launchInstall() {
        if (root.bar)
            root.bar.run("omarchy-launch-tui sh -c " + Lib.shellQuote(Lib.installScript(root.lang)));
        // No callback when the terminal closes — show the hint and let the
        // heartbeat or "Search again" recover.
        root.installFailedShown = true;
    }

    // ---- Settings / dialog state ---------------------------------------------
    property var storageSettings: null
    property var editTarget: null
    property var delTarget: null
    property bool actionBusy: false

    // ---- File list state -----------------------------------------------------
    property bool filterOpen: false
    property string filterText: ""
    property string statusFilter: "all"
    property bool cursorActive: false
    property int fileIndex: 0

    readonly property bool modalOpen: installConfirmOpen || delConfirm.opened || addModal.opened || storageModal.opened || editModal.opened

    readonly property bool connected: root.widget !== null && root.widget.phase === "connected"
    readonly property bool hasModel: root.m !== null
    readonly property int filesTotal: (root.m && root.m.files) ? root.m.files.length : 0
    readonly property bool configured: !(root.m && root.m.storage === false)
    readonly property var visibleFiles: root.computeVisibleFiles()
    readonly property int attentionCount: root.countAttention()
    readonly property var statusOptions: root.buildStatusOptions()

    function statusRank(s) {
        if (s === "conflict" || s === "missing")
            return 0;
        if (s === "pending_upload" || s === "initial_upload" || s === "download")
            return 1;
        if (s === "pending_binding" || s === "unbound")
            return 2;
        return 3;
    }
    // Bucket every SFS status into one of the four filter groups.
    function fileGroup(s) {
        if (s === "matched")
            return "synced";
        if (s === "unbound" || s === "pending_binding")
            return "unbound";
        if (s === "conflict" || s === "missing")
            return "attention";
        return "pending";
    }
    // "linked" = bound to a local dir (anything not unbound); "pending" = has
    // work left (needs attention or a queued sync).
    function matchesStatus(f, key) {
        if (key === "all")
            return true;
        var g = root.fileGroup(f.status || "");
        if (key === "linked")
            return g !== "unbound";
        if (key === "unbound")
            return g === "unbound";
        if (key === "pending")
            return g === "attention" || g === "pending";
        return true;
    }
    function countStatusFilter(key) {
        var files = (root.m && root.m.files) ? root.m.files : [];
        if (key === "all")
            return files.length;
        var n = 0;
        for (var i = 0; i < files.length; i++)
            if (root.matchesStatus(files[i], key))
                n++;
        return n;
    }
    function buildStatusOptions() {
        return [
            { key: "all", label: root.t("fAll"), icon: "\uf00b", count: root.countStatusFilter("all") },
            { key: "linked", label: root.t("fLinked"), icon: "\uf0c1", count: root.countStatusFilter("linked") },
            { key: "unbound", label: root.t("fUnlinked"), icon: "\uf127", count: root.countStatusFilter("unbound") },
            { key: "pending", label: root.t("fPending"), icon: "\uf017", count: root.countStatusFilter("pending") },
        ];
    }
    function currentStatusOption() {
        var opts = root.statusOptions;
        for (var i = 0; i < opts.length; i++)
            if (opts[i].key === root.statusFilter)
                return opts[i];
        return opts[0];
    }
    function selectStatus(key) {
        root.statusFilter = key;
        root.cursorActive = false;
        root.fileIndex = 0;
    }
    // Filter by status bucket + a free-text query (name / dir / path / note),
    // then float the items that need attention to the top.
    function computeVisibleFiles() {
        var all = (root.m && root.m.files) ? root.m.files.slice() : [];
        all = all.filter(function (f) {
            return root.matchesStatus(f, root.statusFilter);
        });
        var q = root.filterText.trim().toLowerCase();
        if (q !== "") {
            all = all.filter(function (f) {
                var hay = [f.fileName, f.localDir, f.localPath, f.note].filter(Boolean).join(" ").toLowerCase();
                return hay.indexOf(q) >= 0;
            });
        }
        all.sort(function (a, b) {
            return root.statusRank(a.status) - root.statusRank(b.status);
        });
        return all;
    }
    function countAttention() {
        var files = (root.m && root.m.files) ? root.m.files : [];
        var n = 0;
        for (var i = 0; i < files.length; i++) {
            var s = files[i].status || "";
            if (s === "conflict" || s === "missing")
                n++;
        }
        return n;
    }
    onVisibleFilesChanged: if (root.fileIndex >= root.visibleFiles.length)
        root.fileIndex = Math.max(0, root.visibleFiles.length - 1);

    function open() {
        if (widget)
            widget.locateIfIdle();
        root.controller.show();
    }
    function close() {
        root.closeModalLayers();
        root.controller.hide();
    }
    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction);
        return false;
    }

    // ---- i18n -----------------------------------------------------------------
    readonly property var tr: ({
            "en": {
                title: "SFS Sync",
                on: "Connected",
                off: "Offline",
                starting: "Starting…",
                notInstalled: "SFS not found",
                retrying: "Looking for SFS…",
                installTitle: "SFS is not installed yet.",
                installBody: "Install the SFS command line tool, then retry. The plugin downloads SFS's official install script from a pinned commit and verifies it before running it in a terminal.",
                installBtn: "Install SFS…",
                installConfirm: "Download SFS's install script from commit %1, verify its SHA-256, then run it in a terminal?".replace("%1", root.installCommitShort),
                installNow: "Install",
                installLater: "Not now",
                retryBtn: "Search again",
                installFailed: "Install did not finish — run the script manually and try again.",
                syncAll: "Sync all",
                syncing: "Syncing…",
                web: "Web UI",
                refresh: "Refresh",
                syncHasFailures: "Sync finished with failed items.",
                files: "Files",
                empty: "No files yet — add them in the SFS app.",
                noMatch: "No matching files.",
                notConfigured: "WebDAV not configured — open SFS to set it up.",
                lastSync: "Last sync",
                lsUp: "up",
                lsDown: "down",
                lsSkip: "skipped",
                lsFail: "failed",
                fAll: "All",
                fLinked: "Linked",
                fUnlinked: "Unlinked",
                fPending: "Pending",
                requestFailed: "Request failed — check that SFS is still running.",
                addFile: "Add file",
                storage: "Storage",
                copied: "copied to clipboard",
                actNote: "Note",
                actDel: "Delete",
                actCopy: "Copy path",
                edit: "Edit",
                filter: "Filter",
                filterPh: "Filter by name, path or note…",
                autoSyncEvery: "Auto sync · every %1s",
                autoSyncOn: "Auto-sync is on — syncing in the background",
                addTitle: "Add sync file",
                addBody: "Add a new file to sync",
                addPath: "File path",
                addPathPh: "/home/user/.config/foo.conf",
                addNote: "Note (optional)",
                addNotePh: "≤ 50 chars",
                addOk: "Add",
                cancel: "Cancel",
                requiredPath: "File path required",
                storageTitle: "Storage settings",
                storageBody: "WebDAV connection for remote sync.",
                endpoint: "WebDAV URL",
                endpointPh: "https://dav.jianguoyun.com/dav",
                username: "Username",
                password: "Password / app password",
                basePath: "Remote base dir",
                basePathPh: "blank = small-file-sync, / = root",
                test: "Test",
                save: "Save",
                testOk: "connection OK",
                testFail: "connection failed",
                saved: "Settings saved",
                requiresAuth: "URL, username and password are required",
                dirTitle: "Local directory",
                dirInput: "Local dir path",
                unbind: "Unbind",
                notePh: "Note for this file",
                delBody: "Removes the cloud copy and the sync record. The local file is kept.",
                delOk: "Delete",
                delCancel: "Cancel",
                expConfig: "Copy import command",
                expCopied: "Import command copied",
                exportNoStorage: "No WebDAV config to export",
                close: "Close",
                language: "中文",
                langTip: "Switch to English"
            },
            "zh": {
                title: "SFS 同步",
                on: "已连接",
                off: "未连接",
                starting: "启动中…",
                notInstalled: "未找到 SFS",
                retrying: "正在查找 SFS…",
                installTitle: "尚未安装 SFS。",
                installBody: "需要先安装 SFS 命令行工具。插件会从固定提交下载 SFS 官方安装脚本并校验 SHA-256，通过后才在终端中运行。",
                installBtn: "安装 SFS…",
                installConfirm: "从固定提交 %1 下载 SFS 安装脚本，校验 SHA-256 后在终端运行？".replace("%1", root.installCommitShort),
                installNow: "安装",
                installLater: "暂不",
                retryBtn: "重新查找",
                installFailed: "安装未完成 — 请手动运行安装脚本后重试。",
                syncAll: "全部同步",
                syncing: "同步中…",
                web: "网页界面",
                refresh: "刷新",
                syncHasFailures: "同步完成，但有失败项。",
                files: "文件",
                empty: "还没有文件 — 请在 SFS 应用里添加。",
                noMatch: "没有匹配的文件。",
                notConfigured: "WebDAV 未配置 — 请先打开 SFS 设置。",
                lastSync: "上次同步",
                lsUp: "上传",
                lsDown: "下载",
                lsSkip: "跳过",
                lsFail: "失败",
                fAll: "全部",
                fLinked: "已关联",
                fUnlinked: "未关联",
                fPending: "待同步",
                requestFailed: "请求失败 — 请确认 SFS 仍在运行。",
                addFile: "添加文件",
                storage: "存储设置",
                copied: "已复制到剪贴板",
                actNote: "备注",
                actDel: "删除",
                actCopy: "复制路径",
                edit: "编辑",
                filter: "筛选",
                filterPh: "按名称、路径或备注筛选…",
                autoSyncEvery: "自动同步 · 每 %1 秒",
                autoSyncOn: "已开启自动同步 — 后台定时同步",
                addTitle: "添加文件",
                addBody: "添加一个新的待同步文件",
                addPath: "文件路径",
                addPathPh: "/home/user/.config/foo.conf",
                addNote: "备注（可选）",
                addNotePh: "50 字以内",
                addOk: "添加",
                cancel: "取消",
                requiredPath: "请填写文件路径",
                storageTitle: "存储设置",
                storageBody: "配置 WebDAV 服务器以启用远程同步。",
                endpoint: "WebDAV 地址",
                endpointPh: "https://dav.jianguoyun.com/dav",
                username: "用户名",
                password: "密码 / 应用密码",
                basePath: "远端目录",
                basePathPh: "留空默认 small-file-sync，/ 表示根目录",
                test: "测试连接",
                save: "保存",
                testOk: "连接成功",
                testFail: "连接失败",
                saved: "设置已保存",
                requiresAuth: "地址、用户名、密码均为必填",
                dirTitle: "设置本地目录",
                dirInput: "目录路径",
                unbind: "解除关联",
                notePh: "此文件的备注",
                delBody: "将删除云端保存的副本与同步记录；本地文件不会删除。",
                delOk: "删除",
                delCancel: "取消",
                expConfig: "复制导入命令",
                expCopied: "导入命令已复制",
                exportNoStorage: "未配置 WebDAV，无法导出",
                close: "关闭",
                language: "English",
                langTip: "Switch to Chinese"
            }
        })
    function t(key) {
        var dict = tr[lang] || tr["en"];
        return dict[key] !== undefined ? dict[key] : tr["en"][key];
    }

    function toneColor(tone) {
        if (tone === "urgent")
            return Color.urgent;
        if (tone === "warning")
            return Qt.alpha(fg, 0.85);
        if (tone === "info")
            return Qt.alpha(fg, 0.7);
        if (tone === "accent")
            return Color.accent;
        return dim;
    }

    // ---- Hero status chip ------------------------------------------------------
    function heroStatusText() {
        var w = root.widget;
        if (!w)
            return root.t("off");
        if (w.phase === "notFound")
            return root.t("notInstalled");
        if (w.phase === "connected")
            return root.t("on");
        if (w.phase === "starting")
            return root.t("starting");
        return root.t("off");
    }
    function heroStatusColor() {
        var w = root.widget;
        if (!w)
            return root.dim;
        if (w.phase === "connected")
            return root.attentionCount > 0 ? Color.urgent : Color.accent;
        if (w.phase === "notFound")
            return Color.urgent;
        return root.dim;
    }

    // ---- Modal helpers --------------------------------------------------------
    function restorePanelFocus() {
        if (!root.opened)
            return;
        Qt.callLater(function () {
            if (!root.modalOpen && keyCatcher)
                keyCatcher.forceActiveFocus();
        });
    }

    function closeTopModal() {
        if (root.installConfirmOpen) {
            root.installConfirmOpen = false;
            restorePanelFocus();
            return;
        }
        if (delConfirm.opened) {
            delConfirm.opened = false;
            root.delTarget = null;
            restorePanelFocus();
            return;
        }
        if (editModal.opened) {
            editModal.opened = false;
            root.editTarget = null;
            restorePanelFocus();
            return;
        }
        if (storageModal.opened) {
            storageModal.opened = false;
            restorePanelFocus();
            return;
        }
        if (addModal.opened) {
            addModal.opened = false;
            restorePanelFocus();
            return;
        }
    }

    function closeModalLayers() {
        addModal.opened = false;
        storageModal.opened = false;
        editModal.opened = false;
        root.installConfirmOpen = false;
        delConfirm.opened = false;
        root.editTarget = null;
        root.delTarget = null;
    }

    // ---- Add file -------------------------------------------------------------
    function openAddModal() {
        closeModalLayers();
        addPath.text = "";
        addNote.text = "";
        addErr.visible = false;
        addModal.opened = true;
        Qt.callLater(function () {
            addPath.forceActiveFocus();
        });
    }

    function doAdd() {
        var path = addPath.text.trim();
        if (!path) {
            addErr.text = root.t("requiredPath");
            addErr.visible = true;
            return;
        }
        if (!widget || root.actionBusy)
            return;
        root.actionBusy = true;
        widget.addFile(path, addNote.text.trim(), function (payload) {
            root.actionBusy = false;
            if (payload && payload.message) {
                addModal.opened = false;
                addPath.text = "";
                addNote.text = "";
                toastMsg(payload.message);
                root.restorePanelFocus();
            } else {
                addErr.text = (payload && payload.error) || root.t("requestFailed");
                addErr.visible = true;
            }
        });
    }

    // ---- Storage settings -----------------------------------------------------
    function loadSettings() {
        if (!widget)
            return;
        widget.settingsGet(function (payload) {
            if (!payload || !payload.settings)
                return;
            root.storageSettings = payload.settings;
            sfAuto.checked = payload.settings.autoSync === true;
            var w = payload.settings.storage && payload.settings.storage.webdav;
            if (w) {
                sfEndpoint.text = w.endpoint || "";
                sfUsername.text = w.username || "";
                // Keep the existing credential when the dialog reopens; the
                // backend returns it as part of its local settings.
                if (w.password !== undefined && w.password !== null)
                    sfPassword.text = String(w.password);
                sfBase.text = w.basePath || "";
            }
        });
    }
    function openStorageModal() {
        closeModalLayers();
        sfResult.visible = false;
        sfResultOk = false;
        root.loadSettings();
        storageModal.opened = true;
        Qt.callLater(function () {
            sfEndpoint.forceActiveFocus();
        });
    }
    function webdavFromForm() {
        return {
            endpoint: sfEndpoint.text.trim(),
            username: sfUsername.text.trim(),
            password: sfPassword.text,
            basePath: sfBase.text.trim()
        };
    }
    function doSaveSettings() {
        var w = root.webdavFromForm();
        if (!w.endpoint || !w.username || !w.password) {
            sfResult.text = root.t("requiresAuth");
            sfResultOk = false;
            sfResult.visible = true;
            return;
        }
        if (!widget || root.actionBusy)
            return;
        root.actionBusy = true;
        widget.settingsSave({
            autoSync: sfAuto.checked,
            storage: {
                type: "webdav",
                webdav: w
            }
        }, function (payload) {
            root.actionBusy = false;
            if (payload && payload.message) {
                root.loadSettings();
                storageModal.opened = false;
                root.restorePanelFocus();
                root.toastMsg(root.t("saved"));
            } else {
                sfResult.text = (payload && payload.error) || root.t("requestFailed");
                sfResultOk = false;
                sfResult.visible = true;
            }
        });
    }
    function doTestSettings() {
        var w = root.webdavFromForm();
        if (!w.endpoint || !w.username || !w.password) {
            sfResult.text = root.t("requiresAuth");
            sfResultOk = false;
            sfResult.visible = true;
            return;
        }
        if (!widget || root.actionBusy)
            return;
        root.actionBusy = true;
        widget.settingsTest(w, function (payload) {
            root.actionBusy = false;
            var ok = payload && payload.success;
            sfResult.text = ok ? root.t("testOk") : ((payload && payload.message) || root.t("testFail"));
            sfResultOk = !!ok;
            sfResult.visible = true;
        });
    }
    property bool sfResultOk: false

    // ---- Edit modal (dir / note / copy / delete in one place) -----------------
    function openEditModal(item) {
        closeModalLayers();
        root.editTarget = item;
        root.cursorActive = true;
        var idx = root.visibleFiles.indexOf(item);
        if (idx >= 0)
            root.fileIndex = idx;
        editDirInput.text = item.localDir || "";
        editNoteInput.text = item.note || "";
        editErr.visible = false;
        editModal.opened = true;
        Qt.callLater(function () {
            editDirInput.forceActiveFocus();
        });
    }

    function editError(payload) {
        editErr.text = (payload && payload.error) || root.t("requestFailed");
        editErr.visible = true;
    }

    // One Save button for the whole dialog: it writes the note, and — only
    // when the dir field actually changed — rebinds the local dir too, so the
    // two "save" actions can never disagree.
    function doEditSave() {
        if (!root.editTarget || !widget || root.actionBusy)
            return;
        widget.setNote(root.editTarget.id, editNoteInput.text, function (payload) {
            if (!payload || !payload.message) {
                editError(payload);
                return;
            }
            var dirChanged = editDirInput.text.trim() !== (root.editTarget.localDir || "");
            if (!dirChanged) {
                toastMsg(payload.message);
                root.restorePanelFocus();
                return;
            }
            widget.setFileDir(root.editTarget.id, editDirInput.text.trim(), function (p2) {
                if (p2 && p2.message)
                    toastMsg(p2.message);
                else
                    editError(p2);
                root.restorePanelFocus();
            });
        });
    }

    function doEditUnbind() {
        if (!root.editTarget || !widget || root.actionBusy)
            return;
        root.actionBusy = true;
        widget.setFileDir(root.editTarget.id, "", function (payload) {
            root.actionBusy = false;
            if (payload && payload.message) {
                toastMsg(payload.message);
                root.restorePanelFocus();
            } else {
                editError(payload);
            }
        });
    }

    // ---- Delete ---------------------------------------------------------------
    function openDeleteConfirm(item) {
        closeModalLayers();
        root.delTarget = item;
        delConfirm.opened = true;
        delConfirm.selectedIndex = 0;
        Qt.callLater(function () {
            delConfirm.forceActiveFocus();
        });
    }
    function doDelete() {
        if (!root.delTarget || !widget || root.actionBusy)
            return;
        root.actionBusy = true;
        widget.deleteFile(root.delTarget.id, function (payload) {
            root.actionBusy = false;
            if (payload && payload.message)
                toastMsg(payload.message);
            else
                toastMsg((payload && payload.error) || root.t("requestFailed"));
            root.delTarget = null;
            root.restorePanelFocus();
        });
    }

    // ---- Per-file primary action ----------------------------------------------
    // Removed: the per-row upload/download button was dropped in favour of a
    // single Edit control (the two overlapped — an unbound row's "set dir"
    // button just opened Edit). Rows now expose one action, and per-file sync
    // stays available from the Edit dialog and "Sync all".

    // ---- Export ---------------------------------------------------------------
    // SFS shares config as a single import command: `sfs --import-config <base64>`
    // where the blob is the settings JSON. We build exactly that so the copied
    // text can be pasted into another machine's shell — not a bare JSON dump.
    function base64Encode(str) {
        var bytes = unescape(encodeURIComponent(str));
        return Qt.btoa(bytes);
    }
    function writeExport() {
        var s = root.storageSettings || {};
        var w = (s.storage && s.storage.webdav) || {};
        if (!w.endpoint || !w.username) {
            root.toastMsg(root.t("exportNoStorage"));
            return;
        }
        var cfg = {
            autoSync: s.autoSync === true,
            storage: {
                type: "webdav",
                webdav: {
                    endpoint: w.endpoint || "",
                    username: w.username || "",
                    password: w.password || "",
                    basePath: w.basePath || ""
                }
            }
        };
        if (root.lang)
            cfg.language = root.lang;
        root.copyOut("sfs --import-config " + root.base64Encode(JSON.stringify(cfg)), root.t("expCopied"));
    }
    function doExportConfig() {
        if (root.storageSettings) {
            root.writeExport();
            return;
        }
        if (!widget)
            return;
        widget.settingsGet(function (payload) {
            if (payload && payload.settings)
                root.storageSettings = payload.settings;
            root.writeExport();
        });
    }

    function syncAll() {
        if (!root.widget || root.syncing || root.actionBusy)
            return;
        root.widget.syncAll(false, function (payload) {
            if (!payload)
                root.toastMsg(root.t("requestFailed"));
            else if (payload.error)
                root.toastMsg(payload.error);
            else if (payload.summary && payload.summary.failed > 0)
                root.toastMsg(root.t("syncHasFailures"));
        });
    }

    // ---- Cursor / filter ------------------------------------------------------
    function openFilter() {
        root.filterOpen = true;
        root.cursorActive = false;
        Qt.callLater(function () {
            filterField.forceActiveFocus();
        });
    }
    function closeFilter() {
        filterField.text = "";
        root.filterText = "";
        root.filterOpen = false;
        root.restorePanelFocus();
    }
    // Keep the query but hand the keyboard back to the list so the arrow keys
    // navigate the filtered results.
    function commitFilter() {
        root.cursorActive = true;
        root.fileIndex = 0;
        if (keyCatcher)
            keyCatcher.forceActiveFocus();
    }
    // Freeze the panel cursor while a dialog or the filter field owns input.
    readonly property bool keysBlocked: root.modalOpen || (filterField && filterField.activeFocus)

    function moveCursor(dy) {
        var files = root.visibleFiles;
        if (files.length === 0)
            return;
        root.cursorActive = true;
        if (root.fileIndex < 0)
            root.fileIndex = 0;
        else
            root.fileIndex = Math.max(0, Math.min(files.length - 1, root.fileIndex + dy));
        if (fileList)
            fileList.positionViewAtIndex(root.fileIndex, ListView.Contain);
    }
    function moveCursorEdge(toEnd) {
        var files = root.visibleFiles;
        if (files.length === 0)
            return;
        root.cursorActive = true;
        root.fileIndex = toEnd ? files.length - 1 : 0;
        if (fileList)
            fileList.positionViewAtIndex(root.fileIndex, ListView.Beginning);
    }
    function activateCursor() {
        var files = root.visibleFiles;
        if (root.fileIndex < 0 || root.fileIndex >= files.length)
            return;
        // Enter opens the row's editor (its single action).
        root.openEditModal(files[root.fileIndex]);
    }

    // ---- Toast ----------------------------------------------------------------
    function toastMsg(msg) {
        toastText.text = msg;
        toastBar.visible = true;
        toastTimer.restart();
    }
    function copyOut(text, msg) {
        if (widget) {
            widget.copy(text);
            root.toastMsg(msg || root.t("copied"));
        }
    }

    // ---- Reusable pieces ------------------------------------------------------
    // A segment inside a bordered group (hero) or the StatusMenu. No border of
    // its own — the surrounding group paints one — so several segments stack
    // without a thicket of adjacent borders. Interactive segments get a hover
    // fill and a handle cursor.
    component HeroChip: Item {
        id: chip
        property string label: ""
        property bool interactive: false
        property bool showDot: false
        property color dot: Color.accent
        property string tooltipText: ""
        signal tapped()

        implicitWidth: chipRow.implicitWidth + Style.space(16)
        implicitHeight: Style.space(28)
        readonly property bool chipHot: chipMouse.containsMouse

        Rectangle {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: chip.interactive && chip.chipHot ? Style.hoverFillFor(root.fg, Color.accent) : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Style.space(5)

            Rectangle {
                visible: chip.showDot
                width: Style.space(6)
                height: width
                radius: width / 2
                color: chip.dot
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                textFormat: Text.PlainText
                text: chip.label
                color: chip.interactive ? root.fg : root.dim
                font.family: root.fontFam
                font.pixelSize: Style.font.body
                font.bold: chip.interactive
                // Fixed line height so segments stay exactly the same height
                // across scripts — CJK glyphs otherwise report a taller line box
                // than Latin ones and the segments misalign.
                lineHeight: Style.font.body
                lineHeightMode: Text.FixedHeight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: chip.interactive
            cursorShape: chip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: chip.tapped()
        }

        PanelToolTip {
            visible: chip.tooltipText !== "" && chipMouse.containsMouse
            text: chip.tooltipText
            fontFamily: root.fontFam
        }
    }

    // Compact right-edge row action: the primary sync verb for the row's state,
    // plus an edit button. Both stay visible for touch and keyboard users.
    component FileRow: CursorSurface {
        id: fileRow
        required property var modelData
        required property int index

        readonly property bool syncable: modelData.status !== "unbound" && modelData.status !== "pending_binding"
        readonly property string glyphIcon: Lib.statusMeta(modelData.status).icon
        readonly property string glyphTone: Lib.statusMeta(modelData.status).tone
        readonly property bool urgentRow: modelData.status === "conflict" || modelData.status === "missing"

        width: ListView.view ? ListView.view.width : 0
        height: root.rowHeight
        foreground: root.fg
        accent: Color.accent
        hasCursor: root.cursorActive && root.fileIndex === index && !root.modalOpen

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: {
                root.cursorActive = true;
                root.fileIndex = fileRow.index;
            }
            onClicked: root.openEditModal(fileRow.modelData)
        }

        Text {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(18)
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            text: fileRow.glyphIcon
            color: root.toneColor(fileRow.glyphTone)
            font.family: root.fontFam
            font.pixelSize: Style.font.body
        }

        Column {
            anchors.left: glyph.right
            anchors.leftMargin: Style.space(8)
            anchors.right: actions.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(1)

            Text {
                width: parent.width
                textFormat: Text.PlainText
                text: fileRow.modelData.fileName || ""
                color: root.fg
                font.family: root.fontFam
                font.pixelSize: Style.font.body
                elide: Text.ElideMiddle
            }
            // Second line: status · size · age on the left, the note pinned to
            // the right so it stays readable instead of being clipped by the
            // (long, less useful) local path.
            Item {
                width: parent.width
                height: Math.max(metaLeft.implicitHeight, noteText.implicitHeight)

                Text {
                    id: metaLeft
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: noteText.visible ? Math.min(implicitWidth, parent.width - noteText.width - Style.space(8)) : parent.width
                    textFormat: Text.PlainText
                    text: {
                        var meta = Lib.statusMeta(fileRow.modelData.status);
                        var bits = [root.lang === "zh" ? meta.zh : meta.en];
                        if (fileRow.modelData.size)
                            bits.push(Lib.fmtSize(fileRow.modelData.size));
                        var when = fileRow.modelData.lastUploadTime || fileRow.modelData.lastChangeTime;
                        var ago = Lib.fmtTime(when, root.lang);
                        if (ago !== "")
                            bits.push(ago);
                        return bits.join("  ·  ");
                    }
                    color: fileRow.urgentRow ? root.warn : root.dim
                    font.family: root.fontFam
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                }
                Text {
                    id: noteText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width * 0.5)
                    textFormat: Text.PlainText
                    visible: (fileRow.modelData.note || "") !== ""
                    text: fileRow.modelData.note || ""
                    horizontalAlignment: Text.AlignRight
                    color: Qt.alpha(Color.accent, 0.9)
                    font.family: root.fontFam
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideLeft
                }
            }
        }

        Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            IconButton {
                iconText: "\uf040"
                tooltipText: root.t("edit")
                foreground: root.fg
                fontFamily: root.fontFam
                onClicked: root.openEditModal(fileRow.modelData)
            }
        }
    }

    component FieldLabel: Text {
        width: parent.width
        textFormat: Text.PlainText
        color: root.dim
        font.family: root.fontFam
        font.pixelSize: Style.font.caption
    }

    component FormError: Text {
        width: parent.width
        visible: false
        textFormat: Text.PlainText
        color: root.warn
        font.family: root.fontFam
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(460))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)

        FocusScope {
            id: keyScope
            anchors.fill: parent

            // Page/Home/End fall through the catcher (which owns Esc / Enter /
            // j-k-h-l / x and text keys) and land here.
            Keys.priority: Keys.AfterItem
            Keys.onPressed: function (event) {
                if (root.keysBlocked)
                    return;
                if (event.key === Qt.Key_PageDown) {
                    root.moveCursor(5);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.moveCursor(-5);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Home) {
                    root.moveCursorEdge(false);
                    event.accepted = true;
                } else if (event.key === Qt.Key_End) {
                    root.moveCursorEdge(true);
                    event.accepted = true;
                }
            }

            PanelKeyCatcher {
                id: keyCatcher
                anchors.fill: parent
                blocked: root.keysBlocked
                onMoveRequested: function (dx, dy) {
                    if (dy !== 0)
                        root.moveCursor(dy);
                }
                onActivateRequested: root.activateCursor()
                onDeleteRequested: {
                    if (root.cursorActive && root.fileIndex >= 0 && root.fileIndex < root.visibleFiles.length)
                        root.openDeleteConfirm(root.visibleFiles[root.fileIndex]);
                }
                onCloseRequested: {
                    // Escape clears an active filter before it closes the panel.
                    if (root.filterOpen || root.filterText !== "") {
                        root.closeFilter();
                        return;
                    }
                    root.close();
                }
                onTabRequested: function (direction) {
                    root.switchPanel(direction);
                }
                onTextKey: function (text) {
                    if (!root.widget)
                        return;
                    if (text === "r" || text === "R")
                        root.widget.refresh();
                    else if (text === "s" || text === "S")
                        root.syncAll();
                    else if (text === "a" || text === "A")
                        root.openAddModal();
                    else if (text === "f" || text === "F")
                        root.openFilter();
                    else if (text === "w" || text === "W")
                        root.widget.openWebUI();
                    else if (text === "e" || text === "E")
                        root.doExportConfig();
                }

                // Install confirmation — overlay above the panel so keys route
                // to the dialog while it is open.
                ConfirmDialog {
                    id: installConfirm
                    anchors.fill: parent
                    opened: root.installConfirmOpen
                    z: 30
                    focus: opened
                    message: root.t("installConfirm")
                    confirmText: root.t("installNow")
                    cancelText: root.t("installLater")
                    fontFamily: root.fontFam
                    onConfirmed: {
                        root.installConfirmOpen = false;
                        root.launchInstall();
                    }
                    onCanceled: {
                        root.installConfirmOpen = false;
                        root.restorePanelFocus();
                    }
                    Keys.onPressed: function (event) {
                        if (handleKey(event))
                            event.accepted = true;
                    }
                }

                ConfirmDialog {
                    id: delConfirm
                    anchors.fill: parent
                    opened: false
                    z: 30
                    focus: opened
                    message: root.t("delBody")
                    confirmText: root.t("delOk")
                    cancelText: root.t("delCancel")
                    fontFamily: root.fontFam
                    onConfirmed: {
                        delConfirm.opened = false;
                        root.doDelete();
                    }
                    onCanceled: {
                        delConfirm.opened = false;
                        root.delTarget = null;
                        root.restorePanelFocus();
                    }
                    Keys.onPressed: function (event) {
                        if (handleKey(event))
                            event.accepted = true;
                    }
                }

                Flickable {
                    id: mainScroll
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: content.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    flickDeceleration: 2200
                    maximumFlickVelocity: 1600
                    Controls.ScrollBar.vertical: Controls.ScrollBar {
                        policy: Controls.ScrollBar.AsNeeded
                    }

                    Column {
                        id: content
                        width: mainScroll.width
                        spacing: Style.space(12)

                        // Everything above the file list — measured together so
                        // the list can claim exactly the leftover height.
                        Column {
                            id: topBlock
                            width: parent.width
                            spacing: Style.space(12)

                            PanelHero {
                                width: parent.width
                                title: root.t("title")
                                foreground: root.fg
                                fontFamily: root.fontFam
                                iconComponent: Component {
                                    SfsIcon {
                                        iconSize: Style.font.display
                                        color: root.connected ? Color.accent : root.dim
                                    }
                                }
                                // Three lightweight segments (status + auto-sync /
                                // language). No surrounding frame — just hover
                                // highlights so the corner stays airy.
                                trailingControl: Component {
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Style.space(6)
                                        HeroChip {
                                            label: root.heroStatusText()
                                            showDot: true
                                            dot: root.heroStatusColor()
                                        }
                                        // Auto-sync marker — only while the background
                                        // timer is armed. Tap opens storage settings.
                                        HeroChip {
                                            id: heroAutoChip
                                            visible: root.widget !== null && root.widget.autoSyncEnabled === true
                                            label: "\uf021"
                                            interactive: true
                                            tooltipText: root.t("autoSyncOn")
                                            onTapped: root.openStorageModal()
                                        }
                                        HeroChip {
                                            label: root.t("language")
                                            interactive: true
                                            tooltipText: root.t("langTip")
                                            onTapped: {
                                                if (root.widget)
                                                    root.widget.setLang(root.lang === "en" ? "zh" : "en");
                                            }
                                        }
                                    }
                                }
                            }

                            // ---- Toolbar: one primary action + icon commands ----
                            Item {
                                id: toolbar
                                width: parent.width
                                implicitHeight: Math.max(syncBtn.implicitHeight, quickRow.implicitHeight)

                                // Content-sized primary button (no stretch) so the
                                // icon commands get the room; the two read as a
                                // left action + right action pair.
                                Button {
                                    id: syncBtn
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.syncing ? root.t("syncing") : root.t("syncAll")
                                    iconText: root.syncing ? "\uf021" : "\uf0ec"
                                    iconSpinning: root.syncing
                                    // A border so the primary button reads as a
                                    // button at rest instead of two empty margins.
                                    bordered: true
                                    implicitHeight: root.controlH
                                    fontFamily: root.fontFam
                                    enabled: !root.syncing && root.m !== null && !root.actionBusy
                                    onClicked: root.syncAll()
                                }

                                // Borderless icon commands — one light row, no
                                // per-button boxes.
                                Row {
                                    id: quickRow
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Style.space(1)

                                    IconButton {
                                        size: root.controlH
                                        iconText: "\uf067"
                                        tooltipText: root.t("addFile")
                                        foreground: root.fg
                                        fontFamily: root.fontFam
                                        onClicked: root.openAddModal()
                                    }
                                    IconButton {
                                        size: root.controlH
                                        iconText: "\uf013"
                                        tooltipText: root.t("storage")
                                        foreground: root.fg
                                        fontFamily: root.fontFam
                                        onClicked: root.openStorageModal()
                                    }
                                    IconButton {
                                        size: root.controlH
                                        iconText: "\uf019"
                                        tooltipText: root.t("expConfig")
                                        foreground: root.fg
                                        fontFamily: root.fontFam
                                        onClicked: root.doExportConfig()
                                    }
                                    IconButton {
                                        size: root.controlH
                                        iconText: "\uf08e"
                                        tooltipText: root.t("web")
                                        foreground: root.fg
                                        fontFamily: root.fontFam
                                        onClicked: {
                                            if (root.widget)
                                                root.widget.openWebUI();
                                        }
                                    }
                                    IconButton {
                                        size: root.controlH
                                        iconText: "\uf021"
                                        tooltipText: root.t("refresh")
                                        foreground: root.fg
                                        fontFamily: root.fontFam
                                        onClicked: {
                                            if (root.widget)
                                                root.widget.refresh();
                                        }
                                    }
                                }
                            }

                            // ---- Notices -------------------------------------------------
                            // One of: install prompt, offline/not-configured hint, or
                            // empty-list hint. The parent's visibility is computed from
                            // its own booleans — never from a child's `visible`, because a
                            // hidden parent forces children invisible and the binding
                            // would latch the whole column off.
                            Column {
                                id: noticeCol
                                width: parent.width
                                spacing: Style.space(8)
                                readonly property bool showNotFound: root.widget !== null && root.widget.phase === "notFound"
                                readonly property bool showState: {
                                    if (!root.widget)
                                        return false;
                                    if (root.widget.phase === "notFound")
                                        return false;
                                    if (root.widget.phase === "locating" || root.widget.phase === "starting")
                                        return root.m === null;
                                    if (root.m === null)
                                        return false;
                                    return root.m.storage === false;
                                }
                                readonly property bool showEmpty: root.hasModel && root.configured && root.filesTotal === 0
                                visible: showNotFound || showState || showEmpty

                                // "SFS not found" page: explanation + assisted install
                                // + manual retry. The install downloads SFS's
                                // install.sh from a pinned commit and verifies
                                // its SHA-256 before running it in a terminal.
                                Column {
                                    id: notFoundBox
                                    width: parent.width
                                    spacing: Style.space(8)
                                    visible: noticeCol.showNotFound

                                    Text {
                                        width: parent.width
                                        textFormat: Text.PlainText
                                        text: root.t("installTitle")
                                        color: root.warn
                                        font.family: root.fontFam
                                        font.pixelSize: Style.font.body
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        width: parent.width
                                        textFormat: Text.PlainText
                                        text: root.t("installBody")
                                        color: root.dim
                                        font.family: root.fontFam
                                        font.pixelSize: Style.font.caption
                                        wrapMode: Text.WordWrap
                                    }
                                    Row {
                                        spacing: Style.space(6)
                                        Button {
                                            text: root.t("installBtn")
                                            iconText: "\uf019"
                                            fontFamily: root.fontFam
                                            bordered: true
                                            onClicked: {
                                                root.installConfirmOpen = true;
                                                Qt.callLater(function () {
                                                    installConfirm.forceActiveFocus();
                                                });
                                            }
                                        }
                                        Button {
                                            text: root.t("retryBtn")
                                            iconText: "\uf021"
                                            fontFamily: root.fontFam
                                            bordered: true
                                            onClicked: {
                                                root.installFailedShown = false;
                                                if (root.widget)
                                                    root.widget.relocate();
                                            }
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        visible: root.installFailedShown
                                        textFormat: Text.PlainText
                                        text: root.t("installFailed")
                                        color: root.warn
                                        font.family: root.fontFam
                                        font.pixelSize: Style.font.caption
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                Text {
                                    id: stateText
                                    width: parent.width
                                    visible: noticeCol.showState
                                    textFormat: Text.PlainText
                                    text: {
                                        if (root.m !== null && root.m.storage === false)
                                            return root.t("notConfigured");
                                        if (root.widget && root.widget.phase === "locating")
                                            return root.t("retrying");
                                        return root.t("off");
                                    }
                                    color: root.warn
                                    font.family: root.fontFam
                                    font.pixelSize: Style.font.body
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    id: emptyText
                                    width: parent.width
                                    visible: noticeCol.showEmpty
                                    textFormat: Text.PlainText
                                    text: root.t("empty")
                                    color: root.dim
                                    font.family: root.fontFam
                                    font.pixelSize: Style.font.body
                                    wrapMode: Text.WordWrap
                                }
                            }

                            // ---- Files section header ------------------------------------
                            Item {
                                id: filesHeader
                                width: parent.width
                                implicitHeight: Style.space(26)
                                visible: root.hasModel && root.configured && root.filesTotal > 0

                                PanelSectionHeader {
                                    id: filesHeading
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    // PanelSectionHeader reserves a topPadding for
                                    // glyph overshoot; cancel it so the heading's
                                    // text centres against its siblings.
                                    topPadding: 0
                                    text: root.t("files")
                                    foreground: root.fg
                                    fontFamily: root.fontFam
                                }

                                Text {
                                    id: countText
                                    anchors.left: filesHeading.right
                                    anchors.leftMargin: Style.space(6)
                                    anchors.verticalCenter: parent.verticalCenter
                                    textFormat: Text.PlainText
                                    text: (root.filterText !== "" || root.statusFilter !== "all") ? (root.visibleFiles.length + " / " + root.filesTotal) : String(root.filesTotal)
                                    color: root.attentionCount > 0 ? root.warn : root.dim
                                    font.family: root.fontFam
                                    font.pixelSize: Style.font.caption
                                    font.bold: true
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Style.space(2)

                                    // Status filter — a compact dropdown living
                                    // next to the search icon, so it costs one row
                                    // of height instead of a chip strip.
                                    Item {
                                        id: statusMenu
                                        readonly property var current: root.currentStatusOption()
                                        readonly property bool activeFilter: root.statusFilter !== "all"
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitWidth: statusRow.implicitWidth + Style.space(24)
                                        implicitHeight: Style.space(28)
                                        visible: root.filesTotal > 0

                                        readonly property bool hot: statusMouse.containsMouse
                                        BorderSurface {
                                            anchors.fill: parent
                                            radius: Style.cornerRadius
                                            color: (statusMenu.hot || statusMenu.activeFilter)
                                                ? Style.hoverFillFor(root.fg, Color.accent)
                                                : "transparent"
                                            borderSpec: Border.controlSpec(
                                                (statusMenu.hot || statusMenu.activeFilter) ? "hover-cursor" : "normal",
                                                root.fg, Color.accent)
                                        }
                                        Row {
                                            id: statusRow
                                            anchors.centerIn: parent
                                            spacing: Style.space(6)
                                            Text {
                                                textFormat: Text.PlainText
                                                text: statusMenu.current.icon
                                                color: statusMenu.activeFilter ? Color.accent : root.fg
                                                font.family: root.fontFam
                                                font.pixelSize: Style.font.caption
                                                lineHeight: Style.font.caption
                                                lineHeightMode: Text.FixedHeight
                                            }
                                            Text {
                                                id: statusLabel
                                                textFormat: Text.PlainText
                                                text: statusMenu.current.label
                                                color: root.fg
                                                font.family: root.fontFam
                                                font.pixelSize: Style.font.caption
                                                font.bold: statusMenu.activeFilter
                                                lineHeight: Style.font.caption
                                                lineHeightMode: Text.FixedHeight
                                            }
                                            Text {
                                                id: statusCaret
                                                textFormat: Text.PlainText
                                                text: "\uf078"
                                                color: root.dim
                                                font.family: root.fontFam
                                                font.pixelSize: Style.font.caption
                                                lineHeight: Style.font.caption
                                                lineHeightMode: Text.FixedHeight
                                            }
                                        }
                                        MouseArea {
                                            id: statusMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: statusPopup.opened ? statusPopup.close() : statusPopup.open()
                                        }

                                        Controls.Popup {
                                            id: statusPopup
                                            // Right-align the popup under the trigger so it
                                            // never runs off the screen edge.
                                            x: statusMenu.width - width
                                            y: statusMenu.height + Style.space(4)
                                            width: Style.space(190)
                                            padding: Style.space(4)
                                            focus: true

                                            background: BorderSurface {
                                                color: Color.popups.background
                                                borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
                                                radius: Style.cornerRadius
                                            }
                                            contentItem: ListView {
                                                id: statusList
                                                implicitHeight: contentHeight
                                                clip: true
                                                model: root.statusOptions
                                                spacing: Style.space(2)
                                                boundsBehavior: Flickable.StopAtBounds
                                                function indexOfKey(k) {
                                                    for (var i = 0; i < root.statusOptions.length; i++)
                                                        if (root.statusOptions[i].key === k)
                                                            return i;
                                                    return 0;
                                                }
                                                Keys.onPressed: function (event) {
                                                    if (event.key === Qt.Key_Escape) {
                                                        statusPopup.close();
                                                        event.accepted = true;
                                                    } else if (event.key === Qt.Key_Down) {
                                                        statusList.currentIndex = Math.min(root.statusOptions.length - 1, statusList.currentIndex + 1);
                                                        event.accepted = true;
                                                    } else if (event.key === Qt.Key_Up) {
                                                        statusList.currentIndex = Math.max(0, statusList.currentIndex - 1);
                                                        event.accepted = true;
                                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                        if (statusList.currentIndex >= 0) {
                                                            root.selectStatus(root.statusOptions[statusList.currentIndex].key);
                                                            statusPopup.close();
                                                        }
                                                        event.accepted = true;
                                                    }
                                                }
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    required property int index
                                                    width: statusList.width
                                                    height: Style.space(26)
                                                    radius: Style.cornerRadius
                                                    readonly property bool current: modelData.key === root.statusFilter
                                                    color: current ? Style.selectedFillFor(root.fg, Color.accent)
                                                        : (index === statusList.currentIndex ? Style.hoverFillFor(root.fg, Color.accent) : "transparent")
                                                    // Icon · label · spacer · count — the count
                                                    // hugs the right edge instead of leaving a
                                                    // wide, unpredictable gap.
                                                    Text {
                                                        id: optIcon
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: Style.space(8)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        textFormat: Text.PlainText
                                                        text: modelData.icon
                                                        color: parent.current ? Color.accent : root.dim
                                                        font.family: root.fontFam
                                                        font.pixelSize: Style.font.caption
                                                    }
                                                    Text {
                                                        id: optCount
                                                        anchors.right: parent.right
                                                        anchors.rightMargin: Style.space(8)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        textFormat: Text.PlainText
                                                        text: String(modelData.count)
                                                        color: parent.current ? Color.accent : root.dim
                                                        font.family: root.fontFam
                                                        font.pixelSize: Style.font.caption
                                                    }
                                                    Text {
                                                        anchors.left: optIcon.right
                                                        anchors.leftMargin: Style.space(6)
                                                        anchors.right: optCount.left
                                                        anchors.rightMargin: Style.space(8)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        textFormat: Text.PlainText
                                                        text: modelData.label
                                                        color: parent.current ? Color.accent : root.fg
                                                        font.family: root.fontFam
                                                        font.pixelSize: Style.font.body
                                                        font.bold: parent.current
                                                        elide: Text.ElideRight
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onEntered: statusList.currentIndex = index
                                                        onClicked: { root.selectStatus(modelData.key); statusPopup.close() }
                                                    }
                                                }
                                            }
                                            onOpened: {
                                                statusList.currentIndex = statusList.indexOfKey(root.statusFilter);
                                                statusList.forceActiveFocus();
                                            }
                                        }
                                    }

                                    IconButton {
                                        iconText: "\uf002"
                                        tooltipText: root.t("filter")
                                        foreground: root.fg
                                        fontFamily: root.fontFam
                                        selected: root.filterOpen
                                        visible: root.filesTotal > 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: root.filterOpen ? root.closeFilter() : root.openFilter()
                                    }
                                }
                            }

                            // ---- Text filter (only when opened) ------------------
                            TextField {
                                id: filterField
                                width: parent.width
                                visible: root.filterOpen && root.filesTotal > 0
                                placeholderText: root.t("filterPh")
                                onTextChanged: root.filterText = text
                                onAccepted: root.commitFilter()
                                Keys.onPressed: function (event) {
                                    if (event.key === Qt.Key_Escape) {
                                        root.closeFilter();
                                        event.accepted = true;
                                    }
                                }
                            }
                        }

                        // ---- File list (fills the leftover height) -------------------
                        Item {
                            id: listWrap
                            width: parent.width
                            visible: root.hasModel && root.configured && root.filesTotal > 0
                            readonly property int desiredH: root.visibleFiles.length > 0 ? (root.visibleFiles.length * root.rowHeight + Math.max(0, root.visibleFiles.length - 1) * root.rowSpacing) : Style.space(30)
                            // Claim exactly the height left over once the fixed
                            // blocks above/below are accounted for, so the list —
                            // not the panel — owns the scroll when files overflow.
                            readonly property int maxH: Style.space(400)
                            readonly property real budgetH: {
                                var avail = panel.availableCardHeight;
                                if (!(avail > 0))
                                    return maxH;
                                var fixed = topBlock.implicitHeight + panel.verticalContentInset + content.spacing * (lastSyncLine.visible ? 2 : 1) + (lastSyncLine.visible ? lastSyncLine.implicitHeight : 0);
                                return Math.max(root.rowHeight, Math.min(maxH, avail - fixed));
                            }
                            height: visible ? Math.min(desiredH, budgetH) : 0

                            ListView {
                                id: fileList
                                anchors.fill: parent
                                clip: true
                                visible: root.visibleFiles.length > 0
                                model: root.visibleFiles
                                spacing: root.rowSpacing
                                boundsBehavior: Flickable.StopAtBounds
                                flickDeceleration: 2200
                                maximumFlickVelocity: 1600
                                Controls.ScrollBar.vertical: Controls.ScrollBar {
                                    policy: Controls.ScrollBar.AsNeeded
                                }
                                delegate: FileRow {}
                            }

                            Text {
                                anchors.fill: parent
                                anchors.margins: Style.space(6)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignTop
                                visible: root.visibleFiles.length === 0
                                textFormat: Text.PlainText
                                text: root.t("noMatch")
                                color: root.dim
                                font.family: root.fontFam
                                font.pixelSize: Style.font.body
                                wrapMode: Text.WordWrap
                            }
                        }

                        // ---- Last sync outcome ---------------------------------------
                        Text {
                            id: lastSyncLine
                            width: parent.width
                            readonly property var summary: (root.lastSync && root.lastSync.summary) ? root.lastSync.summary : null
                            visible: summary !== null
                            textFormat: Text.PlainText
                            text: {
                                var s = summary;
                                if (!s)
                                    return "";
                                var parts = [(s.uploaded || 0) + " " + root.t("lsUp"), (s.downloaded || 0) + " " + root.t("lsDown"), (s.skipped || 0) + " " + root.t("lsSkip"), (s.failed || 0) + " " + root.t("lsFail")];
                                return root.t("lastSync") + "  ·  " + parts.join("  ·  ");
                            }
                            color: (summary && summary.failed > 0) ? root.warn : root.dim
                            font.family: root.fontFam
                            font.pixelSize: Style.font.caption
                            elide: Text.ElideRight
                        }
                    }
                }

                // ---- Add-file dialog ---------------------------------------------
                ModalCard {
                    id: addModal
                    anchors.fill: parent
                    title: root.t("addTitle")
                    subtitle: root.t("addBody")
                    foreground: root.fg
                    dim: root.dim
                    fontFamily: root.fontFam
                    closeTooltip: root.t("close")
                    onClosed: root.closeTopModal()

                    FieldLabel {
                        text: root.t("addPath")
                    }
                    TextField {
                        id: addPath
                        width: parent.width
                        placeholderText: root.t("addPathPh")
                        onAccepted: root.doAdd()
                    }
                    FieldLabel {
                        text: root.t("addNote")
                    }
                    TextField {
                        id: addNote
                        width: parent.width
                        placeholderText: root.t("addNotePh")
                        onAccepted: root.doAdd()
                    }
                    FormError {
                        id: addErr
                    }
                    Row {
                        spacing: Style.space(6)
                        Button {
                            text: root.t("cancel")
                            fontFamily: root.fontFam
                            bordered: true
                            onClicked: root.closeTopModal()
                        }
                        Button {
                            text: root.t("addOk")
                            fontFamily: root.fontFam
                            bordered: true
                            enabled: !root.actionBusy
                            onClicked: root.doAdd()
                        }
                    }
                }

                // ---- Storage settings dialog -------------------------------------
                ModalCard {
                    id: storageModal
                    anchors.fill: parent
                    title: root.t("storageTitle")
                    subtitle: root.t("storageBody")
                    foreground: root.fg
                    dim: root.dim
                    fontFamily: root.fontFam
                    closeTooltip: root.t("close")
                    onClosed: root.closeTopModal()

                    FieldLabel {
                        text: root.t("endpoint")
                    }
                    TextField {
                        id: sfEndpoint
                        width: parent.width
                        placeholderText: root.t("endpointPh")
                    }
                    FieldLabel {
                        text: root.t("username")
                    }
                    TextField {
                        id: sfUsername
                        width: parent.width
                    }
                    FieldLabel {
                        text: root.t("password")
                    }
                    TextField {
                        id: sfPassword
                        width: parent.width
                        password: true
                    }
                    FieldLabel {
                        text: root.t("basePath")
                    }
                    TextField {
                        id: sfBase
                        width: parent.width
                        placeholderText: root.t("basePathPh")
                    }
                    Text {
                        id: sfResult
                        width: parent.width
                        visible: false
                        textFormat: Text.PlainText
                        color: root.sfResultOk ? Color.accent : root.warn
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                    Toggle {
                        id: sfAuto
                        width: parent.width
                        enabled: !root.actionBusy
                        checked: root.storageSettings !== null ? root.storageSettings.autoSync === true : false
                        implicitHeight: Style.space(40)
                        label: root.t("autoSyncEvery").replace("%1", String(root.widget ? root.widget.pollSec : 30))
                        fontFamily: root.fontFam
                        onClicked: checked = !checked
                    }
                    // Actions come last, after the form they act on.
                    Row {
                        width: parent.width
                        spacing: Style.space(6)
                        Button {
                            text: root.t("test")
                            fontFamily: root.fontFam
                            bordered: true
                            enabled: !root.actionBusy
                            onClicked: root.doTestSettings()
                        }
                        Item { width: Math.max(0, parent.width - parent.children[0].width - parent.children[2].width - parent.spacing * 2); height: 1 }
                        Button {
                            text: root.t("save")
                            fontFamily: root.fontFam
                            bordered: true
                            enabled: !root.actionBusy
                            onClicked: root.doSaveSettings()
                        }
                    }
                }

                // ---- Edit-file dialog (dir / note / copy / delete) ---------------
                ModalCard {
                    id: editModal
                    anchors.fill: parent
                    title: root.editTarget ? root.editTarget.fileName : ""
                    subtitle: {
                        var it = root.editTarget;
                        if (!it)
                            return "";
                        var meta = Lib.statusMeta(it.status);
                        var bits = [root.lang === "zh" ? meta.zh : meta.en];
                        if (it.size)
                            bits.push(Lib.fmtSize(it.size));
                        var when = it.lastUploadTime || it.lastChangeTime;
                        var ago = Lib.fmtTime(when, root.lang);
                        if (ago !== "")
                            bits.push(ago);
                        return bits.join("  ·  ");
                    }
                    foreground: root.fg
                    dim: root.dim
                    fontFamily: root.fontFam
                    closeTooltip: root.t("close")
                    onClosed: root.closeTopModal()

                    FieldLabel {
                        text: root.t("dirTitle")
                    }
                    Row {
                        width: parent.width
                        spacing: Style.space(6)
                        TextField {
                            id: editDirInput
                            width: parent.width - unbindBtn.width - parent.spacing
                            placeholderText: root.t("dirInput")
                            onAccepted: root.doEditSave()
                        }
                        Button {
                            id: unbindBtn
                            text: root.t("unbind")
                            fontFamily: root.fontFam
                            foreground: root.warn
                            enabled: !root.actionBusy
                            onClicked: root.doEditUnbind()
                        }
                    }

                    PanelSeparator {
                        width: parent.width
                        foreground: root.fg
                    }

                    FieldLabel {
                        text: root.t("actNote")
                    }
                    TextField {
                        id: editNoteInput
                        width: parent.width
                        placeholderText: root.t("notePh")
                        onAccepted: root.doEditSave()
                    }

                    FormError {
                        id: editErr
                    }

                    // One Save for the whole dialog (note + dir when changed),
                    // then the row-level utilities, all on the same row.
                    Row {
                        width: parent.width
                        spacing: Style.space(6)
                        Button {
                            text: root.t("save")
                            fontFamily: root.fontFam
                            bordered: true
                            enabled: !root.actionBusy
                            onClicked: root.doEditSave()
                        }
                        Item { width: Math.max(0, parent.width - parent.children[0].width - parent.children[2].width - parent.children[3].width - parent.spacing * 3); height: 1 }
                        Button {
                            text: root.t("actCopy")
                            fontFamily: root.fontFam
                            bordered: true
                            onClicked: {
                                if (root.editTarget)
                                    root.copyOut(root.editTarget.localPath || root.editTarget.fileName);
                            }
                        }
                        Button {
                            text: root.t("actDel")
                            fontFamily: root.fontFam
                            foreground: root.warn
                            enabled: !root.actionBusy
                            onClicked: root.openDeleteConfirm(root.editTarget)
                        }
                    }
                }

                // ---- Toast bar ---------------------------------------------------
                Rectangle {
                    id: toastBar
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Style.space(16)
                    width: Math.min(parent.width - Style.space(40), toastText.implicitWidth + Style.space(24))
                    height: Style.space(26)
                    visible: false
                    radius: Style.space(4)
                    color: Color.popups.background
                    border.color: Qt.alpha(root.fg, 0.18)
                    border.width: 1
                    z: 20

                    Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: toastText.text
                        color: root.fg
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                    }
                }
                Text {
                    id: toastText
                    visible: false
                    text: ""
                    font.family: root.fontFam
                    font.pixelSize: Style.font.caption
                }
                Timer {
                    id: toastTimer
                    interval: 2200
                    onTriggered: toastBar.visible = false
                }
            }
        }
    }
}
