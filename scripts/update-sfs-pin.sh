#!/usr/bin/env bash
# Refresh the pinned SFS install-script reference in Lib.js.
#
# The Omarchy marketplace requires the assisted install to execute an
# *immutable* artifact, never a moving branch. We therefore pin cmd/install.sh
# to a full commit SHA plus a SHA-256 committed in Lib.js. This helper is the
# dev-time way to bump that pin when upstream changes install.sh.
#
# It does NOT make the plugin fetch a branch at runtime: it writes a new fixed
# commit + digest into the committed source, which must then go through a fresh
# plugin review. The install script it pins still fetches the *latest* SFS
# release, so SFS version bumps never require touching this pin.
#
# Usage:
#   scripts/update-sfs-pin.sh [REF]
#
# REF may be a branch, tag, or full commit SHA (default: main). The resolved
# commit is what gets pinned; the checksum then binds the exact bytes, so even
# pinning a branch *tip* is safe — the branch can move, the pinned SHA cannot.
#
# Resolution uses `git ls-remote` (no GitHub API, so no rate limits). The file
# itself is fetched from raw.githubusercontent.com at the resolved SHA.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/Lib.js"
REPO="vst93/sfs"
REF="${1:-main}"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }

SHA=""
if printf '%s' "$REF" | grep -qE '^[0-9a-f]{40}$'; then
    # Already a full commit SHA.
    SHA="$REF"
elif command -v git >/dev/null 2>&1; then
    SHA="$(git ls-remote "https://github.com/$REPO" "$REF" 2>/dev/null | awk 'NR==1{print $1}')"
fi

# Fall back to the GitHub API only if git could not resolve the ref.
if ! printf '%s' "$SHA" | grep -qE '^[0-9a-f]{40}$'; then
    echo "git could not resolve '$REF'; trying GitHub API…" >&2
    SHA="$(curl -fsSL "https://api.github.com/repos/$REPO/commits/$REF" 2>/dev/null \
        | grep -m1 '"sha"' | sed -E 's/.*"sha": *"([0-9a-f]{40})".*/\1/')"
fi

if ! printf '%s' "$SHA" | grep -qE '^[0-9a-f]{40}$'; then
    echo "Could not resolve '$REF' to a commit SHA" >&2
    exit 1
fi

URL="https://raw.githubusercontent.com/$REPO/$SHA/cmd/install.sh"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT HUP INT TERM

echo "REF:  $REF"
echo "SHA:  $SHA"
echo "URL:  $URL"
curl -fsSL --proto '=https' --tlsv1.2 -o "$TMP" "$URL"

if command -v sha256sum >/dev/null 2>&1; then
    HASH="$(sha256sum "$TMP" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
    HASH="$(shasum -a 256 "$TMP" | awk '{print $1}')"
else
    echo "Need sha256sum or shasum" >&2
    exit 1
fi

OLD_SHA="$(sed -nE 's/^var SFS_INSTALL_COMMIT = "([0-9a-f]{40})".*/\1/p' "$LIB")"
OLD_HASH="$(sed -nE 's/^var SFS_INSTALL_SHA256 = "([0-9a-f]{64})".*/\1/p' "$LIB")"

if [ "$SHA" = "$OLD_SHA" ] && [ "$HASH" = "$OLD_HASH" ]; then
    echo "Already pinned: ${SHA:0:12} (${HASH})"
    exit 0
fi

sed -i -E \
    -e "s|^var SFS_INSTALL_COMMIT = \"[0-9a-f]{40}\"|var SFS_INSTALL_COMMIT = \"$SHA\"|" \
    -e "s|^var SFS_INSTALL_SHA256 = \"[0-9a-f]{64}\"|var SFS_INSTALL_SHA256 = \"$HASH\"|" \
    "$LIB"

echo "commit: ${OLD_SHA:0:12} -> ${SHA:0:12}"
echo "sha256: $OLD_HASH"
echo "     -> $HASH"

# Fail closed if the rewrite produced something the reviewers would reject.
[ -f "$ROOT/validate.py" ] && python3 "$ROOT/validate.py"

echo
echo "Review the diff, then commit. The new pin must ship in a reviewed plugin release."
