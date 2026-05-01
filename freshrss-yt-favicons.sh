#!/bin/bash
# Download YouTube channel avatars as FreshRSS custom favicons.
# Suitable for monthly cadence: channel avatars rarely change.
set -euo pipefail

FRESHRSS_DIR="${FRESHRSS_DIR:-/var/www/FreshRSS}"

# Auto-detect the FreshRSS user when FRESHRSS_USER is unset. Most installs
# have a single user; multi-user installs must set the env var explicitly.
# The "_" directory is a FreshRSS internal placeholder and is excluded.
if [ -z "${FRESHRSS_USER:-}" ]; then
    users=()
    for d in "$FRESHRSS_DIR"/data/users/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        [ "$name" = "_" ] && continue
        users+=("$name")
    done
    if [ "${#users[@]}" -eq 1 ]; then
        FRESHRSS_USER="${users[0]}"
    elif [ "${#users[@]}" -eq 0 ]; then
        echo "No FreshRSS user found in $FRESHRSS_DIR/data/users/" >&2
        exit 1
    else
        echo "Multiple FreshRSS users found (${users[*]}). Set FRESHRSS_USER explicitly." >&2
        exit 1
    fi
fi

CONFIG="$FRESHRSS_DIR/data/config.php"
DB="$FRESHRSS_DIR/data/users/$FRESHRSS_USER/db.sqlite"
FAVICONS_DIR="$FRESHRSS_DIR/data/favicons"

if [ ! -f "$CONFIG" ] || [ ! -f "$DB" ]; then
    echo "FreshRSS not found at $FRESHRSS_DIR (user: $FRESHRSS_USER)" >&2
    exit 1
fi

SALT=$(grep -oP "'salt'\s*=>\s*'\K[^']+" "$CONFIG")

sqlite3 "$DB" "SELECT id, website FROM feed WHERE url LIKE '%YoutubeBridge%' OR (url LIKE '%FilterBridge%' AND url LIKE '%YoutubeBridge%');" | while IFS='|' read -r feed_id website; do
    [ -z "$website" ] && continue

    hash=$(php -r "echo hash('crc32b', '${SALT}${feed_id}${FRESHRSS_USER}');")
    ico_path="${FAVICONS_DIR}/${hash}.ico"

    avatar_url=$(curl -sL --max-time 10 "$website" 2>/dev/null | grep -oP '"avatar":\{"thumbnails":\[\{"url":"\K[^"]+' | head -1) || true

    if [ -z "$avatar_url" ]; then
        echo "FAIL $feed_id - no avatar found"
        continue
    fi

    if curl -sL --max-time 10 "$avatar_url" -o "$ico_path" 2>/dev/null; then
        sqlite3 "$DB" "UPDATE feed SET attributes = json_set(COALESCE(attributes, '{}'), '\$.customFavicon', json('true')) WHERE id = $feed_id;"
    else
        rm -f "$ico_path"
    fi

    sleep 1
done

chown -R www-data:www-data "$FAVICONS_DIR"
echo "YouTube favicon refresh complete"
