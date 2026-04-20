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

# --- Nord theme: fix nav_menu layout quirks ---
# Two upstream issues only visible in Nord:
#   1. #nav_menu_toggle_aside is absolute-positioned (frss.css). When the
#      button row wraps at narrow widths, the absolute toggle no longer
#      participates in centering/spacing, visually colliding with the first
#      button group. Making it position: static lets it flow inline.
#   2. At <=840px, upstream hides the "Mark as read" text button and keeps
#      only the dropdown toggle. Nord strips that toggle's left border and
#      radius (so it visually joined the text button), leaving a cut-off
#      edge once the text button is gone. Restore a normal left edge.
if [ -f "$NORD_CSS" ] && ! grep -q 'freshrss-patches: nav_menu fixes' "$NORD_CSS" 2>/dev/null; then
    cat >> "$NORD_CSS" <<'EOF'
/* freshrss-patches: nav_menu fixes */
.nav_menu #nav_menu_toggle_aside {
	position: static;
}
@media (max-width: 840px) {
	.nav_menu .stick #mark-read-menu .dropdown-toggle.btn {
		border-left: 1px solid var(--border-elements);
		border-top-left-radius: 6px;
		border-bottom-left-radius: 6px;
	}
}
EOF
    applied+=("Nord nav_menu layout fixes")
fi

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

# --- nbUnreadsPerFeed: exclude hidden feeds from notification poll ---
# Feeds with priority < PRIORITY_FEED (-5) are not rendered in the sidebar,
# but the nbUnreadsPerFeed endpoint still returns their unread counts. This
# causes refreshUnreads() to show the "new articles available" banner every
# 2 minutes in an infinite loop, since the JS can never sync a non-existent
# DOM element. This patch filters hidden feeds from the JSON response.
# See: https://github.com/FreshRSS/FreshRSS/issues/8694
NB_UNREADS="$FRESHRSS_DIR/app/views/javascript/nbUnreadsPerFeed.phtml"
if [ -f "$NB_UNREADS" ] && ! grep -q 'PRIORITY_FEED' "$NB_UNREADS" 2>/dev/null; then
    sed -i "s|\t\t\$result\['feeds'\]\[\$feed->id()\] = \$feed->nbNotRead();|\t\tif (\$feed->priority() >= FreshRSS_Feed::PRIORITY_FEED) {\n\t\t\t\$result['feeds'][\$feed->id()] = \$feed->nbNotRead();\n\t\t}|" "$NB_UNREADS"
    applied+=("nbUnreadsPerFeed hidden feed filter")
fi

if [ ${#applied[@]} -gt 0 ]; then
    echo "Applied patches: ${applied[*]}"
else
    echo "No patches needed (already applied or targets not found)"
fi
