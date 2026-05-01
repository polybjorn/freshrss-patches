#!/bin/bash
# Batched FreshRSS feed fetcher (wrapper for freshrss-fetch.php).
# Runs the PHP script as www-data; pass max feeds as the first argument.
set -euo pipefail

MAX_FEEDS="${1:-15}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
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

sudo -u www-data env \
    FRESHRSS_DIR="$FRESHRSS_DIR" \
    FRESHRSS_USER="$FRESHRSS_USER" \
    php "$SCRIPT_DIR/freshrss-fetch.php" "$MAX_FEEDS"
