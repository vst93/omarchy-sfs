#!/usr/bin/env python3
"""Offline structural validation for the SFS Omarchy plugin.

Mirrors the manifest rules the Omarchy marketplace enforces (see
plugins.omarchy.org/develop.html) plus consistency checks between the
manifest, the QML entry points, and the JS library. Run: ./validate.py
"""
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def load_manifest() -> dict:
    path = ROOT / "manifest.json"
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        err(f"manifest.json does not parse: {e}")
        return {}


def check_manifest(m: dict) -> None:
    for key in ("schemaVersion", "id", "name", "version", "kinds", "entryPoints"):
        if key not in m:
            err(f"manifest missing required key: {key}")
    if m.get("schemaVersion") != 1:
        err("schemaVersion must be 1")
    pid = m.get("id", "")
    if pid.startswith("omarchy."):
        err("third-party ids cannot use the omarchy.* namespace")
    if not re.fullmatch(r"[A-Za-z0-9._-]+", pid):
        err(f"id contains unsafe characters: {pid!r}")
    kinds = m.get("kinds", [])
    ep = m.get("entryPoints", {})
    kind_to_ep = {
        "bar-widget": "barWidget",
        "panel": "panel",
        "overlay": "overlay",
        "menu": "menu",
        "service": "service",
        "bar": "bar",
    }
    if not kinds:
        err("kinds must list at least one kind")
    for kind in kinds:
        if kind not in kind_to_ep:
            err(f"unknown kind: {kind}")
            continue
        ep_key = kind_to_ep[kind]
        if ep_key not in ep:
            err(f"kind {kind!r} requires entryPoints.{ep_key}")
        else:
            rel = ep[ep_key]
            if not isinstance(rel, str) or rel.startswith("/") or ".." in rel:
                err(f"entryPoints.{ep_key} must be a safe relative path")
            elif not (ROOT / rel).is_file():
                err(f"entry point file not found: {rel!r}")
    # Bar widget metadata block, if present, must agree with kinds.
    if "barWidget" in m and "bar-widget" not in kinds:
        warn("manifest has a barWidget metadata block but no bar-widget kind")
    if "omarchy" in m:
        warn("clone-only field 'omarchy.clonedFrom' should be removed before publishing")


def check_symlinks() -> None:
    for p in ROOT.rglob("*"):
        if p.is_symlink():
            err(f"plugin folders cannot contain symlinks: {p.relative_to(ROOT)}")


def strip_qml(text: str) -> str:
    """Char-level comment/string stripper (handles multi-line comments)."""
    out = []
    i, n = 0, len(text)
    in_block = False
    in_str = ""
    while i < n:
        c = text[i]
        if in_block:
            if text[i:i + 2] == "*/":
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == in_str:
                in_str = ""
            i += 1
            continue
        if text[i:i + 2] == "/*":
            in_block = True
            i += 2
            continue
        if text[i:i + 2] == "//":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c in "\"'":
            in_str = c
            out.append(c)
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


def qml_braces_ok(text: str) -> bool:
    t = strip_qml(text)
    return t.count("{") == t.count("}")


def check_qml(name: str) -> dict:
    path = ROOT / name
    if not path.is_file():
        return {}
    text = path.read_text(encoding="utf-8")
    if not qml_braces_ok(text):
        err(f"{name}: unbalanced braces")
    if text.count("(") != text.count(")"):
        err(f"{name}: unbalanced parentheses")
    # imports sanity
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("import qs.") and not re.match(r'import qs\.(Commons|Ui)$', s):
            warn(f"{name}: import outside qs.Commons/qs.Ui: {s}")
    return {"text": text}


def check_qml_consistency(files: dict) -> None:
    bw = files.get("BarWidget.qml", {}).get("text", "")
    panel = files.get("Panel.qml", {}).get("text", "")
    if bw:
        if 'moduleName: "io.github.vst93.sfs"' not in bw:
            err("BarWidget.qml: moduleName does not match the manifest id")
        for needed in ("Loader", "Panel.qml", "IpcHandler",
                       "function open()", "function close()", "function toggle()"):
            if needed not in bw:
                err(f"BarWidget.qml: bar-widget contract piece missing: {needed}")
        # The clickable can be the base WidgetButton or the icon-capable
        # subclass BarIconButton (extends WidgetButton).
        if "BarIconButton" not in bw and "WidgetButton" not in bw:
            err("BarWidget.qml: bar-widget contract piece missing: WidgetButton/BarIconButton")
    if panel:
        if 'moduleName: "io.github.vst93.sfs"' not in panel:
            err("Panel.qml: moduleName does not match the manifest id")
        for needed in ("Panel {", "KeyboardPanel {", "PanelKeyCatcher {",
                       "controller.show()", "controller.hide()"):
            if needed not in panel:
                err(f"Panel.qml: panel contract piece missing: {needed}")
        if "Panel {" not in bw and "panelLoader" in bw:
            pass  # panel loaded via Loader, fine


def check_lib_js() -> None:
    path = ROOT / "Lib.js"
    text = path.read_text(encoding="utf-8")
    if not text.lstrip().startswith(".pragma library"):
        err("Lib.js must start with '.pragma library'")
    # Node syntax check, ignoring the QML-specific pragma line.
    js = text.replace(".pragma library", "// pragma library", 1)
    with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as f:
        f.write(js)
        tmp = f.name
    r = subprocess.run(["node", "--check", tmp], capture_output=True, text=True)  # noqa: S603
    Path(tmp).unlink(missing_ok=True)
    if r.returncode != 0:
        err(f"Lib.js fails node --check: {r.stderr.strip()[:300]}")
    # every status tone used must be one the panel knows how to color
    tones = set(re.findall(r'tone:\s*"(\w+)"', text))
    if not tones <= {"accent", "warning", "info", "urgent", "muted"}:
        err(f"Lib.js: unknown tone values: {tones - {'accent', 'warning', 'info', 'urgent', 'muted'}}")


def check_readme(m: dict) -> None:
    text = (ROOT / "README.md").read_text(encoding="utf-8")
    pid = m.get("id", "")
    if pid and pid not in text:
        warn("README never mentions the plugin id")
    if "plugin add" not in text:
        warn("README missing an install command")
    for lang_marker in ("# 中文说明", "English"):
        if lang_marker not in text:
            warn(f"README missing language section marker: {lang_marker}")


def main() -> int:
    m = load_manifest()
    if m:
        check_manifest(m)
        check_symlinks()
        files = {n: check_qml(n) for n in ("BarWidget.qml", "Panel.qml")}
        check_qml_consistency(files)
        check_lib_js()
        check_readme(m)
    if warnings:
        print("Warnings:")
        for w in warnings:
            print(f"  ! {w}")
    if errors:
        print("Errors:")
        for e in errors:
            print(f"  x {e}")
        return 1
    print("OK: manifest, entry points, QML contract, Lib.js, README all consistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
