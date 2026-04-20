#!/bin/bash
# Batched FreshRSS feed fetcher (wrapper for freshrss-fetch.php).
# Runs the PHP script as www-data; pass max feeds as the first argument.
set -euo pipefail

MAX_FEEDS="${1:-15}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

sudo -u www-data php "$SCRIPT_DIR/freshrss-fetch.php" "$MAX_FEEDS"
