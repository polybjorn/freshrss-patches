#!/bin/bash
# Re-apply FreshRSS and RSS-Bridge patches that get overwritten on update.
# Safe to run repeatedly (idempotent). Run after each FreshRSS or RSS-Bridge update.
set -euo pipefail

FRESHRSS_DIR="${FRESHRSS_DIR:-/var/www/FreshRSS}"
RSSBRIDGE_DIR="${RSSBRIDGE_DIR:-/var/www/rss-bridge}"

MAIN_JS="$FRESHRSS_DIR/p/scripts/main.js"
NORD_CSS="$FRESHRSS_DIR/p/themes/Nord/nord.css"
NORD_RTL="$FRESHRSS_DIR/p/themes/Nord/nord.rtl.css"
YT_BRIDGE="$RSSBRIDGE_DIR/bridges/YoutubeBridge.php"

applied=()

# --- Favicon: detect RFP (Resist Fingerprinting) and skip canvas replacement ---
# Browsers with RFP (LibreWolf, Firefox+arkenfox) corrupt canvas.toDataURL()
# output, producing a striped/garbled favicon. FreshRSS doesn't detect this and
# replaces the good static favicon with corrupted data. This patch adds a pixel
# verification check: draw a known color, read it back, and only proceed if it
# matches. If RFP is active, the read-back will be randomized and the static
# favicon is preserved.
# See: https://github.com/FreshRSS/FreshRSS/issues/4091
if grep -q "link.href = canvas.toDataURL('image/png');" "$MAIN_JS" 2>/dev/null; then
    if ! grep -q "RFP canvas detection" "$MAIN_JS" 2>/dev/null; then
        sed -i "/link\.href = canvas\.toDataURL('image\/png');/i\\
\\t\\t\\t// RFP canvas detection: verify canvas data is not corrupted\\
\\t\\t\\tconst testCanvas = document.createElement('canvas');\\
\\t\\t\\ttestCanvas.width = testCanvas.height = 1;\\
\\t\\t\\tconst testCtx = testCanvas.getContext('2d');\\
\\t\\t\\ttestCtx.fillStyle = '#FF0000';\\
\\t\\t\\ttestCtx.fillRect(0, 0, 1, 1);\\
\\t\\t\\tconst p = testCtx.getImageData(0, 0, 1, 1).data;\\
\\t\\t\\tif (p[0] !== 255 || p[1] !== 0 || p[2] !== 0) return;" "$MAIN_JS"
        applied+=("main.js RFP favicon detection")
    fi
fi

# --- Nord theme: remove favicon background, make circular ---
# The default Nord theme sets a light background behind feed favicons and uses
# slightly rounded corners. This looks bad with transparent/circular favicons
# (e.g. custom YouTube channel avatars) — you get a light rectangle behind a
# circular icon. This patch removes the background and makes favicons circular.
# Trade-off: dark opaque favicons may be less visible on the dark background.
for css in "$NORD_CSS" "$NORD_RTL"; do
    [ -f "$css" ] || continue
    if grep -q 'img\.favicon' "$css" 2>/dev/null; then
        if grep -A1 'img\.favicon' "$css" | grep -q 'background: var(--text-accent)'; then
            sed -i '/img\.favicon/,/^}/{s/background: var(--text-accent);/background: none;/;s/border-radius: 4px;/border-radius: 50%;/}' "$css"
            applied+=("$(basename "$css") favicon style")
        fi
    fi
done

# --- RSS-Bridge: increase YoutubeBridge cache TTL to 6 hours ---
# The default 3-hour cache means RSS-Bridge hits YouTube frequently. With many
# feeds refreshing simultaneously, YouTube rate-limits and returns 404 errors.
# 6 hours reduces request frequency by half while remaining responsive enough
# (channels rarely post more than once a day).
# See: https://github.com/RSS-Bridge/rss-bridge/issues/2113
if [ -f "$YT_BRIDGE" ] && grep -q 'CACHE_TIMEOUT = 60 \* 60 \* 3' "$YT_BRIDGE" 2>/dev/null; then
    sed -i "s/CACHE_TIMEOUT = 60 \* 60 \* 3;.*/CACHE_TIMEOUT = 60 * 60 * 6; \/\/ 6 hours/" "$YT_BRIDGE"
    applied+=("YoutubeBridge cache TTL")
fi

if [ ${#applied[@]} -gt 0 ]; then
    echo "Applied patches: ${applied[*]}"
else
    echo "No patches needed (already applied or targets not found)"
fi
