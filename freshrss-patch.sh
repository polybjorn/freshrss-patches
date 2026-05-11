#!/bin/bash
# Re-apply FreshRSS and RSS-Bridge patches that get overwritten on update.
# Safe to run repeatedly (idempotent). Run after each FreshRSS or RSS-Bridge update.
#
# Each *.patch file in patches/ is a unified diff applied with `patch -p1`.
# Filename prefix selects the target tree:
#   freshrss-*.patch   -> $FRESHRSS_DIR   (default /var/www/FreshRSS)
#   rss-bridge-*.patch -> $RSSBRIDGE_DIR  (default /var/www/rss-bridge)
set -euo pipefail
shopt -s nullglob

FRESHRSS_DIR="${FRESHRSS_DIR:-/var/www/FreshRSS}"
RSSBRIDGE_DIR="${RSSBRIDGE_DIR:-/var/www/rss-bridge}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$SCRIPT_DIR/patches"

applied=()
skipped=()
failed=()

apply_one() {
  local patchfile="$1"
  local name target
  name="$(basename "$patchfile" .patch)"

  case "$name" in
    freshrss-*)   target="$FRESHRSS_DIR" ;;
    rss-bridge-*) target="$RSSBRIDGE_DIR" ;;
    *)
      echo "Skip $name: filename must start with 'freshrss-' or 'rss-bridge-'" >&2
      return 0
      ;;
  esac

  if [ ! -d "$target" ]; then
    skipped+=("$name (target $target missing)")
    return 0
  fi

  if patch -p1 -d "$target" --forward --dry-run --silent <"$patchfile" >/dev/null 2>&1; then
    patch -p1 -d "$target" --forward --silent <"$patchfile" >/dev/null
    applied+=("$name")
  elif patch -p1 -d "$target" --reverse --dry-run --silent <"$patchfile" >/dev/null 2>&1; then
    skipped+=("$name (already applied)")
  else
    failed+=("$name")
    echo "Patch failed: $name (target diverged from upstream)" >&2
  fi
}

patches=("$PATCH_DIR"/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
  echo "No patches found in $PATCH_DIR" >&2
  exit 0
fi

for p in "${patches[@]}"; do
  apply_one "$p"
done

[ ${#applied[@]} -gt 0 ] && echo "Applied patches: ${applied[*]}"
[ ${#skipped[@]} -gt 0 ] && echo "Skipped: ${skipped[*]}"
[ ${#failed[@]} -gt 0 ] && { echo "Failed: ${failed[*]}" >&2; exit 1; }

if [ ${#applied[@]} -eq 0 ] && [ ${#skipped[@]} -eq 0 ]; then
  echo "No patches applicable."
fi
