#!/bin/bash
# Re-apply FreshRSS and RSS-Bridge patches that get overwritten on update.
# Safe to run repeatedly (idempotent). Run after each FreshRSS or RSS-Bridge update.
set -euo pipefail

FRESHRSS_DIR="${FRESHRSS_DIR:-/var/www/FreshRSS}"
RSSBRIDGE_DIR="${RSSBRIDGE_DIR:-/var/www/rss-bridge}"

NORD_CSS="$FRESHRSS_DIR/p/themes/Nord/nord.css"
NORD_RTL="$FRESHRSS_DIR/p/themes/Nord/nord.rtl.css"
YT_BRIDGE="$RSSBRIDGE_DIR/bridges/YoutubeBridge.php"

applied=()

# Each apply_* function detects whether the patch is needed and applies it,
# appending a label to `applied` on success. Functions are no-ops when the
# target file is missing or the patch is already in place.

# Nord theme: remove favicon background, make circular.
# The default Nord theme sets a light background behind feed favicons and
# uses slightly rounded corners. Looks bad with transparent/circular favicons
# (e.g. YouTube channel avatars). Trade-off: dark opaque favicons may be less
# visible without the background.
apply_nord_favicons() {
  for css in "$NORD_CSS" "$NORD_RTL"; do
    [ -f "$css" ] || continue
    grep -q 'img\.favicon' "$css" 2>/dev/null || continue
    grep -A1 'img\.favicon' "$css" | grep -q 'background: var(--text-accent)' || continue
    sed -i '/img\.favicon/,/^}/{s/background: var(--text-accent);/background: none;/;s/border-radius: 4px;/border-radius: 50%;/}' "$css"
    applied+=("$(basename "$css") favicon style")
  done
}

# RSS-Bridge: increase YoutubeBridge cache TTL from 3h to 6h.
# The default 3-hour cache means RSS-Bridge hits YouTube frequently. With
# many feeds refreshing simultaneously, YouTube rate-limits and returns 404
# errors. 6 hours halves request frequency while remaining responsive enough
# (channels rarely post more than once a day).
# See: https://github.com/RSS-Bridge/rss-bridge/issues/2113
apply_yt_cache_ttl() {
  [ -f "$YT_BRIDGE" ] || return 0
  grep -q 'CACHE_TIMEOUT = 60 \* 60 \* 3' "$YT_BRIDGE" 2>/dev/null || return 0
  sed -i "s/CACHE_TIMEOUT = 60 \* 60 \* 3;.*/CACHE_TIMEOUT = 60 * 60 * 6; \/\/ 6 hours/" "$YT_BRIDGE"
  applied+=("YoutubeBridge cache TTL")
}

# To add a patch: define apply_<name>, call it from main, document in README.
main() {
  apply_nord_favicons
  apply_yt_cache_ttl
}

main

if [ ${#applied[@]} -gt 0 ]; then
  echo "Applied patches: ${applied[*]}"
else
  echo "No patches needed (already applied or targets not found)"
fi
