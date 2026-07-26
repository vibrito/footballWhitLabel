#!/bin/sh
#
# Copies the shared crest files from this repo (the source of truth) into the
# Fixture 2026 app, and stamps both copies with a hash of their own content.
#
# Why a hash rather than trusting people to run this: the two apps ship from
# separate git repos, so nothing at build time can compare them. Each repo's
# CrestSyncTests recomputes the hash of its own copy and checks it against the
# stamp. Edit one file without re-running this and that repo's tests fail — and
# because the stamp covers the content, two files carrying the same stamp and
# each hashing to it are necessarily byte-identical.
#
# Usage:  scripts/sync-crests.sh [path-to-worldcup-repo]

set -eu

SRC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DST_ROOT="${1:-$SRC_ROOT/../worldcup}"

[ -d "$DST_ROOT" ] || { echo "error: no repo at $DST_ROOT" >&2; exit 1; }

# source path relative to its app dir : destination path relative to its app dir
FILES="Models/TeamCrestSymbol.swift Components/CrestDisc.swift"

STAMP_PREFIX="// crest-sync:"

hash_body() {
    # Everything except the stamp line, so the hash is of the real content and
    # stamping it cannot change it.
    grep -v "^$STAMP_PREFIX" "$1" | shasum -a 256 | cut -d' ' -f1
}

stamp() {
    file="$1"; sum="$2"; tmp="$file.tmp.$$"
    awk -v line="$STAMP_PREFIX $sum" \
        'index($0, "// crest-sync:") == 1 { print line; next } { print }' \
        "$file" > "$tmp"
    mv "$tmp" "$file"
}

for rel in $FILES; do
    src="$SRC_ROOT/BR2026/$rel"
    dst="$DST_ROOT/Fixture2026App/$rel"

    [ -f "$src" ] || { echo "error: missing source $src" >&2; exit 1; }
    grep -q "^$STAMP_PREFIX" "$src" || {
        echo "error: $src has no '$STAMP_PREFIX' line to stamp" >&2; exit 1; }

    sum="$(hash_body "$src")"
    stamp "$src" "$sum"

    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"

    echo "  $rel  ->  ${sum%"${sum#????????}"}…"
done

echo "note: synced to $DST_ROOT — commit both repos."
