#!/bin/sh

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/Packages/SyncKit"
RECEIPT="$REPO_ROOT/SyncKit.vendor.json"

if [ ! -f "$VENDOR_DIR/Package.swift" ] || [ ! -f "$RECEIPT" ]; then
    printf '%s\n' "SyncKit vendor or receipt is missing." >&2
    exit 1
fi

EXPECTED_HASH="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV.fetch(0))).fetch("tree_sha256")' "$RECEIPT")"
ACTUAL_HASH="$(
    cd "$VENDOR_DIR"
    find . -type f ! -path './.build/*' ! -path './.swiftpm/*' ! -path './.superpowers/*' -print \
        | sed 's#^./##' \
        | LC_ALL=C sort \
        | xargs shasum -a 256 \
        | shasum -a 256 \
        | awk '{print $1}'
)"

if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
    printf '%s\n' "Vendored SyncKit drifted from its recorded canonical snapshot." >&2
    printf '%s\n' "Expected: $EXPECTED_HASH" "Actual:   $ACTUAL_HASH" >&2
    exit 1
fi

printf '%s\n' "Verified vendored SyncKit $EXPECTED_HASH"
