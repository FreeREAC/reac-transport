#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Pau Aliagas <linuxnow@gmail.com>
#
# The README sells and installs the package; building it is BUILDING.md's job.
# Fails when the README's code (fenced blocks, indented blocks, inline `spans`)
# carries a build command, or when BUILDING.md is missing.
#
#   ./scripts/check-readme.sh              # checks README.md at the repo root
#   ./scripts/check-readme.sh <readme>     # checks another file
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
README="${1:-$REPO/README.md}"

[ -f "$README" ] || { echo "ERROR: no README at $README"; exit 1; }
[ -f "$REPO/BUILDING.md" ] || { echo "ERROR: no BUILDING.md: the build steps have nowhere to live"; exit 1; }

# Code text only, as "<line>:<text>", so prose that says "make" is never a hit.
code() {
  awk '
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence              { print NR ":" $0; next }
    /^(    |\t)/ && (prev == "" || indented) { print NR ":" $0; indented = 1; prev = $0; next }
    { indented = 0; prev = $0
      line = $0
      while (match(line, /`[^`]+`/)) {
        print NR ":" substr(line, RSTART + 1, RLENGTH - 2)
        line = substr(line, RSTART + RLENGTH)
      } }
  ' "$1"
}

BUILD='(^|[[:space:]:;&|(])(sudo[[:space:]]+)?(make|meson|cmake|ninja|rpmbuild|pnpm[[:space:]]+build|npm[[:space:]]+run[[:space:]]+build|cargo[[:space:]]+build)([[:space:]]|$)|build(-apk)?\.sh'

if hits=$(code "$README" | grep -E "$BUILD"); then
  echo "ERROR: $README carries a build command; it belongs in BUILDING.md:"
  printf '  %s\n' "$hits"
  exit 1
fi
echo "README clean: no build command"
